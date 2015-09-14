/*
 * Copyright (c) 2015 Adobe Systems Incorporated. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#import "DCXHTTPService.h"

#import "DCXError.h"
#import "DCXHTTPRequest_Internal.h"
#import "DCXHTTPResponse.h"
#import "DCXErrorUtils.h"
#import "DCXFileUtils.h"
#import "DCXNetworkUtils.h"
#import "DCXRequestOperation.h"

#import <libkern/OSAtomic.h>

// The allowed limit on request concurrency. Clients may configure
// this lower, but not higher.
const NSInteger DCXHTTPServiceMaxConcurrentRequests = 5;

/** The number of units of work we add to each http request progress to account for misc
 * work after completion and to avoid premature completion of a progress object if the request fails
 * after send all its data. */
int64_t const DCXHTTPProgressCompletionFudge = 10;

const NSInteger DCXHTTPServiceMaxAuthTokenHistory = 3;

///////////
//
// There have been bugs where iOS caches responses to non-GET requests (PUT, HEAD) and returns
// them as the cached response to a GET request. But there's no good reason to cache anything except a GET
// response, so this code enforces that.
//

@interface DCXURLCache : NSURLCache
@end

@implementation DCXURLCache {
    NSURLCache *_cache;
}

- (DCXURLCache *)initWithCache:(NSURLCache *)cache
{
    self = [super init];
    _cache = cache;
    return self;
}

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request
{
    return [_cache cachedResponseForRequest:request];
}

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request
{
    if ([cachedResponse.response isKindOfClass:NSHTTPURLResponse.class])
    {
        // If this is an HTTP request and isn't successful or isn't a GET, don't cache response
        NSHTTPURLResponse *urlresponse = (NSHTTPURLResponse *)(cachedResponse.response);

        if (urlresponse.statusCode != 200 ||
            [request.HTTPMethod caseInsensitiveCompare:@"GET"] != 0)
        {
            return;
        }
    }

    // Default behavior otherwise
    [_cache storeCachedResponse:cachedResponse forRequest:request];
}

@end

//
///////////

@interface DCXHTTPService ()

@property (atomic, assign) BOOL shouldStopEnqueueingRequests;

@end

// NOTE: Most methods on this class may be invoked simultaneously on multiple threads.
// There are two major thread-safety considerations that must be taken into account:
//
// 1) The request queue. This object is itself thread-safe, so it can be accessed
//    directly at any time.
//
// 2) Delegate notification. When the delegate is notified of an auth failure, we need
//    to guarantee that it's called only once per token, plus update the associated
//    state in `recentAuthTokens` and `shouldRescheduleOnFailure`. This is accomplished
//    by synchronizing all such access on the `recentAuthTokens` object.

@implementation DCXHTTPService
{
    // The queue that dispatches requests to this service.
    NSOperationQueue *_requestQueue;

    // A list of the last MAX_NUM_CONCURRENT_REQUESTS tokens for which the delegate
    // (if any) has received an HTTPServiceAuthenticationDidFail: message. It is
    // used to avoid sending the delegate a second message for any single token.
    // The most recent token is at index 0; the least recent at n-1.
    NSMutableArray *_recentAuthTokens;

    // A list of the history of authentications bounded to DCXHTTPServiceMaxAuthTokenHistory.
    NSMutableArray *_authTokenHistory;

    // When a delegate is notified about an authentication failure, it can ask
    // for the failed requests to be retried when the queue is re-started. We
    // record that response here and re-use it for any requests that were in-flight
    // at that time, and also failed on the same error.
    BOOL _shouldRescheduleOnFailure;

    // Keeps track of the number of recent errors.
    volatile int32_t _recentErrorCount;

    // At this point DCXHTTPService uses only one URL session for all requests.
    NSURLSession *_session;

    // Dictionary to keep track of and look up active request operations by their url session task.
    NSMutableDictionary *_activeRequestOperations;
}

