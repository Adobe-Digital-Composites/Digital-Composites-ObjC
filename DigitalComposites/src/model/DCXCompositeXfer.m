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

#import "DCXCompositeXfer.h"

#import "DCXError.h"
#import "DCXConstants_Internal.h"

#import "DCXCompositeRequest.h"
#import "DCXPushJournal.h"
#import "DCXComposite_Internal.h"
#import "DCXManifest.h"
#import "DCXMutableComponent.h"
#import "DCXTransferSessionProtocol.h"
#import "DCXBranch_Internal.h"
#import "DCXMutableBranch_Internal.h"
#import "DCXNode.h"
#import "DCXLocalStorage.h"
#import "DCXResourceItem.h"

#import "DCXServiceMapping.h"
#import "DCXHTTPService.h"

#import "DCXErrorUtils.h"
#import "DCXFileUtils.h"
#import "DCXUtils.h"

typedef void (^PushCompletionHandler)(NSArray *pushErrors);
typedef void (^PullCompletionHandler)(NSMutableArray *downloadErrors);
typedef void (^DCXCompositeManifestDownloadBlock)(DCXManifest*, DCXManifestRequestCompletionHandler);
typedef DCXHTTPRequest* (^DCXCompositeManifestUploadRequest)(DCXManifest*, void(^)(DCXManifest*, NSError*));
typedef DCXManifest* (^DCXCompositeManifestDownload)(DCXManifest*, NSError**);

#pragma mark - Tracker

/**
 Keeps track of all of the bookkeeping required while updating the compoments in a composite,
 including when some operations are executing asynchronously. All methods in this class
 are thread-safe.
 
 Methods must be invoked in a legal sequence in order for this class to operate properly:
 
 # For each component to be updated, addPendingCompoment: must be called before either
 componentWasAdded:, compomentWasUpdated:, or componentWasDeleted.
 # Each call to addPendingComponent must be balanced with exactly one call to one of
 componentWasAdded:, compomentWasUpdated:, or componentWasDeleted.
 # Clients must not call updateManifest: or getErrors until after calling wait:.
 */
@interface PushComponentTracker : NSObject

/**
 Note that an add, update, or delete for a component is pending. This must be invoked
 for every operation so that pending and completed operations can be properly balanced.
 */

-(void) setPendingComponents:(int)pendingComponents;

/** Record that a pending add has completed. */
-(void) componentWasAdded:(DCXComponent*)component fromPath:(NSString*)path ofComposite:(DCXComposite*)composite error:(NSError*)error;

/** Record that a pending update has completed. */
-(void) componentWasUpdated:(DCXComponent*)component fromPath:(NSString*)path ofComposite:(DCXComposite*)composite error:(NSError*)error;

/** Record that a component was skipped over during the upload because it was unmodified */
-(void) componentWasUnmodified:(DCXComponent*)component;

/** Returns the list of errors that occurred, or nil if none did. */
-(NSArray*) getErrors;

/** Modifies the given manifest to reflect all reported updates. */
-(void) updateManifest;

/** Releases all the requests tracked by this tracker instance. */
-(void) releaseRequest;

/** Explicit call to indicate push completion */
-(void) onPushCompletion;

@end

@implementation PushComponentTracker
{
    NSInteger       pendingOperationCount;
    NSMutableArray *errorList;
    NSMutableArray *componentsToBeUpdated;
    NSMutableArray *componentsToBeRemoved;
    
    DCXPushJournal *_journal;
    DCXCompositeRequest *_request;
    PushCompletionHandler _completionHandler;
    DCXManifest *_trackedManifest;
    DCXComposite *_trackedComposite;
}

-(id) initWithJournal:(DCXPushJournal*)journal
          forManifest:(DCXManifest*)manifest
          ofComposite:(DCXComposite*)composite
           andRequest:(DCXCompositeRequest*)request
andPushCompletionHandler:(PushCompletionHandler)completionHandler
{
    if (self = [super init]) {
        errorList = [[NSMutableArray alloc] init];
        pendingOperationCount = 0;
        componentsToBeUpdated = [NSMutableArray array];
        componentsToBeRemoved = [NSMutableArray array];
        _journal = journal;
        _request = request;
        _completionHandler = completionHandler;
        _trackedManifest = manifest;
        _trackedComposite = composite;
    }
    
    return self;
}

-(void) setPendingComponents:(int) pendingComponents
{
    @synchronized(self){
        pendingOperationCount = pendingComponents;
    }
}

-(void) cancelRemainingRequestsOnNontransientError:(NSError*)error
{
    NSInteger statusCode = [[error.userInfo objectForKey:DCXHTTPStatusKey] integerValue];
    
    //   over quota           forbidden
    if (statusCode == 507 || statusCode == 403 || (error.code == DCXErrorExceededQuota && [error.domain isEqualToString:DCXErrorDomain])) {
        if (!_request.progress.isCancelled) {
            [_request.progress cancel];
        }
    }
}

-(void) componentWasUnmodified:(DCXComponent *)component{
    @synchronized(self){
        pendingOperationCount--;
        if(pendingOperationCount == 0){
            [self onPushCompletion];
        }
    }
}

-(void) componentWasAdded:(DCXComponent *)component fromPath:(NSString*)path
              ofComposite:(DCXComposite*)composite error:(NSError *)error
{
    // These two methods happen to have the same implementation.
    [self componentWasUpdated:component fromPath:path ofComposite:composite error:error];
}

-(void) componentWasUpdated:(DCXMutableComponent*)component fromPath:(NSString*)path
                ofComposite:(DCXComposite*)composite error:(NSError*)error
{
    if (error == nil) {
        NSString *href = nil;
        if ( path != nil) {
            // Add path to lookup table so that other components that share the same local
            // file can be updated via server-to-server copy instead
            DCXResourceItem *resource = [DCXServiceMapping resourceForComponent:component ofComposite:composite withPath:path useVersion:YES];
            href = resource.href;
        }
        // Mark the component as uploaded in the journal
        [_journal recordUploadedComponent:component fromPath:path];
    }
    
    @synchronized(self){
        if (error) {
            [errorList addObject:error];
            [self cancelRemainingRequestsOnNontransientError:error];
            
        } else {
            component.state = DCXAssetStateUnmodified;
            [componentsToBeUpdated addObject:component];
        }
        
        pendingOperationCount--;
        if(pendingOperationCount == 0){
            [self onPushCompletion];
        }
    }
}

-(void) onPushCompletion
{
    NSArray *errors = [self getErrors];
    if (errors) {
        NSMutableArray *errorsToReturn = [NSMutableArray array];
        [errorsToReturn addObjectsFromArray:errors];
        _completionHandler(errorsToReturn);
    }else{
        [self updateManifest];
        [self releaseRequest];  // break retain cycle by releasing all the requests retained by the tracker
        _trackedManifest = nil; // break retain cycle for push manifest being tracked
        _completionHandler(nil);

    }
}

-(NSArray*) getErrors
{
    return errorList.count == 0 ? nil : [errorList copy];
}

-(void) updateManifest
{
    for(DCXMutableComponent *component in componentsToBeUpdated) {
        [_trackedManifest updateComponent:component withError:nil];
    }
    for(DCXMutableComponent *component in componentsToBeRemoved) {
        [_trackedComposite removeComponent:component fromManifest:_trackedManifest];
    }
}

