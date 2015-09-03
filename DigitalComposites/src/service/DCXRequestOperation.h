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
#import "DCXHTTPRequest.h"

@class DCXHTTPResponse;

/** The type of the operation. */
typedef NS_ENUM (NSInteger, DCXRequestType){
    DCXDataRequestType,
    DCXDownloadRequestType,
    DCXUploadRequestType
};

/**
 * An internal utility class that helps DCXHTTPService with request queue
 * management.
 *
 * In order to schedule a request, the service object will make
 * an instance of this class and place it on the queue.
 *
 * When the operation is executed by the queue, it will call
 * DCXHTTPService::processQueuedRequest:.
 *
 * If the request is successful, the service will then call
 * DCXRequestOperation::notifyScheduler, which runs the given
 * notification block. That will signal the original requestor,
 * one way or another.
 *
 * If the request fails due to a temporary issue, the service will
 * call clone: to get another, identical operation, and then schedule
 * that operation on the queue. The queue will also be paused until
 * the issue causing the failure is cleared.
 */
@interface DCXRequestOperation : NSOperation <NSCopying>

/** The request that this operation will attempt to issue. */
@property NSURLRequest *request;

/** The type of request. */
@property DCXRequestType type;

/** The path of the request (for a download or upload). */
@property NSString *path;

/** The block invoked when this request is to be issued. */
@property (strong)void(^ invocationBlock)(DCXRequestOperation *);

/** The block invoked if notifyScheduler: is called. */
@property (strong)void(^ notificationBlock)(DCXHTTPResponse *);

/** Every request has a unique id, even if it's re-issued */
@property NSString *id;

/** Request id to track if this request has been issued previously */
@property NSString *originalId;

/** Used to store an error from a request. */
@property NSError *error;

/** Used to collect the received data from a data request. */
@property NSMutableData *receivedData;

/** USed to store the NSURLSessionTask while it is active. */
@property NSURLSessionTask *sessionTask;

/** Used by AdobeStorageHTTService to store an internal completion callback. */
@property (strong)void(^ completionHandler)(DCXHTTPResponse *);

/** The request object that is returned to the caller. It provides progress as well as means of cancellation
 * and prioritization. Declared as weak to avoid a retain cycle, since it itself has a reference to the
 * operarion. */
@property (weak) DCXHTTPRequest *weakClientRequestObject;

/** Executes this operation, and invoked by NSOperationQueue. */
- (void)main;

/**
 * \brief Notifies the scheduler of this operation by invoking the notification block.
 *
 * \param response The response to the request.
 *
 * This method is *not* invoked by main: when this operation is executed. Instead, the entity responsible
 * for managing the queue is expected to determine when and whether to call this.
 */
- (void)notifyRequesterOfResponse:(DCXHTTPResponse *)response;

@end
