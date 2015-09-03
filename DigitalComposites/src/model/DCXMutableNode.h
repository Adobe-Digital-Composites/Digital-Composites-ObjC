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

#import "DCXNode.h"

/**
 * \class DCXMutableNode
 * \brief Represents a child node of a DCXManifest. Allows read and write access to
 * its properties.
 *
 * Notice that DCXNode doesn't give you access to the components or
 * children of a node. But you can use it to manipulate the components and children
 * via the DCXManifest.
 *
 */
@interface DCXMutableNode : DCXNode

#pragma mark - Initializers

/**
 * \brief Initializer
 * \param nodeId - the id of the node
 * \param name the name
 */
- (instancetype)initWithId:(NSString *)nodeId name:(NSString *)name;

/**
 * \brief Initializer
 * \param type the type
 * \param path the path
 * \param name the name
 */
- (instancetype)initWithType:(NSString *)type path:(NSString *)path name:(NSString *)name;

/**
 * \brief Initializer
 * \param nodeDict the dictionary to initialize with
 * \param parentPath  The parent path of the node.
 */
- (instancetype)initWithDictionary:(NSMutableDictionary *)nodeDict withParentPath:(NSString *)parentPath;


#pragma mark - Convenience methods

/**
 * \brief Constructs a mutable manifest node with the given type, path and name.
 *
 * \param name The name of the new node.
 */
+ (instancetype)nodeWithType:(NSString *)type path:(NSString *)path name:(NSString *)name;

/**
 * \brief Constructs a mutable manifest node with the given name and a random id.
 *
 * \param name The name of the new node.
 */
+ (instancetype)nodeWithName:(NSString *)name;

/**
 * \brief Constructs a mutable manifest node with the given id.
 *
 * \param nodeId The id of the new node.
 */
+ (instancetype)nodeWithId:(NSString *)nodeId;



#pragma mark - Properties

/** The name of the node. */
@property (nonatomic) NSString *name;

/** The path of the node. */
@property (nonatomic) NSString *path;

/** The type of the node. */
@property (nonatomic) NSString *type;

/** The id of the node. */
@property (nonatomic) NSString *nodeId;

/** The unique absolute path of the node. Is nil if the node doesn't have a path property.*/
@property (nonatomic) NSString *absolutePath;

/**
 * \brief Sets the value for the named attribute key.
 *
 * \param value The new value of the attribute. Must not be nil.
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