- (instancetype)initWithUrl:(NSURL *)url
      additionalHTTPHeaders:(NSDictionary *)additionalHTTPHeaders
{
    self = [super init];

    if (self)
    {
        _requestQueue = [[NSOperationQueue alloc] init];
        _requestQueue.maxConcurrentOperationCount = DCXHTTPServiceMaxConcurrentRequests;

        _baseURL = url;
        _recentAuthTokens = [NSMutableArray arrayWithCapacity:DCXHTTPServiceMaxConcurrentRequests];
        _authTokenHistory = [NSMutableArray arrayWithCapacity:DCXHTTPServiceMaxAuthTokenHistory];

        _shouldRescheduleOnFailure = NO;

        _recentErrorCount = 0;
        _recentErrorThresholdToDisconnect = 5;
        _retryOn5xxDelays =  @[@.1, @1, @2]; // Retry 3 times after .1, 1, and 2 seconds

        _activeRequestOperations = [NSMutableDictionary dictionaryWithCapacity:DCXHTTPServiceMaxConcurrentRequests];

        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.HTTPMaximumConnectionsPerHost = DCXHTTPServiceMaxConcurrentRequests;
        NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:additionalHTTPHeaders];
        sessionConfiguration.HTTPAdditionalHeaders = headers;
        
        NSURLCache *networkServiceCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                                        diskCapacity:0
                                                                            diskPath:nil];
        sessionConfiguration.URLCache = [[DCXURLCache alloc] initWithCache:networkServiceCache];
        sessionConfiguration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
        
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
    }

    return self;
}

#pragma mark - Helper Methods


- (NSMutableURLRequest *)prepareRequest:(NSURLRequest *)request withAuthToken:(NSString *)token
                                  andId:(NSString *)requestId
{
    NSMutableURLRequest *result = [request mutableCopy];

    // Clients may pass in requests with relative URLs; make them absolute using the base URL of this service.
    [result setURL:[NSURL URLWithString:request.URL.absoluteString relativeToURL:self.baseURL]];

    if (token)
    {
        // Inject the auth token
        NSString *authString = [NSString stringWithFormat:@"Bearer %@", token];
        [result setValue:authString forHTTPHeaderField:@"Authorization"];
    }

    NSDictionary *allHeaders = [result allHTTPHeaderFields];
    NSDictionary *updatedHdrs = [DCXNetworkUtils encodeRequestHeaders:allHeaders];

    [result setAllHTTPHeaderFields:updatedHdrs];

    return result;
}

#pragma mark - Queue Operation

- (void)setConcurrentRequestCount:(NSInteger)concurrentRequestCount
{
    if (concurrentRequestCount < 1 || concurrentRequestCount > DCXHTTPServiceMaxConcurrentRequests)
    {
        NSException *ex = [NSException exceptionWithName:NSRangeException reason:@"Allowable concurrent request count range is 1..5" userInfo:nil];
        @throw ex;
    }

    _requestQueue.maxConcurrentOperationCount = concurrentRequestCount;
}

- (NSInteger)concurrentRequestCount
{
    return _requestQueue.maxConcurrentOperationCount;
}

- (void)setAuthToken:(NSString *)authToken
{
    @synchronized(_authTokenHistory){
        _authToken = authToken;

        if (authToken)
        {
            if (_authTokenHistory.count >= DCXHTTPServiceMaxAuthTokenHistory)
            {
                [_authTokenHistory removeLastObject];
            }

            [_authTokenHistory insertObject:[NSDate date] atIndex:0];
        }
        else
        {
            [_authTokenHistory removeAllObjects];
        }
    };
}

- (void)setSuspended:(BOOL)suspended
{
    _requestQueue.suspended = suspended;
}

- (BOOL)isSuspended
{
    return _requestQueue.isSuspended;
}

- (BOOL)hasEncounteredTooManyAuthFailures
{
    __block BOOL tooManyFailures = YES;

    if (_authTokenHistory.count < DCXHTTPServiceMaxAuthTokenHistory)
    {
        tooManyFailures = NO;
    }
    else
    {
        NSDate *fiveMinutesAgo = [[NSDate date] dateByAddingTimeInterval:-60 * 5];

        [_authTokenHistory enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
        {
            NSDate *tokenTimestamp = (NSDate *)obj;

            if ([tokenTimestamp timeIntervalSinceDate:fiveMinutesAgo] < 0)
            {
                tooManyFailures = NO;
                *stop = YES;
            }
        }];
    }

    return tooManyFailures;
}

- (void)reconnect
{
    _recentErrorCount = 0;
}

