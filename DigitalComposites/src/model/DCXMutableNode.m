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

#import "DCXNode_Internal.h"
#import "DCXMutableNode_Internal.h"
#import "DCXManifest.h"
#import "DCXConstants_Internal.h"

@implementation DCXMutableNode {
    NSMutableDictionary *_mutableDict;
    NSString *_parentPath;
}

@dynamic isRoot;
@dynamic name;
@dynamic path;
@dynamic type;
@dynamic nodeId;
@dynamic absolutePath;

-(instancetype) init
{
    if (self = [super init]) {
        _mutableDict = [NSMutableDictionary dictionaryWithCapacity:4];
        // make sure to also set the non-mutable dict of the base class
        _dict = _mutableDict;
    }
    return self;
}

-(instancetype) initWithId:(NSString*)nodeId name:(NSString*)name
{
    if (self = [self init]) {
        if (nodeId != nil)  [_mutableDict setObject:nodeId forKey:DCXIdManifestKey];
        else                [_mutableDict setObject:[[NSUUID UUID] UUIDString] forKey:DCXIdManifestKey];
        if (name != nil)    [_mutableDict setObject:name forKey:DCXNameManifestKey];
    }
    
    return self;
}

-(instancetype) initWithType:(NSString *)type path:(NSString *)path name:(NSString *)name
{
    if (self = [self init]) {
        [_mutableDict setObject:[[NSUUID UUID] UUIDString] forKey:DCXIdManifestKey];
        if (type != nil)    [_mutableDict setObject:type forKey:DCXTypeManifestKey];
        if (name != nil)    [_mutableDict setObject:name forKey:DCXNameManifestKey];
        if (path != nil)    [_mutableDict setObject:path forKey:DCXPathManifestKey];
    }
    
    return self;
}

-(instancetype) initWithDictionary:(NSMutableDictionary *)nodeDict withParentPath:(NSString*)parentPath
{
    if (self = [super init]) {
        _mutableDict = nodeDict;
        // make sure also to set the non-mutable dict of the base class
        _dict = _mutableDict;
        _parentPath = parentPath;
    }
    
    return self;
}

+(instancetype) rootNodeFromDict:(NSDictionary *) nodeDict andManifest:(DCXManifest *)manifest {
    NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
    
    for( id key in nodeDict){
        if( [[DCXManifest manifestSpecificProperties] containsObject:key] ){
            continue;
        }
        [dict setObject:[nodeDict objectForKey:key] forKey:key];
    }
    // Use the compositeId of the manifest as the rootNode Id
    NSString *nodeId = manifest.compositeId;
    [dict setObject:nodeId forKey:DCXIdManifestKey];
    
    DCXMutableNode *rootNode = [[self alloc] initWithDictionary:dict withParentPath:@""];
    rootNode.isRoot = YES;
    
    return rootNode;
}

+(instancetype) nodeWithType:(NSString *)type path:(NSString *)path name:(NSString *)name
{
    return [[self alloc] initWithType:type path:path name:name];
}

+(instancetype) nodeWithName:(NSString *)name
{
    return [[self alloc] initWithId:[[NSUUID UUID] UUIDString] name:name];
}

+ (instancetype) nodeWithId:(NSString*)nodeId
{
    return [[self alloc] initWithId:nodeId name:nil];
}

-(void) setName:(NSString *)name
{
    if (name != nil) {
        [_mutableDict setObject:name forKey:DCXNameManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXNameManifestKey];
    }
}

-(void) setType:(NSString *)type
{
    if (type != nil) {
        [_mutableDict setObject:type forKey:DCXTypeManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXTypeManifestKey];
    }
}

-(void) setPath:(NSString *)path
{
    NSAssert(!self.isRoot,  @"You cannot modify the path property of the root node.");
    
    if (path != nil) {
        [_mutableDict setObject:path forKey:DCXPathManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXPathManifestKey];
    }
}

-(NSString*) parentPath
{
    return _parentPath;
}

-(void) setParentPath:(NSString *)parentPath
{
    _parentPath = parentPath;
}

-(void) setNodeId:(NSString *)nodeId
{
    if (nodeId != nil) {
        [_mutableDict setObject:nodeId forKey:DCXIdManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXIdManifestKey];
    }
}

- (void)setValue:(id)value forKey:(NSString*)key
{
    NSAssert(![key isEqualToString:DCXChildrenManifestKey] &&
             ![key isEqualToString:DCXComponentsManifestKey] &&
             ![key isEqualToString:DCXPathManifestKey],
             @"The key %@ is a reserved key for a DCXNode.", key);
    
    [_mutableDict setObject:value forKey:key];
}

-(void) setIsRoot:(Boolean)isRoot
{
    _isRoot = isRoot;
}

- (void) removeValueForKey:(NSString*)key
{
    NSAssert(![key isEqualToString:DCXChildrenManifestKey] &&
             ![key isEqualToString:DCXComponentsManifestKey] &&
             ![key isEqualToString:DCXPathManifestKey],
             @"The key %@ is a reserved key for a DCXNode.", key);
    
    [_mutableDict removeObjectForKey:key];
}

- (NSMutableDictionary *) getMutableDictionary{
    return _mutableDict;
}

@end
