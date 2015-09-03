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

@class DCXBranch;
@class DCXComposite;
@class DCXHTTPRequest;

@protocol DCXTransferSessionProtocol;

/**
 * Implementation of the push & pull logic for composites.
 */
@interface DCXCompositeXfer : NSObject

// Completion Handler Types

/**
 * \brief Type defining the signature of a completion handler for pushComposite:usingSession:queue:completionHandler.
 */
    typedef void (^DCXPushCompletionHandler)(BOOL, NSError *);

/**
 * \brief Type defining the signature of a completion handler for pullComposite:usingSession:queue:completionHandler.
 */
typedef void (^DCXPullCompletionHandler)(DCXBranch *, NSError *);

#pragma mark - Push

/**
 *
 * \brief The first step of a composite push. Uploads the local committed state of the composite to the
 * server, creating it on the server if it is a new composite.
 *
 * \param composite The DCXComposite to push.
 * \param overwrite Whether to forcibly overwrite an already existing composite. Set this when the previous
 *                attempt to push has failed with a DCXErrorCompositeAlreadyExists error and the
 *                user has confirmed that it it OK to overwrite the composite.
 * \param session   The session to use for the required http requests.
 * \param priority  The relative priority of the pull.
 * \param queue     Optional parameter. If not nil queue determines the operation queue handler
 *                gets executed on.
 * \param handler   Gets called when the push has completed.  May be nil if the controller
 *                property has been set on the composite since in that case errors will be always be reported
 *                via the controller's DCXControllerDelegate interface.
 *
 *
 * \return          A DCXHTTPRequest object that can be used to track progress, adjust the priority
 *                of the pull and to cancel it.
 *
 * \note If the controller property of the composite is non-nil, then the associated DCXController
 * will process any errors that result from calling this method and will inform the client via the
 * controller:requestsClientHandleError:... method on its delegate in addition to calling the handler
 * method passed to this function.
 *
 * This method reads the local committed manifest of the composite and analyzes it in order to determine whether
 * it needs to create the composite and which of its component assets need to be uploaded (see Semantics
 * of pushComposite below). If all of the necessary uploads succeed it does a final upload of the manifest
 * (updated with links, etags, checksums and states of all the components) and returns the journal of
 * these changes.
 *
 * There are some things that a client must **not** do while this method is executing:
 *
 * - Making changes to any of the component asset files in the current branch of the composite that are
 * referenced by the current manifest at the time the pushComposite:withError: method gets called. I.e. the
 * client must not write to or over any of those files nor is it allowed to delete any of them.
 * - Call the pushComposite:withError: for the same composite.
 *
 * \note pushComposite:withError: doesn't modify the current state of the composite and thus is only the first
 * step of a 2-step push operation. See below for details.
 *
 * A Complete Push Operation
 * -------------------------
 *
 * A composite push operation consists of 2 separate steps.
 *
 * 1. The first step is always to call pushComposite:withError:. If successful it uploads all necessary
 * assets to the server and stores the resulting manifest, as well as a journal of all the uploads into
 * the pushed branch of the composite. It does not modify the current state of the composite.
 *
 * 2. Once the call to pushComposite:withError: has completed successfully, the client must call [composite
 * acceptPushWithError:]. This completes the push operation by merging the new server state now saved in the
 * pushed branch into the current in memory and into the manifest file on disk.  It also
 * updates the base branch to be the pushed branch before finally discarding the local copy of the pushed branch.
 *
 * Semantics of pushComposite:
 * -------------------------
 *
 * What pushComposite does depends on whether composite points to an existing local
 * composite and, if that is the case, on the state of the composite and its
 * components as reflected in the manifest:
 *
 + If the composite's state is DCXAssetStateCommittedDelete pushComposite will
 + do nothing and will set errorPtr to a DCXErrorDeletedComposite error.
 +
 + Else if the composite doesn't exist in the cloud pushComposite
 + will create a new composite on the server, upload all its components (ignoring
 + their individual states) and update the local manifest with the correct links and
 + states.
 +
 + Else if the composite's state is DCXAssetStatePendingDelete pushComposite
 + will try to delete the composite on the server. On success pushComposite will
 + change the composite's state to DCXAssetStateCommittedDelete, unbind the
 + manifest, _not_ set errorPtr and return nil.
 +
 + Notice that pushComposite never deletes any local files.
 +
 + Notice, too, that deleting a composite will fail if the composite has been modified on
 + the server. In this case errorPtr will contain a DCXErrorConflictingChanges error.
 +
 + Else if the composite's state is DCXAssetStateUnmodified pushComposite will do
 + nothing and will _not_ set errorPtr.
 +
 + Else pushComposite assumes the state to be DCXAssetStateModified. It will iterate over the
 + components of the composite, evaluate what to do with each of them based on their
 + state and update/upload the manifest:
 + If a component doesn't have an proper link it is considered a new component and
 + pushComposite will upload it and record its link in the manifest.
 + Else if a component's state is DCXAssetStateUnmodified the component
 + gets skipped.
 + Else if a component's state is DCXAssetStatePendingDelete pushComposite will
 + set its state to DCXAssetStateCommittedDelete so that it can get deleted
 + during a subsequent push. Notice that pushComposite never deletes any local
 + composites, so you will want to clean up after a successful push.
 + Else if a component's state is DCXAssetStateCommittedDelete pushComposite will
 + delete the component on the server and remove it from the manifest.
 + Else (must be DCXAssetStateModified) pushComposite will upload the component
 + as a new version to the server and record its new etag in the manifest.
 +
 + Errors
 + -------------
 +
 + These errors can occur (all in the DCXErrorDomain or DCXErrorDomain):
 + - DCXErrorBadRequest
 + - DCXErrorOffline
 + - DCXErrorUnexpectedResponse
 + - DCXErrorNetworkFailure
 + - DCXErrorAuthenticationFailed
 + - DCXErrorManifestReadFailure
 + - DCXErrorManifestWriteFailure
 + - DCXErrorManifestFinalWriteFailure
 + - DCXErrorInvalidManifest
 + - DCXErrorComponentReadFailure
 + - DCXErrorConflictingChanges
 + - DCXErrorDeletedComposite
 + - DCXErrorCompositeAlreadyExists
 +
 + Of these a client must handle because they can happen during normal operations:
 +
 + - DCXErrorNetworkFailure
 + - DCXErrorConflictingChanges
 + - DCXErrorCompositeAlreadyExists
 +
 + This error ocurs if the copy of the composite on the server has been
 + modified since the last successfull push or pull. In this scenario the caller
 + should pull down the latest version from the server, resolve any
 + conflicts in that new copy and push that up to the server again.
 +
 + Another cause of this error might be that the client has not yet called acceptPushWithError: or
 + acceptPushedManifest:withError: on the composite after a successful previous call to pushComposite:
 +
 + - DCXErrorAuthenticationFailed
 +
 + - DCXErrorOffline
 */