- (void)clearQueuedRequests
{
    [_requestQueue cancelAllOperations];
}

- (BOOL)isConnected
{
    BOOL connected = (_recentErrorCount < _recentErrorThresholdToDisconnect);

    return connected;
}

// Factored out the actual network requests to enable derived mock classes.

- (NSURLSessionTask *)createAsynchronousDataRequest:(NSURLRequest *)preparedRequest withSession:(NSURLSession *)session
{
    return [session dataTaskWithRequest:preparedRequest];
}

- (NSURLSessionTask *)createAsynchronousDownloadRequest:(NSURLRequest *)preparedRequest withSession:(NSURLSession *)session
{
    return [session downloadTaskWithRequest:preparedRequest];
}

- (NSURLSessionTask *)createAsynchronousUploadRequest:(NSURLRequest *)preparedRequest fromFile:(NSURL *)fileURL
                                          withSession:(NSURLSession *)session
{
    return [session uploadTaskWithRequest:preparedRequest fromFile:fileURL];
}

- (void)sendAsynchronousRequest:(NSURLRequest *)preparedRequest
                   forOperation:(DCXRequestOperation *)operation
              completionHandler:(void (^)(DCXHTTPResponse *))handler
{
    NSURLSessionTask *task = nil;

    // Create the appropriate kind of task
    switch (operation.type)
    {
        case DCXDataRequestType:
            task = [self createAsynchronousDataRequest:preparedRequest withSession:_session];
            break;

        case DCXDownloadRequestType:
            task = [self createAsynchronousDownloadRequest:preparedRequest withSession:_session];
            break;

        case DCXUploadRequestType:
            task = [self createAsynchronousUploadRequest:preparedRequest fromFile:[NSURL fileURLWithPath:operation.path]
                                             withSession:_session];
            break;
    }

    if (task != nil)
    {
        // Configure the task
        operation.sessionTask = task;   // So that the operation can cancel the active request
        operation.completionHandler = handler;

        // In the case where this DCXHTTPService was initialized via
        // -initWithUrl:application:additionalHTTPHeaders:backgroundIdentifier:andSessionDelegate, the NSURLSessionDelegate
        // will be handled externally, in which case, the managing of requests is up to the external delegate.
        if ([_session.delegate isEqual:self])
        {
            @synchronized(_activeRequestOperations){
                [_activeRequestOperations setObject:operation forKey:task];
            }
        }

        // Start the task
        [task resume];
    }
}

