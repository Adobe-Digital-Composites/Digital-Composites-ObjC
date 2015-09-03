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

#import "DCXBranch_Internal.h"
#import "DCXMutableBranch.h"

#import "DCXError.h"
#import "DCXConstants.h"
#import "DCXManifest.h"
#import "DCXMutableComponent.h"
#import "DCXMutableNode.h"
#import "DCXComposite_Internal.h"
#import "DCXLocalStorage.h"

#import "DCXErrorUtils.h"

@implementation DCXMutableBranch

@dynamic name;
@dynamic type;
@dynamic links;
@dynamic compositeState;
@dynamic etag;

- (BOOL) isDirty
{
    return self.manifest == nil ? NO : self.manifest.isDirty;
}

-(void) setName:(NSString *)name
{
    self.manifest.name = name;
}

-(void) setType:(NSString *)type
{
    self.manifest.type = type;
}

-(void) setLinks:(NSDictionary *)links
{
    self.manifest.links = links;
}

-(void) setCompositeState:(NSString *)compositeState
{
    self.manifest.compositeState = compositeState;
}

-(void) setEtag:(NSString *)etag
{
    self.manifest.etag = etag;
}

-(void) setValue:(id)value forKey:(NSString *)key
{
    [self.manifest setValue:value forKey:key];
}

-(void) removeValueForKey:(NSString *)key
{
    [self.manifest removeValueForKey:key];
}

-(void) markCompositeForDeletion
{
    NSAssert(self.compositeState != DCXAssetStateCommittedDelete, @"Composite has already been deleted from server.");
    self.compositeState = DCXAssetStatePendingDelete;
}

#pragma mark - Components

- (DCXComponent*) addComponent:(NSString*)name
                        withId:(NSString*)componentId
                      withType:(NSString*)type
              withRelationship:(NSString*)rel
                      withPath:(NSString*)path
                       toChild:(DCXNode*)node
                      fromFile:(NSString*)sourceFile
                          copy:(BOOL)copy
                     withError:(NSError**)errorPtr
{
    NSAssert(path, @"path");
    DCXMutableComponent *component = [[DCXMutableComponent alloc] initWithId:componentId == nil ? [[NSUUID UUID] UUIDString] : componentId
                                                                                  path:path
                                                                                  name:name
                                                                                  type:type
                                                                                 links:nil
                                                                                 state:DCXAssetStateModified];
    component.relationship = rel;
    return [self addComponent:component toChild:node fromFile:sourceFile copy:copy withError:errorPtr];
}


- (DCXComponent*) addComponent:(DCXComponent*)componentToAdd
                            toChild:(DCXNode *)node
                           fromFile:(NSString*)sourceFile copy:(BOOL)copy
                          withError:(NSError**)errorPtr
{
    NSAssert(componentToAdd, @"componentToAdd");
    NSAssert(componentToAdd.path, @"componentToAdd.path");
    
    DCXMutableComponent *component = [componentToAdd mutableCopy];
    component.state = DCXAssetStateModified;
    if (component.componentId == nil) {
        component.componentId = [[NSUUID UUID] UUIDString];
    }
    
    return [self internalAddComponent:component toChild:node
                             fromFile:sourceFile copy:copy withError:errorPtr];
}

