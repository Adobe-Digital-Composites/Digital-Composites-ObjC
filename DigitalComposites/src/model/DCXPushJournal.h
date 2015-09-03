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

@class DCXMutableComponent;
@class DCXComposite;
@class DCXResourceItem;
@class DCXManifest;
@class DCXComponent;

/**
 \brief Captures the state and progess of a composite push operation
 which can be used to resume a failed push at a later time. 
 */
@interface DCXPushJournal : NSObject 

/**
 \brief Creates a file-backed journal for composite initialized from the contents of filePath (if the file
 exists).
 
 \param composite   The DCXComposite the journal is for.
 \param filePath    The path were the journal should be persisted to. If there is already a file at
 filePath its contents are going to be read in to initialize the journal.
 \param errorPtr    Gets set to an NSError if an error occurs. Can be nil.
 
 \return            The newly created journal.
 
 \note Even in the case of an error (e.g. corrupted data) the method will still return a valid
 instance of a DCXPushJournal, albeit an empty one. The reason for that is that the loss of the
 data of a DCXPushJournal does not prevent dmalib from pushing the composite. As such the errorPtr param
 is for informational purposes only.
 */
+(instancetype) journalForComposite:(DCXComposite*)composite persistedAt:(NSString*)filePath error:(NSError**)errorPtr;

/**
 \brief Creates a file-backed journal for doc initialized from the contents of filePath. Fails if the 
 file doesn't exist or can't be read/parsed.
 
 \param composite   The DCXComposite the journal is for.
 \param filePath    The path were the journal resides.
 \param errorPtr    Gets set to an NSError if an error occurs. Can be nil.
 
 \return            The newly created journal or nil if the file can't be read/parsed.
 */
+(instancetype) journalForComposite:(DCXComposite*)composite fromFile:(NSString*)filePath error:(NSError**)errorPtr;


/** An NSData representation of the journal. */
@property (readonly) NSData* data;


/** A path for a file to be used to persist the journal to. */
@property (readonly) NSString* filePath;


/** The href of the associated composite. */
@property (readonly) NSString* compositeHref;


/** YES if the composite has been deleted as part of the upload. */
@property (readonly) BOOL compositeHasBeenDeleted;


/** YES if the composite has been created as part of the upload. */
@property (readonly) BOOL compositeHasBeenCreated;


/** Is NO if the journal doesn't contain any data that is worth keeping. */
@property (readonly) BOOL isEmpty;


/** Is YES if the push has completed successfully. */
@property (readonly) BOOL isComplete;

/** The etag of current branch from the most recent call to pushComposite. */
@property (readonly) NSString *currentBranchEtag;

/**
 \brief Records the etag of the current branch that is being pushed
 
 \param etag The etag of the current branch
 */
-(void) recordCurrentBranchEtag:(NSString *)etag;

/**
 \brief Records the manifest as uploaded.
 
 \param component The uploaded DCXManifest.
 */
-(void) recordUploadedManifest:(DCXManifest*)manifest;

/**
 \brief Clears flag indicating a completed push
 */
-(void) clearPushCompleted;

/** 
 \brief Updates the etag of the manifest with the journaled etag
 
 \param manifest The manifest to update.
 
 \return NO if there was no journal etag for the manifest.
 */
-(BOOL) updateManifestWithJournalEtag:(DCXManifest*)manifest;

/**
 \brief Adds the component to the list of uploaded components.
 
 \param component The uploaded DCXComponent.
 \param filePath  The uploaded file.
 
 This method synchronizes access to the journal's underlying storage and
 thus can be called from different threads.
 */
-(void) recordUploadedComponent:(DCXComponent *)component fromPath:(NSString*)filePath;

/**
 \brief Returns an updated copy of the component it already has been uploaded.
 
 \param component The component in question.
 \param filePath  The uploaded file.
 
 \return If the component has previously been uploaded this method returns a an updated component 
 (which contains the new etag, hash and content length) otherwise it returns nil.
 
 This method synchronizes access to the journal's underlying storage and
 thus can be called from different threads.
 */
-(DCXMutableComponent*) getUploadedComponent:(DCXComponent*)component fromPath:(NSString*)filePath;


/**
 \brief Clears the journaled component state by removing the component from lists
 of components that have been uploaded, deleted, are pending delete, etc.
 
 \param component The DCXComponent that is being tracked
 
 This method synchronizes access to the journal's underlying storage and
 thus can be called from different threads.
 */
-(void) clearComponent:(DCXComponent*)component;

/**
 \brief Sets the composite href to the given NSURL.
 
 \param href The path of the composite.
 */
-(void) setCompositeHref:(NSString*)href;

/**
 \brief Sets whether the composite has been deleted during the push.
 
 \param deleted Whether the composite should be considered as deleted.
 */
-(void) recordCompositeHasBeenDeleted:(BOOL)deleted;

/**
 \brief Sets whether the composite has been created during the push.
 
 \param created Whether the composite should be considered as created.
 */
-(void) recordCompositeHasBeenCreated:(BOOL)created;


/**
 \brief Deletes the journal's file on disk.
 
 \param errorPtr Gets set to an NSError if something goes wrong.
 
 \return YES if successful or if the journal doesn't have a filePath.
 
 You can use this method to remove the file of a journal if you decide that you won't use
 it any more.
 */
-(BOOL) deleteFileWithError:(NSError**)errorPtr;

@end
