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

#import "DCXHTTPRequest.h"

/** Subclass of DCXkHTTPRequest which represents all the individual HTTP requests for a
 * larger logical operation as a single object, allowing clients to get progress for and/or cancel
 * the operation. */
@interface DCXCompositeRequest : DCXHTTPRequest

- (id)initWithPriority:(NSOperationQueuePriority)priority;

/**
 * \brief Adds the request to the list of component requests.
 *
 * \param request A component request that is part of this composite request.
 */
- (void)addComponentRequest:(DCXHTTPRequest *)request;

/**
 * \brief Notifies the request that it shouldn't expect any more component requests.
 */
- (void)allComponentsHaveBeenAdded;

/**
 * \brief Releases all the component requests that were tracked by this composite request.
 */
- (void)releaseRequests;

@end