+ (DCXHTTPRequest *)pushComposite:(DCXComposite *)composite
                     usingSession:(id<DCXTransferSessionProtocol>)session
                  requestPriority:(NSOperationQueuePriority)priority
                     handlerQueue:(NSOperationQueue *)queue
                completionHandler:(DCXPushCompletionHandler)handler;

#pragma mark - Pull

/**
 * \brief Downloads a version of the composite as it currently exists on the server. The copy
 * can be used to atomically update the local composite and/or to resolve conflicts between
 * the local composite and the cloud.
 *
 * \param composite   The local DCXComposite.
 * \param session     The session to use for the required http requests.
 * \param priority    The relative priority of the pull.
 * \param queue       Optional parameter. If not nil queue determines the operation queue handler
 *                  gets executed on.
 * \param handler     Gets called when the pull has completed. It gets passed the DCXBranch
 *                  of the pulled branch if the pull succeeds otherwise the caller should check errorPtr
 *                  to determine whether there has been a problem (see below).  May be nil if the controller
 *                  property has been set on the composite since in that case errors will be always be reported
 *                  via the controller's DCXControllerDelegate interface.
 *
 * \return            An DCXHTTPRequest object that can be used to track progress, adjust the priority
 *                  of the pull and to cancel it.
 *
 * \note If the controller property of the composite is non-nil, then the associated DCXController
 * will process any errors that result from calling this method and will inform the client via the
 * controller:requestsClientHandleError:... method on its delegate in addition to calling the handler
 * method passed to this function.
 *
 * Pulling a composite can result on one of three possible outcomes:
 *
 * 1. The composite in the cloud has not been modified since the last successful pull.
 * In this case pull returns nil and *errorPtr is nil as well.
 *
 * 2. pullComposite succeededs and returns a DCXBranch. The local storage for the composite now
 * contains two branches of the composite. If there are no local changes to the composite
 * the caller should immediately call [composite acceptPullWithError:notifyMonitor:] so that the pulled version
 * of the composite becomes current. Otherwise the caller is expected to first resolve
 * any conflicts in the pulled down version of the composite and then call
 * [composite acceptPullWithError:notifyMonitor:].
 *
 * 3. An error occurs. In this case pullComposite returns nil and sets errorPtr
 * to an NSError which contains more information about the failure.
 *
 * There are some things that a client must **not** do while this method is executing:
 *
 * - (If the local storage scheme in use is not a copy-on-write scheme:) Make changes to any of the
 * component asset files in the current branch of the composite that are referenced by the current
 * manifest at the time the pullComposite:... method gets called. I.e. the client must not write to or
 * over any of those files nor is it allowed to delete any of them.
 * - Call a pull... method for the same composite.
 *
 * \note pullComposite:... doesn't modify the current state of the composite and thus is only the
 * first step of a 2-3 step pull operation. See below for details.
 *
 * A Complete Pull Operation
 * -------------------------
 *
 * A composite pull operation consists of 2 or 3 separate steps.
 *
 * 1. The first step is always a call to pullComposite:withError:. If successful it downloads all necessary
 * assets from the server and stores the resulting manifest as well as a journal of all the downloads
 * into the pull branch of the composite. Component asset files that have not changed on the server
 * are getting copied into the pull branch from the current branch. This method does not modify the
 * current state of the composite.
 *
 * 2. The second step of the pull operation is necessary if the client has made changes to the current
 * state of the composite since the last successful pull of push operation of the composite. I.e. if
 * the user is allowed to continue working with the composite and the client takes care to not affect
 * any of the existing asset files by e.g. only creating new asset files that replace the existing
 * ones. Or if a previous attempt to push local changes to the server has failed with a
 * DCXErrorConflictingChanges error.
 *
 * If this is the case the client must now merge the local changes that are saved in the current
 * branch into the pull branch.  This can be done by comparing the manifests stored in the current,
 * pull and base branches of the composite.
 *
 * The end result of this step must be a complete and consistent resolved version of the composite
 * in the pull branch.
 *
 * 3. Once the second step is complete (or if it is not necessary) the client must call [composite
 * acceptPullWithError:]. This completes the pull operation by updating the current branch of the
 * composite with the version stored in the pull branch.
 *
 * Errors
 * -------------
 *
 * These errors can occur (all in the DCXErrorDomain or DCXErrorDomain):
 * - DCXErrorBadRequest
 * - DCXErrorOffline
 * - DCXErrorManifestReadFailure
 * - DCXErrorInvalidLocalManifest
 * - DCXErrorUnknownComposite
 * - DCXErrorAuthenticationFailed
 * - DCXErrorUnexpectedResponse
 * - DCXErrorNetworkFailure
 * - DCXErrorInvalidRemoteManifest
 * - DCXErrorManifestWriteFailure
 * - DCXErrorMissingComponentAsset
 * - DCXErrorComponentWriteFailure
 *
 * These errors can occur during normal operations:
 *
 * - DCXErrorNetworkFailure
 * - DCXErrorAuthenticationFailed
 * - DCXErrorUnknownComposite
 * - DCXErrorOffline
 *
 */
