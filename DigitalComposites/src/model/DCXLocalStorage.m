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

#import "DCXLocalStorage.h"

#import "DCXManifest.h"
#import "DCXConstants_Internal.h"
#import "DCXComposite_Internal.h"
#import "DCXBranch_Internal.h"
#import "DCXMutableComponent.h"
#import "DCXError.h"

#import "DCXFileUtils.h"
#import "DCXErrorUtils.h"

NSString *const DCXClientDataPath           = @"clientdata";
NSString *const DCXComponentsPath           = @"components";

NSString *const DCXManifestPath             = @"manifest";
NSString *const DCXBaseManifestPath         = @"base.manifest";
NSString *const DCXPullManifestPath         = @"pull.manifest";
NSString *const DCXPushManifestPath         = @"push.manifest";
NSString *const DCXPushJournalPath         = @"push.journal";

static NSString* storageIdWithPathExtension(DCXComponent *component)
{
    NSString *storageId = [[NSUUID UUID] UUIDString];
    NSString *pathExt = [component.path pathExtension];
    if ( [pathExt length] > 0 ) {
        // Preserve filename extensions in case they are meaningful to the client
        storageId = [storageId stringByAppendingPathExtension:pathExt];
    }
    return storageId;
}

@implementation DCXLocalStorage

#pragma mark Paths

+(NSString*) clientDataPathForComposite:(DCXComposite *)composite
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    
    return [composite.path stringByAppendingPathComponent:DCXClientDataPath];
}

+(NSString*) currentManifestPathForComposite:(DCXComposite *)composite
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    
    return [composite.path stringByAppendingPathComponent:DCXManifestPath];
}

+(NSString*) baseManifestPathForComposite:(DCXComposite *)composite
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    
    return [composite.path stringByAppendingPathComponent:DCXBaseManifestPath];
}

+(NSString*) pullManifestPathForComposite:(DCXComposite *)composite
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    
    return [composite.path stringByAppendingPathComponent:DCXPullManifestPath];
}

+(NSString*) pushManifestPathForComposite:(DCXComposite *)composite
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    
    return [composite.path stringByAppendingPathComponent:DCXPushManifestPath];
}

+(NSString*) pushJournalPathForComposite:(DCXComposite *)composite
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    
    return [composite.path stringByAppendingPathComponent:DCXPushJournalPath];
}

+(NSMutableDictionary*) getStorageIdLookupOfManifest:(DCXManifest*)manifest createIfNecessary:(BOOL)create
{
    NSMutableDictionary *localData = [manifest valueForKey:DCXLocalDataManifestKey];
    if (localData == nil) {
        if (!create) {
            return nil;
        }
        localData = [NSMutableDictionary dictionaryWithObject:[NSMutableDictionary dictionary]
                                                       forKey:DCXLocalStorageAssetIdMapManifestKey];
        [manifest setValue:localData forKey:DCXLocalDataManifestKey];
    }
    NSMutableDictionary *storageIdLookup = [localData objectForKey:DCXLocalStorageAssetIdMapManifestKey];
    if (storageIdLookup == nil) {
        if (!create) {
            return nil;
        }
        storageIdLookup = [NSMutableDictionary dictionary];
        localData[DCXLocalStorageAssetIdMapManifestKey] = storageIdLookup;
    }
    return storageIdLookup;
}

+(NSString*) storageIdForComponent:(DCXComponent*)component ofManifest:(DCXManifest*)manifest
{
    NSMutableDictionary *storageIdLookup = [self getStorageIdLookupOfManifest:manifest createIfNecessary:YES];
    NSString *storageId = storageIdLookup[component.componentId];
    
    // Do not set the storage for unmanaged components.
    if (storageId == nil) {
        storageId = storageIdWithPathExtension(component);
        storageIdLookup[component.componentId] = storageId;
    }
    return storageId;
}

+(NSString*) storageIdForComponent:(DCXComponent*)component ofManifest:(DCXManifest*)manifest
                   createIfMissing:(BOOL)create
{
    if (create) {
        // Call the default version of this method, which creates missing storage IDs
        return [DCXLocalStorage storageIdForComponent:component ofManifest:manifest];
    }
    NSMutableDictionary *storageIdLookup = [self getStorageIdLookupOfManifest:manifest createIfNecessary:NO];
    if ( storageIdLookup == nil ) {
        return nil;
    }
    return storageIdLookup[component.componentId];
}

