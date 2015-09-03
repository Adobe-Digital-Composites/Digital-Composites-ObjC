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
@class DCXMutableBranch;
@class DCXManifest;
@class DCXComponent;
@class DCXNode;

/**
 * \brief Represents a Digital Composite Technology composite.
 *
 * How to create a composite
 * ---------------------------------
 *
 * DCXComposite defines several initializers and convenience methods.
 * Which one you should use depends on whether the composite already exists locally
 * and/or on the server.
 *
 + If the composite exists locally you must use either the @see compositeFromPath:withError:
 + method or @see compositeFromManifest:andPath: if you already have an in-memory instance of
 + the composite's manifest. This will result in a fully populated DCXComposite by reading
 + and parsing the manifest file from local storage (if it isn't being passed in).
 +
 + Else if the composite exists on server you must use either the @see compositeFromHref:andId:andPath:
 + method or @see compositeFromResource:andPath:. Notice that the resulting DCXComposite is
 + not yet fully functional since it doesn't have a manifest yet, however it can be used to pull
 + the composite from the server.
 +
 + Else (the composite doesn't exist on either the server or locally yet) you need to use the
 + @see compositeFromName:andType:andPath:andId:withError method.
 +
 + Branches
 + ----------------
 + The actual data of the composite (its components, child nodes, etc.) are accessible through
 + its branches. The main branch is called 'current' and represents the last synced state of the composite
 + with all additional local changes.
 +
 + After a successful call to DCXCompositeXfer's pullComposite: or pullMinimalComposite: the 'pulled'
 + branch contains the data that was pulled from the service. 'current' remains untouched. If you have
 + made changes to 'current' you can now merge those changes into 'pulled'. Call resolvePullWithBranch:withError:
 + in order to update 'current' from 'pulled' and dispose of 'pulled'.
 +
 + After a successful call to DCXCompositeXfer's pushComposite: the 'pushed' branch contain updates
 + that stem from the push operation. Call acceptPushWithError: to merge the updated server state from the 'pushed'
 + branch into the 'current' branch in memory and into the manifest file on disk, and to dispose of 'pushed'.
 +
 +
 */
@interface DCXComposite : NSObject

#pragma mark - Initializers

/**
 * \brief Initializer with local path. Use for composites that already exist locally.
 *
 * \param path            Path of the local directory of the composite.
 * \param errorPtr        Gets set if an error occurs while reading and parsing the manifest file.
 *
 * Will attempt to read/parse the manifest and fail if that doesn't succeed.
 */
- (instancetype)initWithPath:(NSString *)path withError:(NSError **)errorPtr;

/**
 * \brief Initializer with href and id. Use for composites that do net yet exist locally but do exist on
 * the server.
 *
 * \param href            Path of the composite on the server.
 * \param compositeId     The id of the composite.
 */
- (instancetype)initWithHref:(NSString *)href andId:(NSString *)compositeId;

/**
 * \brief Initializer for an empty new composite.  Use this if you construct a composite from scratch.
 * The composite will not be saved to local storage so you must call commitChangeWithError:
 * before you can push it to the server.
 *
 * \param name            The name of the new composite.
 * \param type            The mime type of the new composite.
 * \param path            Path of the local directory of the composite.
 * \param compositeId     The id of the composite.
 * \param href            Path of the composite on the server. May be nil if href is not yet known.
 */
- (instancetype)initWithName:(NSString *)name andType:(NSString *)type andPath:(NSString *)path andId:(NSString *)compositeId
           andHref:(NSString *)href;


#pragma mark - Convenience Factory Methods

/**
 * \brief Creates a composite from a local path. Use for composites that already exist locally.
 *
 * \param path            Path of the local directory of the composite.
 * \param errorPtr        Gets set if an error occurs while reading and parsing the manifest file.
 *
 * Will attempt to read/parse the manifest and fail if that doesn't succeed.
 */
+ (instancetype)compositeFromPath:(NSString *)path withError:(NSError **)errorPtr;

/**
 * \brief Creates a composite from an href.
 * Use for composites that do net yet exist locally but do exist on the server.
 *
 * \param href            Path of the composite on the server.
 * \param compositeId     The id of the composite.
 * \param path            A file path to an existing but empty local directory that will end up containing the
 * composite's manifest and assets.
 */
+ (instancetype)compositeFromHref:(NSString *)href andId:(NSString *)compositeId andPath:(NSString *)path;