-(void) releaseRequest
{
    [_request releaseRequests];
    _request = nil;
}

@end


@interface PullComponentTracker:NSObject
-(void) setPendingComponnents:(int)pendingComponents;
-(void) componentWasDownloadedWithError:(NSError*)error;
@end

@implementation PullComponentTracker
{
    NSMutableArray          *downloadErrors;
    NSInteger               pendingOperationCount;
    PullCompletionHandler   _completionHandler;
}

-(id) initWithCompletionHandler:(PullCompletionHandler)completionHandler
{
    if (self = [super init]) {
        downloadErrors = [[NSMutableArray alloc] init];
        pendingOperationCount = 0;
        _completionHandler = completionHandler;
    }
    return self;
}


-(void) setPendingComponnents:(int)pendingComponents
{
    @synchronized(self){
        pendingOperationCount = pendingComponents;
    }
}

-(void) componentWasDownloadedWithError:(NSError*)error
{
    @synchronized(self){
        if(error != nil){
            [downloadErrors addObject:error];
        }
        pendingOperationCount--;
        if(pendingOperationCount == 0){
            if(_completionHandler != nil){
                _completionHandler(downloadErrors);
            }
        }
    }
}

@end

#pragma mark - Transfer

@implementation DCXCompositeXfer

#pragma mark - Push - Public API

+(DCXHTTPRequest*) pushComposite:(DCXComposite *)composite
                             usingSession:(id<DCXTransferSessionProtocol>)session
                          requestPriority:(NSOperationQueuePriority)priority
                            handlerQueue :(NSOperationQueue *)queue
                        completionHandler:(DCXPushCompletionHandler)handler
{
    // Defining the callback that issues the upload request for the manifest
    DCXCompositeManifestUploadRequest uploadRequest = ^DCXHTTPRequest*(DCXManifest *manifest, void (^handler)(DCXManifest*, NSError*)) {
        NSAssert(composite.activePushManifest != nil, @"Unexpected composite state: activePushManifest should not be nil.");
        return [session updateManifest:manifest ofComposite:composite requestPriority:priority handlerQueue:nil completionHandler:handler];
    };
    
    if ( composite.current.isDirty ) {
        NSLog(@"Warning: pushComposite has been called with a composite that has uncommitted changes in its current branch. "
                @"Uncommitted changes will not be included in the pushed composite.");
    }
    
    // Create a copy of the manifest. Notice that we do not use composite.manifest since we do not
    // want to touch that unless we are absolutely sure that the push has succeeded.
    // Note that we do this synchronously in order to avoid the potential for concurrency problems
    // if the caller starts modifying the current branch immediately after calling this method.
    NSError *manifestReadError = nil;
    __block DCXManifest *pushManifest = [composite copyCommittedManifestWithError:&manifestReadError];
    
    void(^pushCompletionHandler)(BOOL, NSError*) = ^void(BOOL success, NSError*  error){
        // push manifest not needed anymore
        composite.activePushManifest = nil;
        if(handler){
            if(queue != nil){
                [queue addOperationWithBlock:^{
                    handler(success, error);
                }];
            } else {
                handler(success, error);
            }
        }
    };
    
    DCXCompositeRequest *compRequest = [[DCXCompositeRequest alloc] initWithPriority:priority];
    [self internalPushComposite:composite
                   pushManifest:pushManifest
          pushManifestReadError:manifestReadError
                   usingSession:session
               compositeRequest:compRequest
            updateManifestBlock:uploadRequest
              completionHandler:pushCompletionHandler];

    return compRequest;
}

#pragma mark Push - Internal

/**
This is a helper method for pushComposite; it handles _just_ the components.

Upon successful completion, ``manifest`` will have been modified to reflect the results
of pushing these components to the server: remaining components will have a state of 'unmodified',
and components with a prior state of committedDelete will have been removed.

This method will issue some operations in parallel, and therefore can collect a set of
errors when something goes wrong. If everything succeeds, it returns YES and errorListPtr
is not touched. If an error occurs, it returns NO and sets errorListPtr to an NSArray of
NSError objects.
*/
+(void) pushComponentsInManifest:(DCXManifest*)manifest
                     ofComposite:(DCXComposite*)composite
                    usingSession:(id<DCXTransferSessionProtocol>)session
                     withJournal:(DCXPushJournal*)journal
                compositeRequest:(DCXCompositeRequest*)compRequest
                componentTracker:(PushComponentTracker*) tracker

