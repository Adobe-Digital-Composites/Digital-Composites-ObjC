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

#import "DCXMutableComponent_Internal.h"
#import "DCXComponent_Internal.h"

#import "DCXConstants_Internal.h"
#import "DCXManifest.h"

@implementation DCXMutableComponent {
    NSMutableDictionary *_mutableDict;
    NSString *_parentPath;
}

@dynamic componentId;
@dynamic path;
@dynamic name;
@dynamic type;
@dynamic relationship;
@dynamic links;
@dynamic state;
@dynamic etag;
@dynamic version;
@dynamic length;
@dynamic width;
@dynamic height;

static id _sharedKeySet = nil;

+ (instancetype) componentWithId:(NSString*)componentId path:(NSString*)path name:(NSString*)name
                  type:(NSString*)type relationship:(NSString*)relationship
{
    DCXMutableComponent *component = [[self alloc] initWithId:componentId path:path name:name type:type links:nil
                              state:DCXAssetStateModified];
    component.relationship = relationship;
    return component;
}

-(instancetype) init
{
    if (self = [super init]) {
        if (_sharedKeySet == nil) {
            _sharedKeySet = [NSDictionary sharedKeySetForKeys:@[DCXIdManifestKey, DCXPathManifestKey,
                                                                DCXNameManifestKey, DCXTypeManifestKey,
                                                                DCXLinksManifestKey, DCXStateManifestKey,
                                                                DCXEtagManifestKey]];
        }
        _mutableDict = [NSMutableDictionary dictionaryWithSharedKeySet:_sharedKeySet];
        
        // make sure to also set the non-mutable dict of the base class
        _dict = _mutableDict;
        
    }
    return self;
}

-(instancetype) initWithId:(NSString *)componentId path:(NSString *)path name:(NSString *)name type:(NSString *)type
           links:(NSDictionary *)links state:(NSString *)state
{
    if (self = [self init]) {
        if (componentId != nil) [_mutableDict setObject:componentId forKey:DCXIdManifestKey];
        else                    [_mutableDict setObject:[[NSUUID UUID] UUIDString] forKey:DCXIdManifestKey];
        if (path != nil)  [_mutableDict setObject:path forKey:DCXPathManifestKey];
        if (name != nil)  [_mutableDict setObject:name forKey:DCXNameManifestKey];
        if (type != nil)  [_mutableDict setObject:type forKey:DCXTypeManifestKey];
        if (links != nil) [_mutableDict setObject:[links mutableCopy] forKey:DCXLinksManifestKey];
        if (state != nil) [_mutableDict setObject:state forKey:DCXStateManifestKey];
    }
    
    return self;
}


- (instancetype) initWithDictionary:(NSMutableDictionary*)compDict andManifest:(DCXManifest *)manifest withParentPath:(NSString *)parentPath
{
    if (self = [super initWithDictionary:compDict andManifest:manifest withParentPath:parentPath]) {
        _mutableDict = compDict;
        _parentPath = parentPath;
    }
    
    return self;
}

-(void) setComponentId:(NSString *)componentId
{
    if (componentId != nil) {
        [_mutableDict setObject:componentId forKey:DCXIdManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXIdManifestKey];
    }
}

-(void) setPath:(NSString *)path
{
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

-(void) setRelationship:(NSString *)relationship
{
    if (relationship != nil) {
        [_mutableDict setObject:relationship forKey:DCXRelationshipManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXRelationshipManifestKey];
    }
}

-(void) setEtag:(NSString *)etag
{
    if (etag != nil) {
        [_mutableDict setObject:etag forKey:DCXEtagManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXEtagManifestKey];
    }
}

-(void) setLength:(NSNumber *)length
{
    if (length != nil) {
        [_mutableDict setObject:length forKey:DCXLengthManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXLengthManifestKey];
    }
}

-(void) setVersion:(NSString *)version
{
    if (version != nil) {
        [_mutableDict setObject:version forKey:DCXVersionManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXVersionManifestKey];
    }
}

-(void) setWidth:(NSNumber *)width
{
    if (width != nil) {
        [_mutableDict setObject:width forKey:DCXWidthManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXWidthManifestKey];
    }
}

-(void) setHeight:(NSNumber *)height
{
    if (height != nil) {
        [_mutableDict setObject:height forKey:DCXHeightManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXHeightManifestKey];
    }
}

-(NSMutableDictionary*) links
{
    return [_mutableDict objectForKey:DCXLinksManifestKey];
}

-(void) setLinks:(NSDictionary *)links
{
    if (links != nil) {
        [_mutableDict setObject:links forKey:DCXLinksManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXLinksManifestKey];
    }
}

-(void) setState:(NSString *)state
{
    if (state != nil) {
        [_mutableDict setObject:state forKey:DCXStateManifestKey];
    } else {
        [_mutableDict removeObjectForKey:DCXStateManifestKey];
    }
}

- (void) setValue:(id)value forKey:(NSString*)key
{
    [_mutableDict setObject:value forKey:key];
}

- (void) removeValueForKey:(NSString*)key
{
    [_mutableDict removeObjectForKey:key];
}

@end