- (void)processQueuedOperation:(DCXRequestOperation *)requestOperation
{
    // For errors that indicate temporary conditions, such as an authentication failure,
    // the failing operation will be rescheduled and the requestor will *not* be notified.
    BOOL shouldRescheduleThisRequest = NO;

    // In the case of intermittent server errors (5xx responses) we want to retry for a number
    // of times before giving up. These variables control that behavior.
    BOOL keepTrying = YES;
    NSUInteger retryCount = 0;

    __block DCXHTTPResponse *result = nil;

    BOOL uploadAbortedDueToMissingFile = NO;

    if (requestOperation.type == DCXUploadRequestType)
    {
        // Confirm the existence of the file to be uploaded.  Otherwise an upload task for a non-existent file
        // will actually succeed but with an empty body, which leads to an empty file being created on the server.
        if (![[NSFileManager defaultManager] fileExistsAtPath:requestOperation.path])
        {
            result = [[DCXHTTPResponse alloc] init];
            result.error = [DCXErrorUtils ErrorWithCode:DCXErrorFileDoesNotExist
                                                          domain:DCXErrorDomain
                                                         details:[NSString stringWithFormat:@"File %@ does not exist", requestOperation.path]];
            uploadAbortedDueToMissingFile = YES;
        }
    }

    // Get a strong reference to the delegate.
    id<DCXHTTPServiceDelegate> strongDelegate = self.delegate;

    if (!uploadAbortedDueToMissingFile)
    {
        while (keepTrying && !requestOperation.isCancelled)
        {
            if (retryCount > 0)
            {
                // We need to wait a while before trying again
                NSTimeInterval delay = 0;
                @synchronized(_retryOn5xxDelays)
                {
                    delay = [[_retryOn5xxDelays objectAtIndex:retryCount - 1] doubleValue];
                }
                [NSThread sleepForTimeInterval:delay];
            }

            if (!self.isConnected)
            {
                // Short circuit the case where the service got disconnected and we didn't get a chance
                // to flush the queue yet.
                result = [[DCXHTTPResponse alloc] init];
                result.error = [DCXErrorUtils ErrorWithCode:DCXErrorServiceDisconnected domain:DCXErrorDomain details:nil];
                break;
            }

            // Prepare the request.
            NSString *tokenForThisRequest = nil;
            @synchronized(_authToken)
            {
                tokenForThisRequest = _authToken;
            }

            NSMutableURLRequest *preparedRequest = [self prepareRequest:requestOperation.request withAuthToken:tokenForThisRequest andId:requestOperation.id];
            NSCondition *condition = [[NSCondition alloc] init];

            // Make the request.
            result = nil;
            [self sendAsynchronousRequest:preparedRequest forOperation:requestOperation
                        completionHandler:^(DCXHTTPResponse *response)
            {
                requestOperation.sessionTask = nil;
                [condition lock];
                result = response;
                [condition signal];
                [condition unlock];
            }];

            // Since we are calling into an asynchronous API above we wait here for its completion.
            [condition lock];

            while (result == nil)
            {
                [condition wait];
            }
            [condition unlock];

            NSInteger statusCode = result.statusCode;

            if (statusCode == 401 || (statusCode == 400 && _authToken == nil)) // authentication failure
            {
                result.error = [DCXErrorUtils ErrorWithCode:DCXErrorAuthenticationFailed
                                                              domain:DCXErrorDomain response:result
                                                             details:nil];

                // Inform the delegate (if there is one) and pause the request queue. There's no point
                // in hammering the server with requests that will also fail.
                @synchronized(_recentAuthTokens)
                {
                    // It's possible that a token wasn't set, which is why authentication failed. Our operating
                    // assumption is that the client will then set a token and retry. In order re-use our logic
                    // that guarantees a single call to the delegate, use a special token value for this case.
                    // Note that this value never gets sent to the server; it's only used as a placeholder in the
                    // recentAuthTokens array.

                    if (!tokenForThisRequest)
                    {
                        tokenForThisRequest = @"no-token";
                    }

                    NSUInteger indexOfToken = [_recentAuthTokens indexOfObjectPassingTest:^BOOL (id obj, NSUInteger idx, BOOL *stop)
                    {
                        return [obj isEqualToString:tokenForThisRequest];
                    }];
                    BOOL alreadyAddressed = (indexOfToken != NSNotFound);

                    if (!alreadyAddressed && strongDelegate != nil)
                    {
                        _requestQueue.suspended = YES;
                        _shouldRescheduleOnFailure = [strongDelegate HTTPServiceAuthenticationDidFail:self];
                    }

                    if (!alreadyAddressed)
                    {
                        if (_recentAuthTokens.count >= DCXHTTPServiceMaxConcurrentRequests)
                        {
                            [_recentAuthTokens removeLastObject];
                        }

                        [_recentAuthTokens insertObject:tokenForThisRequest atIndex:0];
                    }

                    shouldRescheduleThisRequest = _shouldRescheduleOnFailure;
                    keepTrying = NO;
                }
            }
            else if (statusCode == 403) // HTTP Forbidden error
            {
                result.error = [DCXErrorUtils ErrorWithCode:DCXErrorRequestForbidden
                                                              domain:DCXErrorDomain
                                                             details:nil];
                keepTrying = NO;
            }
            else if ((statusCode > 499) &&
                     (statusCode < 600) &&
                     (statusCode != 501) &&     // 501 = not implemented
                     (statusCode != 507))       // 507 = quota exceeded
            {
                //
                // A 5xx response code.
                // This can be an intermittent failure. We want to retry.
                @synchronized(_retryOn5xxDelays)
                {
                    keepTrying = (retryCount < _retryOn5xxDelays.count);
                }

                if (keepTrying)
                {
                    retryCount++;
                    DCXHTTPRequest *strongRequest = requestOperation.weakClientRequestObject;

                    if (strongRequest != nil)
                    {
                        // Need to reset the progress for this operation
                        strongRequest.progress.completedUnitCount = 0;
                    }

                    // Need to reset these for the next iteration of the loop.
                    result = nil;
                    requestOperation.receivedData = nil;
                }
            }
            else
            {
                // Success
                keepTrying = NO;
            }
        }
    }

    // Do not update error statistics for cancelations.
    NSError *localErr = result.error;
    BOOL isCancelled = localErr && (([localErr.domain isEqualToString:DCXErrorDomain] &&
                                     (localErr.code == DCXErrorCancelled))
                                    ||
                                    ([localErr.domain isEqualToString:NSURLErrorDomain] &&
                                     (localErr.code == NSURLErrorCancelled)));

    if (!isCancelled && !uploadAbortedDueToMissingFile && !shouldRescheduleThisRequest)
    {
        // Update our error statistics. For now we simply keep a running count of recent errors from
        // which we subtract all successful requests.
        if (result.error != nil)
        {
            // Using atomic operations to increment the error count. Can't use straight forward
            // OSAtomicIncrement32Barrier since we need to make sure that we notify the delegate
            // exactly once when we reach the threshold.
            BOOL incremented = NO;

            while (!incremented)
            {
                int32_t oldValue = _recentErrorCount;
                int32_t newValue = oldValue + 1;
                incremented = OSAtomicCompareAndSwap32Barrier(oldValue, newValue, &_recentErrorCount);

                if (incremented && (newValue == _recentErrorThresholdToDisconnect) && strongDelegate != nil)
                {
                    // We do not flush the queue here but rather rely on it going through all
                    // the remaining requests which will then fail with a DCXErrorServiceDisconnected
                    // error.
                    [strongDelegate HTTPServiceDidDisconnect:self];
                }

                NSLog(@"DCXHTTPService error: %@ - %ld.  Incremented error count to: %d",
                         result.error.domain, (long)result.error.code, _recentErrorCount);
            }
        }
        else
        {
            if (_recentErrorCount > 0)
            {
                // In theory _recentErrorCount can be decremented to 0 or below in between the check
                // above and the call below, but we just accept that possibility in order to avoid doing
                // more costly synchronization since this is the normal (no error) case.
                OSAtomicDecrement32Barrier(&_recentErrorCount);
            }
        }
    }

    if (shouldRescheduleThisRequest && !self.shouldStopEnqueueingRequests)
    {
        [_requestQueue addOperation:[requestOperation copy]];
    }
    else
    {
        [requestOperation notifyRequesterOfResponse:result];
    }
}