{
    NSAssert(composite.activePushManifest != nil, @"Unexpected composite state: activePushManifest should not be nil.");
    NSProgress *progress = compRequest.progress;
    
    // Object to be used for synchronization
    NSString *const accessLock = @"accessLock";
    
    // Implementation Note: Because we schedule as many operations as possibly asynchronously,
    // we can easily traverse the full set of components, and have all operations scheduled,
    // before we find out about any errors. So, rather than trying to abort early in those
    // scenarios, we generally ignore errors until the end.
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Traverse the list of all components, dispatching each appropriately.
    NSArray *componentIds = [manifest.allComponents allKeys];

    if(componentIds.count == 0){
        [tracker onPushCompletion];
        return;
    }

    [tracker setPendingComponents: (int)componentIds.count];
    
    for (id idKey in componentIds) {
        DCXComponent *component  = [manifest.allComponents objectForKey:idKey];
        NSError *error = nil;
        BOOL componentIsNew = ![component isBound];
        NSString *componentState = component.state;
        NSString *filePath = [DCXLocalStorage pathOfComponent:component inManifest:manifest
                                                  ofComposite:composite withError:&error];
        if ( ![fm fileExistsAtPath:filePath] ) {
            filePath = nil;
        }
        
        if (componentIsNew || [componentState isEqualToString:DCXAssetStateModified]) {
            
            // Make sure that components have a local file
            if (filePath == nil) {
                NSError *e = [DCXErrorUtils ErrorWithCode:DCXErrorComponentReadFailure
                                                                         domain:DCXErrorDomain
                                                                        details:[NSString stringWithFormat:@"Component %@,%@ of composite %@ has neither a local storage file nor a source href.", component.componentId,
                                                                                 component.name, composite.compositeId]];
                [tracker componentWasAdded:component fromPath:filePath ofComposite:composite error:e];
                continue;
            }
            
            // First see whether we have already successfully uploaded the asset previously
            DCXMutableComponent *journaledComponent = [journal getUploadedComponent:component fromPath:filePath];
            if (journaledComponent != nil) {
                if (componentIsNew) {
                    [tracker componentWasAdded:journaledComponent fromPath:filePath ofComposite:composite error:nil];
                } else {
                    [tracker componentWasUpdated:journaledComponent fromPath:filePath ofComposite:composite error:nil];
                }
                // We are done for now with this component
                continue;
            }
            else {
                // Reset the component state if it was previously recorded as pending delete during a previous push
                [journal clearComponent:component];
            }
            
            // Now we can do the actual upload
            if (progress.isCancelled) {
                NSError *err = [DCXErrorUtils ErrorWithCode:DCXErrorCancelled
                                                     domain:DCXErrorDomain details:nil];
                [tracker componentWasAdded:component fromPath:nil ofComposite:composite error:err];
            } else {
                int64_t length = [component.length longLongValue] + DCXHTTPProgressCompletionFudge;
                if (progress.totalUnitCount < 0) {
                    progress.totalUnitCount = length;
                    progress.completedUnitCount = 0;
                } else {
                    progress.totalUnitCount += length;
                }
                [progress becomeCurrentWithPendingUnitCount:length];
                DCXHTTPRequest *request = [session uploadComponent:component ofComposite:composite
                                                          fromPath:filePath componentIsNew:componentIsNew
                                                   requestPriority:compRequest.priority
                                                      handlerQueue:nil
                                                 completionHandler:^(DCXComponent *c, NSError *err) {
                                                     NSInteger statusCode = 200;
                                                     if (err != nil) statusCode = [[err.userInfo objectForKey:DCXHTTPStatusKey] integerValue];
                                                     if (statusCode == 404 || statusCode == 409 || statusCode == 412) {
                                                         // Special case: Our assumption about the newness of the composite has
                                                         // been proven wrong. We try it again this time reversing our assumption.
                                                         [progress becomeCurrentWithPendingUnitCount:length];
                                                         DCXHTTPRequest *request = [session uploadComponent:component ofComposite:composite
                                                                                                   fromPath:filePath componentIsNew:!componentIsNew
                                                                                            requestPriority:compRequest.priority
                                                                                               handlerQueue:nil
                                                                                          completionHandler:^(DCXComponent *c, NSError *err) {
                                                                                              NSInteger statusCode = 200;
                                                                                              if (err != nil) statusCode = [[err.userInfo objectForKey:DCXHTTPStatusKey] integerValue];
                                                                                              [tracker componentWasAdded:c
                                                                                                                fromPath:filePath
                                                                                                             ofComposite:composite
                                                                                                                   error:err];
                                                                                          }];
                                                         
                                                         [progress resignCurrent];
                                                         if (request != nil) {
                                                             @synchronized(accessLock){
                                                                 [compRequest addComponentRequest:request];
                                                             } // end of synchronized block
                                                         }
                                                     } else {
                                                         if (componentIsNew) {
                                                             [tracker componentWasAdded:c fromPath:filePath ofComposite:composite error:nil];
                                                         } else {
                                                             [tracker componentWasUpdated:c fromPath:filePath ofComposite:composite error:nil];
                                                         }
                                                     }
                                                 }];
                [progress resignCurrent];
                if (request != nil) {
                    @synchronized(accessLock){
                        [compRequest addComponentRequest:request];
                    } // end of synchronized block
                }
            };
            
        } else if ([componentState isEqualToString:DCXAssetStateUnmodified]) {
            // Clear state in journal in case the component was previously marked as uploaded or pending delete
            [tracker componentWasUnmodified:component];
            [journal clearComponent:component];
            
        } else {
            NSLog(@"Unexpected component state: %@", componentState);
        }
    } // End of for loop over components
}

