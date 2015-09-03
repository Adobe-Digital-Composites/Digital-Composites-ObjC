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


#import "DCXManifest.h"
#import "DCXMutableNode_Internal.h"

#import "DCXConstants_Internal.h"
#import "DCXError.h"
#import "DCXComponent_internal.h"
#import "DCXNode_Internal.h"
#import "DCXMutableComponent.h"
#import "DCXMutableNode.h"
#import "DCXManifestFormatConverter.h"

#import "DCXUtils.h"
#import "DCXErrorUtils.h"
#import "DCXCopyUtils.h"
#import "DCXUtils.h"

static NSDateFormatter *staticDateFormatter;
static NSDateFormatter *staticRFC3339DateParser1;
static NSDateFormatter *staticRFC3339DateParser2;

@implementation DCXManifest
{
    // The overall dictionary that is this manifest
    NSMutableDictionary *_dictionary;
    
    // Hashes that make lookups faster and allow us to catch duplicate ids/paths.
    NSMutableDictionary *_allComponents;
    NSMutableDictionary *_allChildren;
    NSMutableDictionary *_absolutePaths;
}

+ (void) initialize
{
    // Initialize for this class but not again for any subclasses
    if (self == [DCXManifest class]) {
        NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        NSTimeZone *tz = [NSTimeZone timeZoneForSecondsFromGMT:0];
        
        staticDateFormatter = [[NSDateFormatter alloc] init];
        [staticDateFormatter setLocale:locale];
        [staticDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS"];
        [staticDateFormatter setTimeZone:tz];
        
        staticRFC3339DateParser1 = [[NSDateFormatter alloc] init];
        [staticRFC3339DateParser1 setLocale:locale];
        [staticRFC3339DateParser1 setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssXXXXX"];
        [staticRFC3339DateParser1 setTimeZone:tz];
        
        staticRFC3339DateParser2 = [[NSDateFormatter alloc] init];
        [staticRFC3339DateParser2 setLocale:locale];
        [staticRFC3339DateParser2 setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSSSSSXXXXX"];
        [staticRFC3339DateParser2 setTimeZone:tz];
    }
}


#pragma mark Initializers

- (instancetype)initWithDictionary:(NSMutableDictionary*)dictionary withError:(NSError**)errorPtr
{
    if (self = [super init]) {
        // first figure out the format version of the manifest in the dictionary and see
        // whether we need to convert it
        NSUInteger fversion = [[dictionary objectForKey:@"manifest-format-version"] unsignedIntegerValue];
        if (fversion < DCXManifestFormatVersion) {
            if (![DCXManifestFormatConverter updateManifestDictionary:dictionary fromVersion:fversion withError:errorPtr]) {
                return nil;
            }
        } else if (fversion > DCXManifestFormatVersion) {
            // We downgrade the manifest format version number to match the format that
            // this version of the code can produce.
            dictionary[@"manifest-format-version"] = [NSNumber numberWithUnsignedInteger:DCXManifestFormatVersion];
        }
        _dictionary = [self getManifestDictionaryFrom:dictionary];
        
        // Ensure that we have an id
        if ([_dictionary objectForKey:DCXIdManifestKey] == nil) {
            [_dictionary setObject:[[NSUUID UUID] UUIDString] forKey:DCXIdManifestKey];
        }
        
        _rootNode = [DCXMutableNode rootNodeFromDict:dictionary andManifest:self];
        
        if (![self verifyWithError:errorPtr]) {
            return nil;
        }
        
        [self buildHashes];
        
        _isDirty = NO;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name andType:(NSString *)type
{
    NSString *id = [[NSUUID UUID] UUIDString];
    
    // Create a bare bones dictionary:
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInteger:DCXManifestFormatVersion], @"manifest-format-version",
        name,      DCXNameManifestKey,
        type,      DCXTypeManifestKey,
        id,        DCXIdManifestKey,
        nil
    ];
    
    return [self initWithDictionary:dictionary withError:nil];
}

- (instancetype)initWithData:(NSData*)data withError:(NSError**)errorPtr
{
    NSError *parseError;
    NSMutableDictionary *dictionary = [DCXUtils JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&parseError];
    if(dictionary == nil) {
        if (errorPtr != NULL) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidManifest domain:DCXErrorDomain
                                              underlyingError:parseError details:@"Invalid JSON"];
        }
        return nil;
    }
    
    [self recursiveRemoveEmptyArrays:dictionary]; // See explanation below
    
    return [self initWithDictionary:dictionary withError:errorPtr];
}

-(NSMutableDictionary *) getManifestDictionaryFrom:(NSDictionary*)dict {
    NSMutableDictionary *manifestDict = [[NSMutableDictionary alloc] init];
    for( id key in dict){
        if([[DCXManifest manifestSpecificProperties] containsObject:key] ){
            [manifestDict setObject:[dict objectForKey:key] forKey:key];
        }
    }
    return manifestDict;
}

+ (NSArray*) manifestSpecificProperties{
    static NSArray* props = nil;
    if(props == nil){
        props = [NSArray arrayWithObjects:DCXIdManifestKey,
                 DCXStateManifestKey,
                 DCXLocalDataManifestKey,
                 @"manifest-format-version",
                 nil];
    }
    return props;
}


-(BOOL) removeArrayIfEmptyWithName:(NSString*)name fromDict:(NSMutableDictionary*)dict
{
    NSArray *array = [dict objectForKey:name];
    if (array != nil && [array count] == 0) {
        [dict removeObjectForKey:name];
        return YES;
    } else {
        return NO;
    }
}

// Workaround for OS X 10.7 NSJSONSerialization bug:
// Empty collections are immutable
// http://stackoverflow.com/questions/9912707/nsjsonserialization-not-creating-mutable-containers
-(void) recursiveRemoveEmptyArrays:(NSMutableDictionary*)dict
{
    [self removeArrayIfEmptyWithName:DCXLinksManifestKey fromDict:dict];
    [self removeArrayIfEmptyWithName:DCXComponentsManifestKey fromDict:dict];
    if (![self removeArrayIfEmptyWithName:DCXChildrenManifestKey fromDict:dict]) {
        NSArray *children = [dict objectForKey:DCXChildrenManifestKey];
        if (children != nil) {
            for (NSMutableDictionary *child in children) {
                [self recursiveRemoveEmptyArrays:child];
            }
        }
    }
}

-(void) recursiveBuildHashesFrom:(NSDictionary*)dict parentPath:(NSString*)parentPath;
{
    __weak __typeof(self)weakSelf = self;

    NSArray *components = [dict objectForKey:DCXComponentsManifestKey];
    if (components != nil) {
        for (id componentData in components) {
            NSString *componentId = [componentData objectForKey:DCXIdManifestKey];
            if (componentId == nil) {
                componentId = [[NSUUID UUID] UUIDString];
                [componentData setObject:componentId forKey:DCXIdManifestKey];
            }
            
            DCXComponent *comp = [DCXComponent componentFromDictionary:componentData andManifest:weakSelf withParentPath:parentPath];
            [_allComponents setObject:comp forKey:componentId];
            [_absolutePaths setObject:comp forKey:comp.absolutePath.lowercaseString];
        }
    }
    NSArray *children = [dict objectForKey:DCXChildrenManifestKey];
    if (children != nil) {
        for (id nodeData in children) {
            NSString *nodeId = [nodeData objectForKey:DCXIdManifestKey];
            if (nodeId == nil) {
                nodeId = [[NSUUID UUID] UUIDString];
                [nodeData setObject:nodeId forKey:DCXIdManifestKey];
            }
            DCXNode *node = [DCXNode nodeFromDictionary:nodeData andManifest:weakSelf withParentPath:parentPath];
            [_allChildren setObject:node forKey:nodeId];
            if (node.path != nil) {
                [_absolutePaths setObject:node forKey:node.absolutePath.lowercaseString];
                [self recursiveBuildHashesFrom:nodeData parentPath:[parentPath stringByAppendingPathComponent:node.path]];
            } else {
                [self recursiveBuildHashesFrom:nodeData parentPath:parentPath];
            }
        }
    }
}

- (void) buildHashes
{
    NSUInteger numComponents = [[_rootNode.dict objectForKey:DCXComponentsManifestKey] count];
    _allComponents = [NSMutableDictionary dictionaryWithCapacity:numComponents];
    _allChildren = [NSMutableDictionary dictionaryWithCapacity:[[_rootNode.dict objectForKey:DCXChildrenManifestKey] count]];
    _absolutePaths = [NSMutableDictionary dictionaryWithCapacity:numComponents];
    
    [self recursiveBuildHashesFrom:_rootNode.dict parentPath:@"/"];
    
    [_allChildren setObject:_rootNode forKey:_rootNode.nodeId];
    [_absolutePaths setObject:_rootNode forKey:@"/"];
}


#pragma mark Convenience methods

+ (instancetype)manifestWithName:(NSString *)name andType:(NSString *)type
{
    return [[DCXManifest alloc] initWithName:name andType:type];
}

+ (instancetype)manifestWithContentsOfFile:(NSString*)path withError:(NSError**) errorPtr
{
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
    if(data == nil) {
        if (errorPtr != nil) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorManifestReadFailure domain:DCXErrorDomain
                                              underlyingError:nil path:path details:nil];
        }
        return nil;
    }
    
    return [[self alloc] initWithData:data withError:errorPtr];
}

// IMPORTANT NODE : Make sure that this is called AFTER the initialization of the root Node
- (BOOL) verifyWithError:(NSError**)errorPtr
{
    // A valid manifest must have an id, a name, and a type
    if ([_dictionary objectForKey:DCXIdManifestKey] == nil) {
        if (errorPtr != NULL) *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidManifest
                                                                         domain:DCXErrorDomain underlyingError:nil details:@"Manifest is missing an id"];
        return NO;
    }
    if ([_rootNode.dict objectForKey:DCXNameManifestKey] == nil) {
        if (errorPtr != NULL) *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidManifest
                                                                         domain:DCXErrorDomain underlyingError:nil details:@"Manifest is missing a name"];
        return NO;
    }
    if ([_rootNode.dict objectForKey:DCXTypeManifestKey] == nil) {
        if (errorPtr != NULL) *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidManifest
                                                                         domain:DCXErrorDomain underlyingError:nil details:@"Manifest is missing a type"];
        return NO;
    }
    
    return YES;
}