- (DCXHTTPRequest *)scheduleRequest:(NSURLRequest *)request
                                      ofType:(DCXRequestType)type
                                    withPath:(NSString *)path
                             requestPriority:(NSOperationQueuePriority)priority
                           completionHandler:(void (^)(DCXHTTPResponse *))handler
{
    NSError *error = nil;
    
    // If shouldStopEnqueueingRequests is YES, it means we're in the process of invalidating
    // this service and that new requests may not be enqueued.
    if (self.shouldStopEnqueueingRequests)
    {
        error = [DCXErrorUtils ErrorWithCode:DCXErrorServiceInvalidating
                                      domain:DCXErrorDomain
                                     details:@"No new requests could be enqueued because the service is in the process of invalidating."];
    }
    
    // Enforce https protocol:
    if (![request.URL.scheme isEqualToString:@"https"]) {
        error = [DCXErrorUtils ErrorWithCode:DCXErrorUnsupportedProtocol
                                      domain:DCXErrorDomain
                                     details:@"Must use https protocol."];
    }
    
    if (error != nil) {
        if (handler)
        {
            DCXHTTPResponse *result = [[DCXHTTPResponse alloc] init];
            result.error = error;
            handler(result);
        }
        return nil;
    }
    
    // Create a request operation for the request
    DCXRequestOperation *op = [[DCXRequestOperation alloc] init];
    op.request = request;
    op.type = type;
    op.path = path;
    op.invocationBlock = ^(DCXRequestOperation *request){
        [self processQueuedOperation:request];
    };
    op.notificationBlock = ^(DCXHTTPResponse *response){
        handler(response);
    };

    DCXHTTPRequest *httpRequest = [[DCXHTTPRequest alloc] initWithProgress:[NSProgress progressWithTotalUnitCount:-1]
                                                           andOperation:op];

    op.weakClientRequestObject = httpRequest;
    httpRequest.priority = priority;
    [_requestQueue addOperation:op];

    // Return the client-facing request object
    return httpRequest;
}

