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

#import <libkern/OSAtomic.h>

#import "DCXComposite_Internal.h"

#import "DCXBranch_Internal.h"
#import "DCXMutableBranch_Internal.h"

#import "DCXManifest.h"
#import "DCXError.h"
#import "DCXMutableComponent.h"
#import "DCXLocalStorage.h"
#import "DCXPushJournal.h"

#import "DCXResourceItem.h"
#import "DCXConstants_Internal.h"
#import "DCXFileUtils.h"
#import "DCXErrorUtils.h"
#import "DCXUtils.h"

@implementation DCXComposite {
    
    DCXMutableBranch *_current;
    DCXBranch *_pulled;
    DCXBranch *_pushed;
    DCXBranch *_base;
    DCXBranch *_localCommitted;
    
    // Used to ensure that we don't start too many background deletion tasks.
    volatile int32_t _deleteFilesInBackgroundRequestCounter;
    
    NSString *_compositeId;
    NSString *_href;
    
    NSString *_committedCompositeState;

    NSMutableSet *_inflightLocalComponentFiles;
}

#pragma mark Initilizers

- (instancetype)initWithPath:(NSString*)path
           andHref:(NSString*)href andId:(NSString*)compositeId
                   withError:(NSError**) errorPtr
{
    if (self = [super init]) {
        _href = href;
        _compositeId = compositeId;
        _path = path;
        _deleteFilesInBackgroundRequestCounter = 0;
        _autoRemoveUnusedLocalFiles = YES;
        _inflightLocalComponentFiles = [NSMutableSet set];
        
        if (path == nil) {
            return self;
        } else {
            DCXManifest *manifest = [DCXManifest manifestWithContentsOfFile:self.currentManifestPath
                                                                            withError:errorPtr];
            if (manifest != nil) {
                [self updateCurrentBranchWithManifest:manifest updateCommittedAtDate:YES];
                return self;
            }
            else {
                // Use pulled manifest if no current manifest exists.  This is to support composites previously
                // instantiated using initWithHref that have been successfully pulled to local storage and
                // awaiting a resolve operation.
                DCXManifest *pulledManifest = [DCXManifest manifestWithContentsOfFile:self.pulledManifestPath
                                                                                      withError:errorPtr];
                if (pulledManifest != nil) {
                    [self updatePulledBranchWithManifest:pulledManifest];
                    if (_href == nil) {
                        _href = pulledManifest.compositeHref;
                    }
                    if (_compositeId == nil) {
                        _compositeId = pulledManifest.compositeId;
                    }
                    if (errorPtr != NULL) {
                        *errorPtr = nil;
                    }
                    return self;
                }
            }
        }
    }
    
    return nil;
}

- (instancetype) initWithName:(NSString *)name andType:(NSString *)type andPath:(NSString *)path andId:(NSString*)compositeId
{
    if (self = [self initWithPath:nil andHref:nil andId:compositeId withError:nil]) {
        _path = path;
        _deleteFilesInBackgroundRequestCounter = 0;
        _autoRemoveUnusedLocalFiles = YES;
        _inflightLocalComponentFiles = [NSMutableSet set];
        
        [self updateCurrentBranchWithManifest:[DCXManifest manifestWithName:name andType:type] updateCommittedAtDate:NO];
        if (compositeId != nil) {
            _current.manifest.compositeId = compositeId;
        }
        _current.compositeState = DCXAssetStateUnmodified;
        _current.manifest.isDirty = YES;
        
        return self;
    }
    
    return nil;
}

- (instancetype)initWithManifest:(DCXManifest *)manifest andPath:(NSString *)path
{
    if (self = [super init]) {
        [self updateCurrentBranchWithManifest:manifest updateCommittedAtDate:YES];
        _compositeId   = manifest.compositeId;
        _path        = path;
        _deleteFilesInBackgroundRequestCounter = 0;
        _autoRemoveUnusedLocalFiles = YES;
        _inflightLocalComponentFiles = [NSMutableSet set];
        
        return self;
    }
    
    return nil;
}

- (instancetype)initWithPath:(NSString *)path withError:(NSError **)errorPtr
{
    return [self initWithPath:path andHref:nil andId:nil withError:errorPtr];
}

- (instancetype)initWithHref:(NSString*)href andId:(NSString *)compositeId
{
    return [self initWithPath:nil andHref:href andId:compositeId withError:nil];
}

- (instancetype)initWithName:(NSString *)name andType:(NSString *)type andPath:(NSString *)path andId:(NSString *)compositeId
           andHref:(NSString *)href
{
    if ( self = [self initWithName:name andType:type andPath:path andId:compositeId] ) {
        self.href = href;
        return self;
    }
    return nil;
}


#pragma mark Convenience Factory Methods

+ (instancetype)compositeFromPath:(NSString *)path withError:(NSError **)errorPtr;
{
    return [[self alloc] initWithPath:path withError:errorPtr];
}

+ (instancetype)compositeFromHref:(NSString *)href andId:(NSString *)compositeId andPath:(NSString *)path
{
    return [[self alloc] initWithName:nil andType:nil andPath:path andId:(NSString *)compositeId andHref:href];
}

+ (instancetype)compositeFromResource:(DCXResourceItem *)resource andPath:(NSString *)path
{
    return [self compositeFromHref:resource.href andId:resource.name andPath:path];
}

+ (instancetype)compositeWithName:(NSString *)name andType:(NSString *)type andPath:(NSString *)path
                  andId:(NSString *)compositeId andHref:(NSString *)href
{
    return [[self alloc] initWithName:name andType:type andPath:path andId:compositeId andHref:href];

}

+(instancetype) compositeFromManifest:(DCXManifest *)manifest andPath:(NSString *)path
{
    return [[self alloc] initWithManifest:manifest andPath:path];
}

#pragma mark Properties

- (DCXManifest*) manifest
{
    return _current.manifest;
}