#pragma mark Local storage

- (BOOL)writeToFile:(NSString*)path generateNewSaveId:(BOOL)newSaveId withError:(NSError**) errorPtr
{
    NSError *writeError = nil;
    if ( newSaveId ) {
        NSString *saveID = [[NSUUID UUID] UUIDString];
        NSMutableDictionary *local = [_dictionary objectForKey:DCXLocalDataManifestKey];
        if ( local != nil ) {
            [local setObject:saveID forKey:DCXManifestSaveIdManifestKey];
        }
        else {
            [_dictionary setObject:[NSMutableDictionary dictionaryWithObject:saveID forKey:DCXManifestSaveIdManifestKey]
                            forKey:DCXLocalDataManifestKey];
        }
    }
    
    if ([self.localData writeToFile:path options:NSDataWritingAtomic error:&writeError]) {
        _isDirty = NO;
        return YES;
    }
    if (errorPtr != NULL) {
        *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorManifestWriteFailure domain:DCXErrorDomain
                                          underlyingError:writeError path:path details:nil];
    }
    
    return NO;
}

- (void)recursiveReset:(NSMutableDictionary*)node
{
    // Iterate over components
    NSMutableArray *components = [node objectForKey:DCXComponentsManifestKey];
    // Iterate from back to front so that we can safely remove components
    for (NSInteger i=[components count]-1; i>=0; i--) {
        NSMutableDictionary *component = [components objectAtIndex:i];
        NSString *componentState = [component objectForKey:DCXStateManifestKey];
        
        if ([componentState isEqualToString:DCXAssetStateCommittedDelete] || [componentState isEqualToString:DCXAssetStatePendingDelete]) {
            // The component has been deleted, we need to remove it.
            [components removeObjectAtIndex:i];
            // Update components hash
            NSString *componentId = [component objectForKey:DCXIdManifestKey];
            DCXComponent *c = _allComponents[componentId];
            [_absolutePaths removeObjectForKey:c.absolutePath.lowercaseString];
            [_allComponents removeObjectForKey:componentId];
        } else {
            [component removeObjectForKey:DCXEtagManifestKey];
            [component removeObjectForKey:DCXVersionManifestKey];
            [component removeObjectForKey:DCXLengthManifestKey];
            // Resetting state to modified
            [component setObject:DCXAssetStateModified forKey:DCXStateManifestKey];
        }
    }
    
    // Iterate over children
    NSArray *children = [node objectForKey:DCXChildrenManifestKey];
    for (NSMutableDictionary *child in children) {
        [self recursiveReset:child];
    }
}

- (void)resetWithRetainId:(BOOL)retainId
{
    [_dictionary removeObjectForKey:DCXEtagManifestKey];
    if (!retainId) {
        // Assign a new id
        [self internalSetCompositeId:[[NSUUID UUID] UUIDString]];
    }
    
    // Set composite state
    [_dictionary setObject:DCXAssetStateModified forKey:DCXStateManifestKey];
    
    // Recurse through the DOM
    [self recursiveReset:[_rootNode getMutableDictionary]];
    
    self.etag = nil;
    self.compositeHref = nil;
    _isDirty = YES;
}

-(void)resetIdentity
{
    [self resetWithRetainId:NO];
}

-(void)resetBinding
{
    [self resetWithRetainId:YES];
}


#pragma mark Properties

- (NSString*)compositeId
{
    return [_dictionary objectForKey:DCXIdManifestKey];
}

- (void)setCompositeId:(NSString *)compositeId
{
    [self internalSetCompositeId:compositeId];
    [self markAsModifiedAndDirty];
}

- (NSString*)name
{
    return [_rootNode.dict objectForKey:DCXNameManifestKey];
}

- (void)setName:(NSString*)name
{
    if (name != nil) {
        [[_rootNode getMutableDictionary] setObject:name forKey:DCXNameManifestKey];
    } else {
        [[_rootNode getMutableDictionary] removeObjectForKey:DCXNameManifestKey];
    }
    [self markAsModifiedAndDirty];
}

- (NSString*)type
{
    return [_rootNode.dict objectForKey:DCXTypeManifestKey];
}

- (void)setType:(NSString*)type
{
    if (type != nil) {
        [[_rootNode getMutableDictionary] setObject:type forKey:DCXTypeManifestKey];
    } else {
        [[_rootNode getMutableDictionary] removeObjectForKey:DCXTypeManifestKey];
    }
    [self markAsModifiedAndDirty];
}

- (NSString*) compositeState
{
    // default to unmodified in order to support legacy composites
    NSString *result = [_dictionary objectForKey:DCXStateManifestKey];
    return (result != nil) ? result : DCXAssetStateUnmodified;
}

- (void) setCompositeState:(NSString *)state
{
    [_dictionary setObject:state forKey:DCXStateManifestKey];
    _isDirty = YES;
}

- (NSData*)localData
{
    NSMutableDictionary *mergedDictionary = [_rootNode.dict mutableCopy];
    NSAssert([_rootNode.dict objectForKey:DCXIdManifestKey] == [_dictionary objectForKey:DCXIdManifestKey], @"RootNode Id is not equal to the composite Id");
    // Merge the contents of root node and the manifest dictionary before writing out
    [mergedDictionary addEntriesFromDictionary:_dictionary];
    
    return [NSJSONSerialization dataWithJSONObject:mergedDictionary options:NSJSONWritingPrettyPrinted error:nil];
}

- (NSData*)remoteData
{
    // We need to temporarily remove the local property
    NSMutableDictionary *local = [_dictionary objectForKey:DCXLocalDataManifestKey];
    if (local != nil) {
        [_dictionary removeObjectForKey:DCXLocalDataManifestKey];
    }

    // Merge the contents of root node and the manifest dictionary before writing out
    NSMutableDictionary *mergedDictionary = [_rootNode.dict mutableCopy];
    NSAssert([_rootNode.dict objectForKey:DCXIdManifestKey] == [_dictionary objectForKey:DCXIdManifestKey], @"RootNode Id is not equal to the composite Id");
    [mergedDictionary addEntriesFromDictionary:_dictionary];
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:mergedDictionary options:0 error:nil];
    if (local != nil) {
        [_dictionary setObject:local forKey:DCXLocalDataManifestKey];
    }
    return data;
}

- (NSDictionary*)links
{
    return [_rootNode.dict objectForKey:DCXLinksManifestKey];
}

- (void)setLinks:(NSDictionary *)links
{
    if (links != nil) {
        [[_rootNode getMutableDictionary] setObject:[links mutableCopy] forKey:DCXLinksManifestKey];
    } else {
        [[_rootNode getMutableDictionary] removeObjectForKey:DCXLinksManifestKey];
    }
    [self markAsModifiedAndDirty];
}

- (NSString*)etag
{
    NSMutableDictionary *local = [_dictionary objectForKey:DCXLocalDataManifestKey];
    if (local != nil) {
        return [local objectForKey:DCXManifestEtagManifestKey];
    } else {
        return nil;
    }
}

- (void)setEtag:(NSString *)etag
{
    NSMutableDictionary *local = [_dictionary objectForKey:DCXLocalDataManifestKey];
    if (etag != nil && local != nil) {
        [local setObject:etag forKey:DCXManifestEtagManifestKey];
    } else if (etag != nil) {
        [_dictionary setObject:[NSMutableDictionary dictionaryWithObject:etag forKey:DCXManifestEtagManifestKey]
                        forKey:DCXLocalDataManifestKey];
    } else if (local != nil) {
        [local removeObjectForKey:DCXManifestEtagManifestKey];
    }
    // Note that we don't set the composite state to modified here since the etag is local data.
    _isDirty = YES;
}

- (NSString*)compositeHref
{
    NSMutableDictionary *local = [_dictionary objectForKey:DCXLocalDataManifestKey];
    if (local != nil) {
        return [local objectForKey:DCXCompositeHrefManifestKey];
    } else {
        return nil;
    }
}

- (void)setCompositeHref:(NSString *)compositeHref
{
    NSAssert(self.compositeHref == nil || compositeHref == nil,
             @"You must call resetIdentity or resetBinding before you can set the href of an already bound composite");
    
    NSMutableDictionary *local = [_dictionary objectForKey:DCXLocalDataManifestKey];
    if (compositeHref != nil && local != nil) {
        [local setObject:compositeHref forKey:DCXCompositeHrefManifestKey];
    } else if (compositeHref != nil) {
        [_dictionary setObject:[NSMutableDictionary dictionaryWithObject:compositeHref forKey:DCXCompositeHrefManifestKey]
                        forKey:DCXLocalDataManifestKey];
    } else if (local != nil) {
        [local removeObjectForKey:DCXCompositeHrefManifestKey];
    }
    // Note that we don't set the composite state to modified here since the href is local data.
    _isDirty = YES;
}

- (BOOL) isBound
{
    return self.etag != nil;
}

- (NSString *)saveId
{
    NSMutableDictionary *local = [_dictionary objectForKey:DCXLocalDataManifestKey];
    if ( local != nil ) {
        return [local objectForKey:DCXManifestSaveIdManifestKey];
    }
    return nil;
}

- (id) valueForKey:(NSString *)key
{
    id value = nil;
    if([[DCXManifest manifestSpecificProperties] containsObject:key] ){
        value = [_dictionary objectForKey:key];
    }else{
        value = [_rootNode valueForKey:key];
    }
    return value;
}

