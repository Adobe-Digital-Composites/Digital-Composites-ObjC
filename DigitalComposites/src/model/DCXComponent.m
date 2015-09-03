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


#import "DCXComponent_Internal.h"
#import "DCXMutableComponent.h"
#import "DCXManifest.h"
#import "DCXConstants_Internal.h"
#import "DCXCopyUtils.h"

@implementation DCXComponent

-(instancetype) initWithDictionary:(NSDictionary *)component andManifest:(DCXManifest*)manifest
          withParentPath:(NSString*)parentPath
{
    if (self = [super init]) {
        _dict = component;
        _manifest = manifest;
        _parentPath = parentPath;
    }
    
    return self;
}

+(instancetype) componentFromDictionary:(NSDictionary *)component andManifest:(DCXManifest*)manifest
               withParentPath:(NSString*)parentPath
{
    return [[self alloc] initWithDictionary:component andManifest:manifest withParentPath:parentPath];
}

-(instancetype) mutableCopyWithZone:(NSZone *)zone
{
    return [[DCXMutableComponent allocWithZone:zone] initWithDictionary:[DCXCopyUtils
                                                                         deepMutableCopyOfDictionary:_dict ]
                                                            andManifest:_manifest withParentPath:_parentPath];
}

-(NSString*) componentId
{
    return [_dict objectForKey:DCXIdManifestKey];
}

-(NSString*) path
{
    return [_dict objectForKey:DCXPathManifestKey];
}

-(NSString*) absolutePath
{
    return [self.parentPath stringByAppendingPathComponent:self.path];
}

-(NSString*) name
{
    return [_dict objectForKey:DCXNameManifestKey];
}

-(NSString*) type
{
    return [_dict objectForKey:DCXTypeManifestKey];
}

-(NSString*) relationship
{
    return [_dict objectForKey:DCXRelationshipManifestKey];
}

-(NSString*) state
{
    return [_dict objectForKey:DCXStateManifestKey];
}

- (NSString*)etag
{
    return [_dict objectForKey:DCXEtagManifestKey];
}

-(NSNumber*)length
{
    return [_dict objectForKey:DCXLengthManifestKey];
}

-(NSString*)version
{
    return [_dict objectForKey:DCXVersionManifestKey];
}

-(NSNumber *) width
{
    return [_dict objectForKey:DCXWidthManifestKey];
}

-(NSNumber *) height
{
    return [_dict objectForKey:DCXHeightManifestKey];
}

-(NSDictionary*) links
{
    return [_dict objectForKey:DCXLinksManifestKey];
}

-(BOOL) isBound
{
    return (_manifest == nil ? NO : [_manifest componentIsBound:self]);
}

- (id) valueForKey:(NSString*)key
{
    return [_dict objectForKey:key];
}

@end