+(void) internalPushComposite:(DCXComposite *)composite
                 pushManifest:(DCXManifest *)manifest
        pushManifestReadError:(NSError *)manifestReadError
                 usingSession:(id<DCXTransferSessionProtocol>)session
             compositeRequest:(DCXCompositeRequest*)compRequest
          updateManifestBlock:(DCXCompositeManifestUploadRequest)updateManifestBlock
            completionHandler:(DCXPushCompletionHandler) completionHandler
{
    __block DCXManifest *pushManifest = manifest;
    NSAssert(composite, @"composite");
    NSAssert(composite.path, @"composite.path");
    
    // Create the journal. It will initialize itself from an existing journal.
    // We do not pass the error pointer here because in case of a failure the journal will be empty
    // and that is OK.
    DCXPushJournal *journal = [DCXPushJournal journalForComposite:composite persistedAt:composite.pushJournalPath error:nil];
    
    if(pushManifest == nil) {
        if (manifestReadError.code == DCXErrorInvalidManifest && [manifestReadError.domain isEqualToString:DCXErrorDomain]) {
            // Convert generic invalid manifest error into a more specific invalid local manifest
            // error.
            return completionHandler(NO, [DCXErrorUtils ErrorWithCode:DCXErrorInvalidLocalManifest
                                                               domain:DCXErrorDomain
                                                             userInfo:manifestReadError.userInfo]);
        } else {
            return completionHandler(NO, manifestReadError);
        }
    }

    composite.activePushManifest = pushManifest;
    
    BOOL compositeIsNew = !composite.isBound;
    if (composite.href == nil) {
        return completionHandler(NO, [DCXErrorUtils ErrorWithCode:DCXErrorCompositeHrefUnassigned
                                                           domain:DCXErrorDomain
                                                          details:nil]);
    }
    
    if ([pushManifest.compositeState isEqualToString:DCXAssetStateCommittedDelete]) {
        // The composite has previously been deleted. We error out.
        return completionHandler(NO, [DCXErrorUtils ErrorWithCode:DCXErrorDeletedComposite
                                                           domain:DCXErrorDomain
                                                          details:nil]);
    }
    
    // Check whether the composite has been modified at all and return if that is not the case
    if (!compositeIsNew && [pushManifest.compositeState isEqualToString:DCXAssetStateUnmodified]) {
        // Nothing to be done here. We return the empty journal.
        [compRequest allComponentsHaveBeenAdded];
        return completionHandler(YES, nil);
    }
    
    // Configure the progress object with an estimate of the length of the manifest that we will upload
    // so that this final upload is reflected in the total work units for the progress. Later we will
    // correct this before we actually upload the manifest.
    int64_t oldManifestSize = pushManifest.remoteData.length + DCXHTTPProgressCompletionFudge;
    
    // Update the manifest if needed to use the appropriate etag
    if ( pushManifest.etag == nil || [pushManifest.etag isEqualToString:journal.currentBranchEtag] ) {
        // The journal may contain an newer etag if a push has already succeeded without being accepted
        [journal updateManifestWithJournalEtag:pushManifest];
    }
    else {
        // A pulled branch has been merged into the current branch before a previous push
        // has been completed and/or accepted
        [journal recordCurrentBranchEtag:pushManifest.etag];
    }
    
    // #1 ============ Function blocks to handle composite deletion START ===============
    //
    if ([pushManifest.compositeState isEqualToString:DCXAssetStatePendingDelete]) {
        
        //
        // Deleting a composite is a two-step process:
        // 1. Upload the manifest with its state set to committedDelete
        // 2. Delete the collection (and with it all its asssets)
        // While the first step seems to be superflous it prevents deletion
        // of a composite that has changed on the server since last up/download (i.e. data loss).
        //
        pushManifest.compositeState = DCXAssetStateCommittedDelete;
        
        DCXCompositeRequestCompletionHandler cleanUpComposite = ^(DCXComposite *composite, NSError *deleteError){
            if(compositeIsNew || deleteError == nil){
                [journal recordCompositeHasBeenDeleted:YES];
                pushManifest.compositeHref = nil;
                if ([pushManifest writeToFile:composite.pushedManifestPath generateNewSaveId:NO withError:&deleteError]) {
                    if (![pushManifest writeToFile:composite.pushedManifestBasePath generateNewSaveId:NO withError:&deleteError]) {
                        deleteError = [DCXErrorUtils ErrorWithCode:DCXErrorFailedToStoreBaseManifest
                                                                     domain:DCXErrorDomain
                                                            underlyingError:deleteError
                                                                       path:composite.pushedManifestBasePath
                                                                    details:nil];
                    }
                    composite.href = nil;
                } else {
                    deleteError = [DCXErrorUtils ErrorWithCode:DCXErrorManifestFinalWriteFailure
                                                                 domain:DCXErrorDomain
                                                        underlyingError:deleteError
                                                                   path:composite.pushedManifestPath
                                                                details:nil];
                }
            }
            // composite deletion is a special case. We return nil even if we are successful.
            [compRequest allComponentsHaveBeenAdded];
            return completionHandler(deleteError == nil, deleteError);
        };
        

        DCXManifestRequestCompletionHandler manifestUpdateCompletionHandler = ^(DCXManifest *updatedManifest, NSError *updateError){
            if(updateError == nil){
                [session deleteComposite:composite requestPriority:compRequest.priority handlerQueue:nil completionHandler:cleanUpComposite];
            }else{
                // composite deletion is a special case. We return nil even if we are successful.
                [compRequest allComponentsHaveBeenAdded];
                return completionHandler(NO, updateError);
            }
        };
        
        if (!compositeIsNew) {
            [session updateManifest:pushManifest ofComposite:composite requestPriority:compRequest.priority handlerQueue:nil completionHandler:manifestUpdateCompletionHandler];
        }else{
            cleanUpComposite(composite, nil);
        }
        return;
    }
    // #1 ============ Function blocks to handle composite deletion END ===============

    // #3 =================== Manifest Upload function blocks START ====================
    // Notice that we upload the manifest even if we haven't uploaded or deleted a single component
    // since there might be changes in the manifest file itself.
    //
    
    void(^errorCleanup)(NSError*) = ^void(NSError *error)
    {
        DCXCompositeRequestCompletionHandler deleteCompositeHandler = ^void(DCXComposite *composite, NSError *err){
            if (journal.isEmpty) {
                // Clean up the journal file if it is empty.
                [journal deleteFileWithError:nil];
            }
            completionHandler(NO, error);
        };
        
        // If we get here something has gone wrong.
        if(compositeIsNew && journal.isEmpty) {
            // Only delete the composite collection if we haven't already uploaded any components (i.e. the
            // journal is empty).
            [journal setCompositeHref:nil];
            [session deleteComposite:composite requestPriority:compRequest.priority handlerQueue:nil completionHandler:deleteCompositeHandler];
            return;
        }
        if (journal.isEmpty) {
            // Clean up the journal file if it is empty.
            [journal deleteFileWithError:nil];
        }
        return completionHandler(NO, error);
    };
    
    
    void(^manifestUploadHandler)(DCXManifest*, NSError*) =  ^void(DCXManifest *m, NSError *e)
    {
        pushManifest = m;
        if(pushManifest != nil) {
            // Manifest uploaded successfully
            [compRequest allComponentsHaveBeenAdded];
            [journal recordUploadedManifest:pushManifest];
            NSError *writeError = nil;
            if ([pushManifest writeToFile:composite.pushedManifestPath generateNewSaveId:NO withError:&writeError]) {
                //
                // Success!
                //
                [composite updatePushedBranchWithManifest:pushManifest];
                return completionHandler(YES, nil);
            } else {
                // Report the error
                e = [DCXErrorUtils ErrorWithCode:DCXErrorManifestFinalWriteFailure
                                          domain:DCXErrorDomain
                                 underlyingError:writeError
                                            path:composite.pushedManifestPath
                                         details:nil];
            }
        }
        if(pushManifest == nil || e != nil){
            // Error uploading the manifest
            errorCleanup(e);
        }
    };
    
    
    void(^uploadManifestBlock)() = ^void(){
        // Make sure all manifest changes that need to be in the uploaded version are done at this point.
        pushManifest.compositeState = DCXAssetStateUnmodified;
        
        // Now that we have finalized the manifest we can correct the estimated total of work:
        int64_t newManifestSize = pushManifest.remoteData.length + DCXHTTPProgressCompletionFudge;
        compRequest.progress.totalUnitCount += (newManifestSize - oldManifestSize);
        
        [compRequest.progress becomeCurrentWithPendingUnitCount:newManifestSize];
        DCXHTTPRequest *request = updateManifestBlock(pushManifest, manifestUploadHandler);
        [compRequest.progress resignCurrent];
        if (request != nil) {
            [compRequest addComponentRequest:request];
        }
        
    };
    
    // #4 ======================== Manifest Upload function blocks END ========================
    
    // #3 =================== Function Blocks to upload the components START  ===================
    
    
    void (^pushComponentsErrorHandler)(NSArray *pushErrors) = ^void(NSArray* pushErrorList){
        NSMutableArray *pushErrors = [pushErrorList mutableCopy];
        // There are potentially multiple errors. We just promote the first error to be _the_ error
        // and add any remaining errors to the error's userInfo under the DCXOtherErrorsKey.
        __block NSError *theError = [pushErrors objectAtIndex:0];
        [pushErrors removeObjectAtIndex:0];
        BOOL isDCXError = [DCXErrorUtils IsDCXError:theError];
        NSString *domain = isDCXError ? theError.domain : DCXErrorDomain;
        NSInteger code =   isDCXError ? theError.code   : DCXErrorUnexpectedResponse;
        
        void(^populateErrorUserInfo)() = ^void()
        {
            NSDictionary *userInfo = theError.userInfo;
            if (pushErrors.count > 0) {
                if (userInfo != nil) {
                    // merge userInfo
                    NSMutableDictionary *mutableUserInfo = [userInfo mutableCopy];
                    [mutableUserInfo setObject:pushErrors forKey:DCXErrorOtherErrorsKey];
                    userInfo = mutableUserInfo;
                } else {
                    // new userInfo
                    userInfo = @{ DCXErrorOtherErrorsKey:pushErrors};
                }
            }
            theError = [DCXErrorUtils ErrorWithCode:code domain:domain userInfo:userInfo];
        };
        
        DCXResourceRequestCompletionHandler manifestInfoHandler = ^(DCXResourceItem *r, NSError *err)
        {
            
            BOOL remoteManifestMissing = NO;
            if ( err != nil &&
                [[err.userInfo objectForKey:DCXHTTPStatusKey] isEqual:@404] ) {
                remoteManifestMissing = YES;
                err = [DCXErrorUtils ErrorWithCode:DCXErrorUnknownComposite domain:DCXErrorDomain details:nil];
            }
            if ( !remoteManifestMissing ) {
                populateErrorUserInfo();
            }
            errorCleanup(err);
        };
        
        if ( !compositeIsNew && [domain isEqualToString:DCXErrorDomain] && code == DCXErrorUnexpectedResponse )
        {
            // A variety of error response scenarios are possible when attempting to push an existing
            // composite that has been deleted from the server.  Whenever an unexpected response occurs
            // we also check to see if the manifest is missing.  If so, then we assume that errors resulted
            // as a result of the composite having been deleted and return the appropriate error.
            [session getHeaderInfoForManifestOfComposite:composite requestPriority:compRequest.priority handlerQueue:nil completionHandler:manifestInfoHandler];
        }else{
            populateErrorUserInfo();
            errorCleanup(theError);
        }
    };
    
    
    PushCompletionHandler pushCompletionHandler = ^void(NSArray* pushErrors){
        if(pushErrors != nil && [pushErrors count] > 0){
            // There are component push errors. CANNOT proceed with flow.
            pushComponentsErrorHandler(pushErrors);
        }else{
            uploadManifestBlock();
        }
    };
    
    
    void(^pushComponents)() = ^void()
    {
        compRequest.progress.totalUnitCount = oldManifestSize;
        compRequest.progress.completedUnitCount = 0;
        
        // Process the components. Note that we resolve component names as relative to the parent directory
        // of the manifest.
        PushComponentTracker *tracker = [[PushComponentTracker alloc] initWithJournal:journal
                                                                          forManifest:pushManifest ofComposite:composite
                                                                           andRequest:compRequest andPushCompletionHandler:pushCompletionHandler];
        [self pushComponentsInManifest:pushManifest
                           ofComposite:composite
                          usingSession:session
                           withJournal:journal
                      compositeRequest:compRequest
                      componentTracker:tracker];
    };
    
    // #3 =================== Function Blocks to upload the components END  ===================
    
    // #2 =================== Function Blocks to create the composite START ===================
    
    if (compositeIsNew && !journal.compositeHasBeenCreated)
    {
        __block NSError *createCompositeError;
        
        DCXResourceRequestCompletionHandler manifestHeadReqHandler = ^(DCXResourceItem *resource, NSError *manifestHeadError){
            if (manifestHeadError != nil &&
                [[manifestHeadError.userInfo objectForKey:DCXHTTPStatusKey] isEqual: @404])
            {
                //404 implies manifest is not found. Ignore the error. Continue the chain and upload the components
                [journal recordCompositeHasBeenCreated:YES];
                pushComponents();
            }else{
                // Manifest error is not 404. CANNOT continue with push operation.
                return completionHandler(NO, createCompositeError);
            }
        };
        
        DCXCompositeRequestCompletionHandler createCompositeHandler = ^(DCXComposite *localComposite, NSError* newCompositeError)
        {
            if(newCompositeError != nil)
            {
                if (newCompositeError != nil && [newCompositeError.domain isEqualToString:DCXErrorDomain]
                    && newCompositeError.code == DCXErrorCompositeAlreadyExists)
                {
                    // Record the newCompositeError here so that it can be used by manifestHeadReqHandler
                    createCompositeError = newCompositeError;

                    // The composite directory already exists. We check to see if it has a manifest. If
                    // not we are going to ignore the error because it likely stems from an earlier push
                    // attempt.
                    [session getHeaderInfoForManifestOfComposite:composite
                                                        requestPriority:compRequest.priority
                                                           handlerQueue:nil
                                                      completionHandler:manifestHeadReqHandler];
                    return; // explicit return
                } else {
                    return completionHandler(NO, newCompositeError);
                }
            }else{
                // No error creating the composite. Continue the chain and upload the components
                [journal recordCompositeHasBeenCreated:YES];
                pushComponents();
            }
        };
        
        [session createComposite:composite requestPriority:compRequest.priority handlerQueue:nil completionHandler:createCompositeHandler];
    }else{
        // The composite is not new / does not need to be created. Proceed to pushing the components.
        pushComponents();
    }
    // #2 =================== Function Blocks to create the composite END ===================
}

