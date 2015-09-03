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

@class DCXComposite;
@class DCXBranch;
@class DCXComponent;
@class DCXMutableComponent;
@class DCXManifest;

/**
 * \brief Implements the copy-on-write local storage scheme. Component assets are
 * read-only and are stored in a flat directory with a GUID as name. When making
 * an update to a component asset it will get a new GUID and with it a new file name. 
 * This way clients can keep making changes to the composite while a push or a pull 
 * is in progress.
 */
@interface DCXLocalStorage : NSObject


#pragma mark - Paths

/**
 \brief Returns the path for the directory where the client can store private data.
 \param composite The composite to return the path for.
 
 \return The path.
 */
+(NSString*) clientDataPathForComposite:(DCXComposite*)composite;

/**
 \brief Returns the path to the current manifest of the specified composite.
 \param composite The composite to return the path for.
 
 \return The path.
 */
+(NSString*) currentManifestPathForComposite:(DCXComposite*)composite;

/**
 \brief Returns the path to the base manifest of the specified composite.
 \param composite The composite to return the path for.
 
 \return The path.
 */
+(NSString*) baseManifestPathForComposite:(DCXComposite*)composite;

/**
 \brief Returns the path to the pulled manifest of the specified composite.
 \param composite The composite to return the path for.
 
 \return The path.
 */
+(NSString*) pullManifestPathForComposite:(DCXComposite*)composite;

/**
 \brief Returns the path to the pushed manifest of the specified composite.
 \param composite The composite to return the path for.
 
 \return The path.
 */
+(NSString*) pushManifestPathForComposite:(DCXComposite*)composite;

/**
 \brief Returns the path to the pushed journal of the specified composite.
 \param composite The composite to return the path for.
 
 \return The path.
 */
+(NSString*) pushJournalPathForComposite:(DCXComposite*)composite;

/**
 \brief Returns the file path for reading the component.
 
 \param component The DCXComponent in question.
 \param manifest  The manifest that contains the component.
 \param composite The composite to return the path for.
 \param errorPtr  Optional pointer to an NSError that gets set if the path of the component is imvalid.
 
 \return The file path of the current component or nil if the path is invalid.
 */
+(NSString*) pathOfComponent:(DCXComponent*)component
                         inManifest:(DCXManifest*)manifest
                        ofComposite:(DCXComposite*)composite
                          withError:(NSError**)errorPtr;

/**
 \brief Returns the file path for writing a new version of the current component.
 
 \param component The DCXComponent in question.
 \param manifest  The manifest that contains the component.
 \param composite The composite to return the path for.
 \param errorPtr  Optional pointer to an NSError that gets set if the path of the component is imvalid.
 
 \return The file path of the current component or nil if the path is invalid.
 */
+(NSString*) newPathOfComponent:(DCXComponent*)component
                     inManifest:(DCXManifest*)manifest
                    ofComposite:(DCXComposite*)composite
                      withError:(NSError**)errorPtr;

/**
 \brief Updates the component with the new path for the component's asset. May also make the component
 asset file read-only if the storage scheme demands it.
 
 \param component The DCXComponent in question.
 \param manifest  The manifest that contains the component.
 \param composite The composite to return the path for.
 \param assetPath The new absolute file path of the component asset.
 \param errorPtr  Optional pointer to an NSError that gets set if the path of the component is imvalid.
 
 \return True if successful.
 */
+(BOOL) updateComponent:(DCXMutableComponent*)component
             inManifest:(DCXManifest*)manifest
            ofComposite:(DCXComposite*)composite
            withNewPath:(NSString*)assetPath
              withError:(NSError**)errorPtr;

#pragma mark - Push & Pull Support

/**
 \brief Makes the pulled version the current version. Uses the provided manifest or (if it is nil)
 the pulled manifest on disk. Also updates the base manifest.
 
 \param manifest The manifest to accept. Can be nil in which case the pulled manifest on disk must be used.
 \param composite The composite to act upon.
 \param errorPtr Gets set to an NSError if something goes wrong.
 
 \return YES on success.
 
 \note If this operation fails the current state of the composite must stay intact.
 */
+(BOOL) acceptPulledManifest:(DCXManifest*)manifest forComposite:(DCXComposite*)composite withError:(NSError**)errorPtr;

/**
 \brief Discards last pulled-down version of the composite.
 Is a no-op if there isn't such a version.
 
 \param composite The composite to act upon.
 \param errorPtr Gets set to an NSError if something goes wrong.
 
 \return YES on success.
 */
+(BOOL) discardPullOfComposite:(DCXComposite*)composite withError:(NSError**)errorPtr;

/**
 \brief Discards the data from the last push(es).
 Is a no-op if there isn't such data.
 
 \param composite The composite to act upon.
 \param errorPtr Gets set to an NSError if something goes wrong.
 
 \return YES on success.
 */
+(BOOL) discardPushOfComposite:(DCXComposite*)composite withError:(NSError**)errorPtr;


#pragma mark - Misc

/**
 \brief Delete all files associated with previous pushes and pulls.
 
 \param composite The composite to act upon.
 \param errorPtr Gets set to an NSError if something goes wrong.
 
 \return YES on success.
 */
+(BOOL) resetBindingOfComposite:(DCXComposite*)composite withError:(NSError**)errorPtr;

/**
 \brief Delete all local files of the composite.
 
 \param composite The composite to act upon.
 \param errorPtr Gets set to an NSError if something goes wrong.
 
 \return YES on success.
 */
+(BOOL) removeLocalFilesOfComposite:(DCXComposite*)composite withError:(NSError**)errorPtr;

/**
 \brief Delete all unused local files of the composite.
 
 \param composite The composite to act upon.
 \param errorPtr Gets set to an NSError if something goes wrong.
 
 \return NSNumber object containing an unsigned long long value with the total size of local storage
 that was freed as a result of removing the unused files.
 */
+(NSNumber*) removeUnusedLocalFilesOfComposite:(DCXComposite*)composite withError:(NSError**)errorPtr;

/**
 \brief Used by the pull logic to give the local storage scheme an opportunity to
 verify, edit or insert its local storage-related data into a pulled manifest before
 it is stored.
 
 \param targetManifest The manifest to update.
 \param sourceManifest The manifest that has existing storage data.
 */
+(void) updateLocalStorageDataInManifest:(DCXManifest*)targetManifest
                       fromManifestArray:(NSArray*)sourceManifests;

/**
 Gets called when the given component has been removed from the given manifest.
 
 \param component   The component that was removed.
 \param manifest    The manifest the component was removed from.
 */
+(void) didRemoveComponent:(DCXComponent*)component fromManifest:(DCXManifest*)manifest;

/**
 \brief Produces a dictionary which maps component ID to the local storage path for all of the
 components in the specified composite branch that have an existing local file
 
 \param branch  A DCXBranch object
 
 \return The dictionary described above
 */
+(NSDictionary*) existingLocalStoragePathsForComponentsInBranch:(DCXBranch*)branch;

#pragma mark - Partial composite support

/**
 \brief Should be called when the a component's local file has been deleted from the file system.
 
 \param component   The component whose local file storage should be removed
 \param manifest    The manifest containing this component
 */

+(void) didRemoveLocalFileForComponent:(DCXComponent*)component
                            inManifest:(DCXManifest*)manifest;

@end