+(void) setStorageId:(NSString*)storageId forComponent:(DCXComponent*)component ofManifest:(DCXManifest*)manifest
{
    NSMutableDictionary *storageIdLookup = [self getStorageIdLookupOfManifest:manifest createIfNecessary:YES];
    if(storageId == nil){
        [storageIdLookup removeObjectForKey:component.componentId];
    }else{
        storageIdLookup[component.componentId] = storageId;
    }
}

+(NSString*) newPathOfComponent:(DCXMutableComponent *)component
                     inManifest:(DCXManifest*)manifest
                    ofComposite:(DCXComposite *)composite
                      withError:(NSError **)errorPtr
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    NSAssert(component != nil, @"Parameter component must not be nil.");
    
    NSString *newId = storageIdWithPathExtension(component);
    NSString *destPath = [[composite.path stringByAppendingPathComponent:DCXComponentsPath] stringByAppendingPathComponent:newId];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:destPath]) {
        if (errorPtr != NULL) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorComponentWriteFailure
                                                       domain:DCXErrorDomain
                                                      details:[NSString stringWithFormat:@"Component file already exists at %@.", destPath]];
            return nil;
        }
    }
    return destPath;
}

+(BOOL) updateComponent:(DCXMutableComponent *)component
             inManifest:(DCXManifest*)manifest
            ofComposite:(DCXComposite *)composite
            withNewPath:(NSString *)assetPath
              withError:(NSError **)errorPtr
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(component != nil, @"Parameter component must not be nil.");
    if(assetPath == nil){
        [self setStorageId:assetPath forComponent:component ofManifest:manifest];
        return YES;
    }
    
    NSString *dir = [[composite.path stringByAppendingPathComponent:DCXComponentsPath] stringByStandardizingPath];
    assetPath = [assetPath stringByStandardizingPath];
    if (![assetPath hasPrefix:dir]) {
        if (errorPtr != NULL) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidLocalStoragePath
                                                       domain:DCXErrorDomain
                                                      details:[NSString stringWithFormat:@"Component path '%@' reaches out of composite directory",
                                                               assetPath]];
        }
        return NO;
    }
    
    NSString *newId = [assetPath lastPathComponent];
    [self setStorageId:newId forComponent:component ofManifest:manifest];
    
    // Need to make sure that the mod date of the file gets updated so that our garbage collection
    // doesn't delete this file prematurely.
    [DCXFileUtils touch:assetPath withError:nil];
    
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:assetPath error:nil];
    if ( fileAttributes != nil ) {
        component.length = [fileAttributes objectForKey:NSFileSize];
    }
    
    return YES;
}

+(NSString*) pathOfComponent:(DCXComponent *)component
                      inManifest:(DCXManifest*)manifest
                     ofComposite:(DCXComposite *)composite
                       withError:(NSError **)errorPtr
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    NSAssert(component != nil, @"Parameter component must not be nil.");
    
    NSString *fileName = [self storageIdForComponent:component ofManifest:manifest];
    
    NSString *dir = [[composite.path stringByAppendingPathComponent:DCXComponentsPath] stringByStandardizingPath];
    NSString *path = [[dir stringByAppendingPathComponent:fileName] stringByStandardizingPath];
    if (![path hasPrefix:dir]) {
        if (errorPtr != NULL) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidLocalManifest
                                                       domain:DCXErrorDomain
                                                      details:[NSString stringWithFormat:@"Component path '%@' reaches out of composite directory",
                                                               component.path]];
        }
        path = nil;
    }
    return path;
}

#pragma mark Push & Pull


+(BOOL) acceptPulledManifest:(DCXManifest *)manifest forComposite:(DCXComposite *)composite
                   withError:(NSError **)errorPtr
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL success = YES;
    NSString *pulledManifestPath = [self pullManifestPathForComposite:composite];
    NSString *currentManifestPath = [self currentManifestPathForComposite:composite];
    
    if (manifest != nil) {
        // Client provided an in-memory manifest
        success = [manifest writeToFile:currentManifestPath generateNewSaveId:YES withError:errorPtr];
    } else if(![fm fileExistsAtPath:pulledManifestPath]) {
        // nothing to do here
        return YES;
    } else {
        success = [fm copyItemAtPath:pulledManifestPath toPath:currentManifestPath error:errorPtr];
    }
    
    if (success) {
        success = [DCXFileUtils moveFileAtomicallyFrom:[self pullManifestPathForComposite:composite]
                                                    to:[self baseManifestPathForComposite:composite]
                                                      withError:errorPtr];
        [composite updateBaseBranch];
    }
    
    return success;
}