/**
 * \brief Creates an empty composite. Use this if you construct a composite from scratch.
 * The composite will not be saved to local storage so you must call commitChangesWithError before
 * you can push it to the server.
 *
 * \param name            The name of the new composite.
 * \param type            The mime type of the new composite.
 * \param path            Path of the local directory of the composite.
 * \param compositeId     The id of the new composite. Can be nil in which case an id will be generated when
 *                      writing the manifest.
 * \param href            Path of the composite on the server. May be nil if this path is not known at the time of
 *                      creation.
 */
+ (instancetype)compositeWithName:(NSString *)name andType:(NSString *)type andPath:(NSString *)path
                  andId:(NSString *)compositeId andHref:(NSString *)href;


#pragma mark - Properties


/** The local storage directory for this composite. */
@property NSString *path;

/** The href path (on the server) of this composite.
 * \note You can only set this on an unbound composite. I.e. you need to call resetBinding: or resetIdentity:
 * before you can assign a new href to a composite. */
@property NSString *href;

/** The id of this composite. */
@property NSString *compositeId;

/** Is YES if the composite is bound to a specific composite on the server. */
@property (nonatomic, readonly) BOOL isBound;

/** Controls whether unused local components are cleaned up automatically in a background thread
 * Defaults to YES.  If set to NO then the client is responsible for calling removeUnusedLocalFiles
 */
@property (nonatomic, readwrite) BOOL autoRemoveUnusedLocalFiles;

/** The state of the composite that has been committed (saved) to local storage.
 *  The string will be one of DCXAssetStateUnmodified, DCXAssetStateModified,
 *  DCXAssetStatePendingDelete, DCXAssetStateCommittedDelete, or nil if the
 *  composite has not been committed yet.
 *
 *  Note: to obtain the in-memory composite state, use the compositeState property of
 *  the 'current' branch.
 */
@property (nonatomic, readonly) NSString *committedCompositeState;

#pragma mark - Branches

/** The different branches of the composite. A branch can be nil if it doesn't exist in local storage. */

/** The mutable current branch of the composite (including any in-memory changes). Is nil if the
 * composite doesn't yet exist locally. */
@property (nonatomic, readonly) DCXMutableBranch *current;

/** The pulled branch of the composite. Is nil if the composite doesn't have a pending pull. */
@property (nonatomic, readonly) DCXBranch *pulled;

/** The pushed branch of the composite. Is nil if the composite doesn't have a pending push. */
@property (nonatomic, readonly) DCXBranch *pushed;

/** The base branch of the composite. Is nil if the composite doesn't exist either locally (never
 * been pulled) or on the server (never been pushed).
 */
@property (nonatomic, readonly) DCXBranch *base;

/**
 * \brief Makes the provided merged branch the current branch of the composite in memory and on disk,
 * discards the pulled branch on disk, and updates the base branch.
 *
 * \param branch          The merged branch to be promoted to the new current branch.  May be nil, in
 * which case the pulled branch is copied directly.
 * \param errorPtr        Gets set to an NSError if something goes wrong.
 *
 * \return         YES on success.
 *
 * \note The merged branch should be the result of merging the pulled branch with the current branch,
 * and the merged branch should originate by copying either the pulled or current branch.
 *
 * \note If the controller property of the composite is non-nil, then the associated DCXController
 * will process any errors that result from calling this method and will inform the client via the
 * controller:requestsClientHandleError:... method on its delegate in addition to setting the
 * errorPtr upon return from this call.
 */
- (BOOL)resolvePullWithBranch:(DCXMutableBranch *)branch withError:(NSError **)errorPtr;


/**
 * \brief Accepts the result of a successful push operation by merging the server state in the resulting pushed
 * branch into the current branch in memory and into the manifest file on disk,
 * updating the base branch to be the pushed branch, and ultimately discarding the pushed branch.
 * This method is a no-op and returns YES in the event that no pushed branch exists.
 *
 * \param errorPtr        Gets set to an NSError if something goes wrong.
 *
 * \return                YES on success.
 *
 * \note This method should only be used on composites that have been created to use the copy-on-write local
 * storage scheme.
 *
 * \note If the controller property of the composite is non-nil, then the associated DCXController
 * will process any errors that result from calling this method and will inform the client via the
 * controller:requestsClientHandleError:... method on its delegate in addition to setting the
 * errorPtr upon return from this call.
 */
- (BOOL)acceptPushWithError:(NSError **)errorPtr;