+ (DCXHTTPRequest *)pullComposite:(DCXComposite *)composite
                     usingSession:(id<DCXTransferSessionProtocol>)session
                  requestPriority:(NSOperationQueuePriority)priority
                     handlerQueue:(NSOperationQueue *)queue
                completionHandler:(DCXPullCompletionHandler)handler;

/**
 * \brief Downloads a minimal version of the specified composite (i.e. its manifest),
 * which can be used to selectively pull specific components and/or add new components to the composite.
 *
 * \param composite   The local DCXComposite.
 * \param session     The session to use for the required http requests.
 * \param priority    The relative priority of the pull.
 * \param queue       Optional parameter. If not nil queue determines the operation queue handler
 *                  gets executed on.
 * \param handler     Gets called when the pull has completed. It gets passed the DCXBranch of the new
 *                  version if the pull succeeds otherwise the caller should check errorPtr to determine
 *                  whether there has been a problem (see below). May be nil if the controller
 *                  property has been set on the composite since in that case errors will be always be reported
 *                  via the controller's DCXControllerDelegate interface.
 *
 * \return            An DCXHTTPRequest object that can be used to track progress, adjust the priority
 * of the pull and to cancel it.
 *
 * \note If the controller property of the composite is non-nil, then the associated DCXController
 * will process any errors that result from calling this method and will inform the client via the
 * controller:requestsClientHandleError:... method on its delegate in addition to calling the handler
 * method passed to this function.
 *
 * Pulling a composite manifest can result on one of three possible outcomes:
 *
 * 1. The composite in the cloud has not been modified since the last successful pull.
 * In this case pull returns nil and *errorPtr is nil as well.
 *
 * 2. pullMinimalComposite succeeds and returns a DCXBranch.
 *
 * 3. An error occurs. In this case pullComposite returns nil and sets errorPtr
 * to an NSError which contains more information about the failure.
 *
 * There are some things that a client must **not** do while this method is executing:
 *
 * - (If the local storage scheme in use is not a copy-on-write scheme:) Make changes to any of the
 * component asset files in the current branch of the composite that are referenced by the current
 * manifest at the time the pullComposite:... method gets called. I.e. the client must not write to or
 * over any of those files nor is it allowed to delete any of them.
 * - Call a pull... method for the same composite.
 *
 * Errors
 * -------------
 *
 * These errors can occur (all in the DCXErrorDomain or DCXErrorDomain):
 * - DCXErrorBadRequest
 * - DCXErrorOffline
 * - DCXErrorManifestReadFailure
 * - DCXErrorInvalidLocalManifest
 * - DCXErrorUnknownComposite
 * - DCXErrorAuthenticationFailed
 * - DCXErrorUnexpectedResponse
 * - DCXErrorNetworkFailure
 * - DCXErrorInvalidRemoteManifest
 * - DCXErrorManifestWriteFailure
 *
 * These errors can occur during normal operations:
 *
 * - DCXErrorNetworkFailure
 * - DCXErrorAuthenticationFailed
 * - DCXErrorUnknownComposite
 * - DCXErrorOffline
 *
 */