- (DCXHTTPResponse *)waitForRequest:(NSURLRequest *)request
                                      ofType:(DCXRequestType)type
                                    withPath:(NSString *)path
                                withPriority:(NSOperationQueuePriority)priority
                                     options:(NSDictionary *)options
{
    NSCondition *condition = [[NSCondition alloc] init];
    DCXHTTPResponse *__block result;

    [self scheduleRequest:request ofType:type withPath:path requestPriority:priority
        completionHandler:^(DCXHTTPResponse *response){
            [condition lock];
            result = response;
            [condition signal];
            [condition unlock];
        }];

    [condition lock];

    while (!result)
    {
        [condition wait];
    }
    [condition unlock];

    return result;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([object isEqual:_requestQueue] && [keyPath isEqualToString:@"operationCount"])
    {
        NSNumber *newValue = change[NSKeyValueChangeNewKey];
        NSUInteger operationCount = [newValue unsignedIntegerValue];

        if (operationCount == 0)
        {
            // When the operationCount gets to 0, finish up the remaining tasks submitted to the NSURLSession and remove
            // ourselves as an observer.
            [_session finishTasksAndInvalidate];

            @try
            {
                [_requestQueue removeObserver:self forKeyPath:@"operationCount"];
            }
            @catch (NSException *exception)
            {
                NSLog(@"Caught an exception when trying to remove an observer:\n%@", exception);
            }
        }
    }
}

#pragma mark - NSURL delegate protocol

/* Helper method to update the operation's progress object from the given task. */
- (void)updateProgressFromTask:(NSURLSessionTask *)task
{
    DCXRequestOperation *operation = nil;

    @synchronized(_activeRequestOperations){
        operation = _activeRequestOperations[task];
    }

    if (operation != nil)
    {
        int64_t total = task.countOfBytesExpectedToReceive + task.countOfBytesExpectedToSend + DCXHTTPProgressCompletionFudge;
        int64_t completed = task.countOfBytesReceived + task.countOfBytesSent;

        DCXHTTPRequest *strongRequest = operation.weakClientRequestObject;

        if (strongRequest != nil)
        {
            @synchronized(strongRequest.progress){
                NSProgress *progress = strongRequest.progress;

                if (!progress.isCancelled)
                {
                    if (progress.totalUnitCount < total)
                    {
                        progress.totalUnitCount = total;
                    }

                    progress.completedUnitCount = MIN(completed, progress.totalUnitCount);
                }
            }
        }
    }
}

/*
 * The following methods implement that various delegate callbacks that are necessary to support the
 * different NSURLSessionTasks.
 */

// ------------------------------------------------------------------
// NSURLSessionTaskDelegate protocol
// ------------------------------------------------------------------

/* The task has completed. We construct a response and call the appropriate handler. */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    DCXRequestOperation *operation = nil;

    @synchronized(_activeRequestOperations){
        operation = _activeRequestOperations[task];
    }

    if (operation != nil)
    {
        @synchronized(_activeRequestOperations){
            [_activeRequestOperations removeObjectForKey:task];
        }

        // Setting the session task on the operation to nil so that we do not get called again
        // should the client cancel the request.
        operation.sessionTask = nil;

        // Construct a response
        DCXHTTPResponse *response = [[DCXHTTPResponse alloc] init];
        response.URL           = task.response.URL;
        response.error         = (error != nil ? error : operation.error);
        response.bytesReceived = task.countOfBytesReceived;
        response.bytesSent     = task.countOfBytesSent;
        response.path          = operation.path;
        response.data          = operation.receivedData;

        // Reinterpret a possible NSURLErrorCancelled error
        NSError *e = response.error;

        if (e != nil && e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled)
        {
            response.error = [DCXErrorUtils ErrorWithCode:DCXErrorCancelled domain:DCXErrorDomain
                                                   underlyingError :error details:nil];
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;

        if (httpResponse != nil)
        {
            //
            // response.allHeaderFields uses case-sensitive keys. Since the identifiers for HTTP header fields are supposed
            // be case-insensitive we create a copy of that dictionary with all keys converted to lower case.
            NSDictionary *lowercaseHeaders = [DCXNetworkUtils lowerCaseKeyedCopyOfDictionary:httpResponse.allHeaderFields];

            // Non-ascii keys in response.allHeaderFields are RFC 2047-encoded ( see http://www.ietf.org/rfc/rfc2047.txt ).
            // Decode them.
            response.headers    = [DCXNetworkUtils decodeResponseHeaders:lowercaseHeaders];

            response.statusCode = (int)httpResponse.statusCode;
        }

        if (response.error == nil && ((response.statusCode >= 200 && response.statusCode < 300 && response.statusCode != 202)
                                      || response.statusCode == 304))
        {
            DCXHTTPRequest *strongRequest = operation.weakClientRequestObject;

            if (strongRequest != nil)
            {
                strongRequest.progress.completedUnitCount = MIN(strongRequest.progress.completedUnitCount + DCXHTTPProgressCompletionFudge, strongRequest.progress.totalUnitCount);
            }
        }

        // Call completion handler for the operation.
        if (operation.completionHandler != nil)
        {
            operation.completionHandler(response);
            operation.completionHandler = nil;
        }
        else
        {
            NSLog(@"Completion handler for request was nil: %@", task.originalRequest);
        }
    }
}