+(BOOL) discardPullOfComposite:(DCXComposite *)composite withError:(NSError **)errorPtr
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [composite.path stringByAppendingPathComponent:DCXPullManifestPath];
    return (![fm fileExistsAtPath:path]) || [fm removeItemAtPath:path error:errorPtr];
}

+(BOOL) acceptPushedManifest_deprecated:(DCXManifest*)manifest forComposite:(DCXComposite*)composite
                   withError:(NSError**)errorPtr
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    
    BOOL success = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *currentManifestPath = [self currentManifestPathForComposite:composite];
    
    if (manifest == nil) {
        // Move push/manifest to current/manifest
        NSString *pushedManifestPath = [self pushManifestPathForComposite:composite];
        success = [DCXFileUtils moveFileAtomicallyFrom:pushedManifestPath to:currentManifestPath withError:errorPtr];
    } else {
        success = [manifest writeToFile:currentManifestPath generateNewSaveId:YES withError:errorPtr];
        if (success) {
            // Delete push manifest
            NSString *path = [composite.path stringByAppendingPathComponent:DCXPushManifestPath];
            success = (![fm fileExistsAtPath:path]) || [fm removeItemAtPath:path error:errorPtr];
        }
    }
    
    if (success) {
        // Move push manifest to base manifest
        success = [DCXFileUtils moveFileAtomicallyFrom:[self pushManifestPathForComposite:composite]
                                                             to:[self baseManifestPathForComposite:composite]
                                                      withError:errorPtr];
        [composite updateBaseBranch];
    }
    
    if (success) {
        // Delete push journal
        NSString *path = [composite.path stringByAppendingPathComponent:DCXPushJournalPath];
        success = (![fm fileExistsAtPath:path]) || [fm removeItemAtPath:path error:errorPtr];
    }
    
    if (success) {
        [self removeUnusedLocalFilesOfComposite:composite withError:nil];
    }
    
    return success;
}

+(BOOL) discardPushOfComposite:(DCXComposite *)composite withError:(NSError **)errorPtr
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [composite.path stringByAppendingPathComponent:DCXPushJournalPath];
    BOOL success = (![fm fileExistsAtPath:path]) || [fm removeItemAtPath:path error:errorPtr];
    if (success) {
        path = [composite.path stringByAppendingPathComponent:DCXPushManifestPath];
        success = (![fm fileExistsAtPath:path]) || [fm removeItemAtPath:path error:errorPtr];
    }
    if (success) {
        [self removeUnusedLocalFilesOfComposite:composite withError:nil];
    }
    return success;
}

#pragma Misc


+(BOOL) discardBaseOfComposite:(DCXComposite*)composite withError:(NSError**)errorPtr
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [composite.path stringByAppendingPathComponent:DCXBaseManifestPath];
    BOOL success = YES;
    if ([fm fileExistsAtPath:base]) {
        success = [fm removeItemAtPath:base error:errorPtr];
    }
    if (success) {
        [composite updateBaseBranch];
    }
    return success;
}

#pragma mark Misc

+(BOOL) resetBindingOfComposite:(DCXComposite *)composite withError:(NSError **)errorPtr
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    
    return [self discardPullOfComposite:composite withError:errorPtr]
    && [self discardBaseOfComposite:composite withError:errorPtr]
    &&  [self discardPushOfComposite:composite withError:errorPtr]; // do this last since it also deletes unused components
}