#pragma mark - Pull - Public API

+(DCXHTTPRequest*) pullComposite:(DCXComposite *)composite usingSession:(id<DCXTransferSessionProtocol>)session
                 requestPriority:(NSOperationQueuePriority)priority handlerQueue :(NSOperationQueue *)queue
               completionHandler:(DCXPullCompletionHandler)handler
{
    __block DCXCompositeRequest *compRequest = [[DCXCompositeRequest alloc] initWithPriority:priority];
    
    void(^reportCompletion)(DCXBranch*, NSError*) = ^void(DCXBranch* pulledBranch, NSError* error){
        if(handler != nil){
            handler(pulledBranch, error);
        }
    };
    
    DCXPullCompletionHandler pullCompletionHandler = ^void(DCXBranch *pulledBranch, NSError *error){
        if(queue != nil){
            [queue addOperationWithBlock:^{
                reportCompletion(pulledBranch, error);
            }];
        }else{
            reportCompletion(pulledBranch, error);
        }
    };
    
    [DCXCompositeXfer internalPullComposite:composite usingSession:session compositeRequest:compRequest pullCompletionHandler:pullCompletionHandler];
    
    return compRequest;
}

+(DCXHTTPRequest*) pullMinimalComposite:(DCXComposite *)composite
                                    usingSession:(id<DCXTransferSessionProtocol>)session
                                 requestPriority:(NSOperationQueuePriority)priority
                                    handlerQueue:(NSOperationQueue *)queue
                               completionHandler:(DCXPullCompletionHandler)handler
{
    // Defining the callback that downloads the manifest
    DCXCompositeManifestDownloadBlock downloadBlock = ^void(DCXManifest *manifest, DCXManifestRequestCompletionHandler manifestReqCompletionHandler) {
        if (composite.href == nil) {
            NSAssert(NO, @"Should not happen");
        }
        [session getManifest:manifest ofComposite:composite requestPriority:priority handlerQueue:nil completionHandler:manifestReqCompletionHandler];
    };
    
    DCXCompositeRequest *compRequest = [[DCXCompositeRequest alloc] initWithPriority:priority];
    
    DCXPullCompletionHandler pullCompletionHandler = ^void(DCXBranch *branch, NSError *error){
        if(handler){
            if(queue != nil){
                [queue addOperationWithBlock:^{
                    handler(branch, error);
                }];
            }
            else{
                handler(branch, error);
            }
        }
    };
    
    [DCXCompositeXfer internalPullMinimalComposite:composite
                                           usingSession:session
                                       compositeRequest:compRequest
                                       getManifestBlock:downloadBlock
                                  withCompletionHandler:pullCompletionHandler];
    
    return compRequest;
}

+ (DCXHTTPRequest*) downloadComponents:(NSArray*)components
                              ofBranch:(DCXBranch*)branch
                                   usingSession:(id<DCXTransferSessionProtocol>)session
                                requestPriority:(NSOperationQueuePriority)priority
                                   handlerQueue:(NSOperationQueue*)queue
                              completionHandler:(DCXPullCompletionHandler)handler
{
    NSAssert(branch, @"branch");
    DCXComposite *composite = branch.weakComposite;
    
    __block DCXCompositeRequest *compRequest = [[DCXCompositeRequest alloc] initWithPriority:priority];

    DCXManifest *manifest = (branch == composite.current ? nil : branch.manifest);
    
    DCXPullCompletionHandler completionHandlerWrapper = ^void(DCXBranch* branch, NSError* error){
        if(handler != nil){
            if(queue != nil){
                [queue addOperationWithBlock:^{
                    handler(branch, error);
                }];
            }else{
                handler(branch, error);
            }
        }
    };
    
    [DCXCompositeXfer internalDownloadComponents:components 
                                          ofComposite:composite
                                  usingPulledManifest:manifest
                                         usingSession:session
                                     compositeRequest:compRequest
                                withCompletionHandler:completionHandlerWrapper];
    
    return compRequest;
}

