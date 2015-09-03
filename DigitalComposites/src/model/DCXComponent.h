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

/**
 * \class DCXComponent
 * \brief Wrapper for a component in a DCXManifest. Notice that this is an immutable
 * object. If you want to modify a component you need to create a mutable copy
 * (e.g. copy = [component mutableCopy]).
 */
@interface DCXComponent : NSObject <NSMutableCopying> {
    @protected
    NSDictionary *_dict;     /**< The underlying dictionary of the component. */
}

#pragma mark - Properties

/** The unique identifier of the component. */
@property (nonatomic, readonly) NSString *componentId;

/** The unique path of the component relative to its parentPath. */
@property (nonatomic, readonly) NSString *path;

/** The absolute path defined by the component's enclosing nodes. */
@property (nonatomic, readonly) NSString *parentPath;

/** The unique absolute path of the component. */
@property (nonatomic, readonly) NSString *absolutePath;

/** The name of the component. */
@property (nonatomic, readonly) NSString *name;

/** The relationship type of the component. */
@property (nonatomic, readonly) NSString *relationship;

/** The mime type of the component's asset file. */
@property (nonatomic, readonly) NSString *type;

/** List of links keyed by link type. Can be nil. */
@property (nonatomic, readonly) NSDictionary *links;

/** The DCXAssetState of the component. */
@property (nonatomic, readonly) NSString *state;

/** The etag of the manifest asset on the server. */
@property (nonatomic, readonly) NSString *etag;

/** The version of the manifest asset on the server. */
@property (nonatomic, readonly) NSString *version;

/** The content length of the manifest asset on the server. */
@property (nonatomic, readonly) NSNumber *length;

/** The width of the component. */
@property (nonatomic, readonly) NSNumber *width;

/** The height of the component. */
@property (nonatomic, readonly) NSNumber *height;

/** Is YES if the component is bound to a specific resource on the server. */
@property (nonatomic, readonly) BOOL isBound;


#pragma mark - Methods

/**
 * \brief Returns a named attribute of the component. Use this to access attributes
 * that are not exposed as separate properties.
 *
 * \param key The name of the attribute.
 */
- (id)valueForKey:(NSString *)key;

@end
