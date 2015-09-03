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

#import "DCXServiceMapping.h"

#import "DCXComponent.h"
#import "DCXComposite_Internal.h"
#import "DCXConstants_Internal.h"
#import "DCXManifest.h"
#import "DCXResourceItem.h"

@implementation DCXServiceMapping

+ (NSString *)getSyncGroupNameForComposite:(DCXComposite *)composite
{
    NSAssert(composite != nil, @"Composite must not be nil.");

    // The sync group name is derived from the href of the composite
    if (composite.href == nil)
    {
        return nil;
    }
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:composite.href];
    NSArray *hrefComponents = [urlComponents.path componentsSeparatedByString:@"/"];
    // We expect the path portion of the URL to be of the form .../assets/<SyncGroupName>/<CompositeId>
    // with optional preceeding and trailing slashes and optional preceeding path components.
    // We simply return the second-to-last non-empty path component.
    if ( hrefComponents.count > 2 )
    {
        BOOL foundLastPathComponent = NO;
        for ( NSInteger n = hrefComponents.count - 1; n > 0; n-- )
        {
            // Identify the last non-empty path component (in case we have a trailing slash)
            if ( !foundLastPathComponent && ((NSString*)hrefComponents[n]).length > 0 )
            {
                foundLastPathComponent = YES;
                continue;
            }
            
            if ( foundLastPathComponent )
            {
                return (NSString*)hrefComponents[n];
            }
        }
    }
    
    return nil;
}

+ (DCXResourceItem *)resourceForComposite:(DCXComposite *)composite
{
    DCXResourceItem *resource = nil;

    if (composite.href != nil)
    {
        resource = [DCXResourceItem resourceFromHref:composite.href];
        resource.type = @"application/vnd.adobe.directory+json";
        DCXManifest *manifest = composite.manifest;

        if (manifest != nil)
        {
            resource.name = manifest.compositeId;
        }
        else
        {
            resource.name = [composite.href lastPathComponent];
        }
    }

    return resource;
}

+ (DCXResourceItem *)resourceForManifest:(DCXManifest *)manifest
                                      ofComposite:(DCXComposite *)composite
{
    NSString *href = [composite.href stringByAppendingPathComponent:@"manifest"];

    DCXResourceItem *resource = [[DCXResourceItem alloc] init];

    resource.type = DCXManifestType;
    resource.href = href;
    resource.etag = manifest.etag;

    return resource;
}

+ (DCXResourceItem *)resourceForComponent:(DCXComponent *)component
                                       ofComposite:(DCXComposite *)composite
                                          withPath:(NSString *)path
                                        useVersion:(BOOL)useVersion
{
    return [self resourceForComponent:component withCompositeHref:composite.href withPath:path useVersion:useVersion];
}

+ (DCXResourceItem *)resourceForComponent:(DCXComponent *)component
                                 withCompositeHref:(NSString *)compositeHref
                                          withPath:(NSString *)path
                                        useVersion:(BOOL)useVersion
{
    NSString *resourceHref = nil;

    if (component.componentId != nil && compositeHref != nil)
    {
        NSURL *compositeURL = [NSURL URLWithString:compositeHref];
        compositeURL = [compositeURL URLByAppendingPathComponent:component.componentId];
        resourceHref = compositeURL.absoluteString;

        if (useVersion)
        {
            resourceHref = [resourceHref stringByAppendingFormat:@";version=%@", component.version];
        }
    }

    DCXResourceItem *resource = [[DCXResourceItem alloc] init];
    resource.name = component.componentId;
    resource.type = component.type;
    resource.href = resourceHref;
    resource.etag = component.etag;
    resource.length = component.length;
    resource.version = component.version;
    resource.path = path;
    return resource;
}

@end