#pragma mark Pull - Internal

+(DCXManifest*) getPreviouslyPulledManifestOfComposite:(DCXComposite *)composite
{
    NSString *pulledManifestPath = composite.pulledManifestPath;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:pulledManifestPath]) {
        // We do not care about any error. If we can't load it we just ignore it.
        DCXManifest *previouslyPulledManifest = [DCXManifest manifestWithContentsOfFile:pulledManifestPath withError:nil];
        
        // Sanity check: Verify that the composite id of the previously pulled manifest matches
        // the id of the current manifest.
        DCXManifest *currentManifest = composite.manifest;
        if (currentManifest != nil && previouslyPulledManifest != nil) {
            if (![currentManifest.compositeId isEqualToString:previouslyPulledManifest.compositeId]) {
                // Somehow the ids of the next manifest (from a previous pull) and the current manifest
                // don't match. We discard the next manifest.
                [fm removeItemAtPath:pulledManifestPath error:nil];
                previouslyPulledManifest = nil;
            }
        }
        return previouslyPulledManifest;
    } else {
        return nil;
    }
}

+(DCXManifest*) getCurrentManifestOfComposite:(DCXComposite *)composite
                                             error:(NSError **)errorPtr
{
    NSString *currentManifestFilePath = composite.currentManifestPath;
    
    if (composite.current == nil && [[NSFileManager defaultManager] fileExistsAtPath:currentManifestFilePath]) {
        NSError *error = nil;
        DCXManifest *manifest = [DCXManifest manifestWithContentsOfFile:currentManifestFilePath
                                                             withError:&error];
        if (manifest == nil) {
            if (error.code == DCXErrorInvalidManifest && [error.domain isEqualToString:DCXErrorDomain]) {
                // Convert generic invalid manifest error into a more specific invalid local manifest error.
                if (errorPtr != NULL) *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidLocalManifest
                                                                                 domain:DCXErrorDomain
                                                                               userInfo:error.userInfo];
            } else {
                if (errorPtr != NULL) *errorPtr = error;
            }
        } else {
            [composite updateCurrentBranchWithManifest:manifest updateCommittedAtDate:YES];
        }
    }
    
    return composite.current.manifest;
}

+(NSError*) adjustErrorFromPulledManifest:(NSError*)error withRequest:(DCXHTTPRequest*)request
{
    NSError *adjustedError = error;
    
    if (request.isCancelled) {
        adjustedError = [DCXErrorUtils ErrorWithCode:DCXErrorCancelled
                                                       domain:DCXErrorDomain userInfo:nil];
    } else {
        if ([[error.userInfo objectForKey:DCXHTTPStatusKey] isEqual: @404]) {
            adjustedError = [DCXErrorUtils ErrorWithCode:DCXErrorMissingManifest
                                                           domain:DCXErrorDomain
                                                         userInfo:error.userInfo];
        } else if (error.code == DCXErrorInvalidManifest && [error.domain isEqualToString:DCXErrorDomain]) {
            // Convert generic invalid manifest error into a more specific invalid local manifest error.
            adjustedError = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidRemoteManifest
                                                           domain:DCXErrorDomain userInfo:error.userInfo];
        }
    }
    
    return adjustedError;
}

+(DCXBranch*) finalizePullManifestOfComposite:(DCXComposite *)composite
                            compositeRequest:(DCXCompositeRequest*)compRequest
                          withPulledManifest:(DCXManifest*)pulledManifest
                 andPreviouslyPulledManifest:(DCXManifest*)previouslyPulledManifest
                                       error:(NSError**)errorPtr
{
    DCXManifest *currentManifest = composite.manifest;
    DCXManifest *baseManifest = composite.base.manifest;
    
    if (pulledManifest == nil) {
        //
        // If we get here it means that the manifest on the server hasn't changed.
        //
        pulledManifest = (previouslyPulledManifest != nil ? previouslyPulledManifest : currentManifest);
    
    } else if(previouslyPulledManifest != nil) {
        //
        // Consolidate pulled manifest with the previously pulled manifest (if available).
        //
        if ([previouslyPulledManifest.etag isEqualToString:pulledManifest.etag]) {
            //
            // The remote manifest is the same as the previously pulled remote manifest.
            //
            pulledManifest = previouslyPulledManifest;
            
        } else {
            // Need to update the pulled manifest with the local storage data from the previously pulled manifest
            [composite updateLocalStorageDataInManifest:pulledManifest fromManifestArray:previouslyPulledManifest == nil ? nil : @[previouslyPulledManifest]];
        }
    } else {
        NSMutableArray *sourceManifests = [NSMutableArray array];
        if (currentManifest != nil) {
            [sourceManifests addObject:currentManifest];
        }
        if (baseManifest != nil) {
            [sourceManifests addObject:baseManifest];
        }
        [composite updateLocalStorageDataInManifest:pulledManifest fromManifestArray:sourceManifests];
    }
    
    // Determine whether there are any changes for us to download.
    //
    BOOL manifestHasChanged = currentManifest == nil || ![currentManifest.etag isEqualToString:pulledManifest.etag];
    if (!manifestHasChanged) {
        // By definition, if the manifest itself hasn't changed no other asset in the composite
        // has changed, so we are done here.
        [compRequest allComponentsHaveBeenAdded];
        [composite discardPulledBranchWithError:nil];
        return nil;
    }
    
    // Update the manifest and write it out to disk
    //
    
    // Make sure the directory we write to exists.
    NSString *pulledManifestPath = composite.pulledManifestPath;
    NSString *destDir = [pulledManifestPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:destDir withIntermediateDirectories:YES
                                               attributes:nil error:nil];
    if (![pulledManifest writeToFile:pulledManifestPath generateNewSaveId:YES withError:errorPtr]) {
        return nil;
    }
        
    [composite updatePulledBranchWithManifest:pulledManifest];
    return composite.pulled;
}