- (void)setValue:(id)value forKey:(NSString*)key
{
    NSAssert(![key isEqualToString:DCXChildrenManifestKey]
             && ![key isEqualToString:DCXComponentsManifestKey], @"The key %@ is a reserved key for a DCXManifest.", key);

    if([[DCXManifest manifestSpecificProperties] containsObject:key] ){
        [_dictionary setObject:value forKey:key];
    }else{
        [_rootNode setValue:value forKey:key];
    }
    [self markAsModifiedAndDirty];
}

- (void) removeValueForKey:(NSString*)key
{
    if([[DCXManifest manifestSpecificProperties] containsObject:key] ){
        [_dictionary removeObjectForKey:key];
    }else{
        [_rootNode removeValueForKey:key];
    }
    
    [self markAsModifiedAndDirty];
}

#pragma mark Debugging

-(void) recursivelyVerifyIntegrityFromNodeDict:(NSDictionary*)nodeDict
                                   currentPath:(NSString*)currentPath
                                      children:(NSMutableDictionary*)allChildren
                                    components:(NSMutableDictionary*)allComponents
                                         paths:(NSMutableDictionary*)absolutePaths
                         componentsEncountered:(NSMutableDictionary*)componentsEncountered
                              nodesEncountered:(NSMutableDictionary*)nodesEncountered
                                        assert:(BOOL (^)(BOOL condition, NSString *format, ...))assertBlock
{
    // check the children
    NSArray *children = nodeDict[DCXChildrenManifestKey];
    for (NSDictionary *childDict in children) {
        NSString *nodeId = childDict[DCXIdManifestKey];
        if (assertBlock(nodeId != nil, @"Encountered a node without an id.") && nodeId != nil) {
            if (assertBlock(nodesEncountered[nodeId] == nil, @"Encountered node %@ a second time.", nodeId)) {
                nodesEncountered[nodeId] = nodeId;
                DCXNode *childNode = allChildren[nodeId];
                if (assertBlock(childNode != nil, @"Node %@ is not in cache", nodeId)) {
                    NSString *newCurrentPath = currentPath;
                    [allChildren removeObjectForKey:nodeId];
                    assertBlock(!childNode.isRoot, @"Node %@ is root", nodeId);
                    assertBlock([childNode.parentPath isEqualToString:currentPath], @"Node %@ has the wrong parent path %@ (expected: %@)", nodeId, childNode.parentPath, currentPath);
                    if (childNode.path != nil) {
                        newCurrentPath = [currentPath stringByAppendingPathComponent:childNode.path];
                        assertBlock([childNode.absolutePath isEqualToString:newCurrentPath], @"Node %@ has the wrong absolute path %@ (expected: %@)", nodeId, childNode.absolutePath, newCurrentPath);
                        id absolutePathNode = absolutePaths[newCurrentPath.lowercaseString];
                        assertBlock(absolutePathNode == childNode, @"Node %@ does not match the node stored in the the absolutePaths lookup table (%@).", childNode, absolutePathNode);
                        if (assertBlock(absolutePathNode != nil, @"Node %@'s absolute path %@ missing from cache.", nodeId, newCurrentPath)) {
                            [absolutePaths removeObjectForKey:newCurrentPath.lowercaseString];
                        }
                    }
                    // recurse down
                    [self recursivelyVerifyIntegrityFromNodeDict:childDict
                                                     currentPath:newCurrentPath
                                                        children:allChildren
                                                      components:allComponents
                                                           paths:absolutePaths
                                           componentsEncountered:componentsEncountered
                                                nodesEncountered:nodesEncountered
                                                          assert:assertBlock];
                }
            }
        }
    }
    
    // check the components
    NSArray *components = nodeDict[DCXComponentsManifestKey];
    for (NSDictionary *componentDict in components) {
        NSString *componentId = componentDict[DCXIdManifestKey];
        if (assertBlock(componentId != nil, @"Encountered a component without an id.") && componentId != nil) {
            if (assertBlock(componentsEncountered[componentId] == nil, @"Encountered component %@ a second time.", componentId)) {
                componentsEncountered[componentId] = componentId;
                DCXComponent *component = allComponents[componentId];
                if (assertBlock(component != nil, @"Component %@ is not in cache", componentId)) {
                    [allComponents removeObjectForKey:componentId];
                    assertBlock([component.parentPath isEqualToString:currentPath], @"Component %@ has the wrong parent path %@ (expected: %@)", componentId, component.parentPath, currentPath);
                    if (assertBlock(component.path != nil, @"Component %@ doesn't have a path", componentId)) {
                        NSString *absPath = [currentPath stringByAppendingPathComponent:component.path];
                        assertBlock([component.absolutePath isEqualToString:absPath], @"Component %@ has the wrong absolute path %@ (expected: %@)", componentId, component.absolutePath, absPath);
                        if (assertBlock(absolutePaths[component.absolutePath.lowercaseString] != nil, @"Component %@'s absolute path %@ missing from cache.", componentId, component.absolutePath) && component.absolutePath != nil) {
                            [absolutePaths removeObjectForKey:component.absolutePath.lowercaseString];
                        }
                    }
                }
            }
        }
    }
}

-(NSMutableArray*) verifyIntegrityWithLogging:(BOOL)doLog withBranchName:(NSString*)name
{
    __block NSMutableArray *inconsistencies = nil;
    
    NSMutableDictionary *allChildren = [_allChildren mutableCopy];
    NSMutableDictionary *allComponents = [_allComponents mutableCopy];
    NSMutableDictionary *absolutePaths = [_absolutePaths mutableCopy];
    NSMutableDictionary *componentsEncountered = [NSMutableDictionary dictionary];
    NSMutableDictionary *nodesEncountered = [NSMutableDictionary dictionary];
    
    void (^logInconsistency)() = ^(NSString *inconsistency) {
        if (inconsistencies == nil) {
            inconsistencies = [NSMutableArray array];
        }
        [inconsistencies addObject:inconsistency];
    };
    
    // Exclude root node from allChildren and absolute paths
    [allChildren removeObjectForKey:_rootNode.nodeId];
    [absolutePaths removeObjectForKey:@"/"];
    
    if (!_rootNode.isRoot) {
        logInconsistency(@"Root node must vahe isRoot flag set.");
    }
    if (_rootNode.dict[@"path"] != nil) {
        logInconsistency(@"Root node must not have a path.");
    }
    
    [self recursivelyVerifyIntegrityFromNodeDict:_rootNode.dict
                                     currentPath:@"/"
                                        children:allChildren
                                      components:allComponents
                                           paths:absolutePaths
                           componentsEncountered:componentsEncountered
                                nodesEncountered:nodesEncountered
                                          assert:^BOOL(BOOL condition, NSString *format, ...) {
                                              if (!condition) {
                                                  va_list args;
                                                  va_start(args, format);
                                                  NSString *inconsistency = [[NSString alloc] initWithFormat:format arguments:args];
                                                  va_end(args);
                                                  
                                                  logInconsistency(inconsistency);
                                                  
                                                  return NO;
                                              } else {
                                                  return YES;
                                              }
                                          }];
    
    for (NSString *nodeId in [allChildren allKeys]) {
        logInconsistency([NSString stringWithFormat:@"Node %@ is in cache but not in DOM.", nodeId]);
    }
    for (NSString *componentId in [allComponents allKeys]) {
        logInconsistency([NSString stringWithFormat:@"Component %@ is in cache but not in DOM.", componentId]);
    }
    for (NSString *path in [absolutePaths allKeys]) {
        logInconsistency([NSString stringWithFormat:@"Path %@ is in cache but not in DOM.", path]);
    }
    
    // verify local storage mapping
    
    
    if (doLog && inconsistencies != nil) {
        NSString *title = nil;
        if (name) {
            title = [NSString stringWithFormat:@"Branch %@ of composite %@ shows %ld inconsistencies:", name, self.compositeId, (unsigned long)inconsistencies.count];
        } else {
            title = [NSString stringWithFormat:@"Manifest %@ shows %ld inconsistencies:", self.compositeId, (unsigned long)inconsistencies.count];
        }
        [inconsistencies insertObject:title atIndex:0];
        NSString *output = [inconsistencies componentsJoinedByString:@"\n   "];
        NSLog(@"**************************************************\n%@\n**************************************************", output);
    }
    
    return inconsistencies;
}

#pragma mark Components (public methods)

-(DCXComponent*) componentWithAbsolutePath:(NSString *)absPath
{
    id item = _absolutePaths[absPath.lowercaseString];
    
    return [item isKindOfClass:[DCXComponent class]] ? item : nil;
}

-(DCXNode*) findParentOfComponent:(DCXComponent *)component
{
    NSUInteger index;
    NSMutableDictionary *nodeDict = [self findNodeOfComponentById:component.componentId foundAtIndex:&index];
    
    id result = nil;
    
    if (nodeDict != nil) {
        if (nodeDict == _rootNode.dict) {
            result = _rootNode;
        } else {
            result = _allChildren[nodeDict[DCXIdManifestKey]];
        }
    }
    
    return result;
}

// array of components at the root level
- (NSArray*) components
{
    return [self createComponentListFromArray:[_rootNode.dict objectForKey:DCXComponentsManifestKey]
                               withParentPath:[self parentPathForDescendantsOf:nil]];
}

// array of components for a particular node
-(NSArray*) componentsOfChild:(DCXNode *)node
{
    NSAssert(node != nil, @"Node must not be nil");
    return [self createComponentListFromArray:[[self findNodeById:node.nodeId] objectForKey:DCXComponentsManifestKey]
                               withParentPath:[self parentPathForDescendantsOf:node]];
}

