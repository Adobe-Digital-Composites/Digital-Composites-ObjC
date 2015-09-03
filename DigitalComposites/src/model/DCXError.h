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

/** The domain for Digital Composite library errors */
extern NSString *const DCXErrorDomain;


#pragma mark - UserInfo Dictionary Keys

/** These keys may appear in the NSError userInfo dictionary for network related errors.
 */

extern NSString *const DCXHTTPStatusKey;       /**< userInfo key returning an NSNumber containing
                                                         * the HTTP status code returned by the request
                                                         * that caused the error. */

extern NSString *const DCXRequestURLStringKey; /**< userInfo key returning an NSString* containing
                                                         * the url of the request that caused the error. */

extern NSString *const DCXResponseHeadersKey;  /**< userInfo key returning an NSDictionary*
                                                         * containing the repsonse headers of the request
                                                         * that caused the error. */

extern NSString *const DCXResponseDataKey;     /**< userInfo key returning an NSData* containing
                                                         * the data returned from the request that caused
                                                         * the error. */

extern NSString *const DCXErrorPathKey;             /**< userInfo key returning an NSString* containing
                                                       * the path of a local file that caused the error. */
extern NSString *const DCXErrorOtherErrorsKey;      /**< userInfo key returning an NSArray containing
                                                       * other errors that happened in parallel. */
extern NSString *const DCXErrorDetailsStringKey;    /**< userInfo key returning an NSString. containing
                                                       * a clear text description of the problem. */

#pragma mark - Error Codes
/**
 * \brief Error codes for the Digital Composite Technology error domain.
 */