- (DCXComponent*) internalAddComponent:(DCXMutableComponent*)component
                                    toChild:(DCXNode *)node
                                   fromFile:(NSString*)sourceFile copy:(BOOL)copy
                                  withError:(NSError**)errorPtr
{
    NSAssert(self.manifest != nil, @"Manifest must be loaded.");
    
    // Get a strong reference to the composite
    DCXComposite *composite = self.weakComposite;
    NSAssert(composite != nil, @"Using branch after the composite has been released");
    
    NSString *destPath = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ( sourceFile != nil ) {
        // Determine where the file should go
        destPath = [DCXLocalStorage newPathOfComponent:component inManifest:self.manifest ofComposite:composite withError:errorPtr];
        if (destPath == nil) {
            return nil;
        }
        NSString *destDir  = [destPath stringByDeletingLastPathComponent];
        
        // Make sure to create any necessary subdirectories
        [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSString *standardSourcePath = [sourceFile stringByStandardizingPath];
        NSString *standardDestPath = [destPath stringByStandardizingPath];
        
        // Copy or move file into place only if the source file differs from the path
        if ( ![standardSourcePath isEqualToString:standardDestPath] ) {
            [composite addPathToInflightLocalComponents:standardDestPath];
            if (copy) {
                if (![fm copyItemAtPath:sourceFile toPath:destPath error:errorPtr]) {
                    [composite removePathFromInflightLocalComponents:standardDestPath];
                    return nil;
                }
            }
            else {
                NSURL *resultURL;
                if ( ![fm replaceItemAtURL:[NSURL fileURLWithPath:destPath]
                             withItemAtURL:[NSURL fileURLWithPath:sourceFile]
                            backupItemName:nil
                                   options:NSFileManagerItemReplacementUsingNewMetadataOnly
                          resultingItemURL:&resultURL
                                     error:errorPtr] ) {
                    [composite removePathFromInflightLocalComponents:standardDestPath];
                    return nil;
                }
            }
        }
        
        if (![DCXLocalStorage updateComponent:component inManifest:self.manifest ofComposite:composite
                                         withNewPath:destPath withError:errorPtr]) {
            [composite removePathFromInflightLocalComponents:standardDestPath];
            return nil;
        }
        [composite removePathFromInflightLocalComponents:standardDestPath];
    }

    DCXComponent *result;
    if (node == nil) {
        result = [self.manifest addComponent:component fromManifest:nil newPath:nil withError:errorPtr];

    } else {
        result = [self.manifest addComponent:component fromManifest:nil toChild:node newPath:nil withError:errorPtr];
    }
    if ( result == nil && destPath != nil ) {
        // An error occurred so remove the new component file from local storage ID lookup
        if ( copy ) {
            [fm removeItemAtPath:destPath error:nil];
        }
        else {
            NSURL *resultURL;
            [fm replaceItemAtURL:[NSURL fileURLWithPath:sourceFile]
                   withItemAtURL:[NSURL fileURLWithPath:destPath]
                  backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly
                resultingItemURL:&resultURL error:nil];
        }
        [DCXLocalStorage didRemoveComponent:component fromManifest:self.manifest];
    }
    return result;
}

- (DCXComponent*) updateComponent:(DCXComponent *)component
                         fromFile:(NSString*)sourceFile copy:(BOOL)copy
                        withError:(NSError **)errorPtr
{
    NSAssert(self.manifest != nil, @"Manifest not loaded");
    NSAssert(component, @"component");
    NSAssert(component.componentId, @"component.componentId");
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Get a strong reference to the composite
    DCXComposite *composite = self.weakComposite;
    NSAssert(composite != nil, @"Using branch after the composite has been released");
    
    DCXMutableComponent *updatedComponent = [component isKindOfClass:[DCXMutableComponent class]] ? component : [component mutableCopy];
    NSString *destPath = nil;
    NSString *origPath = [DCXLocalStorage pathOfComponent:component inManifest:self.manifest ofComposite:composite withError:nil];

    BOOL componentFileWasUpdated = NO;
    NSString *standardSourcePath = nil;
    NSString *standardDestPath = nil;

    if(sourceFile != nil)
    {
        if (sourceFile != nil) {
            // Determine where the file should go
            destPath = [DCXLocalStorage newPathOfComponent:updatedComponent inManifest:self.manifest
                                                      ofComposite:composite withError:errorPtr];
            if (destPath == nil) {
                return nil;
            }
            NSString *destDir  = [destPath stringByDeletingLastPathComponent];
            
            // Make sure to create any necessary subdirectories
            [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
            
            standardSourcePath = [sourceFile stringByStandardizingPath];
            standardDestPath = [destPath stringByStandardizingPath];
            
            // Copy or move file into place only if the source file differs from the path
            if ( ![standardSourcePath isEqualToString:standardDestPath] ) {
                [composite addPathToInflightLocalComponents:standardDestPath];
                if (copy) {
                    if (![fm copyItemAtPath:sourceFile toPath:destPath error:errorPtr]) {
                        [composite removePathFromInflightLocalComponents:standardDestPath];
                        return nil;
                    }
                }
                else {
                    NSURL *resultURL;
                    if ( ![fm replaceItemAtURL:[NSURL fileURLWithPath:destPath]
                                 withItemAtURL:[NSURL fileURLWithPath:sourceFile]
                                backupItemName:nil
                                       options:NSFileManagerItemReplacementUsingNewMetadataOnly
                              resultingItemURL:&resultURL
                                         error:errorPtr] ) {
                        [composite removePathFromInflightLocalComponents:standardDestPath];
                        return nil;
                    }
                }
                // Ensure that the component state is modified so that we can upload the new
                // component asset during the next push.
                if ([updatedComponent.state isEqualToString:DCXAssetStateUnmodified]) {
                    updatedComponent.state = DCXAssetStateModified;
                }
                componentFileWasUpdated = YES;
            }
        }
        else{
            // It is an unmanaged component, reset the length of the component to 0, since we do not know the new length
            updatedComponent.length = 0;
            if ([updatedComponent.state isEqualToString:DCXAssetStateUnmodified]) {
                updatedComponent.state = DCXAssetStateModified;
            }
            componentFileWasUpdated = YES;
        }
        // Let the storage scheme update its records
        if (![DCXLocalStorage updateComponent:updatedComponent inManifest:self.manifest
                                         ofComposite:composite
                                         withNewPath:destPath withError:errorPtr]) {
            if(standardDestPath !=nil){
                [composite removePathFromInflightLocalComponents:standardDestPath];
            }
            return nil;
        }
        
        if(standardDestPath !=nil){
            [composite removePathFromInflightLocalComponents:standardDestPath];
        }
    }
    
    DCXComponent *result = [self.manifest updateComponent:updatedComponent withError:errorPtr];
    if ( result == nil && destPath != nil ) {
        // An error occurred when attempting to update the component data in the manifest so we must
        // restore our local storage ID mapping and sourceHref information, as well as try to "undo"
        // any filesystem operations
        if ( origPath != nil ) {
            [DCXLocalStorage updateComponent:updatedComponent inManifest:self.manifest
                                        ofComposite:composite withNewPath:origPath withError:nil];
        }
        if ( componentFileWasUpdated ) {
            if ( copy ) {
                [fm removeItemAtPath:destPath error:nil];
            }
            else {
                NSURL *resultURL;
                [fm replaceItemAtURL:[NSURL fileURLWithPath:sourceFile]
                       withItemAtURL:[NSURL fileURLWithPath:destPath]
                      backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly
                    resultingItemURL:&resultURL error:nil];
            }
        }
    }
    
    return result;
}


-(DCXComponent*) moveComponent:(DCXComponent *)component toChild:(DCXNode *)node
                          withError:(NSError**)errorPtr
{
    NSAssert(component, @"component");
    NSAssert(component.componentId, @"component.componentId");
    
    return [self.manifest moveComponent:component toChild:node withError:errorPtr];
}

-(DCXComponent*) copyComponent:(DCXComponent *)component from:(DCXBranch *)branch
                            toChild:(DCXNode *)node newPath:(NSString *)newPath
                          withError:(NSError **)errorPtr
{
    NSAssert(branch, @"branch");
    DCXComposite *composite = self.weakComposite;
    DCXComposite *sourceComposite = branch.weakComposite;
    NSAssert(composite != nil, @"Using branch after the composite has been released");
    NSAssert(sourceComposite != nil, @"Using 'from' branch after its composite has been released");

    return [composite addComponent:component fromManifest:branch.manifest ofComposite:sourceComposite
                                                    toChild:node ofManifest:self.manifest replaceExisting:NO newPath:newPath
                                                withError:errorPtr];
}

-(DCXComponent*) copyComponent:(DCXComponent *)component from:(DCXBranch *)branch
                            toChild:(DCXNode *)node withError:(NSError **)errorPtr
{
    NSAssert(branch, @"branch");
    DCXComposite *composite = self.weakComposite;
    DCXComposite *sourceComposite = branch.weakComposite;
    NSAssert(composite != nil, @"Using branch after the composite has been released");
    NSAssert(sourceComposite != nil, @"Using 'from' branch after its composite has been released");
    
    return [composite addComponent:component fromManifest:branch.manifest ofComposite:sourceComposite
                           toChild:node ofManifest:self.manifest replaceExisting:NO newPath:nil
                         withError:errorPtr];
}

-(DCXComponent*) updateComponent:(DCXComponent *)component from:(DCXBranch *)branch
                            withError:(NSError **)errorPtr
{
    NSAssert(branch, @"branch");
    DCXComposite *composite = self.weakComposite;
    DCXComposite *sourceComposite = branch.weakComposite;
    NSAssert(composite != nil, @"Using branch after the composite has been released");
    NSAssert(sourceComposite != nil, @"Using 'from' branch after its composite has been released");

    return [composite addComponent:component fromManifest:branch.manifest ofComposite:sourceComposite
                           toChild:nil ofManifest:self.manifest replaceExisting:YES newPath:nil
                         withError:errorPtr];
}

-(DCXComponent*) removeComponent:(DCXComponent *)component
{
    NSAssert(component, @"component");
    NSAssert(component.componentId, @"component.componentId");
    
    // Get a strong reference to the composite
    DCXComposite *composite = self.weakComposite;
    NSAssert(composite != nil, @"Using branch after the composite has been released");
    
    return [composite removeComponent:component fromManifest:self.manifest];
}

#pragma mark - Children

-(DCXNode*) updateChild:(DCXNode*)node withError:(NSError**)errorPtr
{
    NSAssert(node, @"node");
    NSAssert(node.nodeId, @"node.nodeId");
    
    return [self.manifest updateChild:node withError:errorPtr];
}

-(DCXNode*) addChild:(DCXNode*)node toParent:(DCXNode*)parentNode
                        withError:(NSError**)errorPtr
{
    NSAssert(node, @"node");
    NSAssert(node.nodeId, @"node.nodeId");
    
    if (parentNode == nil) {
        return [self.manifest addChild:node withError:errorPtr];
    } else {
        return [self.manifest addChild:node toParent:parentNode withError:errorPtr];
    }
}

-(DCXNode*) insertChild:(DCXNode*)node parent:(DCXNode*)parentNode
                             atIndex:(NSUInteger)index withError:(NSError**)errorPtr
{
    NSAssert(node, @"node");
    NSAssert(node.nodeId, @"node.nodeId");
    
    if (parentNode == nil) {
        return [self.manifest insertChild:node atIndex:index withError:errorPtr];
    } else {
        return [self.manifest insertChild:node parent:parentNode atIndex:index withError:errorPtr];
    }
}

-(DCXNode*) copyChild:(DCXNode *)node from:(DCXBranch *)branch
                          toParent:(DCXNode *)parentNode toIndex:(NSUInteger)index
                         withError:(NSError **)errorPtr
{
    NSAssert(branch, @"branch");
    
    DCXComposite *composite = self.weakComposite;
    DCXComposite *sourceComposite = branch.weakComposite;
    NSAssert(composite != nil, @"Using branch after the composite has been released");
    NSAssert(sourceComposite != nil, @"Using 'from' branch after its composite has been released");
    
    return [composite addChild:node
                  fromManifest:branch.manifest
                   ofComposite:sourceComposite
                            to:parentNode
                       atIndex:index
                    ofManifest:self.manifest
               replaceExisting:NO
                       newPath:nil
                     withError:errorPtr];
}

-(DCXNode*) copyChild:(DCXNode *)node from:(DCXBranch *)branch
                          toParent:(DCXNode *)parentNode toIndex:(NSUInteger)index
                          withPath:(NSString *)newPath
                         withError:(NSError **)errorPtr
{
    NSAssert(branch, @"branch");

    
    DCXComposite *composite = self.weakComposite;
    DCXComposite *sourceComposite = branch.weakComposite;
    NSAssert(composite != nil, @"Using branch after the composite has been released");
    NSAssert(sourceComposite != nil, @"Using 'from' branch after its composite has been released");

    return [composite addChild:node
                  fromManifest:branch.manifest
                   ofComposite:sourceComposite
                            to:parentNode
                       atIndex:index
                    ofManifest:self.manifest
               replaceExisting:NO
                       newPath:newPath
                     withError:errorPtr];
}

-(DCXNode*) updateChild:(DCXNode *)node from:(DCXBranch *)branch
                           withError:(NSError **)errorPtr
{
    NSAssert(branch, @"branch");
    
    DCXComposite *composite = self.weakComposite;
    DCXComposite *sourceComposite = branch.weakComposite;
    NSAssert(composite != nil, @"Using branch after the composite has been released");
    NSAssert(sourceComposite != nil, @"Using 'from' branch after its composite has been released");
    
    return [composite addChild:node
                  fromManifest:branch.manifest
                   ofComposite:sourceComposite
                            to:nil
                       atIndex:0
                    ofManifest:self.manifest
               replaceExisting:YES
                       newPath:nil
                     withError:errorPtr];
}

-(DCXNode*) moveChild:(DCXNode*)node toParent:(DCXNode*)parentNode
                           toIndex:(NSUInteger)index withError:(NSError**)errorPtr
{
    NSAssert(node, @"node");
    NSAssert(node.nodeId, @"node.nodeId");
    
    if (parentNode == nil) {
        return [self.manifest moveChild:node toIndex:index withError:errorPtr];
    } else {
        return [self.manifest moveChild:node toParent:parentNode toIndex:index withError:errorPtr];
    }
}

-(DCXNode*) removeChild:(DCXNode*)node
{
    NSAssert(node, @"node");
    NSAssert(node.nodeId, @"node.nodeId");
    
    NSMutableArray *removedComponents = [NSMutableArray array];
    DCXNode *child = [self.manifest removeChild:node removedComponents:removedComponents];
    for ( DCXComponent *c in removedComponents ) {
        [DCXLocalStorage didRemoveComponent:c fromManifest:self.manifest];
    }
    return child;
}


#pragma mark - Storage

- (BOOL) writeManifestTo:(NSString*)path withError:(NSError **)errorPtr {
    BOOL success = ( [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                                               withIntermediateDirectories:YES
                                                                attributes:0
                                                                     error:errorPtr]
                    && [self.manifest writeToFile:path generateNewSaveId:YES withError:errorPtr] );
    
    if (success) {
        // Get a strong reference to the composite
        DCXComposite *composite = self.weakComposite;
        NSAssert(composite != nil, @"Using branch after the composite has been released");
        [composite requestDeletionOfUnsusedLocalFiles];
    }
    
    return success;
}

@end