- (NSString*) compositeId
{
    if (self.manifest == nil) {
        return _compositeId;
    } else {
        return self.manifest.compositeId;
    }
}

- (void) setCompositeId:(NSString *)compositeId
{
    if (self.manifest == nil) {
        _compositeId = compositeId;
    } else {
        self.manifest.compositeId = compositeId;
    }
}

- (NSString*) href
{
    if (self.manifest == nil) {
        return _href;
    } else {
        return self.manifest.compositeHref;
    }
}

- (void) setHref:(NSString *)href
{
    if (self.manifest == nil) {
        _href = href;
    } else {
        self.manifest.compositeHref = href;
    }
}

- (BOOL) isBound
{
    return self.manifest == nil ? (_href != nil) : self.manifest.isBound;
}

- (NSString *) committedCompositeState
{
    if ( !self.current.isDirty ) {
        return self.current.compositeState;
    }
    else if ( _committedCompositeState != nil ) {
        return _committedCompositeState;
    }
    else {
        return self.localCommitted.compositeState;
    }
}

- (void) setCommittedCompositeState:(NSString *)state
{
    _committedCompositeState = state;
}

- (NSSet *) inflightLocalComponentFiles
{
    @synchronized(_inflightLocalComponentFiles) {
        return [_inflightLocalComponentFiles copy];
    }
}

-(void) addPathToInflightLocalComponents:(NSString*)destinationPath
{
    @synchronized(_inflightLocalComponentFiles) {
        NSString *componentFileName = [destinationPath lastPathComponent];
        NSAssert([_inflightLocalComponentFiles containsObject:componentFileName] == NO, @"The component file should not already be contained in the set of inflight components.");
        [_inflightLocalComponentFiles addObject:componentFileName];
    }
}

-(void) removePathFromInflightLocalComponents:(NSString*)destinationPath
{
    @synchronized(_inflightLocalComponentFiles) {
        NSString *componentFileName = [destinationPath lastPathComponent];
        NSAssert([_inflightLocalComponentFiles containsObject:componentFileName], @"The component file is unexpectedly missing from the set of inflight components.");
        [_inflightLocalComponentFiles removeObject:componentFileName];
    }
}

#pragma mark Branches

-(DCXMutableBranch *) current
{
    if (_current == nil) {
        NSString *path = self.currentManifestPath;
        DCXManifest *manifest = [DCXManifest manifestWithContentsOfFile:path
                                                                        withError:nil];
        if (manifest != nil) {
            _current = [DCXMutableBranch branchWithComposite:self
                                                                        andManifest:manifest];
            [self updateCurrentBranchCommittedDate];
        }
    }
    
    return _current;
}

-(void) updateCurrentBranchWithManifest:(DCXManifest *)manifest updateCommittedAtDate:(BOOL)updateCommittedAt
{
    if (manifest == nil) {
        _current = nil;
        self.currentBranchCommittedAtDate = nil;
    } else if (_current == nil) {
        _current = [DCXMutableBranch branchWithComposite:self
                                                                    andManifest:manifest];
    } else {
        _current.manifest = manifest;
    }
    if (manifest != nil && updateCommittedAt) {
        [self updateCurrentBranchCommittedDate];
    }
}

-(DCXBranch *) localCommitted
{
    if (_localCommitted == nil) {
        NSString *path = self.currentManifestPath;
        DCXManifest *manifest = [DCXManifest manifestWithContentsOfFile:path
                                                                        withError:nil];
        if (manifest != nil) {
            _localCommitted = [DCXBranch branchWithComposite:self
                                                                        andManifest:manifest];
        }
    }
    
    return _localCommitted;
}

-(void) updateLocalBranch
{
    // Let the "localCommitted" property construct it lazily if anyone needs it.
    _localCommitted = nil;
}

-(DCXBranch *) pulled
{
    if (_pulled == nil) {
        NSString *path = self.pulledManifestPath;
        DCXManifest *manifest = [DCXManifest manifestWithContentsOfFile:path
                                                                        withError:nil];
        if (manifest != nil) {
            _pulled = [DCXBranch branchWithComposite:self
                                                                       andManifest:manifest];
        }
    }
    
    return _pulled;
}

-(void) updatePulledBranchWithManifest:(DCXManifest *)manifest
{
    if (manifest == nil) {
        _pulled = nil;
    } else if (_pulled == nil) {
        _pulled = [DCXBranch branchWithComposite:self
                                                                   andManifest:manifest];
    } else {
        _pulled.manifest = manifest;
    }
}

-(DCXBranch *) pushed
{
    if (_pushed == nil) {
        NSString *path = self.pushedManifestPath;
        DCXManifest *manifest = [DCXManifest manifestWithContentsOfFile:path
                                                                        withError:nil];
        if (manifest != nil) {
            _pushed = [DCXBranch branchWithComposite:self
                                                                       andManifest:manifest];
        }
    }
    
    return _pushed;
}

-(void) updatePushedBranchWithManifest:(DCXManifest *)manifest
{
    if (manifest == nil) {
        _pushed = nil;
    } else if (_pushed == nil) {
        _pushed = [DCXBranch branchWithComposite:self
                                                                   andManifest:manifest];
    } else {
        _pushed.manifest = manifest;
    }
}

-(DCXBranch *) base
{
    if (_base == nil) {
        NSString *path = self.baseManifestPath;
        if (path) {
            DCXManifest *manifest = [DCXManifest manifestWithContentsOfFile:path
                                                                            withError:nil];
            if (manifest != nil) {
                _base = [DCXBranch branchWithComposite:self
                                                                           andManifest:manifest];
            }
        }
    }
    
    return _base;
}

-(void) updateBaseBranch
{
    // Let the "base" property construct it lazily if anyone needs it.
    // We don't need the withManifest variant because there are no cases where a base branch
    // is updated except when a pushed or pulled branch is accepted.
    _base = nil;
}

