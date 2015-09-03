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

#import "DCXComposite.h"
#import "DCXComponent.h"
#import "DCXManifest.h"
#import "DCXConstants.h"
#import "DCXError.h"
#import "DCXNode.h"
#import "DCXMutableNode.h"
#import "DCXErrorUtils.h"
#import "DCXLocalStorage.h"


@implementation DCXBranch
{
    DCXManifest *_manifest;
}

#pragma mark Private manifest access

- (DCXManifest*)manifest
{
    // Need @synchronized to enforce memory barriers?
    return _manifest;
}

- (void)setManifest:(DCXManifest*) manifest
{
    @synchronized(self) {
        _manifest = manifest;
    }
}

#pragma mark Initialization & Convenience Constructors

-(instancetype) initWithComposite:(DCXComposite *)composite
            andManifest:(DCXManifest *)manifest
{
    if (self = [super init]) {
        _weakComposite = composite;
        _manifest = manifest;
    }
    return self;
}

+(instancetype) branchWithComposite:(DCXComposite *)composite
                       andManifest:(DCXManifest *)manifest
{
    return [[self alloc] initWithComposite:composite andManifest:manifest];
}

-(instancetype) mutableCopyWithZone:(NSZone *)zone
{
    NSData *manifestData = _manifest.localData;
    DCXManifest *manifestCopy = [[DCXManifest allocWithZone:zone] initWithData:manifestData withError:nil];
    
    if (manifestCopy != nil) {
        DCXMutableBranch *copy = [DCXMutableBranch branchWithComposite:_weakComposite andManifest:manifestCopy];
        return copy;
    } else {
        return nil;
    }
}

#pragma mark - Properties

-(NSString*) name
{
    return _manifest.name;
}

-(NSString*) type
{
    return _manifest.type;
}

-(NSString*) compositeState
{
    return _manifest.compositeState;
}

-(NSDictionary*) links
{
    return _manifest.links;
}

-(NSString*) etag
{
    return _manifest.etag;
}

-(DCXNode *)rootNode
{
    return _manifest.rootNode;
}

-(id) valueForKey:(NSString *)key
{
    return [_manifest valueForKey:key];
}

#pragma mark - Components

-(NSArray*) getComponentsOf:(DCXNode *)node
{
    if (node == nil) {
        return _manifest.components;
    } else {
        return [_manifest componentsOfChild:node];
    }
}

-(DCXComponent*) getComponentWithId:(NSString*)componentId
{
    return _manifest.allComponents[componentId];
}

-(DCXComponent*) getComponentWithAbsolutePath:(NSString *)absolutePath
{
    return [_manifest componentWithAbsolutePath:absolutePath];
}

-(DCXNode*) findParentOfComponent:(DCXComponent *)component
{
    DCXNode* result = [_manifest findParentOfComponent:component];
    return result;
}

-(NSArray*) getAllComponents;
{
    return [_manifest.allComponents allValues];
}

#pragma mark - Children

-(NSArray*) getChildrenOf:(DCXNode*)node
{
    if (node == nil) {
        return _manifest.children;
    } else {
        return [_manifest childrenOf:node];
    }
}

-(DCXNode*) getChildWithId:(NSString*)nodeId
{
    return _manifest.allChildren[nodeId];
}

-(DCXNode*) getChildWithAbsolutePath:(NSString *)absolutePath
{
    return [_manifest childWithAbsolutePath:absolutePath];
}

-(DCXNode*) findParentOfChild:(DCXNode *)node foundIndex:(NSUInteger *)index
{
    DCXNode *result = [_manifest findParentOfChild:node foundIndex:index];
    return result;
}

-(NSString*) pathForComponent:(DCXComponent*)component withError:(NSError**)errorPtr
{
    // Get a strong reference to the composite
    DCXComposite *composite = self.weakComposite;
    NSAssert(composite != nil, @"Using branch after the composite has been released");
    bool isPulledBranch = self == composite.pulled;

    NSString *path = [DCXLocalStorage pathOfComponent:component
                                           inManifest:_manifest
                                          ofComposite:composite
                                            withError:errorPtr];
    if (isPulledBranch || [[NSFileManager defaultManager] fileExistsAtPath:path])
        return path;
    return nil;
}

#pragma mark Storage

- (BOOL) loadManifestFrom:(NSString*)path withError:(NSError**)errorPtr
{    DCXManifest *newManifest = [DCXManifest manifestWithContentsOfFile:path withError:errorPtr];
    
    if (newManifest == nil) {
        return NO;
    } else {
        self.manifest = newManifest;
        self.manifest.isDirty = NO;
        return YES;
    }
}

@end