- (DCXComponent*) updateComponent:(DCXComponent*)component withError:(NSError**)errorPtr
{
    NSAssert(component, @"Component must not be nil");
    NSAssert(component.componentId != nil, @"Component must have an id");
    
    // find the node the component belongs to
    NSUInteger index;
    NSMutableDictionary *nodeDict = [self findNodeOfComponentById:component.componentId foundAtIndex:&index];
    NSAssert(nodeDict != nil, @"Component with id %@ not found in manifest.", component.componentId);
    
    return [self updateComponent:component at:nodeDict atIndex:index withError:errorPtr];
}

- (DCXComponent*) addComponent:(DCXComponent *)component fromManifest:(DCXManifest*)sourceManifest
                            newPath:(NSString*)newPath withError:(NSError**)errorPtr
{
    DCXComponent *newComponent = [self addComponent:component to:[_rootNode getMutableDictionary]  newPath:newPath replaceExisting:NO withError:errorPtr];
    return newComponent;
}

-(DCXComponent*) addComponent:(DCXComponent *)component fromManifest:(DCXManifest*)sourceManifest
                           toChild:(DCXNode *)node newPath:(NSString*)newPath withError:(NSError**)errorPtr
{
    NSAssert(node != nil, @"Node must not be nil");
    NSMutableDictionary *nodeDict = [self findNodeById:node.nodeId];
    NSAssert(nodeDict != nil, @"Node with id %@ not found in manifest.", node.nodeId);

    DCXComponent *newComponent = [self addComponent:component to:nodeDict newPath:newPath replaceExisting:NO withError:errorPtr];
    return newComponent;
}

-(DCXComponent*) replaceComponent:(DCXComponent *)component fromManifest:(DCXManifest*)sourceManifest withError:(NSError**)errorPtr
{
    DCXComponent *newComponent = [self addComponent:component to:nil newPath:nil
                                         replaceExisting:YES withError:errorPtr];
    
    return newComponent;
}

-(DCXComponent*) moveComponent:(DCXComponent*)component toChild:(DCXNode *)node
                          withError:(NSError**)errorPtr
{
    NSAssert(component != nil, @"Component must not be nil");
    
    // Find the current parent node the component belongs to
    NSUInteger index;
    NSMutableDictionary *currentParentNodeDict = [self findNodeOfComponentById:component.componentId foundAtIndex:&index];
    NSAssert(currentParentNodeDict != nil, @"Component with id %@ not found in manifest.", component.componentId);
    NSMutableArray *components = [currentParentNodeDict objectForKey:DCXComponentsManifestKey];
    
    // Find the new parent node
    NSMutableDictionary *newParentNodeDict = node == nil ? [_rootNode getMutableDictionary] : [self findNodeById:node.nodeId];
    NSAssert(newParentNodeDict != nil, @"Node with id %@ not found in manifest.", node.nodeId);
    
    // We need to create a new component object because it will likely have a different parent path
    NSDictionary *componentDict = [components objectAtIndex:index];
    DCXComponent *updatedComponent = [DCXComponent componentFromDictionary:componentDict
                                                                         andManifest:self
                                                                      withParentPath:[self parentPathForDescendantsOf:node]];
    
    NSString *newAbsPath = updatedComponent.absolutePath.lowercaseString;
    NSString *oldAbsPath = component.absolutePath.lowercaseString;
    if (![newAbsPath isEqualToString:oldAbsPath]) {
        if (_absolutePaths[newAbsPath] != nil) {
            if (errorPtr != NULL) {
                *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicatePath domain:DCXErrorDomain
                                                          details:[NSString stringWithFormat:@"Duplicate absolute path: %@", newAbsPath]];
            }
            return nil;
        }
        [_absolutePaths removeObjectForKey:oldAbsPath];
    }
    _absolutePaths[newAbsPath] = updatedComponent;
    _allComponents[updatedComponent.componentId] = updatedComponent;
    
    // Remove from old parent
    [components removeObjectAtIndex:index];
    
    // Add to new parent
    components = [newParentNodeDict objectForKey:DCXComponentsManifestKey];
    if (components == nil) {
        [newParentNodeDict setObject:[NSMutableArray arrayWithObject:componentDict] forKey:DCXComponentsManifestKey];
    } else {
        [components addObject:componentDict];
    }
    
    [self markAsModifiedAndDirty];
    
    return updatedComponent;
}

-(DCXComponent*) setComponent:(DCXComponent *)component modified:(BOOL)modified
{
    NSAssert(component, @"Component must not be nil");
    DCXMutableComponent *mutableComponent = [component mutableCopy];
    mutableComponent.state = modified ? DCXAssetStateModified : DCXAssetStateUnmodified;
    return [self updateComponent:mutableComponent withError:nil];
}

-(BOOL) componentIsBound:(DCXComponent *)component
{
    NSAssert(component, @"Component must not be nil");
    
    return self.isBound && component.etag != nil;
}

- (DCXComponent*) removeComponent:(DCXComponent *)component
{
    NSAssert(component, @"Component must not be nil");
    // find the node the component belongs to
    NSUInteger index;
    NSMutableDictionary *nodeDict = [self findNodeOfComponentById:component.componentId foundAtIndex:&index];
    NSAssert(nodeDict != nil, @"Component with id %@ not found in manifest.", component.componentId);
    
    return [self removeComponent:component at:nodeDict atIndex:index];
}

- (void) removeAllComponents
{
    [self recursiveRemoveAllComponentsAt:[_rootNode getMutableDictionary]];
}

- (void) removeAllComponentsFromRoot
{
    [self removeAllComponentsAt:[_rootNode getMutableDictionary]];
}

- (void) removeAllComponentsFromChild:(DCXNode *)node
{
    NSAssert(node != nil, @"Node must not be nil");
    NSMutableDictionary *nodeDict = [self findNodeById:node.nodeId];
    NSAssert(nodeDict != nil, @"Node with id %@ not found", node.nodeId);
    [self removeAllComponentsAt:nodeDict];
}

#pragma mark Components (private methods)

-(NSArray*) createComponentListFromArray:(NSArray*)array withParentPath:(NSString*)parentPath
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[array count]];
    if (array != nil) {
        for (id component in array) {
            [result addObject:[DCXComponent componentFromDictionary:component andManifest:self withParentPath:parentPath]];
        }
    }
    
    return result;
}

- (DCXComponent*) updateComponent:(DCXComponent*)component at:(NSMutableDictionary*)nodeDict
                               atIndex:(NSUInteger)index withError:(NSError**)errorPtr
{
    NSString *componentId = component.componentId;
    NSAssert(componentId != nil, @"Component must have an id");
    
    DCXNode *parent = _allChildren[nodeDict[DCXIdManifestKey]];
    
    NSMutableDictionary *updatedComponentDict = [component.dict mutableCopy];
    DCXComponent *updatedComponent = [DCXComponent componentFromDictionary:updatedComponentDict andManifest:self
                                                                      withParentPath:[self parentPathForDescendantsOf:parent]];
    
    // Verify path
    DCXComponent *existingComponent = _allComponents[component.componentId];
    if (![existingComponent.path isEqualToString:updatedComponent.path]) {
        if (![DCXUtils isValidPath:updatedComponent.path]) {
            if (errorPtr != NULL) {
                *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidPath domain:DCXErrorDomain
                                                          details:[NSString stringWithFormat:@"Invalid path: %@", updatedComponent.path]];
            }
            return nil;
        }
        if (_absolutePaths[updatedComponent.absolutePath.lowercaseString] != nil) {
            if (errorPtr != NULL) {
                *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicatePath domain:DCXErrorDomain
                                                          details:[NSString stringWithFormat:@"Duplicate path: %@", updatedComponent.absolutePath]];
            }
            return nil;
        }
        [_absolutePaths removeObjectForKey:existingComponent.absolutePath.lowercaseString];
    }
    
    NSMutableArray *components = [nodeDict objectForKey:DCXComponentsManifestKey];
    [components replaceObjectAtIndex:index withObject:updatedComponentDict];
    
    component = _allComponents[componentId];
    [_absolutePaths removeObjectForKey:component.absolutePath.lowercaseString];
    
    [_allComponents setObject:updatedComponent forKey:componentId];
    [_absolutePaths setObject:updatedComponent forKey:updatedComponent.absolutePath.lowercaseString];
    
    [self markAsModifiedAndDirty];
    
    return updatedComponent;
}

