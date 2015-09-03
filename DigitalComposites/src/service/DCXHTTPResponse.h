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

@class DCXErrorResponse;
/**
 * \brief Data object that captures the result of an HTTP request.
 */
@interface DCXHTTPResponse : NSObject

/** Contains an NSError if the request has failed. */
@property (nonatomic) NSError *error;

/** The data returned by the server. Can be nil if the request has failed or if it was a download. */
@property (nonatomic) NSData *data;

/** The path to the downloaded file. Can be nil if the request has failed or if it was not a download. */
@property (nonatomic) NSString *path;

/** The HTTP status code returned by the server. */
@property (nonatomic) int statusCode;

/** The URL of the request. */
@property (nonatomic) NSURL *URL;

/** Dictionary of the response header key/value pairs. Keys are lower case. */
@property (nonatomic) NSDictionary *headers;

/** Number of bytes sent. */
@property (nonatomic) int64_t bytesSent;

/** Number of bytes received. */
@property (nonatomic) int64_t bytesReceived;

- (NSString *)description;

@end
