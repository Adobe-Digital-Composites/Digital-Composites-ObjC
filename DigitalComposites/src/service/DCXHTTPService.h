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

#import <Foundation/Foundation.h>

@class DCXHTTPResponse;
@class DCXHTTPRequest;

/** The number of units of work we add to each http request progress to account for misc
 * work after completion and to avoid premature completion of a progress object if the request fails
 * after send all its data. */
extern int64_t const DCXHTTPProgressCompletionFudge;

/** Protocol for the AdobeNetworkHTTPService delegate. */
@class DCXHTTPService;
@protocol DCXHTTPServiceDelegate <NSObject>

@required

/**
 * If a request issued by an instance of DCXHTTPService fails with an authentication
 * error, the service will invoke this method on its delegate.
 *
 * @param service The service that encountered the authentication failure.
 *
 * @return If the delegate returns YES, then the authentication call will be retried after
 * the queue is re-started. If it returns NO, then the original authentication call
 * will return immediately with an error.
 *
 * Typically, a delegate should use this method to obtain a revised authentication token,
 * and then inform the service of the revised token via DCXHTTPService::setAuthToken:.
 *
 * When this method is called, the request queue for the given service will have been
 * paused in order to avoid spamming the server with multiple requests for the same
 * expired token. The client must arrange to set DCXHTTPService::suspended to NO in order
 * to restart requests.
 *
 * The delegate may set both the authToken and suspended state of the service during this
 * call, or at any time after this call.
 *
 * DCXHTTPService guarantees that it will call this method exactly once per token,
 * assuming tokens are not recycled. It also guarantees that only one invocation will
 * happen at a time. There are no guarantees as to which threasd invocation will occur on.
 *
 * @note You should check service::hasEncounteredTooManyAuthFailures to see if the service has
 * encountered too many authentication failures in last five minutes.
 */
- (BOOL)HTTPServiceAuthenticationDidFail:(DCXHTTPService *)service;

/**
 * Gets called if the service got disconnected. This usually happens because it experienced too many
 * recent failures (see AdobeNetworkHTTPSession for details).
 *
 * @param service The service that has been disconnected.
 */
- (void)HTTPServiceDidDisconnect:(DCXHTTPService *)service;

@end


/**
 * DCXHTTPService represents a specific instance of a service and allows any necessary customization.
 *
 * Service session objects, like DCXSession, are configured with one of
 * these in order to connect to a specific environment, such as staging or production.
 *
 * ### Threading
 *
 * Methods on this class may be invoked on any thread. Instances of this manage one thread for
 * each allowed concurrent request. (See setConcurrentRequest: count for information on this
 * property.)
 */
@interface DCXHTTPService : NSObject <NSURLSessionDataDelegate, NSURLSessionDownloadDelegate, NSURLSessionTaskDelegate>

/**
 * Designated initializer.
 *
 * @param url The base url of the service
 * @param additionalHTTPHeaders Any kvp that are to be added to the HTTP headers.
 */
- (instancetype)initWithUrl:(NSURL *)url additionalHTTPHeaders:(NSDictionary *)additionalHTTPHeaders;

/**
 * The base URL of this service. All requests are
 * resolved relative to this URL, although requests may contain absolute URLs.
 */
@property (nonatomic, readwrite, strong) NSURL *baseURL;

/**
 * The number of requests that may be issued to this service in parallel.
 * Must be in the range 1-5.
 *
 * This value can be modified for a service that is in use. Raising the number
 * will cause any additional pending requests to be started immediately.
 * Lowering the value will not affect already-issued requests, and will cause
 * all pending requests to remain queued until the current operation count drops
 * below the new limit.
 */
@property NSInteger concurrentRequestCount;

/**
 * Whether or not issuing requests to this service is suspended. When the service
 * is suspended, new requests can be made but they will only be added to the queue.
 */
@property (getter = isSuspended) BOOL suspended;

/** Set the authentication token to be used with all outgoing requests. */
@property (nonatomic, strong) NSString *authToken;

/**
 * Whether or not the service is currently connected. A disconnected service will not try to send new
 * requests to the server but rather let them fail with a DCXServiceDisconnected error.
 * A service starts out being connected and will disconnect once the number of recent errors have reached
 * the threshold defined by recentErrorThresholdToDisconnect. When this happens the service delegate
 * will be notified.
 * The delegate then can call reconnect: in order to restart the service.
 */
@property (readonly, getter = isConnected) BOOL connected;

/**
 * The number of recent errors that will make the service disconnect itself. Default is 5
 */
@property NSInteger recentErrorThresholdToDisconnect;

/**
 * This is an array of NSTimeInterval values. The number and values of the entries determine how often
 * and with what length of a delay (in seconds) a request that has failed with a 5xx response code
 * will be retried before it fails. Default is @[@0.1, @1, @2] which makes the servive retry these
 * requests three times with a delay of 0.1, 1, and 2 seconds on each successive attempt.
 */
@property NSArray *retryOn5xxDelays;

/**
 * The primary delegate for this class; it is notified of any authentication
 * failures that occur. Notice that this is a weak reference.
 */
@property (weak) id<DCXHTTPServiceDelegate> delegate;

/**
 * Reconnects a disconnected service.
 */
- (void)reconnect;

/**
 * Clear the request queue.
 */
- (void)clearQueuedRequests;

/**
 * Tests to see if the authentication failure rate is too high.
 *
 * @return YES if there have been too many authentication failures in the last five minutes.
 */
- (BOOL)hasEncounteredTooManyAuthFailures;

/**
 * /brief Issues the given request to this service asynchronously.
 *
 * @param request   The request to make.
 * @param priority  The initial priority of the request.
 * @param handler   Upon completion, the specified handler is invoked; no guarantees are made as to which
 *                  thread it is invoked on.
 *
 * @return          A DCXHTTPRequest object that can be used to track progress, adjust the priority of
 *                  the request and to cancel it.
 */
- (DCXHTTPRequest *)getResponseForDataRequest:(NSURLRequest *)request
                              requestPriority:(NSOperationQueuePriority)priority
                            completionHandler:(void (^)(DCXHTTPResponse *))handler;

/**
 * Downloads a file to the given path asynchronously.
 *
 * @param request   The request to make.
 * @param path      A path including file name that determines where the file will be saved. An existing
 *                  file at the same location will be overriden.
 * @param priority  The initial priority of the request.
 * @param handler   Upon completion, the specified handler is invoked; no guarantees are made as to which
 *                  thread it is invoked on.
 *
 * @return          A DCXHTTPRequest object that can be used to track progress, adjust the priority of
 *                  the request and to cancel it.
 */
- (DCXHTTPRequest *)getResponseForDownloadRequest:(NSURLRequest *)request toPath:(NSString *)path
                                           requestPriority:(NSOperationQueuePriority)priority
                                         completionHandler:(void (^)(DCXHTTPResponse *))handler;

/**
 * Uploads the file at the given path asynchronously.
 *
 * @param request   The request to make.
 * @param path      A path specifying the file to upload.
 * @param priority  The initial priority of the request.
 * @param handler   Upon completion, the specified handler is invoked; no guarantees are made as to which
 *                  thread it is invoked on.
 *
 * @return          A DCXHTTPRequest object that can be used to track progress, adjust the priority of
 *                  the request and to cancel it.
 */
- (DCXHTTPRequest *)getResponseForUploadRequest:(NSURLRequest *)request fromPath:(NSString *)path
                                         requestPriority:(NSOperationQueuePriority)priority
                                       completionHandler:(void (^)(DCXHTTPResponse *))handler;

@end