-(DCXComponent*) addComponent:(DCXComponent *)component to:(NSMutableDictionary*)nodeDict
                           newPath:(NSString*)newPath replaceExisting:(BOOL)replace withError:(NSError**)errorPtr
{
    NSAssert(component, @"Component must not be nil");
    NSString *componentId = component.componentId;
    NSMutableDictionary *newComponentDict = [component.dict mutableCopy];
    if (newPath != nil) {
        newComponentDict[DCXPathManifestKey] = newPath;
        componentId = newComponentDict[DCXIdManifestKey] = [[NSUUID UUID] UUIDString];
        // Need to reset the state and some additional properties. Notice that we do
        // not reset length since it does not change.
        [newComponentDict removeObjectForKey:DCXEtagManifestKey];
        [newComponentDict removeObjectForKey:DCXVersionManifestKey];
        newComponentDict[DCXStateManifestKey] = DCXAssetStateModified;
    }
    NSAssert(componentId != nil, @"Component must have an id");

    NSString *newComponentPath = newComponentDict[DCXPathManifestKey];
    if ( ![DCXUtils isValidPath:newComponentPath] ) {
        if ( errorPtr != NULL ) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidPath domain:DCXErrorDomain
                                                      details:[NSString stringWithFormat:@"Invalid path: %@", newComponentPath]];
        }
        return nil;
    }
    
    DCXComponent *existingComponent = _allComponents[componentId];
    if (!replace && existingComponent != nil) {
        if (errorPtr != NULL) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicateId domain:DCXErrorDomain
                                                      details:[NSString stringWithFormat:@"Duplicate id: %@", componentId]];
        }
        return nil;
    }
                         
    NSUInteger index;
    DCXNode *parent;
    if (replace) {
        nodeDict = [self findNodeOfComponentById:componentId foundAtIndex:&index];
        NSAssert(nodeDict != nil, @"Couldn't find parent node of component.");
    } else {
        index = nodeDict.count;
    }
    parent = _allChildren[nodeDict[DCXIdManifestKey]];
    
    DCXComponent *newComponent = [DCXComponent componentFromDictionary:newComponentDict andManifest:self
                                                                  withParentPath:[self parentPathForDescendantsOf:parent]];
    
    NSString *absolutePath = newComponent.absolutePath.lowercaseString;
    NSString *existingComponentAbsolutePath = replace ? existingComponent.absolutePath.lowercaseString : nil;
    
    if (!replace || ![absolutePath isEqualToString:existingComponentAbsolutePath]) {
        if (_absolutePaths[absolutePath] != nil) {
            if (errorPtr != NULL) {
                *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicatePath domain:DCXErrorDomain
                                                          details:[NSString stringWithFormat:@"Duplicate absolute path: %@", absolutePath]];
            }
            return nil;
        }
    }
    
    NSMutableArray *components = [nodeDict objectForKey:DCXComponentsManifestKey];
    if (components == nil) {
        [nodeDict setObject:[NSMutableArray arrayWithObject:newComponentDict] forKey:DCXComponentsManifestKey];
    } else if (replace) {
        [components replaceObjectAtIndex:index withObject:newComponentDict];
    } else {
        [components addObject:newComponentDict];
    }
    
    [_allComponents setObject:newComponent forKey:componentId];
    [_absolutePaths setObject:newComponent forKey:absolutePath];
    if (existingComponentAbsolutePath != nil && ![absolutePath isEqualToString:existingComponentAbsolutePath]) {
        [_absolutePaths removeObjectForKey:existingComponentAbsolutePath];
    }
    
    [self markAsModifiedAndDirty];
    
    return newComponent;
}

- (DCXComponent*) removeComponent:(DCXComponent*)component at:(NSMutableDictionary*)nodeDict atIndex:(NSUInteger)index
{
    NSString *componentId = component.componentId;
    NSAssert(componentId != nil, @"Component must have an id");
    
    NSMutableArray *components = [nodeDict objectForKey:DCXComponentsManifestKey];
    [components removeObjectAtIndex:index];
    if ([components count] == 0) {
        [nodeDict removeObjectForKey:DCXComponentsManifestKey];
    }
    [_allComponents removeObjectForKey:componentId];
    [_absolutePaths removeObjectForKey:component.absolutePath.lowercaseString];
    
    [self markAsModifiedAndDirty];
    
    return component;
}

- (void) removeAllComponentsAt:(NSMutableDictionary*)nodeDict
{
    NSArray *components = [nodeDict objectForKey:DCXComponentsManifestKey];
    
    if (components != nil) {
        for (NSDictionary *component in components) {
            NSString *componentId = [component objectForKey:DCXIdManifestKey];
            DCXComponent *comp = _allComponents[componentId];
            [_absolutePaths removeObjectForKey:comp.absolutePath.lowercaseString];
            [_allComponents removeObjectForKey:componentId];
        }
        
        [nodeDict removeObjectForKey:DCXComponentsManifestKey];
        
        [self markAsModifiedAndDirty];
    }
}

- (void) recursiveRemoveAllComponentsAt:(NSMutableDictionary*)nodeDict
{
    [self removeAllComponentsAt:nodeDict];
    
    NSArray *children = [nodeDict objectForKey:DCXChildrenManifestKey];
    
    if (children != nil) {
        for (NSMutableDictionary *child in children) {
            [self recursiveRemoveAllComponentsAt:child];
        }
    }
}

