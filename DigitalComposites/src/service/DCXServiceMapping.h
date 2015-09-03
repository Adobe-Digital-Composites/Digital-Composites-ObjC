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

#import <Foundation/Foundation.h>

@class DCXComposite;
@class DCXManifest;
@class DCXComponent;
@class DCXResourceItem;

/**
 * Static helper class that knows where to store composites on the server and
 * how to create resource objects for the various Digital Composite objects.*/
@interface DCXServiceMapping : NSObject

/**
 * \brief Creates and returns an DCXResourceItem for the given composite.
 *
 * \param composite The composite to return the reosurce for.
 *
 * \return The resource or nil if the composite object doesn't contain sufficient data.
 */
+ (DCXResourceItem *)resourceForComposite:(DCXComposite *)composite;


/**
 * \brief Creates and returns an DCXResourceItem for the given manifest.
 *
 * \param manifest  The manifest to return the resource for.
 * \param composite The composite of the manifest to return the resource for.
 *
 * \return The resource.
 */
+ (DCXResourceItem *)resourceForManifest:(DCXManifest *)manifest
                             ofComposite:(DCXComposite *)composite;


/**
 * \brief Creates and returns an DCXResourceItem for the given component.
 *
 * \param component  The component to return the resource for.
 * \param composite  The composite to return the resource for.
 * \param path       The local file path of the component.
 * \param useVersion Whether the resource should address the specific version of the component.
 *
 * \return The resource.
 */
+ (DCXResourceItem *)resourceForComponent:(DCXComponent *)component
                              ofComposite:(DCXComposite *)composite
                                 withPath:(NSString *)path
                               useVersion:(BOOL)useVersion;

/**
 * \brief Creates and returns an DCXResourceItem for the given component.
 *
 * \param component      The component to return the resource for.
 * \param compositeHref  The href to composite containing the specified component
 * \param path           The local file path of the component.
 * \param useVersion     Whether the resource should address the specific version of the component.
 *
 * \return The resource.
 */
+ (DCXResourceItem *)resourceForComponent:(DCXComponent *)component
                        withCompositeHref:(NSString *)compositeHref
                                 withPath:(NSString *)path
                               useVersion:(BOOL)useVersion;


@end
