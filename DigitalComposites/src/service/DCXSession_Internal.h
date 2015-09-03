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

#import "DCXSession.h"

@class DCXHTTPRequest;
@class DCXResource;
@class DCXHTTPResponse;

/**
 * \brief Exposes private helper methods and ivars to the different categories of DCXSession.
 */
@interface DCXSession ()

/**
 * \brief Construct a mutable URL request for the given resource.
 *
 * \param resource          The resource to construct the request for.
 * \param method            The HTTP method to use. E.g. @"GET", @"PUT"
 * \param etagHeaderField   If not nil and if the resource has an etag property it will be copied to
 *                          this header field of the request.
 * \param setContentType    Determines whether the resource's content type should be copied to the Content-Type
 *                          header of the request.
 *
 * \return                The newly constructed URL request.
 */
- (NSMutableURLRequest *)requestFor:(DCXResource *)resource
                         withMethod:(NSString *)method
                    etagHeaderField:(NSString *)etagHeaderField
                     setContentType:(BOOL)setContentType;


/**
 * \brief Construct a mutable URL request for the given resource.  Same as above method except for the
 * addition of the link argument
 *
 *
 * \param resource          The resource to construct the request for.
 * \param method            The HTTP method to use. E.g. @"GET", @"PUT"
 * \param etagHeaderField   If not nil and if the resource has an etag property it will be copied to
 *                          this header field of the request.
 * \param setContentType    Determines whether the resource's content type should be copied to the Content-Type
 *                          header of the request.
 * \param link              Link header argument
 *
 * \return                  The newly constructed URL request.
 */
- (NSMutableURLRequest *)requestFor:(DCXResource *)resource
                         withMethod:(NSString *)method
                    etagHeaderField:(NSString *)etagHeaderField
                     setContentType:(BOOL)setContentType
                               link:(NSString *)linkHeader;

/**
 * \brief Starts an asynchronous request using the proper method for the request.
 *
 * \param request  The request to get the response for.
 * \param path     The file to upload from or download to. Can be nil.
 * \param data     The data to upload. Can be nil. Ignored if path is set.
 * \param priority The prioprity of the HTTP request.
 * \param handler  Called when the upload has finished or failed.
 */
- (DCXHTTPRequest *)getResponseFor:(NSMutableURLRequest *)request
                    streamToOrFrom:(NSString *)path data:(NSData *)data
                   requestPriority:(NSOperationQueuePriority)priority
                 completionHandler:(void (^)(DCXHTTPResponse *response))handler;

/**
 * \brief Constructs an error for the response.
 *
 * \param response The response.
 * \param path     Optional file path which will be recorded in the error.
 * \param details  Optional string that will be recorded in the error.
 *
 * \return The newly constructed error.
 */
- (NSError *)errorFromResponse:(DCXHTTPResponse *)response andPath:(NSString *)path details:(NSString *)details;

/**
 * Calls handler on the given queue if that is not nil. Otherwise calls handler directly.
 *
 * \param handler  The completion handler to call.
 * \param queue    The queue to call the completion handler on. Can be nil.
 * \param data     The resource to pass to the handler. Can be nil.
 * \param error    The error to pass to the handler. Can be nil.
 */
- (void)callCompletionHandler:(DCXDataRequestCompletionHandler)handler onQueue:(NSOperationQueue *)queue
                     withData:(NSData *)data andError:(NSError *)error;

/**
 * Calls handler on the given queue if that is not nil. Otherwise calls handler directly.
 *
 * \param handler  The completion handler to call.
 * \param queue    The queue to call the completion handler on. Can be nil.
 * \param resource The resource to pass to the handler. Can be nil.
 * \param error    The error to pass to the handler. Can be nil.
 */
- (void)callCompletionHandler:(DCXResourceRequestCompletionHandler)handler onQueue:(NSOperationQueue *)queue
                 withResource:(DCXResourceItem *)resource andError:(NSError *)error;

@end