-(void) updateCurrentBranchCommittedDate
{
    // Record the date to be the floor of the current time so that it can be used to compare
    // against component file modification times which may only have a resolution of 1 second
    self.currentBranchCommittedAtDate = [NSDate dateWithTimeIntervalSince1970:floor([[NSDate date] timeIntervalSince1970])];
}

-(void) discardPushedManifest
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if ( [fm fileExistsAtPath:self.pushedManifestPath] ) {
        [fm removeItemAtPath:self.pushedManifestPath error:nil];
        [self updatePushedBranchWithManifest:nil];
    }
}

#pragma mark Storage

-(NSString*) currentManifestPath
{
    return _path == nil ? nil : [DCXLocalStorage currentManifestPathForComposite:self];
}

-(NSString*) pulledManifestPath
{
    return _path == nil ? nil : [DCXLocalStorage pullManifestPathForComposite:self];
}

-(NSString*) pushedManifestPath
{
    return _path == nil ? nil : [DCXLocalStorage pushManifestPathForComposite:self];
}

-(NSString*) baseManifestPath
{
    return _path == nil ? nil : [DCXLocalStorage baseManifestPathForComposite:self];
}

-(NSString*) pushJournalPath
{
    return _path == nil ? nil : [DCXLocalStorage pushJournalPathForComposite:self];
}

-(NSString*) clientDataPath
{
    return _path == nil ? nil : [DCXLocalStorage clientDataPathForComposite:self];
}

- (void)resetBinding
{
    _href = nil;
    if (self.manifest != nil) {
        [self.manifest resetBinding];
    }
    // Delete pull, push, and base directories
    [self discardEverythingButCurrentWithError:nil];
}

- (void)resetIdentity
{
    _href = nil;
    if (self.manifest != nil) {
        [self.manifest resetIdentity];
        _compositeId = self.manifest.compositeId;
    } else {
        _compositeId = [[NSUUID UUID] UUIDString];
    }
    // Delete pull, push, and base directories
    [self discardEverythingButCurrentWithError:nil];
}

- (BOOL) commitChangesWithError:(NSError **)errorPtr {
    // Update modified time
    NSString *oldModified = _current.manifest.modified;
    if (_current.manifest.isDirty) {
        NSDate *now = [NSDate date];
        _current.manifest.modified = [DCXManifest.dateFormatter stringFromDate:now];
    }

    if (![self.current writeManifestTo:self.currentManifestPath withError:errorPtr]) {
        _current.manifest.modified = oldModified;
        return NO;
    }
    [self updateLocalBranch];
    self.committedCompositeState = self.current.compositeState;
    [self updateCurrentBranchCommittedDate];
    
    return YES;
}

-(BOOL) removeLocalStorage:(NSError**)errorPtr
{
    return [DCXLocalStorage removeLocalFilesOfComposite:self withError:errorPtr];
}

-(BOOL) removeUnusedLocalFiles:(NSError**)errorPtr
{
    return [self removeUnusedLocalFilesWithError:errorPtr] != nil;
}

-(NSNumber*) removeUnusedLocalFilesWithError:(NSError**)errorPtr
{
    return [DCXLocalStorage removeUnusedLocalFilesOfComposite:self withError:errorPtr];
}

