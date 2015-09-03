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

/**
 * Represents a single HTTP request that is either scheduled or already in progress. Allows the client
 * to receive progress updates, manage the relative priority of the request and cancel it.
 */
@interface DCXHTTPRequest : NSObject

/** Exposes progress and the ability to cancel. See documentation for NSProgress.
 * \note Clients must not set the cancellationHandler on the progress object, since that is being
 * utilized internally to actually cancel the operation.*/
@property (readonly) NSProgress *progress;

/** Whether the request is currently being executed. */
@property (readonly) BOOL isExecuting;

/** Whether the request has finished. */
@property (readonly) BOOL isFinished;

/** Whether the request has been canceled. */
@property (readonly) BOOL isCancelled;

/** Allows setting the priority of the request relative to other queued requests. Setting this property
 * has no effect if the request is already executing. */
@property NSOperationQueuePriority priority;

@end