+ (DCXHTTPRequest *)pullMinimalComposite:(DCXComposite *)composite
                            usingSession:(id<DCXTransferSessionProtocol>)session
                         requestPriority:(NSOperationQueuePriority)priority
                            handlerQueue:(NSOperationQueue *)queue
                       completionHandler:(DCXPullCompletionHandler)handler;

/**
 * \brief Downloads specific components of the specified composite branch
 *
 * \param components          Optional list of components to download. Pass nil to download all missing components.
 * \param branch              The DCXBranch whose components are to be downloaded.
 * \param session             The session to use for the required http requests.
 * \param priority            The relative priority of the pull.
 * \param queue               Optional parameter. If not nil queue determines the operation queue handler
 * gets executed on.
 * \param handler             Gets called when the download has completed. It gets passed the DCXBranch of the new
 * version if the download succeeds otherwise the caller should check errorPtr to determine
 * whether there has been a problem (see below).
 *
 * \return                    An DCXHTTPRequest object that can be used to track progress, adjust the priority
 * of the pull and to cancel it.
 *
 * \note                      Unlike the pull methods, the client is expected to provide its own handler method
 * even when the composite's controller property is non nil in order to obtain notification
 * of the success or failure of the component download operation.
 *
 * There are some things that a client must **not** do while this method is executing:
 *
 * - (If the local storage scheme in use is not a copy-on-write scheme:) Make changes to any of the
 * component asset files in the current branch of the composite that are referenced by the current
 * manifest at the time the pullComposite:... method gets called. I.e. the client must not write to or
 * over any of those files nor is it allowed to delete any of them.
 * - Call a pull... method for the same composite.
 *
 * Errors
 * -------------
 *
 * These errors can occur (all in the DCXErrorDomain or DCXErrorDomain):
 * - DCXErrorBadRequest
 * - DCXErrorOffline
 * - DCXErrorManifestReadFailure
 * - DCXErrorInvalidLocalManifest
 * - DCXErrorAuthenticationFailed
 * - DCXErrorUnexpectedResponse
 * - DCXErrorNetworkFailure
 * - DCXErrorInvalidRemoteManifest
 * - DCXErrorManifestWriteFailure
 * - DCXErrorMissingComponentAsset
 * - DCXErrorComponentWriteFailure
 *
 * These errors can occur during normal operations:
 *
 * - DCXErrorNetworkFailure
 * - DCXErrorAuthenticationFailed
 * - DCXErrorUnknownComposite
 * - DCXErrorOffline
 *
 */
+ (DCXHTTPRequest *)downloadComponents:(NSArray *)components
                     ofBranch:(DCXBranch *)branch
                          usingSession:(id<DCXTransferSessionProtocol>)session
                       requestPriority:(NSOperationQueuePriority)priority
                          handlerQueue:(NSOperationQueue *)queue
                     completionHandler:(DCXPullCompletionHandler)handler;


@end