- (NSUInteger) indexOfComponentWithId:(NSString*)componentId in:(NSArray*)listOfComponents
{
    return [listOfComponents indexOfObjectPassingTest:^BOOL(id component, NSUInteger idx, BOOL *stop) {
        NSString *compId = [component valueForKey:DCXIdManifestKey];
        if (compId != nil && [compId isEqualToString:componentId]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
}

- (void) componentsDescendedFromParent:(DCXNode *)node intoArray:(NSMutableArray*)resultArray
{
    [self recursiveComponentsDescendedFrom:node.dict intoArray:resultArray];
    
}
- (void) recursiveComponentsDescendedFrom:(NSDictionary *)nodeDict intoArray:(NSMutableArray*)resultArray
{
    NSAssert(resultArray != nil, @"resultArray must not be nil.");
    NSArray *componentDicts = [nodeDict objectForKey:DCXComponentsManifestKey];
    for (NSMutableDictionary *componentData in componentDicts) {
        NSString *componentId = [componentData objectForKey:DCXIdManifestKey];
        DCXComponent *component = [_allComponents objectForKey:componentId];
        NSAssert(component != nil, @"A corresponding component object should always exist in the manifest's hash table.");
        [resultArray addObject:component];
    }

    NSArray *children = [nodeDict objectForKey:DCXChildrenManifestKey];
    for (NSMutableDictionary *childDict in children) {
        [self recursiveComponentsDescendedFrom:childDict intoArray:resultArray];
    }
}


#pragma mark Children (public methods)
-(DCXNode*) childWithAbsolutePath:(NSString *)absPath
{
    id item = _absolutePaths[absPath.lowercaseString];
    
    return [item isKindOfClass:[DCXNode class]] ? item : nil;
}

-(DCXNode *) findParentOfChild:(DCXNode *)node foundIndex:(NSUInteger*)index
{
    if (node.isRoot){
        return nil;
    }
    
    NSMutableDictionary *nodeDict = [self findParentOfNodeById:node.nodeId foundAtIndex:index];
    id result = nil;
   
    if (nodeDict != nil) {
        if (nodeDict == _rootNode.dict) {
            // Node was found at top level, so return the root node.
            result = _rootNode;
        } else {
            result = _allChildren[nodeDict[DCXIdManifestKey]];
        }
    }
    
    return result;
}

-(NSArray*) children
{
    return [self createChildListFromArray:[_rootNode.dict objectForKey:DCXChildrenManifestKey] withParentPath:@"/"];
}

-(NSArray*) childrenOf:(DCXNode*)node
{
    NSAssert(node != nil, @"Node must not be nil");
    return [self createChildListFromArray:[[self findNodeById:node.nodeId] objectForKey:DCXChildrenManifestKey]
                           withParentPath:[self parentPathForDescendantsOf:node]];
}

-(void) copyChildrenAndComponentsTo:(NSMutableDictionary*)modifiedNodeDict from:(NSDictionary*)existingNodeDict
{
    id children = [existingNodeDict objectForKey:DCXChildrenManifestKey];
    if (children != nil) {
        [modifiedNodeDict setObject:children forKey:DCXChildrenManifestKey];
    } else {
        [modifiedNodeDict removeObjectForKey:DCXChildrenManifestKey];
    }
    id components = [existingNodeDict objectForKey:DCXComponentsManifestKey];
    if (components != nil) {
        [modifiedNodeDict setObject:components forKey:DCXComponentsManifestKey];
    } else {
        [modifiedNodeDict removeObjectForKey:DCXComponentsManifestKey];
    }
}

-(DCXNode*) updateChild:(DCXNode*)node withError:(NSError**)errorPtr
{
    NSAssert(node != nil, @"Node must not be nil");
    NSString *nodeId = node.nodeId;
    NSAssert(nodeId != nil, @"Node must have an id");
    DCXNode *modifiedNode = nil;

    // Special handling for root node
    if(nodeId == self.rootNode.nodeId)
    {
        NSAssert(node.path == self.rootNode.path, @"Cannot update the path of the root node");
        NSMutableDictionary *modifiedNodeDict = [node.dict mutableCopy];
        [self copyChildrenAndComponentsTo:modifiedNodeDict from:self.rootNode.dict];
        DCXMutableNode *rootNode = [[DCXMutableNode alloc] initWithDictionary:modifiedNodeDict withParentPath:@""];
        rootNode.isRoot = YES;
        modifiedNode = _rootNode = rootNode;
        [_allChildren setObject:_rootNode forKey:_rootNode.nodeId];
    }
    else
    {
        // Find the node's parent in the dictionary and get the existing data.
        NSUInteger index;
        NSMutableDictionary *parentDict = [self findParentOfNodeById:nodeId foundAtIndex:&index];
        NSAssert(parentDict != nil, @"Child node with id %@ could not be found in manifest.", nodeId);
        NSMutableArray *parentsChildren = [parentDict objectForKey:DCXChildrenManifestKey];
        NSMutableDictionary *existingNodeDict = [parentsChildren objectAtIndex:index];
        DCXNode *parentNode = _allChildren[parentDict[DCXIdManifestKey]];
        
        // Make a mutable copy of the modified node's dictionary and copy over the
        // children and components from the existing node
        NSMutableDictionary *modifiedNodeDict = [node.dict mutableCopy];
        [self copyChildrenAndComponentsTo:modifiedNodeDict from:existingNodeDict];
        
        modifiedNode = [DCXNode nodeFromDictionary:modifiedNodeDict andManifest:self
                                                                              withParentPath:[self parentPathForDescendantsOf:parentNode]];
        
        NSMutableDictionary *allChildren = nil;
        NSMutableDictionary *allComponents= nil;
        NSMutableDictionary *absolutePaths = nil;
        
        // Check for a change to the path property
        NSString *newPath = node.path;
        if (newPath != nil && ![DCXUtils isValidPath:newPath]) {
            if (errorPtr != NULL) {
                *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidPath domain:DCXErrorDomain
                                                          details:[NSString stringWithFormat:@"Invalid path: %@", newPath]];
            }
            return nil;
        }
        NSString *existingPath = existingNodeDict[DCXPathManifestKey];
        if ((newPath != nil || existingPath != nil) && ![newPath isEqualToString:existingPath]) {
            // The path property has changed. We need to ensure that new new path is valid and unique
            // and we need to update the path cache for all children and components
            // The absolute path of the new node would conflict with an existing path
            
            DCXNode *existingNode = _allChildren[nodeId];
            
            allComponents = [_allComponents mutableCopy];
            allChildren = [_allChildren mutableCopy];
            absolutePaths = [_absolutePaths mutableCopy];
            
            if (![self recursivelyRemoveNode:existingNode fromChildrenLU:allChildren fromComponentLU:allComponents
                                  fromPathLU:absolutePaths removedComponents:nil withError:errorPtr]) {
                return nil;
            }
            if (![self recursivelyAddNode:modifiedNode withDict:modifiedNodeDict assignNewIds:NO
                             toChildrenLU:allChildren toComponentLU:allComponents
                                 toPathLU:absolutePaths addedComponents:nil addedComponentOrgIds:nil
                                withError:errorPtr]) {
                return nil;
            }
        }
        
        // finally replace the node in its parent's children array
        [parentsChildren replaceObjectAtIndex:index withObject:modifiedNodeDict];
        if (allChildren != nil) {
            _allChildren = allChildren;
            _allComponents = allComponents;
            _absolutePaths = absolutePaths;
        } else {
            [_allChildren setObject:modifiedNode forKey:nodeId];
            if (modifiedNode.path != nil) {
                NSAssert(existingPath != nil, @"Previous node should have an existing path if we are in this branch.");
                NSString *absPath = modifiedNode.absolutePath.lowercaseString;
                if (absPath) {
                    [_absolutePaths setObject:modifiedNode forKey:absPath];
                }
            }
        }
    }
    [self markAsModifiedAndDirty];
    
    return modifiedNode;
}

-(DCXNode*) addChild:(DCXNode*)node withError:(NSError**)errorPtr
{
    NSAssert(node != nil, @"Node must not be nil");
    return [self insertChild:node in:[_rootNode getMutableDictionary]  at:[[_rootNode.dict objectForKey:DCXChildrenManifestKey] count]
              withParentPath:[self parentPathForDescendantsOf:nil] withError:errorPtr];
}

-(DCXNode*) addChild:(DCXNode*)node toParent:(DCXNode*)parentNode
                        withError:(NSError**)errorPtr
{
    NSAssert(node != nil, @"Node must not be nil");
    
    NSMutableDictionary *parentDict = [self findNodeById:parentNode.nodeId];
    NSAssert(parentDict != nil, @"Parent node with id %@ could not be found in manifest.", parentNode.nodeId);
    
    return [self insertChild:node in:parentDict at:[[parentDict objectForKey:DCXChildrenManifestKey] count]
              withParentPath:[self parentPathForDescendantsOf:parentNode] withError:errorPtr];
}

-(DCXNode*) insertChild:(DCXNode *)node atIndex:(NSUInteger)index withError:(NSError**)errorPtr
{
    NSAssert(node != nil, @"Node must not be nil");
    return [self insertChild:node in:[_rootNode getMutableDictionary] at:index
              withParentPath:[self parentPathForDescendantsOf:nil] withError:errorPtr];
}

-(DCXNode*) insertChild:(DCXNode *)node parent:(DCXNode *)parentNode
                             atIndex:(NSUInteger)index withError:(NSError**)errorPtr;
{
    NSAssert(node != nil, @"Node must not be nil");
    
    NSMutableDictionary *parentDict = [self findNodeById:parentNode.nodeId];
    NSAssert(parentDict != nil, @"Parent node with id %@ could not be found in manifest.", parentNode.nodeId);
    
    return [self insertChild:node in:parentDict at:index
              withParentPath:[self parentPathForDescendantsOf:parentNode] withError:errorPtr];
}

-(DCXNode*) insertChild:(DCXNode *)node
                        fromManifest:(DCXManifest *)manifest
                              parent:(DCXNode *)parentNode
                             atIndex:(NSUInteger)index
                     replaceExisting:(BOOL)replaceExisting
                             newPath:(NSString *)newPath
                         forceNewIds:(BOOL)forceNewIds
                     addedComponents:(NSMutableArray *)addedComponents
                addedComponentOrgIds:(NSMutableArray *)addedComponentOrgIds
                   removedComponents:(NSMutableArray *)removedComponents
                           withError:(NSError**)errorPtr
{
    // Check preconditions
    NSAssert(node != nil, @"Node must not be nil");
    NSAssert(manifest != nil, @"Manifest must not be nil");
    NSAssert(newPath == nil || [DCXUtils isValidPath:newPath], @"Invalid path: %@", newPath);
    
    // First make a copy of the node dictionary
    NSMutableDictionary *nodeDict = [manifest findNodeById:node.nodeId];
    NSAssert(node != nil, @"Couldn't find node.");
    nodeDict = [DCXCopyUtils deepMutableCopyOfDictionary:nodeDict];
    if (newPath != nil) {
        nodeDict[DCXPathManifestKey] = newPath;
        nodeDict[DCXIdManifestKey] = [[NSUUID UUID] UUIDString];
    }
    
    // Verify pre-existing node
    NSString *nodeId = nodeDict[DCXIdManifestKey];
    DCXNode *existingNode = _allChildren[nodeId];
    if (replaceExisting) {
        NSAssert(existingNode != nil, @"Couldn't find existing node.");
    } else if (existingNode != nil) {
        if (errorPtr != NULL) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicateId
                                                       domain:DCXErrorDomain
                                                      details:[NSString stringWithFormat:@"Child node with id %@ already exists.",
                                                               nodeId]];
        }
        // We haven't made any changes at this point so we just return.
        return nil;
    }
    
    // Determine the new parent
    NSMutableDictionary *parentDict;
    if (!replaceExisting) {
        parentDict = parentNode != nil ? [self findNodeById:parentNode.nodeId] : [_rootNode getMutableDictionary];
        NSAssert(parentDict != nil, @"Can't find new parent");
    } else {
        parentDict = [self findParentOfNodeById:nodeId foundAtIndex:&index];
        NSAssert(parentDict != nil, @"Can't find existing parent");
        parentNode = _allChildren[parentDict[DCXIdManifestKey]];
    }
    NSString *parentPath = [self parentPathForDescendantsOf:parentNode];
    
    // Construct the new node
    DCXNode *newNode = [DCXNode nodeFromDictionary:nodeDict andManifest:self withParentPath:parentPath];
    
    // Verify new path
    if (newNode.path != nil) {
        DCXNode *itemWithSamePath = _absolutePaths[newNode.absolutePath.lowercaseString];
        if (itemWithSamePath != nil && ![itemWithSamePath.nodeId isEqualToString:existingNode.nodeId]) {
            // The absolute path of the new node would conflict with an existing path
            if (errorPtr != NULL) {
                *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicatePath
                                                           domain:DCXErrorDomain
                                                          details:[NSString stringWithFormat:@"Child node with absolute path %@ already exists.",
                                                                   newNode.absolutePath.lowercaseString]];
            }
            // We haven't made any changes at this point so we just return.
            return nil;
        }
    }
    
    // Now that we have passed all the checks above we can start preparing the necessary changes.
    // We do so by creating copies of our lookup tables so that we can
    // back out cleanly if we run into a problem while traversing the new node's hiearchy.
    
    NSMutableDictionary *allChildren = [_allChildren mutableCopy];
    NSMutableDictionary *allComponents = [_allComponents mutableCopy];
    NSMutableDictionary *absolutePaths = [_absolutePaths mutableCopy];

    if (existingNode != nil) {
        // Remove all traces of the existing node from our temorary lookups.
        if (![self recursivelyRemoveNode:existingNode fromChildrenLU:allChildren fromComponentLU:allComponents
                             fromPathLU:absolutePaths removedComponents:removedComponents
                              withError:errorPtr]) {
            return nil;
        }
    }
    
    // Add new node and descendants to the temporary lookups. Fails if it encounters a duplicate
    // id or bsolute path.
    if (![self recursivelyAddNode:newNode withDict:nodeDict assignNewIds:(newPath != nil || forceNewIds)
                     toChildrenLU:allChildren toComponentLU:allComponents toPathLU:absolutePaths
                  addedComponents:addedComponents
             addedComponentOrgIds:addedComponentOrgIds
                        withError:errorPtr]) {
        return nil;
    }
    
    // Now we can make the actualy changes:
    
    // Insert the node dictionary
    if (replaceExisting ) {
        parentDict[DCXChildrenManifestKey][index] = nodeDict;
    } else {
        NSMutableArray *children = [parentDict objectForKey:DCXChildrenManifestKey];
        if (children == nil) {
            [parentDict setObject:[NSMutableArray arrayWithObject:nodeDict] forKey:DCXChildrenManifestKey];
        } else {
            if (index > children.count - 1) {
                index = children.count;
            }
            [children insertObject:nodeDict atIndex:index];
        }
    }
    
    // Update lookup tables
    _allChildren = allChildren;
    _allComponents = allComponents;
    _absolutePaths = absolutePaths;
    
    [self markAsModifiedAndDirty];

    // return the newly added node
    return [_allChildren objectForKey:[nodeDict objectForKey:DCXIdManifestKey]];
}

-(DCXNode*) moveChild:(DCXNode *)node toParent:(DCXNode *)parentNode
                           toIndex:(NSUInteger)index withError:(NSError**)errorPtr
{
    NSAssert(node != nil, @"Node must not be nil");
    NSAssert(!node.isRoot, @"Root Node cannot be moved");
    NSMutableDictionary *parentDict = [self findNodeById:parentNode.nodeId];
    NSAssert(parentDict != nil, @"Parent node with id %@ could not be found.", parentNode.nodeId);
    
    return [self moveChild:node to:parentDict at:index withError:errorPtr];
}

-(DCXNode*) moveChild:(DCXNode *)node toIndex:(NSUInteger)index
                         withError:(NSError**)errorPtr
{
    NSAssert(node != nil, @"Node must not be nil");
    NSAssert(!node.isRoot, @"Root Node cannot be moved");
    return [self moveChild:node to:[_rootNode getMutableDictionary] at:index withError:errorPtr];
}