/**
 * \brief Discards last pulled-down branch of the composite. Is a no-op if there isn't such a branch.
 *
 * \param errorPtr Gets set to an NSError if something goes wrong.
 *
 * \return YES on success.
 */
- (BOOL)discardPulledBranchWithError:(NSError **)errorPtr;


/**
 * \brief Discards the branch from the last push(es). Is a no-op if there isn't such branch.
 *
 * \param errorPtr Gets set to an NSError if something goes wrong.
 *
 * \return YES on success.
 */
- (BOOL)discardPushedBranchWithError:(NSError **)errorPtr;

#pragma mark - Local Storage

/** The file path for client-specific data belonging to the composite. The files in this directory
 * will be ignored by library logic. Notice that this directory might not yet exist. */
@property (readonly) NSString *clientDataPath;

/**
 * \brief Commits the manifest of the composite to local storage.
 *
 * Returns YES if the manifest is successfully written (or if the manifest is not written
 * because the composite's manifestPath is nil); NO if an error occurs.
 *
 * \param errorPtr Gets set if an error occurs while writing the manifest file.
 *
 * \return YES on success.
 */
- (BOOL)commitChangesWithError:(NSError **)errorPtr;

/**
 * \brief Deletes the directory at the path of the composite with all its contents.
 *
 * \param errorPtr Gets set if an error occurs.
 *
 * \return YES on success.
 */
- (BOOL)removeLocalStorage:(NSError **)errorPtr;

/**
 * \brief Deletes unused local files such as components that are no longer referenced by any branch of the composite.
 *
 * This method is only required to be called when the client has set the autoRemoveUnusedLocalFiles property to NO
 * and only when using the DCXLocalStorageSchemeCopyOnWrite storage scheme is used.  Since the
 * DCXLocalStorageDirectores scheme does not generate any unused local files, this method will have no effect
 * when that scheme is in use.
 *
 * \param errorPtr Gets set if an error occurs.
 *
 * \return NSNumber object containing an unsigned long long values with the total number of bytes freed
 * as a result of removing the files.
 *
 * \note Returns a non-nil NSNumber if any files were successfully removed OR if no error has
 * occurred.
 */
- (NSNumber *)removeUnusedLocalFilesWithError:(NSError **)errorPtr;

/**
 * \brief Deletes the local files for the specified unmodified components that are referenced from the
 * current or base branches of this composite.
 *
 * An DCXErrorCannotRemoveModifiedComponent error will be generated for any components that exist
 * in the 'current' branch (in memory or on disk) whose state is currently set to DCXAssetStateModified
 *
 * \param componentIDs    An array of component IDs
 * \param errorList       An optional pointer to an array that will be set to a list of any errors that prevent
 * the successful removal of one or more of the specified components
 *
 * \return The number of bytes freed by removing the files as a result of calling this method.
 *
 * \note A number will always be returned from this method so the caller should check the errorList
 * parameter to determine if any errors prevented the entire operation from completing successfully.
 */
- (NSNumber *)removeLocalFilesForComponentsWithIDs:(NSArray *)componentIDs errorList:(NSArray **)errorListPtr;

/**
 * \brief Returns the number of bytes of local storage consumed by the composite
 *
 * \return A NSNumber object containing an unsigned long long value
 *
 * \note This method does not include files that are managed directly by the application (e.g. files saved in clientdata)
 */
- (NSNumber *)localStorageBytesConsumed;

#pragma mark - Reset

/**
 * \brief Remove all service-related data from the current branch so that
 * it can be pushed again to the same or a different service.
 *
 * Removes all service-related links, etags and the service identifier.
 * Removes any deleted components.
 * Sets states of composite and components to modified.
 *
 * \note This method doesn't reset the ids of the composite or its child nodes/components.
 * Thus you cannot push it to the same service as long as the original composite still exists on that
 * service. If you do want to push this composite as a duplicate of the original composite
 * you'll want to call resetIdentity instead.
 */
- (void)resetBinding;


/**
 * \brief Assigns new ids to the current branch. Also removes service-related data from the manifest so that
 * it can be pushed again to the same or a different service.
 *
 * Removes all service-related links, etags, etc.
 * Removes any deleted components.
 * Generates new a id for the composite.
 * Sets states of composite and components to modified.
 */
- (void)resetIdentity;

#pragma mark - Testing

/**
 * Can be used in tests to verify the internal consistency of the composite.
 */
-(NSArray*) verifyIntegrityWithLogging:(BOOL)doLog shouldBeComplete:(BOOL)shouldBeComplete;

@end