/* The task did send some data. We just update the appropriate progress object. */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    [self updateProgressFromTask:task];
}

// ------------------------------------------------------------------
// NSURLSessionDataDelegate protocol
// ------------------------------------------------------------------

/* Data has been received for a data task. We collect the data in the corresponding DCXRequestOperation object. */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    DCXRequestOperation *operation = nil;

    @synchronized(_activeRequestOperations){
        operation = _activeRequestOperations[dataTask];
    }

    if (operation != nil)
    {
        if (operation.receivedData == nil)
        {
            operation.receivedData = [data mutableCopy];
        }
        else
        {
            [operation.receivedData appendData:data];
        }

        [self updateProgressFromTask:dataTask];
    }
}

// ------------------------------------------------------------------
// NSURLSessionDownloadDelegate protocol
// ------------------------------------------------------------------

/* A download to a file has completed. We move the file to the proper location. */
- (void)           URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location
{
    DCXRequestOperation *operation = nil;

    @synchronized(_activeRequestOperations){
        operation = _activeRequestOperations[downloadTask];
    }
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)downloadTask.response;

    if (operation != nil && httpResponse != nil && httpResponse.statusCode == 200)
    {
        // Atomically move the downloaded file into place
        NSError *error = nil;
        [DCXFileUtils moveFileAtomicallyFrom:location.path to:operation.path withError:&error];

        if (error != nil)
        {
            operation.error = error;
        }
    }
}

/* The task did receive some data. We just update the appropriate progress object. */
- (void)   URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    [self updateProgressFromTask:downloadTask];
}

/* The task did receive some data. We just update the appropriate progress object. */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    [self updateProgressFromTask:downloadTask];
}

#pragma mark - Public API

- (DCXHTTPRequest *)getResponseForDataRequest:(NSURLRequest *)request
                                       requestPriority:(NSOperationQueuePriority)priority
                                     completionHandler:(void (^)(DCXHTTPResponse *))handler
{
    return [self scheduleRequest:request
                          ofType:DCXDataRequestType
                        withPath:nil
                 requestPriority:priority
               completionHandler:handler];
}

- (DCXHTTPRequest *)getResponseForDownloadRequest:(NSURLRequest *)request
                                                    toPath:(NSString *)path
                                           requestPriority:(NSOperationQueuePriority)priority
                                         completionHandler:(void (^)(DCXHTTPResponse *))handler
{
    return [self scheduleRequest:request
                          ofType:DCXDownloadRequestType
                        withPath:path
                 requestPriority:priority
               completionHandler:handler];
}

- (DCXHTTPRequest *)getResponseForUploadRequest:(NSURLRequest *)request
                                                fromPath:(NSString *)path
                                         requestPriority:(NSOperationQueuePriority)priority
                                       completionHandler:(void (^)(DCXHTTPResponse *))handler
{
    return [self scheduleRequest:request
                          ofType:DCXUploadRequestType
                        withPath:path
                 requestPriority:priority
               completionHandler:handler];
}

@end
