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

#import "DCXComposite.h"

@interface DCXComposite()

/** The DCXManifest. */
@property (readonly) DCXManifest* manifest;

/**
 \brief The most recent time that current branch was committed to, or initialized from, the manifest file in local storage
 */
@property (atomic, readwrite) NSDate *currentBranchCommittedAtDate;

#pragma mark - Initialization

/**
 * \brief Designated initializer. Used by the other initializers.
 *
 * \param path            Path of the local directory of the composite.
 * \param href            Path of the composite on the server.
 * \param compositeId     The id of the composite.
 * \param errorPtr        Gets set if an error occurs while reading and parsing the manifest file.
 *
 * If a path is given the initializer will attempt to read/parse the manifest and fail if that doesn't
 * succeed.
 */
- (instancetype)initWithPath:(NSString *)path andHref:(NSString *)href andId:(NSString *)compositeId
         withError:(NSError **)errorPtr;


/**
 * \brief Initializer with manifest and local path. Use for composites that already exist locally.
 *
 * \param manifest        DCXManifest.
 * \param path            Path of the local directory of the composite.
 *
 * This initializer doesn't attempt to read in the manifest from disk but rather uses the provided manifest.
 */
- (instancetype)initWithManifest:(DCXManifest *)manifest andPath:(NSString *)path;


/**
 * \brief Creates a composite from a manifest and a local path.
 * Use for composites that already exist locally and whose manifest is already instantiated.
 *
 * \param manifest        The current manifest object of the composite.
 * \param path            Path of the local directory of the composite.
 */
+ (instancetype)compositeFromManifest:(DCXManifest *)manifest andPath:(NSString *)path;


#pragma mark - Branches

-(void) updateCurrentBranchWithManifest:(DCXManifest*)manifest updateCommittedAtDate:(BOOL)updateCommittedAt;
-(void) updatePulledBranchWithManifest:(DCXManifest*)manifest;
-(void) updatePushedBranchWithManifest:(DCXManifest*)manifest;
-(void) updateLocalBranch;
-(void) updateBaseBranch;

-(void) updateCurrentBranchCommittedDate;

/**
 * \brief Removes the pushed manifest if it exists and invalidates the pushed branch property of the composite
 while preserving the push journal
 */
-(void) discardPushedManifest;

#pragma mark - Components

/**
 \brief Removes the given component from the given manifest.
 
 \param component   The component to remove.
 \param manifest    The manifest to remove the component from. If nil the manifest gets removed from
 the current manifest.
 
 \return The component or nil if the component didn't exist within the composite.
 */
-(DCXComponent*) removeComponent:(DCXComponent*)component fromManifest:(DCXManifest*)manifest;


/**
 Adds the existing component from sourceManifest to destManifest.
 
 \param component       The component which must exist in sourceManifest.
 \param sourceManifest  The manifest of the component.
 \param sourceComposite The composite of the component.
 \param node            The child node to add the new component to. Can be nil.
 \param destManifest    The manifest the component should be added to.
 \param replaceExisting If a component with the same ID exists, remove it before adding
 \param newPath         Optional new path.
 \param errorPtr        Gets set if an error occurs.
 
 \return The newly added component or nil if an error occurs.
 
 \note This method does not remove the component from sourceManifest.
 
 \note IMPORTANT: This version of addComponent may only be called on composites using the
 CopyOnWrite local storage scheme.
 */
-(DCXComponent*) addComponent:(DCXComponent*)component
                      fromManifest:(DCXManifest*)sourceManifest
                       ofComposite:(DCXComposite*)sourceComposite
                           toChild:(DCXNode*)node
                        ofManifest:(DCXManifest*)destManifest
                   replaceExisting:(BOOL)replaceExisting
                           newPath:(NSString*)newPath
                         withError:(NSError**)errorPtr;


#pragma mark - Components

/**
 Adds the existing child node from sourceManifest to destManifest.
 
 \param node            The node to add which must exist in sourceManifest.
 \param sourceManifest  The manifest of the node.
 \param sourceComposite The composite of the node.
 \param parentNode      The parent node to add the new child to. Can be nil.
 \param destManifest    The manifest the node should be added to.
 \param replaceExisting Whether to replace an existing node.
 \param newPath         Optional new path.
 \param errorPtr        Gets set if an error occurs.
 
 \return The newly added child node or nil if an error occurs.
 
 \note This method does not remove the child node from sourceManifest.
 
 \note IMPORTANT: This version of addChild may only be called on composites using the
 CopyOnWrite local storage scheme.
 
 */
-(DCXNode*) addChild:(DCXNode *)node
                     fromManifest:(DCXManifest *)sourceManifest
                      ofComposite:(DCXComposite*)sourceComposite
                               to:(DCXNode *)parentNode
                          atIndex:(NSUInteger)index
                       ofManifest:(DCXManifest *)destManifest
                  replaceExisting:(BOOL)replaceExisting
                          newPath:(NSString*)newPath
                        withError:(NSError **)errorPtr;


#pragma mark - Storage

/**
 \brief Used by the pull logic to give the local storage scheme an opportunity to
 verify, edit or insert its local storage-related data into a pulled manifest before
 it is stored.
 
 \param targetManifest The manifest to update.
 \param sourceManifests The manifests that have existing storage data.
 */
-(void) updateLocalStorageDataInManifest:(DCXManifest *)targetManifest fromManifestArray:(NSArray *)sourceManifests;


/** The file path of the manifest of the current local composite.
 Notice that this file might not yet/anymore exist. */
@property (readonly) NSString* currentManifestPath;

/** The file path of the pulled manifest.
 Notice that this file might not yet/anymore exist. */
@property (readonly) NSString* pulledManifestPath;

/** The file path of the base copy of the pulled manifest.
 Notice that this file might not yet/anymore exist. */
@property (readonly) NSString* pulledManifestBasePath;

/** The file path of the pushed manifest.
 Notice that this file might not yet/anymore exist. */
@property (readonly) NSString* pushedManifestPath;

/** The file path of the base copy of the pushed manifest.
 Notice that this file might not yet/anymore exist. */
@property (readonly) NSString* pushedManifestBasePath;

/** The file path of a previously uploaded or downloaded manifest that can be used to diff  local and remote versions. */
@property (readonly) NSString* baseManifestPath;

/** The file path for the composite's push journal.
 Notice that this file might not yet/anymore exist. */
@property (readonly) NSString* pushJournalPath;

/** The manifest of an active push operation for this composite. */
@property (readwrite) DCXManifest* activePushManifest;

/** The set of component files that are currently being copied or moved into the components directory
 and may not yet have updated timestamps.  Retrieves a copy in a thread-safe manner. */
@property (readonly) NSSet *inflightLocalComponentFiles;

/** Thread-safe methods to add and remove a component path to the list of inflight components. */
-(void) addPathToInflightLocalComponents:(NSString*)destinationPath;
-(void) removePathFromInflightLocalComponents:(NSString*)destinationPath;

-(void) requestDeletionOfUnsusedLocalFiles;

-(DCXManifest *) copyCommittedManifestWithError:(NSError **)errorPtr;


@end
