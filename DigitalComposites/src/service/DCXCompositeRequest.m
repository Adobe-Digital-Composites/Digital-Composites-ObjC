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

#import "DCXCompositeRequest.h"

#import "DCXHTTPRequest_Internal.h"

@implementation DCXCompositeRequest {
    NSMutableArray *_requests;
    NSOperationQueuePriority _priority;
    BOOL _complete;
}

- (id)initWithPriority:(NSOperationQueuePriority)priority
{
    self = [super initWithProgress:[NSProgress progressWithTotalUnitCount:-1] andOperation:nil];
    _priority = priority;
    _complete = NO;

    return self;
}

- (void)addComponentRequest:(DCXHTTPRequest *)request
{
    NSAssert(request != nil, @"Param 'request' must not be nil");

    if (_requests == nil)
    {
        _requests = [NSMutableArray arrayWithObject:request];
    }
    else
    {
        [_requests addObject:request];
    }
}

- (void)allComponentsHaveBeenAdded
{
    _complete = YES;

    if (_requests == nil)
    {
        // No actual component requests were issued, we need to update our progress to reflect that
        // we are done.
        self.progress.totalUnitCount = 1;
        self.progress.completedUnitCount = 1;
    }
}

- (NSOperationQueuePriority)priority
{
    return _priority;
}

- (void)setPriority:(NSOperationQueuePriority)priority
{
    _priority = priority;

    // Adjust the priority of all child requests
    for (DCXHTTPRequest *request in _requests)
    {
        request.priority = priority;
    }
}

- (BOOL)isExecuting
{
    // A composite request is executing if at least one of its component requests is executing
    for (DCXHTTPRequest *request in _requests)
    {
        if (request.isExecuting)
        {
            return YES;
        }
    }

    return NO;
}

- (BOOL)isFinished
{
    if (!_complete)
    {
        return NO;
    }

    // A composite request is finished when all its component requests are finished
    for (DCXHTTPRequest *request in _requests)
    {
        if (!request.isFinished)
        {
            return NO;
        }
    }

    return YES;
}

- (BOOL)isCancelled
{
    for (DCXHTTPRequest *request in _requests)
    {
        if (request.isCancelled)
        {
            return YES;
        }
    }

    return self.progress.isCancelled;
}

- (void)releaseRequests
{
    [_requests removeAllObjects];
}

@end