typedef NS_ENUM (NSInteger, DCXErrorCode)
{
    /**
     * \brief The manifest could not be read from local file system.
     *
     * The NSUnderlyingErrorKey and DCXPathKey entries in userInfo often contain
     * more information about the cause of this error.
     */
    DCXErrorManifestReadFailure = 0,

    /**
     * \brief The final write of the manifest to local storage has failed. When this occurs
     * during a push it means that the changes have been successfully uploaded to the server,
     * but the final write of the manifest file has failed so that it is now out of sync
     * with the server.
     *
     * The NSUnderlyingErrorKey and DCXPathKey entries in userInfo often contain
     * more information about the cause of this error.
     *
     * Once the problem with the local storage has been resolved a pull can be used to update
     * the local copy of the composite.
     */
    DCXErrorManifestFinalWriteFailure = 1,

    /**
     * \brief Writing= the manifest to local storage has failed.
     *
     * The NSUnderlyingErrorKey and DCXPathKey entries in userInfo often contain
     * more information about the cause of this error.
     */
    DCXErrorManifestWriteFailure = 2,

    /**
     * \brief A local file or server-provided resource that supposedly contains a valid manifest
     * could not be parsed as such.
     *
     * The DCXDetailsStringKey, NSUnderlyingErrorKey and DCXPathKey entries in userInfo often
     * contain more information about the cause of this error.
     */
    DCXErrorInvalidManifest = 3,

    /**
     * \brief A local file that supposedly contains a valid manifest could not be parsed
     * as such.
     *
     * The DCXDetailsStringKey, NSUnderlyingErrorKey and DCXPathKey entries in userInfo often
     * contain more information about the cause of this error.
     */
    DCXErrorInvalidLocalManifest = 4,

    /**
     * \brief A server-provided resource that supposedly contains a valid manifest
     * could not be parsed as such.
     *
     * The DCXDetailsStringKey, NSUnderlyingErrorKey and DCXPathKey entries in userInfo often
     * contain more information about the cause of this error.
     */
    DCXErrorInvalidRemoteManifest = 5,

    /**
     * \brief The composite on the server doesn't contain a manifest.
     *
     * This typically means that either the composite is currently in the process of
     * being created or that the creation of the composite on the server has failed.
     */
    DCXErrorMissingManifest = 6,

    /**
     * \brief The asset file for a component could not be read from local file system.
     *
     * The NSUnderlyingErrorKey and DCXPathKey entries in userInfo often contain
     * more information about the cause of this error.
     */
    DCXErrorComponentReadFailure = 7,

    /**
     * \brief Writing a component asset file to local storage has failed.
     *
     * The NSUnderlyingErrorKey and DCXPathKey entries in userInfo often contain
     * more information about the cause of this error.
     */
    DCXErrorComponentWriteFailure = 8,

    /**
     * \brief A component referenced by the manifest is missing on the server.
     */
    DCXErrorMissingComponentAsset = 9,

    /**
     * \brief Trying to pull a DCXComposite that doesn't exist (any more?) on the server.
     *
     * The userInfo property of the error often contains additional information via
     * the DCXRequestURLKey, DCXResponseDataKey, DCXHTTPStatusKey, DCXErrorResponseHeadersKey
     * and NSUnderlyingErrorKey keys.
     */
    DCXErrorUnknownComposite = 10,

    /**
     * \brief Trying to pull or push a local composite that was previously deleted.
     *
     * In order to successfully upload the composite as a new composite on the server
     * the caller should first unbind it.
     */
    DCXErrorDeletedComposite = 11,

    /**
     * \brief The journal data is not valid.
     *
     * This error occurs when you create a DCXPushJournal from either from a file. Check the DCXDetailsKey
     * property in the userInfo dictionary of the error to get more details about the cause of the failure.
     */
    DCXErrorInvalidJournal = 12,

    /**
     * \brief The journal data is not complete.
     *
     * This error occurs when you try to merge or accept the results of a push if that push had
     * not succeeded.
     */
    DCXErrorIncompleteJournal = 13,

    /**
     * \brief The attempt to store a copy of a manifest as base manifest has failed.
     *
     * This error indicates a file manager error during push or pull. See NSUnderlyingError and
     * DCXPathErrorKey for details.
     */
    DCXErrorFailedToStoreBaseManifest = 14,

    /**
     * \brief A component of a composite has an invalid local storage path.
     */
    DCXErrorInvalidLocalStoragePath = 15,

    /**
     * \brief Trying to save a new composite over an existing composite on the server. You either
     * need to pull the existing composite from the server and resolve any conflicts before pushing
     * again, reset the identity of the composite to do the equivalent of a save as, or specify the
     * overwrite flag on the next pull request.
     */
    DCXErrorCompositeAlreadyExists = 16,

    /**
     * \brief This error can happen when attempting to copy components and/or manifest child nodes
     * between different branches of a composite if any of the components/child nodes already
     * exists in the target branch.
     */
    DCXErrorDuplicateId = 17,

    /**
     * \brief A server operation was attempted on a composite that does not have an assigned href.
     */
    DCXErrorCompositeHrefUnassigned = 18,

    /**
     * \brief This error can happen when an operation on a branch would result into two items (nodes,
     * components) with the same absolute path.
     */
    DCXErrorDuplicatePath = 19,

    /**
     * \brief A path of a manifest node or a component is invalid.
     */
    DCXErrorInvalidPath = 20,

    /**
     * \brief Cannot remove a component that has been locally modified from local storage
     */
    DCXErrorCannotRemoveModifiedComponent = 21,

    /**
     * \brief The component or child node ID could not be found.
     */
    DCXErrorUnknownId = 22,
    /**
     * The request cannot be completed.
     *
     * This typically means that there is something wrong with the url, the data,
     * or the file system. Repeating the request will most likely not help.
     *
     * The userInfo property of the error often contains additional information via
     * the DCXRequestURLKey, DCXResponseDataKey, DCXHTTPStatusKey, DCXErrorResponseHeadersKey
     * and NSUnderlyingErrorKey keys.
     */
    DCXErrorBadRequest = 23,
    
    /**
     * This error indicates a (likely temporary) problem with the network. This could
     * be caused by a server that is down or just too slow to respond.
     *
     * The NSUnderlyingErrorKey entry in userInfo often contains more information about the
     * cause of this error.
     */
    DCXErrorNetworkFailure = 24,
    
    /**
     * This error indicates that the device doesn't have a network connection (any more).
     *
     * The NSUnderlyingErrorKey entry in userInfo often contains more information about the
     * cause of this error.
     */
    DCXErrorOffline = 25,
    
    /**
     * This error indicates that the operation was cancelled.
     *
     * The NSUnderlyingErrorKey entry in userInfo often contains more information about the
     * cause of this error.
     */
    DCXErrorCancelled = 26,
    
    /**
     * The request failed due to an authentication failure, such as missing or
     * incorrect credentials.
     */
    DCXErrorAuthenticationFailed = 27,
    
    /**
     * The service is disconnected. This most likely happened because too many requests
     * have failed.
     */
    DCXErrorServiceDisconnected = 28,
    
    /**
     * A local input file does not exist
     */
    DCXErrorFileDoesNotExist = 29,
    
    /**
     *  No new requests could be enqueued because the service is in the process of processing existing requests prior
     *  to invalidation.
     */
    DCXErrorServiceInvalidating = 30,
    
    /**
     * A HTTP request was forbidden by the service.
     */
    DCXErrorRequestForbidden = 31,
    
    /**
     * A response from the server did not match its anticipated form and therefore
     * could not be processed.
     *
     * This could be caused by an unexpected HTTP response code or missing/malformed data.
     * Typically this indicates a (temporary) problem with the server or the network.
     *
     * The userInfo property of the error often contains additional information via
     * the DCXRequestURLKey, DCXResponseDataKey, DCXHTTPStatusKey,
     * DCXErrorResponseHeadersKey and NSUnderlyingErrorKey keys.
     */
    DCXErrorUnexpectedResponse = 32,
    
    /**
     * Both the local copy and the copy on the server have been modified. This error can happen
     * when trying to push local changes to an asset on the server.
     */
    DCXErrorConflictingChanges = 33,
    
    /**
     * Reading from a file has failed. This error can happen when a file fails to upload because it
     * can't be found or read.
     */
    DCXErrorFileReadFailure = 34,
    
    /**
     * Writing to a file has failed. This error can happen when a file fails to download because it
     * can't be written to local storage.
     */
    DCXErrorFileWriteFailure = 35,
    
    /**
     * An upload has failed because it would have exceeded the quota on the account
     */
    DCXErrorExceededQuota = 36,
    
    /**
     * An attempt was made to use an empty JSON payload.
     */
    DCXErrorMissingJSONData = 37,
    
    /**
     * A request with an unsupported protocol.
     */
    DCXErrorUnsupportedProtocol = 38
};