+(BOOL) removeLocalFilesOfComposite:(DCXComposite *)composite withError:(NSError **)errorPtr
{
    NSAssert(composite != nil, @"Parameter composite must not be nil.");
    NSAssert(composite.path != nil, @"Parameter composite must have a non-nil path.");
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Check for the existence of a components directory and unlock all files within it
    BOOL isDirectory = NO;
    NSString *componentsDir = [composite.path stringByAppendingPathComponent:DCXComponentsPath];
    if ([fm fileExistsAtPath:componentsDir isDirectory:&isDirectory] && isDirectory) {
        NSArray *components = [fm contentsOfDirectoryAtPath:componentsDir error:errorPtr];
        if (components == nil) {
            return NO;
        }
        for (NSString *component in components) {
            NSString *componentPath = [componentsDir stringByAppendingPathComponent:component];
            NSDictionary *attributes = [fm attributesOfItemAtPath:componentPath error:errorPtr];
            if ((attributes != nil) && (attributes[NSFileImmutable] != nil)) {
                NSMutableDictionary *mutableAttributes = [attributes mutableCopy];
                mutableAttributes[NSFileImmutable] = @"0";
                [fm setAttributes:mutableAttributes ofItemAtPath:componentPath error:errorPtr];
            }
        }
    }
    
    return [fm removeItemAtPath:composite.path error:errorPtr];
}


+(NSNumber*) removeUnusedLocalFilesOfComposite:(DCXComposite*)composite withError:(NSError**)errorPtr
{
    unsigned long long bytesFreed = 0;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *manifestNames = @[DCXManifestPath, DCXBaseManifestPath, DCXPullManifestPath,
                               DCXPushManifestPath,];
    NSMutableArray *manifestStorageIdLookups = [NSMutableArray arrayWithCapacity:manifestNames.count];
    NSDate *oldestManifestModeDate = [NSDate distantFuture];
    BOOL baseManifestExists = NO;
    
    // Load all manifests and determine the mod date of the oldest manifest
    for (NSString *manifestName in manifestNames) {
        NSString *path = [composite.path stringByAppendingPathComponent:manifestName];
        if ([fm fileExistsAtPath:path]) {
            if ( [manifestName isEqualToString:DCXBaseManifestPath] ) {
                baseManifestExists = YES;
            }
            NSDictionary *attributes = [fm attributesOfItemAtPath:path error:&error];
            if (attributes != nil && error == nil) {
                NSDate *manifestModDate = attributes.fileModificationDate;
                DCXManifest *manifest = [DCXManifest manifestWithContentsOfFile:path withError:&error];
                if (manifest != nil && error == nil) {
                    if (manifestModDate != nil) {
                        oldestManifestModeDate = [manifestModDate earlierDate:oldestManifestModeDate];
                    }
                    NSDictionary *lookup = [self getStorageIdLookupOfManifest:manifest createIfNecessary:NO];
                    if (lookup != nil) {
                        [manifestStorageIdLookups addObject:lookup];
                    }
                }
            }
        }
        if (error != nil) {
            break;
        }
    }
    
    // Consider the last time that the current branch was committed to, or initialized from, local storage
    if ( composite.currentBranchCommittedAtDate != nil ) {
        oldestManifestModeDate = [composite.currentBranchCommittedAtDate earlierDate:oldestManifestModeDate];
    }

    DCXManifest *activePushManifest = composite.activePushManifest; // get strong reference
    if ( activePushManifest != nil ) {
        // We need to include the components that are referenced in an active push operation, which
        // may have been updated in, or removed from, the current branch and may not be referenced
        // by any on-disk manifests
        NSDictionary *lookup = [self getStorageIdLookupOfManifest:activePushManifest createIfNecessary:NO];
        if (lookup != nil) {
            [manifestStorageIdLookups addObject:lookup];
        }
    }

    if (error == nil && manifestStorageIdLookups.count > 0) {
        
        // Create a merged set of all referenced component storage ids
        NSMutableSet *referencedStorageIds = nil;
        for (NSDictionary *componentLookup in manifestStorageIdLookups) {
            NSArray *storageIds = [componentLookup allValues];
            if (storageIds.count > 0) {
                if (referencedStorageIds == nil) {
                    referencedStorageIds = [NSMutableSet setWithCapacity:storageIds.count];
                }
                for (NSString *storageId in storageIds) {
                    [referencedStorageIds addObject:storageId];
                }
            }
        }
        
        // Now iterate over all files in the components directory
        BOOL isDirectory = NO;
        NSString *componentsDir = [composite.path stringByAppendingPathComponent:DCXComponentsPath];
        if ([fm fileExistsAtPath:componentsDir isDirectory:&isDirectory] && isDirectory) {
            NSArray *fileNames = [fm contentsOfDirectoryAtPath:componentsDir error:&error];
            NSSet *inflightComponentFiles = composite.inflightLocalComponentFiles;
            if (error == nil) {
                for (NSString *fileName in fileNames) {
                    NSError *loopError = nil;
                    if (![referencedStorageIds containsObject:fileName] && ![inflightComponentFiles containsObject:fileName]) {
                        // Get the mod date of the file
                        NSString *filePath = [componentsDir stringByAppendingPathComponent:fileName];
                        NSDictionary *attributes = [fm attributesOfItemAtPath:filePath error:&loopError];
                        if (loopError == nil) {
                            NSDate *componentModDate = attributes.fileModificationDate;
                            if ([componentModDate compare:oldestManifestModeDate] == NSOrderedAscending) {
                                [fm removeItemAtPath:filePath error:&loopError];
                                if ( !loopError ) {
                                    bytesFreed += attributes.fileSize;
                                }
                            }
                        }
                    }
                    if (loopError != nil && error == nil) {
                        // We are going to continue the loop but we want to preserve the first local error
                        error = loopError;
                    }
                }
            }
        }
    }
    
    if (error != nil && errorPtr != NULL) {
        *errorPtr = error;
    }
    
    if ( error == nil || bytesFreed > 0 ) {
        // Return number of bytes freed even if an error occurs
        return [NSNumber numberWithUnsignedLongLong:bytesFreed];
    }
    return nil;
}