-(DCXNode*) removeChild:(DCXNode*)node removedComponents:(NSMutableArray *)removedComponents
{
    NSAssert(!node.isRoot, @"Root Node cannot be removed");
    NSAssert(node != nil, @"Node must not be nil");
    NSString *nodeId = node.nodeId;
    NSAssert(nodeId != nil, @"Node must have an id");
    
    // Find the node's parent in the dictionary and get the existing data.
    NSUInteger index;
    NSMutableDictionary *parent = [self findParentOfNodeById:nodeId foundAtIndex:&index];
    NSAssert(parent != nil, @"Child node with id %@ could not be found.", nodeId);
    
    NSMutableArray *children = [parent objectForKey:DCXChildrenManifestKey];
    
    // Update the hashes for children and components
    [self recursivelyRemoveNode:node fromChildrenLU:_allChildren fromComponentLU:_allComponents
                     fromPathLU:_absolutePaths removedComponents:removedComponents withError:nil];
    
    // Remove the node.
    [children removeObjectAtIndex:index];
    if ([children count] == 0) {
        [parent removeObjectForKey:DCXChildrenManifestKey];
    }
    
    [self markAsModifiedAndDirty];
    
    return node;
}

- (void) removeAllChildrenWithRemovedComponents:(NSMutableArray *)removedComponents
{
    [self removeAllChildrenAt:[_rootNode getMutableDictionary] removedComponents:removedComponents];
}


- (void) removeAllChildrenFromParent:(DCXNode *)node removedComponents:(NSMutableArray *)removedComponents
{
    NSMutableDictionary *nodeDict = [self findNodeById:node.nodeId];
    [self removeAllChildrenAt:nodeDict removedComponents:removedComponents];
}

-(NSUInteger) absoluteIndexOf:(DCXNode *)node
{
    if(node.isRoot){
        return NSNotFound;
    }
    NSUInteger runningIndex = 0;
    return [self recursiveGetAbsoluteIndexOfNodeId:node.nodeId startAt:[_rootNode getMutableDictionary] withRunningIndex:&runningIndex];
}

#pragma mark Nodes/children (private methods)

// Recursively removes the node and all of its children and components
// from the provided lookup tables. Gets used whenever we want to make
// extensive changes to the DOM while maintaining the option of backing
// out cleanly if we run into an error.
-(BOOL) recursivelyRemoveNode:(DCXNode*)nodeToRemove
               fromChildrenLU:(NSMutableDictionary*)allChildren
              fromComponentLU:(NSMutableDictionary*)allComponents
                   fromPathLU:(NSMutableDictionary*)absolutePaths
            removedComponents:(NSMutableArray*)removedComponents
                    withError:(NSError**)errorPtr
{
    NSString *nodeId = nodeToRemove.nodeId;
    NSDictionary *nodeDict = [self findNodeById:nodeId];
    
    [allChildren removeObjectForKey:nodeId];
    
    if (nodeToRemove.path != nil) {
        [absolutePaths removeObjectForKey:nodeToRemove.absolutePath.lowercaseString];
    }
    
    NSDictionary *children = nodeDict[DCXChildrenManifestKey];
    for (NSDictionary *childNodeDict in children) {
        DCXNode *childNode = allChildren[childNodeDict[DCXIdManifestKey]];
        if (![self recursivelyRemoveNode:childNode fromChildrenLU:allChildren fromComponentLU:allComponents
                              fromPathLU:absolutePaths removedComponents:removedComponents withError:errorPtr]) {
            return NO;
        }
    }
    
    NSDictionary *components = nodeDict[DCXComponentsManifestKey];
    for (NSDictionary *componentDict in components) {
        DCXComponent *component = allComponents[componentDict[DCXIdManifestKey]];
        [allComponents removeObjectForKey:component.componentId];
        [absolutePaths removeObjectForKey:component.absolutePath.lowercaseString];
        if (removedComponents != nil) {
            [removedComponents addObject:component];
        }
    }
    
    return YES;
};

// Recursively adds the node and all of its children and components to the provided temporary
// lookup tables. Gets used whenever we want to make extensive changes to the DOM while
// maintaining the option of backing out cleanly if we run into an error.
-(BOOL) recursivelyAddNode:(DCXNode*)nodeToAdd
                  withDict:(NSDictionary*)nodeDict
              assignNewIds:(BOOL)assignNewIds
              toChildrenLU:(NSMutableDictionary*)allChildren
             toComponentLU:(NSMutableDictionary*)allComponents
                  toPathLU:(NSMutableDictionary*)absolutePaths
           addedComponents:(NSMutableArray*)addedComponents
      addedComponentOrgIds:(NSMutableArray *)addedComponentOrgIds
                 withError:(NSError**)errorPtr
{
    NSString *nodeId = nodeDict[DCXIdManifestKey];
    
    if (allChildren[nodeId] != nil) {
        if (errorPtr != NULL) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicateId
                                                       domain:DCXErrorDomain
                                                      details:[NSString stringWithFormat:@"Child node with id %@ already exists.",
                                                               nodeId]];
        }
        return NO;
    }
    allChildren[nodeId] = nodeToAdd;
    
    NSString *absolutePath;
    if (nodeToAdd.path != nil) {
        absolutePath = nodeToAdd.absolutePath.lowercaseString;
        if (absolutePaths[absolutePath] != nil) {
            if (errorPtr != NULL) {
                *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicatePath
                                                           domain:DCXErrorDomain
                                                          details:[NSString stringWithFormat:@"Child node with absolute path %@ already exists.",
                                                                   absolutePath]];
            }
            return NO;
        }
        absolutePaths[absolutePath] = nodeToAdd;
    }
    
    NSString *parentPath = [self parentPathForDescendantsOf:nodeToAdd];
    
    NSDictionary *children = nodeDict[DCXChildrenManifestKey];
    for (NSMutableDictionary *childNodeDict in children) {
        if (assignNewIds) {
            childNodeDict[DCXIdManifestKey] = [[NSUUID UUID] UUIDString];
        }
        DCXNode *childNode = [DCXNode nodeFromDictionary:childNodeDict
                                                                       andManifest:self
                                                                    withParentPath:parentPath];
        
        if (![self recursivelyAddNode:childNode withDict:childNodeDict assignNewIds:assignNewIds
                         toChildrenLU:allChildren toComponentLU:allComponents
                             toPathLU:absolutePaths addedComponents:addedComponents
                 addedComponentOrgIds:addedComponentOrgIds
                            withError:errorPtr]) {
            return NO;
        }
    }
    
    NSDictionary *components = nodeDict[DCXComponentsManifestKey];
    for (NSMutableDictionary *componentDict in components) {
        if (addedComponentOrgIds != nil) {
            [addedComponentOrgIds addObject:(componentDict[DCXIdManifestKey])];
        }
        if (assignNewIds) {
            componentDict[DCXIdManifestKey] = [[NSUUID UUID] UUIDString];
            // Need to reset the state and some additional properties. Notice that we do
            // not reset length since it does not change.
            [componentDict removeObjectForKey:DCXEtagManifestKey];
            [componentDict removeObjectForKey:DCXVersionManifestKey];
            componentDict[DCXStateManifestKey] = DCXAssetStateModified;
        }
        DCXComponent *component = [DCXComponent componentFromDictionary:componentDict
                                                                      andManifest:self
                                                                   withParentPath:parentPath];
        
        if (allComponents[component.componentId] != nil) {
            if (errorPtr != NULL) {
                *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicateId
                                                           domain:DCXErrorDomain
                                                          details:[NSString stringWithFormat:@"Component with id %@ already exists.",
                                                                   component.componentId]];
            }
            return NO;
        }
        
        if (addedComponents != nil) {
            [addedComponents addObject:component];
        }
        allComponents[component.componentId] = component;
        absolutePath =component.absolutePath.lowercaseString;
        if (absolutePaths[absolutePath] != nil) {
            if (errorPtr != NULL) {
                *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicatePath
                                                           domain:DCXErrorDomain
                                                          details:[NSString stringWithFormat:@"Component with absolute path %@ already exists.",
                                                                   absolutePath]];
            }
            return NO;
        }
        absolutePaths[absolutePath] = component;
    }

    return YES;
};

-(NSArray*) createChildListFromArray:(NSArray*)list withParentPath:(NSString*)parentPath
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[list count]];
    if (list != nil) {
        for (id child in list) {
            [result addObject:[DCXNode nodeFromDictionary:child andManifest:self withParentPath:parentPath]];
        }
    }
    
    return result;
}

-(DCXNode*) insertChild:(DCXNode*)node in:(NSMutableDictionary*)dict at:(NSUInteger)index
                      withParentPath:(NSString*)parentPath withError:(NSError**)errorPtr
{
    NSAssert(node, @"Node must not be nil");
    NSString *nodeId = node.nodeId;
    NSAssert(nodeId != nil, @"Node must have an id");
    
    if (_allChildren[nodeId] != nil) {
        if (errorPtr != NULL) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicateId domain:DCXErrorDomain
                                                      details:[NSString stringWithFormat:@"Duplicate node id: %@", nodeId]];
        }
        return nil;
    }
    // take absPath as nil when the node being added is root node (i.e. with the path "/" )
    NSString *absPath = ((node.path == nil || [node.path isEqualToString:@"/"]) ? nil : [parentPath stringByAppendingPathComponent:node.path].lowercaseString);
    if (absPath != nil && _absolutePaths[absPath] != nil) {
        if (errorPtr != NULL) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorDuplicatePath domain:DCXErrorDomain
                                                      details:[NSString stringWithFormat:@"Duplicate absolute path: %@", absPath]];
        }
        return nil;
    }
    
    NSMutableArray *children = [dict objectForKey:DCXChildrenManifestKey];
    NSAssert(index <= [children count], @"Index %ul is out of bounds", (unsigned int)index);
    NSMutableDictionary *newNodeDict = [node.dict mutableCopy];
    if (children == nil) {
        [dict setObject:[NSMutableArray arrayWithObject:newNodeDict] forKey:DCXChildrenManifestKey];
    } else {
        [children insertObject:newNodeDict atIndex:index];
    }
    
    DCXNode *newNode = [DCXNode nodeFromDictionary:newNodeDict andManifest:self
                                                              withParentPath:parentPath];
    if (absPath != nil) {
        [_absolutePaths setObject:newNode forKey:absPath];
    }
    [_allChildren setObject:newNode forKey:nodeId];
    
    [self markAsModifiedAndDirty];
    
    return newNode;
}