+(void) internalPullMinimalComposite:(DCXComposite *)composite
                        usingSession:(id<DCXTransferSessionProtocol>)session
                    compositeRequest:(DCXCompositeRequest*)compRequest
                    getManifestBlock:(DCXCompositeManifestDownloadBlock)getManifestBlock
               withCompletionHandler:(DCXPullCompletionHandler) completionHandler
{
    NSAssert(composite, @"composite");
    NSAssert(composite.path, @"composite.path");
    
    // Load existing manifests
    //
    NSError *error = nil;
    [self getCurrentManifestOfComposite:composite error:&error];
    if (error != nil) {
        return completionHandler(nil, error);
    }
    DCXManifest *previouslyPulledManifest = [self getPreviouslyPulledManifestOfComposite:composite];
    DCXManifestRequestCompletionHandler compositeDownloadHandler = ^void(DCXManifest* pulledManifest, NSError *downloadError)
    {
        if(downloadError != nil || compRequest.isCancelled){
            NSError *adjustedError = [self adjustErrorFromPulledManifest:downloadError withRequest:compRequest];
            return completionHandler(nil, adjustedError);
        }
       
        if ([pulledManifest.compositeState isEqualToString:DCXAssetStateCommittedDelete]) {
            DCXCompositeRequestCompletionHandler deleteCompletionHandler = ^void(DCXComposite* composite, NSError* err)
            {
                NSError *unknownCompositeError = [DCXErrorUtils ErrorWithCode:DCXErrorUnknownComposite
                                                                                domain:DCXErrorDomain details:nil];
                return completionHandler(nil, unknownCompositeError);
            };
            
            [session deleteComposite:composite requestPriority:compRequest.priority handlerQueue:nil completionHandler:deleteCompletionHandler];
            return;
        }

        NSError *pullError;
        DCXBranch *branch = [self finalizePullManifestOfComposite:composite
                                                               compositeRequest:compRequest
                                                             withPulledManifest:pulledManifest
                                                    andPreviouslyPulledManifest:previouslyPulledManifest
                                                                          error:&pullError];
        if(pullError != nil){
            return completionHandler(nil, pullError);
        }
        
        if(branch != nil){
            NSMutableArray *minimalComponents = [NSMutableArray arrayWithCapacity:0];
            // Add minimal components here
            if (minimalComponents.count > 0) {
                return [self internalDownloadComponents:minimalComponents
                                            ofComposite:composite
                                    usingPulledManifest:branch.manifest
                                           usingSession:session
                                       compositeRequest:compRequest
                                  withCompletionHandler:completionHandler];
            }
        }
        completionHandler(branch, nil);
    };
    
    getManifestBlock(previouslyPulledManifest, compositeDownloadHandler);
}


/**
 Asynchronous wrapper around internalDownloadComponents
 */
+(void) internalDownloadComponents:(NSArray*)componentsToPull
                       ofComposite:(DCXComposite *)composite
               usingPulledManifest:(DCXManifest*)pulledManifest
                      usingSession:(id<DCXTransferSessionProtocol>)session
                  compositeRequest:(DCXCompositeRequest*)compRequest
             withCompletionHandler:(DCXPullCompletionHandler)completionHandler
{
    PullCompletionHandler wrapperHandler = ^void(NSMutableArray* downloadErrors){
        [DCXCompositeXfer internalComponentDownloadCompletionForComposite:composite
                                                 withCompletionHandler:completionHandler
                                                    withPulledManifest:pulledManifest
                                                        andCompRequest:compRequest
                                                            withErrors:downloadErrors];
    };
    PullComponentTracker *tracker = [[PullComponentTracker alloc] initWithCompletionHandler:wrapperHandler];
    [DCXCompositeXfer coreDownloadComponents:componentsToPull
                                      ofComposite:composite
                              usingPulledManifest:pulledManifest
                                     usingSession:session
                                 compositeRequest:compRequest
                                  withPullTracker:tracker];
    
}


