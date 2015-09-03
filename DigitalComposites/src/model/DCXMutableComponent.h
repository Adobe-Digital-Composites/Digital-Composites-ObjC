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

#import "DCXComponent.h"

@class DCXManifest;

/**
 * \class DCXMutableComponent
 * \brief Mutable version of DCXComponent.
 */
@interface DCXMutableComponent : DCXComponent

#pragma mark - Convenience methods

/**
 * \brief Constructs a mutable component.
 *
 * \param componentId         The unique identifier of the component.
 * \param path                The path of the component relative to its parent node
 * \param name                The name of the component.
 * \param type                The mime type of the component's asset file.
 * \param relationship        The relationship type of the component's asset file.
 *
 * \note  The path does not refer to the actual file path of the component on disk.  
 * However, if the path contains a valid file extension then this will be preserved when 
 * constructing the file's actual path on disk.
 */
+ (instancetype)componentWithId:(NSString *)componentId path:(NSString *)path name:(NSString *)name
                 type:(NSString *)type relationship:(NSString *)relationship;


#pragma mark - Initializers

/**
 * \brief Designated initializer. Creates new mutable dictionary containing the properties
 * that are being passed in via the parameter.
 *
 * \param componentId The unique identifier of the component.
 * \param path The path of the component relative to its parent node
 * \param name The name of the component.
 * \param type The mime type of the component's asset file.
 * \param links The links of the component.
 * \param state The DCXAssetState of the component.
 */
- (instancetype) initWithId:(NSString *)componentId path:(NSString *)path name:(NSString *)name type:(NSString *)type
           links:(NSDictionary *)links state:(NSString *)state;


#pragma mark - Properties

// Override the properties as mutable.

/** The unique identifier of the component. */
@property (nonatomic) NSString *componentId;

/** The unique path of the component relative to its parentPath. */
@property (nonatomic) NSString *path;

/** The name of the component. */
@property (nonatomic) NSString *name;

/** The mime type of the component's asset file. */
@property (nonatomic) NSString *type;

/** The relationship type of the component. */
@property (nonatomic) NSString *relationship;

/** List of links keyed by link type. */
@property (nonatomic) NSMutableDictionary *links;

/** The DCXAssetState of the component. */
@property (nonatomic) NSString *state;

/** The etag of the manifest asset on the server. */
@property (nonatomic) NSString *etag;

/** The version of the manifest asset on the server. */
@property (nonatomic) NSString *version;

/** The content length of the manifest asset on the server. */
@property (nonatomic) NSNumber *length;

/** The width of the component. */
@property (nonatomic) NSNumber *width;

/** The height of the component. */
@property (nonatomic) NSNumber *height;


#pragma mark - Methods

/**
 * \brief Sets a named attribute of the component. Use this to modify attributes
 * that are not exposed as separate properties.
 *
 * \param value The new value of the attribute.
 * \param key The name of the attribute.
 */
- (void)setValue:(id)value forKey:(NSString *)key;

/**
 * \brief Removes a named attribute from the component. Use this to remove attributes
 * that are not exposed as separate properties.
 *
 * \param key The name of the attribute.
 */
- (void)removeValueForKey:(NSString *)key;

@end
