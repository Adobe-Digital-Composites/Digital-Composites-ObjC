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

#import "DCXSession_Internal.h"

#import "DCXError.h"
#import "DCXHTTPRequest.h"
#import "DCXHTTPResponse.h"
#import "DCXHTTPService.h"
#import "DCXUtils.h"
#import "DCXErrorUtils.h"
#import "DCXResourceItem.h"

@implementation DCXSession

- (instancetype)initWithHTTPService:(DCXHTTPService *)service
{
    if (self = [self init]) {
        _service = service;
    }
    return self;
}

- (NSMutableURLRequest *)requestFor:(DCXResource *)resource withMethod:(NSString *)method
                    etagHeaderField:(NSString *)etagHeaderField setContentType:(BOOL)setContentType
{
    return [self requestFor:resource withMethod:method etagHeaderField:etagHeaderField setContentType:setContentType];
}

- (NSMutableURLRequest *)requestFor:(DCXResource *)resource
                         withMethod:(NSString *)method
                    etagHeaderField:(NSString *)etagHeaderField
                     setContentType:(BOOL)setContentType
                               link:(NSString *)linkHeader
{
    NSURL *url = [NSURL URLWithString:resource.href relativeToURL:self.service.baseURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    [request setHTTPMethod:method];

    // Set up etag if it exists for the given link.
    if (etagHeaderField != nil)
    {
        [request setValue:(resource.etag == nil ? @"*" : resource.etag) forHTTPHeaderField:etagHeaderField];
    }

    // Set Content-Type header if requested
    if (setContentType && resource.type != nil)
    {
        [request setValue:resource.type forHTTPHeaderField:@"Content-Type"];
    }

    return request;
}

- (DCXHTTPRequest *)getResponseFor:(NSMutableURLRequest *)request
                    streamToOrFrom:(NSString *)path
                              data:(NSData *)data
                   requestPriority:(NSOperationQueuePriority)priority
                 completionHandler:(void (^)(DCXHTTPResponse *response))handler
{
    if (path == nil)
    {
        // Upload/download from/to memory via data request.
        [request setHTTPBody:data];
        return [self.service getResponseForDataRequest:request requestPriority:priority completionHandler:handler];
    }
    else if ([[request HTTPMethod] isEqualToString:@"GET"])
    {
        // Download to file
        return [self.service getResponseForDownloadRequest:request toPath:path requestPriority:priority completionHandler:handler];
    }
    else if ([[request HTTPMethod] isEqualToString:@"HEAD"])
    {
        return [self.service getResponseForDataRequest:request requestPriority:priority completionHandler:handler];
    }
    else
    {
        // Upload from file via upload request.
        return [self.service getResponseForUploadRequest:request fromPath:path requestPriority:priority completionHandler:handler];
    }
}
// Construct an error from a response.
- (NSError *)errorFromResponse:(DCXHTTPResponse *)response andPath:(NSString *)path details:(NSString *)details
{
    NSError *error = nil;

    if (response.statusCode == 412)
    {
        error = [DCXErrorUtils ErrorWithCode:DCXErrorConflictingChanges
                                               domain:DCXErrorDomain
                                             response:response details:nil];
    }

    if (error == nil)
    {
        if (response.error != nil)
        {
            error = response.error;

            if ([DCXErrorUtils IsDCXError:error])
            {
                return error;
            }
        }

        error = [DCXErrorUtils ErrorFromResponse:response
                                                  andPath:path
                                              defaultCode:DCXErrorUnexpectedResponse
                                            defaultDomain:DCXErrorDomain
                                                  details:details];
    }

    return error;
}

- (void)callCompletionHandler:(DCXDataRequestCompletionHandler)handler
                      onQueue:(NSOperationQueue *)queue
                     withData:(NSData *)data
                     andError:(NSError *)error
{
    if (queue != nil)
    {
        [queue addOperationWithBlock: ^{
                   handler(data, error);
               }];
    }
    else
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{handler(data, error); });
    }
}

- (void)callCompletionHandler:(DCXResourceRequestCompletionHandler)handler onQueue:(NSOperationQueue *)queue
                 withResource:(DCXResourceItem *)resource andError:(NSError *)error
{
    if (queue != nil)
    {
        [queue addOperationWithBlock: ^
        {
            handler(resource, error);
        }];
    }
    else
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{handler(resource, error); });
    }
}

@end