+(void) coreDownloadComponents:(NSArray*)componentsToPull
                   ofComposite:(DCXComposite *)composite
           usingPulledManifest:(DCXManifest*)pulledManifest
                  usingSession:(id<DCXTransferSessionProtocol>)session
              compositeRequest:(DCXCompositeRequest*)compRequest
               withPullTracker:(PullComponentTracker*)tracker
{
    
    NSFileManager    *fm                 = [NSFileManager defaultManager];
    NSString         *pulledManifestPath = composite.pulledManifestPath;
    
    NSString         *currentManifestFilePath = composite.currentManifestPath;
    DCXManifest *currentManifest         = composite.manifest;
    
    // Object to be used for synchronization
    NSString *const accessLock = @"accessLock";
    
    if (currentManifest == nil && [fm fileExistsAtPath:currentManifestFilePath]) {
        currentManifest = [DCXManifest manifestWithContentsOfFile:currentManifestFilePath
                                                             withError:nil];
    }

    
    // We need to remember whether we have a pulled manifest. If not that means
    // that we are pulling additional components from the current manifest.
    BOOL hasPulledManifest = pulledManifest != nil;
    if (!hasPulledManifest) {
        pulledManifest = currentManifest;
    }
    
    // Establish a set of component Ids to pull
    NSMutableSet *idsOfComponentsToPull = nil;
    if (componentsToPull != nil) {
        idsOfComponentsToPull = [NSMutableSet setWithCapacity:componentsToPull.count];
        for (DCXComponent *component in componentsToPull) {
            [idsOfComponentsToPull addObject:component.componentId];
        }
    }
    
    void(^decrementPendingCountWithError)(NSError*) = ^(NSError* err){
        [tracker componentWasDownloadedWithError:err];
    };

    
    // Iterate over the components of the remote manifest to update those that have changed.
    NSProgress *progress = compRequest.progress;
    NSArray *allComponentsKeys = [pulledManifest.allComponents allKeys];
    [tracker setPendingComponnents:(int)allComponentsKeys.count];
    for (id idKey in allComponentsKeys) {
        @synchronized(accessLock){
            NSError *error = nil;
            
            if (idsOfComponentsToPull != nil && ![idsOfComponentsToPull containsObject:idKey]) {
                // Don't pull it if it ain't on the list.
                decrementPendingCountWithError(nil);
                continue;
            }
            
            DCXComponent *pulledComponent = [pulledManifest.allComponents objectForKey:idKey];
            DCXComponent *localComponent = nil;
            if (currentManifest != nil) {
                localComponent = [currentManifest.allComponents objectForKey:pulledComponent.componentId];
            }
            
            NSString *componentDestinationPath = [DCXLocalStorage pathOfComponent:pulledComponent
                                                                    inManifest:pulledManifest
                                                                   ofComposite:composite
                                                                     withError:&error];
            
            if (componentDestinationPath == nil) {
                decrementPendingCountWithError([DCXErrorUtils ErrorWithCode:DCXErrorInvalidRemoteManifest
                                                                              domain:DCXErrorDomain underlyingError:error
                                                                             details:nil]);
                continue;
            }
                
            if ([fm fileExistsAtPath:componentDestinationPath]) {
                // We have already pulled this exact component file in a previous pull.
                decrementPendingCountWithError(nil);
                continue;
            }
            NSString *pulledComponentState = pulledComponent.state;
            
            if (![pulledComponentState isEqualToString:DCXAssetStateUnmodified]) {
                if (pulledComponentState != nil && !hasPulledManifest) {
                    // Skip components that we have modified locally if we are not using a pulled
                    // manifest but rather pulling additional components from the current manifest.
                    decrementPendingCountWithError(nil);
                    continue;
                }
                DCXMutableComponent *mutableComponent = [pulledComponent mutableCopy];
                mutableComponent.state = DCXAssetStateUnmodified;
                pulledComponent = [pulledManifest updateComponent:mutableComponent withError:&error];
                if (pulledComponent == nil) {
                    decrementPendingCountWithError(error);
                    continue;
                }
                if (hasPulledManifest && ![pulledManifest writeToFile:pulledManifestPath generateNewSaveId:NO withError:&error]) {
                    decrementPendingCountWithError(error);
                    continue;
                }
            }
                
            // Make sure that necessary directories exist
            NSString *destDir = [componentDestinationPath stringByDeletingLastPathComponent];
            [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
            
            // See whether we already have (a previous version of) the file asset locally
            // and determine its current (and new) etag as well as its local state
            //
            NSString *localEtag = nil;
            NSString *localState = nil;
            NSString *localFullPath = nil;
            if (currentManifest != nil) {
                if (localComponent != nil) {
                    localFullPath = [DCXLocalStorage pathOfComponent:localComponent inManifest:currentManifest
                                                                ofComposite:composite withError:nil];
                    if ([fm fileExistsAtPath:localFullPath]) {
                        localEtag = localComponent.etag;
                        localState = localComponent.state;
                    }
                }
            }
            
            if ([fm fileExistsAtPath:componentDestinationPath]) {
                //
                // Compare the remote asset with the asset we have already downloaded.
                NSDictionary *fileAttributes = [fm attributesOfItemAtPath:componentDestinationPath error:nil];
                if (fileAttributes != nil) {
                    NSNumber *downloadedContenLength = [fileAttributes objectForKey:NSFileSize];
                    NSNumber *pulledContentLength = pulledComponent.length;
                    if ([downloadedContenLength isEqual:pulledContentLength]) {
                        decrementPendingCountWithError(nil);
                        continue;
                    }
                }
            }
                
            // Download the asset if necessary.
            if ( ![pulledComponent.etag isEqualToString:localEtag] ) {
                
                if (progress.isCancelled) {
                    NSError *error = [DCXErrorUtils ErrorWithCode:DCXErrorCancelled domain:DCXErrorDomain details:nil];
                    decrementPendingCountWithError(error);
                } else {
                    int64_t length = (pulledComponent.length != nil ? [pulledComponent.length longLongValue] + DCXHTTPProgressCompletionFudge : 0);
                    
                    if (length > 0 ) {
                        if (progress.totalUnitCount < 0) {
                            progress.totalUnitCount = length;
                            progress.completedUnitCount = 0;
                        } else {
                            progress.totalUnitCount += length;
                        }
                        [progress becomeCurrentWithPendingUnitCount:length];
                    }
                    DCXHTTPRequest *request = nil;
                    request = [session downloadComponent:pulledComponent
                                             ofComposite:composite
                                                  toPath:componentDestinationPath
                                         requestPriority:compRequest.priority
                                            handlerQueue:nil
                                       completionHandler:^(DCXComponent *c, NSError *err) {
                                           if (err != nil) {
                                               if ([[err.userInfo objectForKey:DCXHTTPStatusKey] isEqual: @404]) {
                                                   err = [DCXErrorUtils ErrorWithCode:DCXErrorMissingComponentAsset
                                                                                        domain:DCXErrorDomain userInfo:err.userInfo];
                                               }
                                           }
                                           
                                           decrementPendingCountWithError(err);
                                       }];
                    if (length > 0 ) {
                        if (request != nil) {
                            [compRequest addComponentRequest:request];
                        }
                        [progress resignCurrent];
                    }
                }
            };
        } // end of synchronized block of for loop
    }   // end of for loop over list of components
}

+(void) internalComponentDownloadCompletionForComposite:(DCXComposite*)composite
                       withCompletionHandler:(DCXPullCompletionHandler)completionHandler
                          withPulledManifest:(DCXManifest*)pulledManifest
                              andCompRequest:(DCXCompositeRequest*)compRequest
                                  withErrors:(NSMutableArray*)downloadErrors
{
    NSString         *currentManifestFilePath = composite.currentManifestPath;
    DCXManifest *currentManifest         = composite.manifest;
    
    NSError *manifestNotFoundError;
    if (currentManifest == nil && [[NSFileManager defaultManager] fileExistsAtPath:currentManifestFilePath]) {
        currentManifest = [DCXManifest manifestWithContentsOfFile:currentManifestFilePath
                                                             withError:&manifestNotFoundError];
    }
    
    // We need to remember whether we have a pulled manifest. If not that means
    // that we are pulling additional components from the current manifest.
    BOOL hasPulledManifest = pulledManifest != nil;
    if (!hasPulledManifest) {
        pulledManifest = currentManifest;
    }
    
    if (downloadErrors.count > 0) {
        // There are potentially multiple errors. We just promote the first error to be _the_ error
        // and add any remaining errors to the error's userInfo using the DCXOtherErrorsKey.
        NSError *theError = [downloadErrors objectAtIndex:0];
        [downloadErrors removeObjectAtIndex:0];
        BOOL isDCXError = [DCXErrorUtils IsDCXError:theError];
        NSString *domain = isDCXError ? theError.domain : DCXErrorDomain;
        NSInteger code =   isDCXError ? theError.code   : DCXErrorUnexpectedResponse;
        NSDictionary *userInfo = theError.userInfo;
        
        if (downloadErrors.count > 0) {
            if (userInfo != nil) {
                // merge userInfo
                NSMutableDictionary *mutableUserInfo = [userInfo mutableCopy];
                [mutableUserInfo setObject:downloadErrors forKey:DCXErrorOtherErrorsKey];
                userInfo = mutableUserInfo;
            } else {
                // new userInfo
                userInfo = @{ DCXErrorOtherErrorsKey:downloadErrors };
            }
        }
        
        NSError *err = [DCXErrorUtils ErrorWithCode:code domain:domain
                                                                       userInfo:userInfo];
        return completionHandler(nil, err);
    } else {
        [compRequest allComponentsHaveBeenAdded];
    }
    
    if (pulledManifest != nil) {
        if (hasPulledManifest) {
            [composite updatePulledBranchWithManifest:pulledManifest];
            return completionHandler(composite.pulled, nil);
        } else {
            return completionHandler(composite.current, nil);
        }
    } else {
        return completionHandler(nil, manifestNotFoundError);
    }

}


+(void) internalPullComposite:(DCXComposite *)composite
                                     usingSession:(id<DCXTransferSessionProtocol>)session
                                 compositeRequest:(DCXCompositeRequest*)compRequest
                            pullCompletionHandler:(DCXPullCompletionHandler)completionHandler
{
    DCXCompositeManifestDownloadBlock downloadBlock = ^void(DCXManifest *manifest, DCXManifestRequestCompletionHandler manifestDownloadCompletionHandler) {
        NSError *error;
        if (composite.href == nil) {
            error = [DCXErrorUtils ErrorWithCode:DCXErrorCompositeHrefUnassigned
                                                       domain:DCXErrorDomain
                                                      details:nil];
            return manifestDownloadCompletionHandler(nil, error);
        }
        [session getManifest:manifest ofComposite:composite requestPriority:compRequest.priority handlerQueue:nil completionHandler:manifestDownloadCompletionHandler];
        return;
    };
    
    
    DCXPullCompletionHandler pullMinimalCompositeCompletionHandler = ^void(DCXBranch *branch, NSError *error){
        if (error == nil) {
            [self internalDownloadComponents:nil
                                 ofComposite:composite 
                         usingPulledManifest:(branch != nil ? branch.manifest : composite.current.manifest)
                                usingSession:session 
                            compositeRequest:compRequest
                       withCompletionHandler:^(DCXBranch *branch, NSError *error) {
                           completionHandler(branch, error);
                       }];
        } else {
            completionHandler(nil, error);
        }
    };
    
    [self internalPullMinimalComposite:composite
                          usingSession:session
                      compositeRequest:compRequest
                      getManifestBlock:downloadBlock
                 withCompletionHandler:pullMinimalCompositeCompletionHandler];
}

@end
