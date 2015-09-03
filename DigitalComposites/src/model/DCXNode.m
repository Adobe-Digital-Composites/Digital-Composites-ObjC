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
#import "DCXConstants_Internal.h"
#import "DCXCopyUtils.h"

@implementation DCXNode

-(instancetype) initWithDictionary:(NSMutableDictionary *)nodeDict andManifest:(DCXManifest*)manifest
          withParentPath:(NSString*)parentPath
{
    if (self = [super init]) {
        _dict = nodeDict;
        _manifest = manifest;
        _parentPath = parentPath;
        _isRoot = NO;
    }
    
    return self;
}

+(instancetype) nodeFromDictionary:(NSDictionary *)nodeDict andManifest:(DCXManifest*)manifest
          withParentPath:(NSString*)parentPath
{
    return [[self alloc] initWithDictionary:nodeDict andManifest:manifest
                             withParentPath:parentPath];
}

-(id) mutableCopyWithZone:(NSZone *)zone
{
    NSMutableDictionary* mutableCopy = [[NSMutableDictionary allocWithZone:zone] initWithCapacity:[_dict count]];
	NSArray* keys = [_dict allKeys];
    
    for (id key in keys) {
        // We do not want to deep copy children or components
        if (![key isEqualToString:DCXChildrenManifestKey] && ![key isEqualToString:DCXComponentsManifestKey]) {
            id object = [_dict objectForKey:key];
            if ([object isKindOfClass:[NSDictionary class]]) {
                [mutableCopy setObject:[DCXCopyUtils deepMutableCopyOfDictionary:object] forKey:key];
            } else if ([object isKindOfClass:[NSArray class]]) {
                [mutableCopy setObject:[DCXCopyUtils deepMutableCopyOfArray:object] forKey:key];
            } else {
                [mutableCopy setObject:object forKey:key];
            }
        }
	}
    
    DCXMutableNode *copy = [[DCXMutableNode allocWithZone:zone] initWithDictionary:mutableCopy withParentPath:_parentPath];
    
    if (_isRoot) {
        copy.isRoot = YES;
    }
    
    return copy;
}

-(NSString*) nodeId
{
    return [_dict objectForKey:DCXIdManifestKey];
}

-(NSString*) name
{
    return [_dict objectForKey:DCXNameManifestKey];
}

-(NSString*) path
{
    return _isRoot ? @"/" : [_dict objectForKey:DCXPathManifestKey];
}

-(NSString*) absolutePath
{
    return self.path == nil ? nil : [self.parentPath stringByAppendingPathComponent:self.path];
}

-(NSString*) type
{
    return [_dict objectForKey:DCXTypeManifestKey];
}

- (id) valueForKey:(NSString*)key
{
    NSAssert(![key isEqualToString:DCXChildrenManifestKey] && ![key isEqualToString:DCXComponentsManifestKey], @"The key %@ is a reserved key for a DCXNode.", key);
    return [_dict objectForKey:key];
}

@end
