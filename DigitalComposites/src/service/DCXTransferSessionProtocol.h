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

#import "DCXSession.h"

@class DCXComposite;
@class DCXManifest;
@class DCXComponent;
@class DCXHTTPRequest;

/** The generic completion handlers for asynchronous manifest/component-based CCStorageSession requests. */
typedef void (^DCXCompositeRequestCompletionHandler)(DCXComposite *, NSError *);
typedef void (^DCXManifestRequestCompletionHandler)(DCXManifest *, NSError *);
typedef void (^DCXComponentRequestCompletionHandler)(DCXComponent *, NSError *);

/**
 * Defines the protocol that a session has to implement in order to be used as a session for the
 * push and pull methods of DCXCompositeXfer.
 */
@protocol DCXTransferSessionProtocol <NSObject>

#pragma mark - Composite Methods

/**
 * \brief Create the specified composite (if it doesn't yet exist) asynchronously.
 *
 * \param composite The composite to create on the server.
 * \param priority  The priority of the HTTP request.
 * \param queue     Optional parameter. If not nil queue determines the operation queue handler
 * gets executed on.
 * \param handler   Called when the upload has finished or failed.
 *
 *
 * \return          A DCXHTTPRequest object that can be used to track progress, adjust the
 * priority of the request and to cancel it.
 *
 * \note Returns success even if there is already a composite directory with the same href.
 */
- (DCXHTTPRequest *)createComposite:(DCXComposite *)composite
                    requestPriority:(NSOperationQueuePriority)priority
                       handlerQueue:(NSOperationQueue *)queue
                  completionHandler:(DCXCompositeRequestCompletionHandler)handler;

/**
 * \brief Delete the specified composite, recursively and asynchronously.
 *
 * \param composite The composite to delete.
 * \param priority  The priority of the HTTP request.
 * \param queue     Optional parameter. If not nil queue determines the operation queue handler
 * gets executed on.
 * \param handler   Called when the upload has finished or failed.
 *
 *
 * \return          A DCXHTTPRequest object that can be used to track progress, adjust the
 * priority of the request and to cancel it.
 */
- (DCXHTTPRequest *)deleteComposite:(DCXComposite *)composite
                    requestPriority:(NSOperationQueuePriority)priority
                       handlerQueue:(NSOperationQueue *)queue
                  completionHandler:(DCXCompositeRequestCompletionHandler)handler;

#pragma mark - Manifest Methods

/**
 * \brief Creates and returns an AdobeStorageResourceItem for the given manifest.
 *
 * \param manifest  The manifest to return the resource for.
 * \param composite The composite of the manifest to return the resource for.
 *
 * \return The resource.
 */
- (DCXResourceItem *)resourceForManifest:(DCXManifest *)manifest
                                      ofComposite:(DCXComposite *)composite;

/**
 * \brief Upload a manifest asset from memory to the server asynchronously, creating it if it doesn't
 * already exist.
 *
 * \param manifest  The manifest to upload.
 * \param composite  The composite of the manifest.
 * \param priority The priority of the HTTP request.
 * \param queue     Optional parameter. If not nil queue determines the operation queue handler
 * gets executed on.
 * \param handler   Called when the upload has finished or failed.
 *
 * \note On success manifest gets copied, updated with the new etag, version, length, md5 values and
 * passed to the completion handler.
 *
 * \return          A DCXHTTPRequest object that can be used to track progress, adjust the
 * priority of the request and to cancel it.
 */
- (DCXHTTPRequest *)updateManifest:(DCXManifest *)manifest ofComposite:(DCXComposite *)composite
                   requestPriority:(NSOperationQueuePriority)priority
                      handlerQueue:(NSOperationQueue *)queue
                 completionHandler:(DCXManifestRequestCompletionHandler)handler;

/**
 * \brief Get the header information for the manifest asset from the server asynchronously.
 *
 * \param composite The composite to download the manifest of.
 * \param priority  The priority of the HTTP request.
 * \param queue     Optional parameter. If not nil queue determines the operation queue handler
 * gets executed on.
 * \param handler   Gets called when the upload has completed or failed.
 *
 * \return          A DCXHTTPRequest object that can be used to track progress, adjust the
 * priority of the request and to cancel it.
 */