-(DCXNode*) moveChild:(DCXNode*)node to:(NSMutableDictionary*)dict
                                at:(NSUInteger)index withError:(NSError**)errorPtr;
{
    // Find the old location
    NSUInteger oldIndex;
    NSMutableDictionary *oldParent = [self findParentOfNodeById:node.nodeId foundAtIndex:&oldIndex];
    NSAssert(oldParent != nil, @"Couldn't find the specified node to move");
    
    DCXNode *updatedNode = node;
    if (oldParent != dict) {
        // The node gets moved to a different parent node. This means that it and its child
        // nodes/components might end up with different absolutePaths which we have to verify.
        
        NSMutableDictionary *absoluePaths = [_absolutePaths mutableCopy];
        NSMutableDictionary *allChildren = [_allChildren mutableCopy];
        NSMutableDictionary *allComponents = [_allComponents mutableCopy];
        if (![self recursivelyRemoveNode:node fromChildrenLU:allChildren fromComponentLU:allComponents
                              fromPathLU:absoluePaths removedComponents:nil withError:errorPtr]) {
            return nil;
        }
        DCXNode *newParent = _allChildren[dict[DCXIdManifestKey]];
        updatedNode = [DCXNode nodeFromDictionary:node.dict
                                                                         andManifest:self
                                                                      withParentPath:[self parentPathForDescendantsOf:newParent]];
        if (![self recursivelyAddNode:updatedNode withDict:updatedNode.dict assignNewIds:NO toChildrenLU:allChildren
                        toComponentLU:allComponents toPathLU:absoluePaths addedComponents:nil addedComponentOrgIds:nil
                            withError:errorPtr]) {
            return nil;
        }
        
        // Now we can make the changes permanent.
        _absolutePaths = absoluePaths;
        _allComponents = allComponents;
        _allChildren = allChildren;
    }
    
    // Remove the child from the old parent/location
    NSMutableArray *children = [oldParent objectForKey:DCXChildrenManifestKey];
    id childDict = [children objectAtIndex:oldIndex];
    [children removeObjectAtIndex:oldIndex];
    
    // Insert the child at the new location
    children = [dict objectForKey:DCXChildrenManifestKey];
    if (children == nil) {
        [dict setObject:[NSMutableArray arrayWithObject:childDict] forKey:DCXChildrenManifestKey];
    } else {
        [children insertObject:childDict atIndex:index];
    }
    [self markAsModifiedAndDirty];
    
    return updatedNode;
}

- (void) removeAllChildrenAt:(NSMutableDictionary*)nodeDict removedComponents:(NSMutableArray*)removedComponents
{
    NSArray *children = [nodeDict objectForKey:DCXChildrenManifestKey];
    
    if (children != nil) {
        for (NSDictionary *nodeDict in children) {
            [self recursivelyRemoveNode:_allChildren[nodeDict[DCXIdManifestKey]] fromChildrenLU:_allChildren
                        fromComponentLU:_allComponents fromPathLU:_absolutePaths removedComponents:removedComponents withError:nil];
        }
        
        [nodeDict removeObjectForKey:DCXChildrenManifestKey];
        
        [self markAsModifiedAndDirty];
    }
}


-(NSMutableDictionary*) recursiveFindNodeById:(NSString*)nodeId startAt:(NSMutableDictionary*)dict
{
    if ([[dict objectForKey:DCXIdManifestKey] isEqualToString:nodeId]) {
        return dict;
    }
    
    NSMutableArray *children = [dict objectForKey:DCXChildrenManifestKey];
    
    if (children != nil) {
        for (id child in children) {
            NSMutableDictionary *found = [self recursiveFindNodeById:nodeId startAt:child];
            if (found != nil) {
                return found;
            }
        }
    }
    
    return nil;
}

-(NSMutableDictionary*) findNodeById:(NSString*)nodeId
{
    // findNodeById searches recursively through top level dict, which has no idead about rootNode.
    if([nodeId isEqualToString:_rootNode.nodeId]){
        return [_rootNode getMutableDictionary];
    }
    return [self recursiveFindNodeById:nodeId startAt:[_rootNode getMutableDictionary]];
}


- (NSUInteger) indexOfChildWithId:(NSString*)nodeId in:(NSArray*)listOfChildren
{
    return [listOfChildren indexOfObjectPassingTest:^BOOL(id node, NSUInteger idx, BOOL *stop) {
        NSString *nId = [node valueForKey:DCXIdManifestKey];
        if (nId != nil && [nId isEqualToString:nodeId]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
}


-(NSMutableDictionary*) recursiveFindParentOfNodeById:(NSString*)nodeId startAt:(NSMutableDictionary*)dict foundAtIndex:(NSUInteger*)indexPtr
{
    NSMutableArray *children = [dict objectForKey:DCXChildrenManifestKey];
    
    if (children != nil) {
        NSUInteger index = [self indexOfChildWithId:nodeId in:children];
        if (index != NSNotFound) {
            if (indexPtr != NULL) {
                *indexPtr = index;
            }
            return dict;
        }
        for (id child in children) {
            NSMutableDictionary *found = [self recursiveFindParentOfNodeById:nodeId startAt:child foundAtIndex:indexPtr];
            if (found != nil) {
                return found;
            }
        }
    }
    
    return nil;
}

-(NSUInteger) recursiveGetAbsoluteIndexOfNodeId:(NSString*)nodeId startAt:(NSMutableDictionary*)dict withRunningIndex:(NSUInteger*)runningIndex
{
    NSMutableArray *children = [dict objectForKey:DCXChildrenManifestKey];
    
    if (children != nil) {
        for (NSMutableDictionary *node in children) {
            if ([node[DCXIdManifestKey] isEqualToString:nodeId]) {
                return *runningIndex;
            } else {
                *runningIndex = *runningIndex + 1;
                NSUInteger foundIndex = [self recursiveGetAbsoluteIndexOfNodeId:nodeId startAt:node withRunningIndex:runningIndex];
                if (foundIndex != NSNotFound) {
                    return foundIndex;
                }
            }
        }
    }
    
    return NSNotFound;
}

-(NSMutableDictionary*) findParentOfNodeById:(NSString*)nodeId foundAtIndex:(NSUInteger*)indexPtr
{
    return [self recursiveFindParentOfNodeById:nodeId startAt:[_rootNode getMutableDictionary] foundAtIndex:indexPtr];
}

-(NSMutableDictionary*) recursiveFindNodeOfComponentById:(NSString*)componentId startAt:(NSMutableDictionary*)dict foundAtIndex:(NSUInteger*)indexPtr
{
    NSArray *components = [dict objectForKey:DCXComponentsManifestKey];
    
    if (components != nil) {
        NSUInteger index = [self indexOfComponentWithId:componentId in:components];
        if (index != NSNotFound) {
            if (indexPtr != NULL) {
                *indexPtr = index;
            }
            return dict;
        }
    }
    NSMutableArray *children = [dict objectForKey:DCXChildrenManifestKey];
    if (children != nil) {
        for (id child in children) {
            NSMutableDictionary *found = [self recursiveFindNodeOfComponentById:componentId startAt:child foundAtIndex:indexPtr];
            if (found != nil) {
                return found;
            }
        }
    }
    
    return nil;
}

-(NSMutableDictionary*) findNodeOfComponentById:(NSString*)componentId foundAtIndex:(NSUInteger*)indexPr
{
    return [self recursiveFindNodeOfComponentById:(NSString*)componentId startAt:[_rootNode getMutableDictionary] foundAtIndex:indexPr];
}

-(NSString*) parentPathForDescendantsOf:(DCXNode*)parentNode
{
    return parentNode == nil ? @"/" : (parentNode.path == nil ? parentNode.parentPath : parentNode.absolutePath);
}

-(void) internalSetCompositeId:(NSString *)newCompositeId
{
    // Set the id in the internalDict
    [_dictionary setObject:newCompositeId forKey:DCXIdManifestKey];
    // Remove the entry for the old node from allChildren
    [_allChildren removeObjectForKey:_rootNode.nodeId];
    // Change the root nodeId
    [_rootNode setNodeId:newCompositeId];
    // add the node back into allChildren
    [_allChildren setObject:_rootNode forKey:_rootNode.nodeId];
}


#pragma mark NSCopying protocol

-(id)copyWithZone:(NSZone *)zone
{
    DCXManifest *copy = [[DCXManifest alloc] initWithData:[self localData] withError:nil];
    
    return copy;
}



#pragma mark Helper methods

+ (NSDateFormatter*)dateFormatter
{
    return staticDateFormatter;
}

+ (NSDate *)parseDate:(NSString*)dateStr
{
    NSDate *date = [staticRFC3339DateParser1 dateFromString:dateStr];
    if (!date) {
        date = [staticRFC3339DateParser2 dateFromString:dateStr];
    }
    return date;
}


-(void) markAsModifiedAndDirty
{
    if ( [self.compositeState isEqualToString:DCXAssetStateUnmodified] ) {
        self.compositeState = DCXAssetStateModified; // setting the composite state also sets _isDirty
    } else {
        _isDirty = YES;
    }
}

@end
