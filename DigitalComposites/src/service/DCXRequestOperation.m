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

#import "DCXRequestOperation.h"

#import "DCXError.h"
#import "DCXHTTPRequest_Internal.h"
#import "DCXHTTPResponse.h"
#import "DCXErrorUtils.h"

@implementation DCXRequestOperation {
    __weak DCXHTTPRequest *_weakClientRequestObject;
}

- (id)init
{
    if (self = [super init])
    {
        _id = [[NSUUID UUID] UUIDString];
        _originalId = _id;
        _receivedData = nil;
        _error = nil;
    }

    return self;
}

- (DCXHTTPRequest *)weakClientRequestObject
{
    return _weakClientRequestObject;
}

- (void)setWeakClientRequestObject:(DCXHTTPRequest *)clientRequestObject
{
    // Need to set the cancellation handler of the progress object.
    if (clientRequestObject != nil)
    {
        __weak DCXRequestOperation *weakSelf = self;
        clientRequestObject.progress.cancellationHandler = ^(void){
            DCXRequestOperation *strongSelf = weakSelf;

            if (strongSelf != nil)
            {
                [strongSelf cancel];
            }
        };
    }

    _weakClientRequestObject = clientRequestObject;
}

- (void)main
{
    @autoreleasepool {
        self.invocationBlock(self);
    }
}

- (void)notifyRequesterOfResponse:(DCXHTTPResponse *)response
{
    self.notificationBlock(response);
}

// Overriding cancel method
- (void)cancel
{
    // Call super class -- This removes the operation from its queue if it is still queued.
    [super cancel];

    if (_sessionTask != nil && _sessionTask.state != NSURLSessionTaskStateCompleted)
    {
        // Need to cancel the active task
        [_sessionTask cancel];
    }
    else
    {
        // Notify requester by sending it a DCXErrorCancelled.
        DCXHTTPResponse *response = [[DCXHTTPResponse alloc] init];
        response.error = [DCXErrorUtils ErrorWithCode:DCXErrorCancelled domain:DCXErrorDomain details:nil];
        [self notifyRequesterOfResponse:response];
    }
}

#pragma mark NSCopying protocol

- (id)copyWithZone:(NSZone *)zone
{
    DCXRequestOperation *result = [[DCXRequestOperation allocWithZone:zone] init];

    result.request             = self.request;
    result.type                = self.type;
    result.path                = self.path;
    result.invocationBlock     = self.invocationBlock;
    result.notificationBlock   = self.notificationBlock;
    result.originalId          = self.originalId;

    // Need to make sure that the client request object gets copied over and redirected to point
    // to the new operation.
    DCXHTTPRequest *strongRequest = self.weakClientRequestObject;

    if (strongRequest != nil)
    {
        NSOperationQueuePriority priority = strongRequest.priority;
        result.weakClientRequestObject = strongRequest;
        strongRequest.operation = result;
        strongRequest.priority = priority;

        // Reset progress
        strongRequest.progress.completedUnitCount = -1;
    }

    return result;
}

@end