- (DCXHTTPRequest *)getHeaderInfoForManifestOfComposite:(DCXComposite *)composite
                                        requestPriority:(NSOperationQueuePriority)priority
                                           handlerQueue:(NSOperationQueue *)queue
                                      completionHandler:(DCXResourceRequestCompletionHandler)handler;



/**
 * \brief Download a manifest asset to memory from the server asynchronously.
 *
 * \param manifest  Optional: A locally existing manifest.
 * \param composite The composite to download the manifest of.
 * \param priority  The priority of the HTTP request.
 * \param queue     Optional parameter. If not nil queue determines the operation queue handler
 *                gets executed on.
 * \param handler   Gets called when the upload has completed or failed.
 *
 * \note If the manifest has its etag set and the latest version of the manifest file on
 * the server has the same etag the manifest will not get downloaded and no error will be returned.
 *
 * \return          A DCXHTTPRequest object that can be used to track progress, adjust the
 *                priority of the request and to cancel it.
 */
- (DCXHTTPRequest *)getManifest:(DCXManifest *)manifest ofComposite:(DCXComposite *)composite
                requestPriority:(NSOperationQueuePriority)priority
                   handlerQueue:(NSOperationQueue *)queue
              completionHandler:(DCXManifestRequestCompletionHandler)handler;

#pragma mark - Component Methods

/**
 * \brief Upload a component asset from a file to the server asynchronously, creating it if it doesn't
 * already exist.
 *
 * \param component The component to upload.
 * \param composite The composite the component belongs to.
 * \param path      File path to upload the component from.
 * \param isNew     Whether the component is considered a new component of the composite.
 * \param priority  The priority of the HTTP request.
 * \param queue     Optional parameter. If not nil queue determines the operation queue handler
 * gets executed on.
 * \param handler   Called when the upload has finished or failed.
 *
 * \note On success the component will be duplicated, updated with etag, etc. and passed to the handler.
 *
 * \return          A DCXHTTPRequest object that can be used to track progress, adjust the
 * priority of the request and to cancel it.
 */
- (DCXHTTPRequest *)uploadComponent:(DCXComponent *)component
                        ofComposite:(DCXComposite *)composite
                           fromPath:(NSString *)path
                     componentIsNew:(BOOL)isNew
                    requestPriority:(NSOperationQueuePriority)priority
                       handlerQueue:(NSOperationQueue *)queue
                  completionHandler:(DCXComponentRequestCompletionHandler)handler;

/**
 * \brief Download a component asset asynchronously
 *
 * \param component The component to download.
 * \param composite The composite the component belongs to.
 * \param path      File path to download the component to.
 * \param priority  The priority of the HTTP request.
 * \param queue     Optional parameter. If not nil queue determines the operation queue handler
 * gets executed on.
 * \param handler   Gets called when the upload has completed or failed.
 *
 * \note On success the modified component, whose length property has been updated to reflect
 * the downloaded content, will passed to the handler.
 *
 * \return          A DCXHTTPRequest object that can be used to track progress, adjust the
 * priority of the request and to cancel it.
 */

-(DCXHTTPRequest*) downloadComponent:(DCXComponent *)component
                         ofComposite:(DCXComposite *)composite
                              toPath:(NSString *)path
                     requestPriority:(NSOperationQueuePriority)priority
                        handlerQueue:(NSOperationQueue *)queue
                   completionHandler:(DCXComponentRequestCompletionHandler)handler;

/**
 * \brief Delete a component asset on the server asynchronously.
 *
 * \param component The component to download.
 * \param composite The composite the component belongs to.
 * \param priority  The priority of the HTTP request.
 * \param queue     Optional parameter. If not nil queue determines the operation queue handler
 * gets executed on.
 * \param handler   Gets called when the deletion has completed or failed.
 *
 * \note On success the unmodified component will passed to the handler.
 *
 * \return          A DCXHTTPRequest object that can be used to track progress, adjust the
 * priority of the request and to cancel it.
 */
- (DCXHTTPRequest *)deleteComponent:(DCXComponent *)component
                        ofComposite:(DCXComposite *)composite
                    requestPriority:(NSOperationQueuePriority)priority
                       handlerQueue:(NSOperationQueue *)queue
                  completionHandler:(DCXComponentRequestCompletionHandler)handler;
@end