-(NSNumber *) localStorageBytesConsumed
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *fileAttributes = nil;

    // Compute the size of all stored components
    unsigned long long componentBytes = 0;
    NSArray *currentComponents = [self.current getAllComponents];
    NSArray *baseComponents = [self.base getAllComponents];
    NSArray *pushedComponents = [self.pushed getAllComponents];
    NSArray *pulledComponents = [self.pulled getAllComponents];
    NSUInteger numComponents = [currentComponents count] + [baseComponents count] + [pushedComponents count] + [pulledComponents count];
    NSMutableSet *visitedComponents = [NSMutableSet setWithCapacity:numComponents];
    
    NSMutableArray *componentArrays = [NSMutableArray array];
    if ( currentComponents != nil ) [componentArrays addObject:currentComponents];
    if ( baseComponents != nil ) [componentArrays addObject:baseComponents];
    if ( pushedComponents != nil ) [componentArrays addObject:pushedComponents];
    if ( pulledComponents != nil ) [componentArrays addObject:pulledComponents];
    
    for ( NSArray *branchComponents in componentArrays ) {
        DCXBranch *branch;
        if ( branchComponents == currentComponents ) branch = self.current;
        else if ( branchComponents == baseComponents ) branch = self.base;
        else if ( branchComponents == pushedComponents ) branch = self.pushed;
        else branch = self.pulled;
        
        // Discover which of this branch's components has a corresponding local file
        NSDictionary *componentPathMap = [DCXLocalStorage existingLocalStoragePathsForComponentsInBranch:branch];
        
        for ( DCXComponent *c in branchComponents ) {
            // Different branches may refer to the same file on disk so we check to see
            // whether we have already included this file in our result
            NSString *componentFilePath = componentPathMap[c.componentId];
            if ( componentFilePath != nil && ![visitedComponents containsObject:componentFilePath] ) {
                if ( c.length != nil ) {
                    componentBytes += [c.length unsignedLongLongValue];
                }
                else {
                    // We are dealing with an old manifest created with a version of Digital Composistes that did not record
                    // the file length upon inserting or updating the component and that has never been pushed,
                    // so just look it up here
                    fileAttributes = [fm attributesOfItemAtPath:componentFilePath error:nil];
                    if ( fileAttributes != nil ) {
                        componentBytes += [[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
                    }
                }
                [visitedComponents addObject:componentFilePath];
            }
        }
    }

    // Compute the size of any saved manifests
    unsigned long long manifestBytes = 0;
    NSArray *manifestPaths = [NSArray arrayWithObjects:self.currentManifestPath, self.baseManifestPath, self.pushJournalPath, self.pushedManifestPath, self.pulledManifestPath,
                              self.pushedManifestBasePath, self.pulledManifestBasePath, nil];
    for ( NSString *filePath in manifestPaths ) {
        fileAttributes = [fm attributesOfItemAtPath:filePath error:nil];
        if ( fileAttributes != nil ) {
            manifestBytes += [[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
        }
    }

    return [NSNumber numberWithUnsignedLongLong:componentBytes + manifestBytes];
}

-(void) requestDeletionOfUnsusedLocalFiles
{
    if ( !_autoRemoveUnusedLocalFiles ) return;
    
    // We are using _deletingFilesInBackgroundRequestCounter as a means of preventing multiple
    // deletion requests for the same composite from getting executed at the same time as well as
    // a way to remmeber that we need to do another pass if we get parallel requests.
    int32_t newValue = OSAtomicIncrement32Barrier(&_deleteFilesInBackgroundRequestCounter);
    
    if (newValue == 1) {
        // Since the original value was 0 we can safely assume that no other background deletion
        // is currently underway.
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        dispatch_async(queue, ^{
            
            // Execute the actual request.
            if([DCXLocalStorage removeUnusedLocalFilesOfComposite:self withError:nil]) {
                
                // Reset the counter value and figure out whether we need to kick off another request
                // (which we have to if _deletingFilesInBackgroundRequestCounter is greater than 1.
                // We need to do this in a loop using OSAtomic compare and swap so that we can
                // tell the value the counter was at when we actually set it back to 0.
                BOOL success = NO;
                while(!success) {
                    
                    int32_t currentCounterValue = _deleteFilesInBackgroundRequestCounter;
                    success = OSAtomicCompareAndSwap32Barrier(currentCounterValue, 0, &_deleteFilesInBackgroundRequestCounter);
                    
                    if (success && currentCounterValue > 1) {
                        // At least one other request has been made
                        [self requestDeletionOfUnsusedLocalFiles];
                    }
                }
            }
        });
    }
}

-(void) updateLocalStorageDataInManifest:(DCXManifest *)targetManifest fromManifestArray:(NSArray *)sourceManifests
{
    [DCXLocalStorage updateLocalStorageDataInManifest:targetManifest fromManifestArray:sourceManifests];
}

-(NSNumber*) removeLocalFilesForComponentsWithIDs:(NSArray*)componentIDs errorList:(NSArray**)errorListPtr
{
    NSAssert(componentIDs, @"componentIDs");
    
    unsigned long long bytesFreed = 0;
    NSMutableArray *errors = [NSMutableArray array];
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];

    DCXBranch *committedBranch = self.localCommitted;
    DCXBranch *baseBranch = self.base;
    
    for ( NSString *componentID in componentIDs ) {
        DCXComponent *currentComponent = [self.current getComponentWithId:componentID];
        DCXComponent *committedComponent = [committedBranch getComponentWithId:componentID];
        DCXComponent *baseComponent = [baseBranch getComponentWithId:componentID];
        
        if ( [[currentComponent state] isEqualToString:DCXAssetStateModified] ||
                 [[committedComponent state] isEqualToString:DCXAssetStateModified] ) {
            // Verify that the component has not been marked as modified
            [errors addObject:[DCXErrorUtils ErrorWithCode:DCXErrorCannotRemoveModifiedComponent
                                                             domain:DCXErrorDomain
                                                            details:[NSString stringWithFormat:@"Component with ID %@ cannot be evicted because it has local changes.", componentID]]];
            continue;
        }

        NSMutableArray *componentManifestPathTuples = [NSMutableArray arrayWithCapacity:3];
        if ( currentComponent != nil ) {
            [componentManifestPathTuples addObject:@[currentComponent, self.current.manifest, @""]];
        }
        if ( committedComponent != nil ) {
            [componentManifestPathTuples addObject:@[committedComponent, committedBranch.manifest, self.currentManifestPath]];
        }
        if ( baseComponent != nil ) {
            [componentManifestPathTuples addObject:@[baseComponent, baseBranch.manifest, self.baseManifestPath]];
        }
        
        NSMutableSet *removedComponentPaths = [NSMutableSet set];
        for ( NSArray *tuple in componentManifestPathTuples ) {
            DCXComponent *component = tuple[0];
            DCXManifest *manifest = tuple[1];
            NSString *manifestFilePath = tuple[2];
            
            NSString *componentFilePath = [DCXLocalStorage pathOfComponent:component
                                                              inManifest:manifest
                                                             ofComposite:self withError:&error];
            if ( !componentFilePath ) {
                [errors addObject:error];
            }
            else if ( ![removedComponentPaths containsObject:componentFilePath] ) {
                NSDictionary *attributes = [fm attributesOfItemAtPath:componentFilePath error:nil];
                if ( attributes ) {
                    // Local file exists
                    if ( [fm removeItemAtPath:componentFilePath error:&error] ) {
                        [removedComponentPaths addObject:componentFilePath];
                        bytesFreed += attributes.fileSize;
                    }
                    else {
                        [errors addObject:error];
                    }
                }
            }
            
            // Unless we encounter an error, we always inform the local storage mapping that the local file
            // has been removed so we can cleanup any bookkeeping details (such as the storage ID mapping
            // in the copy-on-write scheme) associated with local storage in the manifest
            if ( componentFilePath != nil && error == nil ) {
                [DCXLocalStorage didRemoveLocalFileForComponent:component inManifest:manifest];
                if ( ![manifestFilePath isEqualToString:@""] ) {
                    [manifest writeToFile:manifestFilePath generateNewSaveId:NO withError:&error];
                    if ( error != nil ) {
                        [errors addObject:error];
                    }
                }
            }
        }
    }
    
    if ( errorListPtr != NULL && [errors count] > 0 ) {
        *errorListPtr = errors;
    }
    return [NSNumber numberWithUnsignedLongLong:bytesFreed];
}



#pragma mark Components

-(DCXComponent*) addComponent:(DCXComponent *)component
                      fromManifest:(DCXManifest *)sourceManifest
                       ofComposite:(DCXComposite *)sourceComposite
                           toChild:(DCXNode*)node
                        ofManifest:(DCXManifest*)destManifest
                   replaceExisting:(BOOL)replaceExisting
                           newPath:(NSString*) newPath
                         withError:(NSError**)errorPtr
{
    NSAssert(component, @"component");
    NSAssert(sourceManifest, @"sourceManifest");
    NSAssert(sourceComposite, @"sourceComposite");
    NSAssert(destManifest, @"destManifest");
    NSAssert([destManifest.compositeId isEqualToString:self.compositeId], @"Argument 'destManifest' must be a manifest of the composite");
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *newComponentPath = nil;
    BOOL componentCopyInFlight = NO;

    NSString *sourceComponentPath = [DCXLocalStorage pathOfComponent:component inManifest:sourceManifest
                                             ofComposite:sourceComposite withError:errorPtr];
    if ( sourceComposite != self && sourceComponentPath != nil ) {
        newComponentPath = [DCXLocalStorage newPathOfComponent:component inManifest:destManifest ofComposite:self withError:errorPtr];
        if ( !newComponentPath ) {
            return nil;
        }
        NSString *destDir  = [newComponentPath stringByDeletingLastPathComponent];
        [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
        [self addPathToInflightLocalComponents:newComponentPath];
        componentCopyInFlight = YES;
        if ( ![fm copyItemAtPath:sourceComponentPath toPath:newComponentPath error:errorPtr] ) {
            [self removePathFromInflightLocalComponents:newComponentPath];
            return nil;
        }

    }
    else {
        newComponentPath = sourceComponentPath;
    }
    
    if ( sourceComposite != self && newPath == nil ) {
        // Specifying a new path ensures that the state of the copied component will be set to modified
        // and that the appropriate server state will be reset, which is necessary when copying between
        // composites
        newPath = component.path;
    }
    
    DCXComponent *newComponent = nil;
    if (replaceExisting) {
        newComponent = [destManifest replaceComponent:component fromManifest:sourceManifest withError:errorPtr];
    } else if (node == nil) {
        newComponent = [destManifest addComponent:component fromManifest:sourceManifest newPath:newPath withError:errorPtr];
    } else {
        newComponent = [destManifest addComponent:component fromManifest:sourceManifest toChild:node newPath:newPath withError:errorPtr];
    }
    
    // newComponentPath will be nil in the case where unmanaged components are added
    // This will therefore lead to removal of the entry from local storage mapping
    if (newComponent != nil) {
        if (![DCXLocalStorage updateComponent:[newComponent mutableCopy] inManifest:destManifest ofComposite:self
                                withNewPath:newComponentPath withError:errorPtr]) {
            NSAssert(NO, @"updateComponent should never fail in this context.");
            return nil;
        }
    }
    else {
        // Clean up copy of source component immediately if the operation has failed
        if (componentCopyInFlight) {
            [fm removeItemAtPath:newComponentPath error:nil];
        }
    }
    if (componentCopyInFlight) {
        [self removePathFromInflightLocalComponents:newComponentPath];
    }
    return newComponent;
}

-(DCXComponent*) removeComponent:(DCXComponent *)component fromManifest:(DCXManifest*)manifest
{
    if (manifest == nil) {
        manifest = self.manifest;
    }
    component = [manifest removeComponent:component];
    
    if (component != nil) {
        [DCXLocalStorage didRemoveComponent:component fromManifest:manifest];
    }

    return component;
}


#pragma mark Child Nodes

-(DCXNode*) addChild:(DCXNode *)node
                     fromManifest:(DCXManifest *)sourceManifest
                      ofComposite:(DCXComposite *)sourceComposite
                               to:(DCXNode *)parentNode
                          atIndex:(NSUInteger)index
                       ofManifest:(DCXManifest *)destManifest
                  replaceExisting:(BOOL)replaceExisting
                          newPath:(NSString*)newPath
                        withError:(NSError **)errorPtr
{
    NSAssert(node, @"node");
    NSAssert(sourceManifest, @"sourceManifest");
    NSAssert(sourceComposite, @"sourceComposite");
    NSAssert(destManifest, @"destManifest");
    NSAssert([destManifest.compositeId isEqualToString:self.compositeId], @"Argument 'destManifest' must be a manifest of the composite");

    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *sourceComponents = [NSMutableArray array];
    [sourceManifest componentsDescendedFromParent:node intoArray:sourceComponents];
    NSMutableDictionary *newComponentPathLookup = [NSMutableDictionary dictionaryWithCapacity:sourceComponents.count];

    void (^cleanupCopiedComponentsDuetoError)() = ^() {
        NSArray *newComponentFilePaths = [newComponentPathLookup allValues];
        for ( NSString *newComponentPath in newComponentFilePaths ) {
            [fm removeItemAtPath:newComponentPath error:nil];
            [self removePathFromInflightLocalComponents:newComponentPath];
        }
    };
    
    for ( DCXComponent *sourceComponent in sourceComponents ) {
        NSString *sourceComponentPath = [DCXLocalStorage pathOfComponent:sourceComponent inManifest:sourceManifest
                                                                          ofComposite:sourceComposite withError:errorPtr];
        NSString *newComponentPath = nil;
        if ( sourceComposite != self && sourceComponentPath != nil ) {
            // When copying across different composites we need to copy the node's component files to their new locations
            if ( sourceComponentPath != nil ) {
                newComponentPath = [DCXLocalStorage newPathOfComponent:sourceComponent inManifest:destManifest ofComposite:self withError:errorPtr];
                if ( newComponentPath == nil ) {
                    cleanupCopiedComponentsDuetoError();
                    return nil;
                }
                NSString *destDir = [newComponentPath stringByDeletingLastPathComponent];
                [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
                [self addPathToInflightLocalComponents:newComponentPath];
                if ( ![fm copyItemAtPath:sourceComponentPath toPath:newComponentPath error:errorPtr] ) {
                    [self removePathFromInflightLocalComponents:newComponentPath];
                    cleanupCopiedComponentsDuetoError();
                    return nil;
                }
            }
        }
        else {
            newComponentPath = sourceComponentPath;
        }
        
        if ( newComponentPath != nil ) {
            [newComponentPathLookup setObject:newComponentPath forKey:sourceComponent.componentId];
        }
    }
    
    // Copy the node data to the target manifest
    NSMutableArray *addedComponents = [NSMutableArray array];
    NSMutableArray *removedComponents = [NSMutableArray array];
    NSMutableArray *addedComponentOrgIds = [NSMutableArray array];
    DCXNode *addedNode = [destManifest insertChild:node
                                                   fromManifest:sourceManifest
                                                         parent:parentNode
                                                        atIndex:index
                                                replaceExisting:replaceExisting
                                                        newPath:newPath
                                                    forceNewIds:sourceComposite != self
                                                addedComponents:addedComponents
                                           addedComponentOrgIds:addedComponentOrgIds
                                              removedComponents:removedComponents
                                                      withError:errorPtr];
    
    if (addedNode == nil) {
        if ( sourceComposite != self ) {
            cleanupCopiedComponentsDuetoError();
        }
        return nil;
    }

    // Now we need to update local storage mapping
    for (DCXComponent *component in removedComponents) {
        [DCXLocalStorage didRemoveComponent:component fromManifest:destManifest];
    }
    for (int i = 0; i < addedComponents.count; i++) {
        DCXComponent *addedComponent = addedComponents[i];
        NSString *origComponentId = addedComponentOrgIds[i];
        NSString *addedComponentPath = [newComponentPathLookup objectForKey:origComponentId];
        if (addedComponentPath != nil) {
            if (![DCXLocalStorage updateComponent:[addedComponent mutableCopy] inManifest:destManifest ofComposite:self
                                    withNewPath:addedComponentPath withError:errorPtr]) {
                NSAssert(NO, @"This call to updateComponent should never fail in this context.");
                return nil;
            }
        }
    }

    if ( sourceComposite != self ) {
        // Remove new component paths from list of inflight component updates
        NSArray *newComponentFilePaths = [newComponentPathLookup allValues];
        for ( NSString *newComponentPath in newComponentFilePaths ) {
            [self removePathFromInflightLocalComponents:newComponentPath];
        }
    }
    
    return addedNode;
}

#pragma mark Push & Pull Support

-(BOOL) resolvePullWithBranch:(DCXMutableBranch *)branch withError:(NSError *__autoreleasing *)errorPtr
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if ( branch == nil && ![fm fileExistsAtPath:self.pulledManifestPath] ) {
        // Early return if there is no pulled manifest
        return YES;
    }
    NSError *error = nil;
    BOOL result = [self internalResolvePulledBranch:branch withError:&error updateInMemory:YES];
    if ( !result && errorPtr != NULL) {
        *errorPtr = error;
    }
    return result;
}

-(BOOL) internalResolvePulledBranch:(DCXMutableBranch *)branch withError:(NSError **)errorPtr
                    updateInMemory:(BOOL)updateCurrent
{
    BOOL success = YES;
    branch.manifest.etag = self.pulled.etag;
    
    // Let the local storage manager handle the details
    DCXManifest *manifest = branch.manifest;
    success = [DCXLocalStorage acceptPulledManifest:manifest forComposite:self withError:errorPtr];
    if (success) {
        self.committedCompositeState = manifest.compositeState;
    }
    
    if (success && updateCurrent) {
        // Instantiate new manifest
        DCXManifest *manifest = [DCXManifest manifestWithContentsOfFile:self.currentManifestPath
                                                                        withError:errorPtr];
        if (manifest != nil) {
            [self updateCurrentBranchWithManifest:manifest updateCommittedAtDate:NO];
        } else {
            success = NO;
        }
    }
    
    if (success) {
        [self updateLocalBranch];
        [self updatePulledBranchWithManifest:nil];
        [self requestDeletionOfUnsusedLocalFiles];
    }
    
    return success;
}

-(BOOL) acceptPushWithError:(NSError**)errorPtr
{
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL success = YES;
    if ( ![fm fileExistsAtPath:self.pushJournalPath] && ![fm fileExistsAtPath:self.pushedManifestPath] ) {
        // No-op if no push data exists
        return YES;
    }

    if ( !self.current.isDirty ) {
        // If there are no in-memory changes to the current branch then we only need to merge with current and commit the changes to disk
        if ( [self mergePushedStateIntoBranch:self.current writeManifestToPath:self.currentManifestPath withError:&error] ) {
            self.committedCompositeState = self.current.compositeState;
            [self updateCurrentBranchCommittedDate];            
            [self updateLocalBranch];
        }
        else {
            success = NO;
        }
    }
    else {
        // Update the local committed branch on disk
        if ( [self mergePushedStateIntoBranch:self.localCommitted writeManifestToPath:self.currentManifestPath withError:&error] ) {
            self.committedCompositeState = self.localCommitted.compositeState;
            // Update the current branch in memory only
            if ( ![self mergePushedStateIntoBranch:self.current writeManifestToPath:nil withError:&error] ) {
                success = NO;
            }
        }
        else {
            success = NO;
        }
    }
    
    // Update base branch
    if ( success && [DCXFileUtils moveFileAtomicallyFrom:self.pushedManifestPath
                                                      to:self.baseManifestPath
                                               withError:&error] ) {
        [self updateBaseBranch];
    }
    else {
        success = NO;
    }
    
    // Delete push journal and pushed manifest
    if ( success && (([fm fileExistsAtPath:self.pushJournalPath] && ![fm removeItemAtPath:self.pushJournalPath error:&error]))) {
        success = NO;
    }

    if ( success ) {
        // Invalidate pushed branch property
        [self updatePushedBranchWithManifest:nil];
        [self removeUnusedLocalFilesWithError:nil];
    }
    if ( !success && errorPtr != NULL ) {
        *errorPtr = error;
    }
    return success;
}

-(BOOL) discardPulledBranchWithError:(NSError *__autoreleasing *)errorPtr
{
    BOOL success = [DCXLocalStorage discardPullOfComposite:self withError:errorPtr];
    if (success) {
        [self updatePulledBranchWithManifest:nil];
        [self requestDeletionOfUnsusedLocalFiles];
    }
    return success;
}

-(BOOL) discardPushedBranchWithError:(NSError *__autoreleasing *)errorPtr{
    BOOL success = [DCXLocalStorage discardPushOfComposite:self withError:errorPtr];
    if (success) {
        [self updatePushedBranchWithManifest:nil];
        [self requestDeletionOfUnsusedLocalFiles];
    }
    return success;
}

-(BOOL) discardEverythingButCurrentWithError:(NSError **)errorPtr
{
    return [DCXLocalStorage resetBindingOfComposite:self withError:errorPtr];
}

-(NSMutableArray*) verifyLocalStorageOfBranch:(DCXBranch*)branch withLogging:(BOOL)doLog
                             shouldBeComplete:(BOOL)shouldBeComplete withBranchName:(NSString*)name
{
    NSMutableArray *inconsistencies = nil;
    
    // This assumes that we use the copy-on-write storage scheme:
    NSDictionary *local = [branch.manifest valueForKey:DCXLocalDataManifestKey];
    if (local != nil) {
        NSDictionary *mapping = local[DCXLocalStorageAssetIdMapManifestKey];
        if (mapping != nil) {
            NSArray *mappedComponentIds = [mapping allKeys];
            for (NSString *componentId in mappedComponentIds) {
                if (branch.manifest.allComponents[componentId] == nil) {
                    NSString *inconsistency = [NSString stringWithFormat:@"Unknown component %@ has an entry in the local storage mapping.", componentId];
                    if (inconsistencies == nil) {
                        inconsistencies = [NSMutableArray arrayWithObject:inconsistency];
                    } else {
                        [inconsistencies addObject:inconsistency];
                    }
                }
            }
        }
    }
    
    if (shouldBeComplete) {
        NSArray *existingComponents = [branch.manifest.allComponents allValues];
        for (DCXComponent *component in existingComponents) {
            NSString *path = [branch pathForComponent:component withError:nil];
            if (path == nil) {
                NSString *inconsistency = [NSString stringWithFormat:@"Component %@ doesn't have a local file.", component.componentId];
                if (inconsistencies == nil) {
                    inconsistencies = [NSMutableArray arrayWithObject:inconsistency];
                } else {
                    [inconsistencies addObject:inconsistency];
                }
            }}
    }
    
    if (doLog && inconsistencies != nil) {
        NSString *title = nil;
        if (name) {
            title = [NSString stringWithFormat:@"Local storage of branch %@ of composite %@ shows %ld inconsistencies:", name, self.compositeId, (unsigned long)inconsistencies.count];
        } else {
            title = [NSString stringWithFormat:@"Local storage of manifest %@ shows %ld inconsistencies:", self.compositeId, (unsigned long)inconsistencies.count];
        }
        [inconsistencies insertObject:title atIndex:0];
        NSString *output = [inconsistencies componentsJoinedByString:@"\n   "];
        NSLog(@"**************************************************\n%@\n**************************************************", output);
    }
    
    return inconsistencies;
}

-(void) verifyBranch:(DCXBranch*)branch withLogging:(BOOL)doLog shouldBeComplete:(BOOL)shouldBeComplete
      withBranchName:(NSString*)name inconsistencies:(NSMutableArray**)inconsistencies
{
    if (branch != nil) {
        NSMutableArray *branchInconsistencies = [branch.manifest verifyIntegrityWithLogging:doLog withBranchName:name];
        if (branchInconsistencies != nil) {
            if (*inconsistencies == nil) {
                *inconsistencies = branchInconsistencies;
            } else {
                [*inconsistencies addObjectsFromArray:branchInconsistencies];
            }
        }
        branchInconsistencies = [self verifyLocalStorageOfBranch:branch withLogging:doLog
                                                shouldBeComplete:shouldBeComplete withBranchName:name];
        if (branchInconsistencies != nil) {
            if (*inconsistencies == nil) {
                *inconsistencies = branchInconsistencies;
            } else {
                [*inconsistencies addObjectsFromArray:branchInconsistencies];
            }
        }
    }
}

-(NSArray*) verifyIntegrityWithLogging:(BOOL)doLog shouldBeComplete:(BOOL)shouldBeComplete
{
    NSMutableArray *inconsistencies;
    
    [self verifyBranch:self.current withLogging:doLog shouldBeComplete:shouldBeComplete
        withBranchName:@"current" inconsistencies:&inconsistencies];
    [self verifyBranch:self.localCommitted withLogging:doLog shouldBeComplete:shouldBeComplete
        withBranchName:@"local committed" inconsistencies:&inconsistencies];
    [self verifyBranch:self.base withLogging:doLog shouldBeComplete:shouldBeComplete
        withBranchName:@"base" inconsistencies:&inconsistencies];
    [self verifyBranch:self.pulled withLogging:doLog shouldBeComplete:shouldBeComplete
        withBranchName:@"pulled" inconsistencies:&inconsistencies];
    [self verifyBranch:self.pushed withLogging:doLog shouldBeComplete:shouldBeComplete
        withBranchName:@"pushed" inconsistencies:&inconsistencies];
    
    return inconsistencies;
}

-(DCXManifest *) copyCommittedManifestWithError:(NSError **)errorPtr
{
    DCXManifest *result = nil;
    if ( _localCommitted == nil ) {
        NSString *path = self.currentManifestPath;
        DCXManifest *manifest = [DCXManifest manifestWithContentsOfFile:path
                                                                        withError:errorPtr];
        if ( manifest != nil ) {
            result = manifest;
        }
    }
    else {
        result = [_localCommitted.manifest copy];
    }
    return result;
}

-(BOOL) mergePushedStateIntoBranch:(DCXBranch*)destBranch writeManifestToPath:(NSString*)destManifestPath withError:(NSError **)errorPtr
{
    NSError *error = nil;
    
    // Read and verify the push journal
    DCXPushJournal *journal = [DCXPushJournal journalForComposite:self
                                                         fromFile:self.pushJournalPath
                                                                      error:&error];
    NSString *journalCompositeHref = [journal compositeHref];
    
    if (error == nil && self.href != nil &&
        ![journalCompositeHref isEqualToString:self.href]) {
        error = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidJournal domain:DCXErrorDomain
                                      underlyingError:nil
                                                 path:self.pushJournalPath
                                              details:[NSString stringWithFormat:
                                                       @"Composite href in journal (%@) doesn't match the href from the composite (%@)",
                                                       journalCompositeHref, self.href]];
    }
    
    if (error == nil && !journal.isComplete) {
        error = [DCXErrorUtils ErrorWithCode:DCXErrorIncompleteJournal domain:DCXErrorDomain
                                      underlyingError:nil
                                                 path:self.pushJournalPath
                                              details:@"Journal is not complete."];
    }
    
    // Read the pushed manifest
    DCXManifest *pushedManifest = nil;
    if (error == nil) {
        pushedManifest = [DCXManifest manifestWithContentsOfFile:self.pushedManifestPath
                                                            withError:&error];
    }
    DCXBranch *pushedBranch = nil;
    if (error == nil) {
        pushedBranch = [DCXMutableBranch branchWithComposite:self
                                                                        andManifest:pushedManifest];
    }
    
    // Make a copy of the destination branch's manifest so that if we encounter an error
    // we can exit without leaving the destination branch in a partially modified state.
    DCXBranch *destBranchCopy = [destBranch mutableCopy];
    DCXManifest *destManifest = destBranchCopy.manifest;
    
    if (destBranch == nil || destManifest == nil) {
        error = [DCXErrorUtils ErrorWithCode:DCXErrorManifestReadFailure domain:DCXErrorDomain
                                              details:nil];
    }
    
    // Start the merge (i.e. apply the push journal to the destination manifest)
    if (error == nil) {
        if (journal.compositeHasBeenDeleted) {
            // The document got deleted during the previous push.
            destManifest.compositeState = DCXAssetStateCommittedDelete;
        } else {
            // Iterate over all components in the destination manifest
            NSArray *allComponentIds = [destManifest.allComponents allKeys];
            for (NSString *componentId in allComponentIds) {
                
                DCXComponent *component = [destManifest.allComponents objectForKey:componentId];
                DCXMutableComponent *journaledComponent = [journal getUploadedComponent:component fromPath:nil];
                
                if (journaledComponent != nil) {
                    // Component has been uploaded -
                    // If it is still marked as modified in our destination branch then we check to see if
                    // it has been updated since its upload in order to determine its correct new state.
                    // We take advantage of the fact that the copy-on-write storage scheme will always result in a new
                    // path when a component is updated.
                    if ([component.state isEqualToString:DCXAssetStateModified] ) {
                        DCXComponent *pushedComponent = [pushedManifest.allComponents objectForKey:componentId];
                        
                        NSString *destBranchPath = [destBranchCopy pathForComponent:component withError:nil];
                        NSString *pushedBranchPath = [self.pushed pathForComponent:pushedComponent withError:nil];
                        
                        BOOL markAsModified = YES;
                        if ( destBranchPath != nil && pushedBranchPath != nil && [destBranchPath isEqualToString:pushedBranchPath] ) {
                            markAsModified = NO;
                        }
                        
                        if ( markAsModified ) {
                            journaledComponent.state = DCXAssetStateModified;
                            journaledComponent.length = component.length;
                        }
                        else {
                            journaledComponent.state = DCXAssetStateUnmodified;
                        }
                    }
                    else if ([component.state isEqualToString:DCXAssetStatePendingDelete]) {
                        journaledComponent.state = DCXAssetStatePendingDelete;
                    }
                    else {
                        journaledComponent.state = DCXAssetStateUnmodified;
                    }
                    
                    // Update the component
                    component = [destManifest updateComponent:journaledComponent withError:&error];
                                        
                }
            }
            
            // Update the manifest's properties
            [journal updateManifestWithJournalEtag:destManifest];
            
            // Make sure to set the document's href for newly created documents
            if (self.href == nil && journalCompositeHref != nil) {
                self.href = journalCompositeHref;
                destManifest.compositeHref = journalCompositeHref;
            }
            
            // Update the document's state if necessary
            if ( ((!destManifest.saveId && !pushedManifest.saveId) || [destManifest.saveId isEqualToString:pushedManifest.saveId]) && [destManifest.compositeState isEqualToString:DCXAssetStateModified] ) {
                // The destination manifest hasn't been written to disk since the push began so we only need to check whether the
                // destination branch was previously updated in memory to determine the appropriate state after merging
                destManifest.compositeState = destBranch.manifest.isDirty ? DCXAssetStateModified : DCXAssetStateUnmodified;
            }
        }
    }
    
    if ( error == nil ) {
        if ( destManifestPath != nil ) {
            // Write out the merged manifest
            [destManifest writeToFile:destManifestPath generateNewSaveId:YES withError:&error];
        }
        if ( error == nil ) {
            // Update the in-memory copy of the destination branch
            destBranch.manifest = destManifest;
        }
    }

    if (error != nil) {
        if (errorPtr != NULL) *errorPtr = error;
        return NO;
    }
    
    return YES;
}


@end
