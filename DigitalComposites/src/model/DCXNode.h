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
 * \class DCXNode
 * \brief Represents a child node of a DCXManifest. Allows read-only access to
 * its properties. If you want to modify a manifest node you need to create a
 * mutable copy of it (e.g. copy = [node mutableCopy]).
 *
 * Notice that DCXNode doesn't give you access to the components or
 * children of a node. But you can use it to get the components and children
 * from the DCXManifest.
 *
 */
@interface DCXNode : NSObject <NSMutableCopying>
{
    @protected
    NSDictionary *_dict; /**< The underlying dictionary of the node. */
    Boolean _isRoot;
}

#pragma mark - Properties

/** The name of the node. */
@property (nonatomic, readonly) NSString *name;

/** The unique path of the node relative to its parentPath. */
@property (nonatomic, readonly) NSString *path;

/** The absolute path defined by the node's enclosing nodes. */
@property (nonatomic, readonly) NSString *parentPath;

/** The unique absolute path of the node. Is nil if the node doesn't have a path property.*/
@property (nonatomic, readonly) NSString *absolutePath;

/** Whether the node is the root node. */
@property (nonatomic, readonly) Boolean isRoot;

/** The type of the node. */
@property (nonatomic, readonly) NSString *type;

/** The id of the node. */
@property (nonatomic, readonly) NSString *nodeId;

/** The dictionary that was used to construct this node. */
@property (nonatomic, readonly) NSDictionary *dict;


/**
 * \brief Returns the value of a named attribute of the node or nil if the attribute
 * doesn't exist. Use this to access attributes
 * that are not exposed as properties.
 *
 * \param key The name of the attribute.
 *
 * \return The value of the attribute.
 */
- (id)valueForKey:(NSString *)key;

@end