+(void) updateLocalStorageDataInManifest:(DCXManifest*)targetManifest fromManifestArray:(NSArray *)sourceManifests
{
    // Iterate over all components in target manifest. If a given component asset is unchanged
    // (as compared to its instance in the source manifest) we make sure to use its local storage
    // asset id from source manifest -- otherwise create a new id
    
    NSArray *targetComponents = [[targetManifest allComponents] allValues];
    NSString *storageId;
    
    for (DCXComponent *targetComponent in targetComponents) {
        storageId = [self storageIdForComponent:targetComponent ofManifest:targetManifest createIfMissing:NO];
        if (storageId != nil) {
            // Skip over target components that have already been assigned a storage ID
            continue;
        }
        
        for (DCXManifest *sourceManifest in sourceManifests) {
            DCXComponent *sourceComponent = [sourceManifest.allComponents objectForKey:targetComponent.componentId];
            if (sourceComponent != nil
                && [targetComponent.etag isEqualToString:sourceComponent.etag]
                && ![sourceComponent.state isEqualToString:DCXAssetStateModified]) {
                storageId = [self storageIdForComponent:sourceComponent ofManifest:sourceManifest];
                if (storageId != nil) {
                    break;
                }
            }
        }
        
        if (storageId == nil) {
            storageId = storageIdWithPathExtension(targetComponent);
        }
        [self setStorageId:storageId forComponent:targetComponent ofManifest:targetManifest];
    }
}

+(void) didRemoveComponent:(DCXComponent*)component fromManifest:(DCXManifest*)manifest
{
    return [DCXLocalStorage didRemoveLocalFileForComponent:component inManifest:manifest];
}

#pragma mark Partial composite support

+(void) didRemoveLocalFileForComponent:(DCXComponent*)component
                            inManifest:(DCXManifest*)manifest
{
    NSMutableDictionary *lookup = [self getStorageIdLookupOfManifest:manifest createIfNecessary:NO];
    if (lookup != nil && [lookup objectForKey:component.componentId] != nil) {
        [lookup removeObjectForKey:component.componentId];
    }
}

+(NSDictionary*) existingLocalStoragePathsForComponentsInBranch:(DCXBranch*)branch
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    DCXComposite *composite = branch.weakComposite;
    NSAssert(composite != nil, @"Using using stale branch reference to a deallocated composite");
    
    NSArray *components = [branch getAllComponents];
    if ( !components ) return result;

    NSMutableDictionary *storageIdLookup = [self getStorageIdLookupOfManifest:branch.manifest createIfNecessary:NO];
    if ( storageIdLookup != nil ) {
        NSFileManager *fm = [NSFileManager defaultManager];
        for ( DCXComponent *c in components ) {
            if ( [storageIdLookup valueForKey:c.componentId] ) {
                // Obtain local path and test for existence
                NSString *componentPath = [self pathOfComponent:c
                                                     inManifest:branch.manifest
                                                    ofComposite:composite
                                                      withError:nil];
                if ( componentPath != nil && [fm fileExistsAtPath:componentPath isDirectory:nil] ) {
                    [result setValue:componentPath forKey:c.componentId];
                }
            }
        }
    }
    return result;
}

@end
