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

@class DCXNode;
@class DCXComponent;

/**
 * Gives read-only access to the DOM of a specific branch of a composite.
 */

@interface DCXBranch : NSObject <NSMutableCopying>

/** The name of the composite described in the manifest. */
@property (nonatomic, readonly) NSString *name;

/** The mime type of the composite described in the manifest. */
@property (nonatomic, readonly) NSString *type;

/** The links of the manifest. */
@property (nonatomic, readonly) NSDictionary *links;

/** The state of the composite. */
@property (nonatomic, readonly) NSString *compositeState;

/** The etag of the composite branch. Can be nil for a new composite. */
@property (nonatomic, readonly) NSString *etag;

/** The immutable rootNode of the underlying manifest. */
@property (nonatomic, readonly) DCXNode *rootNode;

/**
 * \brief Returns the value of a named attribute of the node or nil if the attribute
 * doesn't exist. Use this to access attributes that are not exposed as properties.
 *
 * \param key The name of the attribute.
 *
 * \return The value of the attribute.
 */
- (id)valueForKey:(NSString *)key;

#pragma mark - Components

/**
 * \brief Returns the list of components for the specified child node.
 *
 * \param node    The node for which to return the list of components of. Can be nil in which case the
 *              list of components of the root-level of the manifest will be returned.
 *
 * \return        An NSArray of DCXComponent objects which can be empty if the provided node doesn't
 *              have any components.
 */
- (NSArray *)getComponentsOf:(DCXNode *)node;


/**
 * \brief Returns the component with the given id or nil if it doesn't exist.
 *
 * \param componentId     The id of the requested component.
 *
 * \return                The component with the given id or nil if it doesn't exist.
 */
- (DCXComponent *)getComponentWithId:(NSString *)componentId;

/**
 * \brief Returns the component with the given absolute path or nil.
 *
 * \param absPath The absolute path of the requested component.
 *
 * \return The component with the given absolute path or nil.
 */
- (DCXComponent *)getComponentWithAbsolutePath:(NSString *)absPath;

/**
 * \brief Locates the given component in the manifest and returns the parent DCXNode.
 * Returns nil if not found.
 *
 * \param component The component to return the parent for.
 *
 * \return The DCXNode that is the parent of component. Returns nil if not found.
 */
- (DCXNode *)findParentOfComponent:(DCXComponent *)component;

/**
 * \brief         Returns the list of all components referred to by the manifest of this composite branch.
 *
 * \return        An NSArray of DCXComponent objects which can be empty if the composite does not have any components.
 */
- (NSArray *)getAllComponents;



/**
 * \brief Returns the file path of the local file asset of the given component in the composite branch.
 *
 * \param component   The component to get the path for.
 * \param errorPtr    Optional pointer to an NSError that gets set if the path of the component is invalid.
 *
 * \return            The file path of the local file asset of the given component or nil if it hasn't been pulled
 * yet or if it is not valid (errorPtr != nil).
 */
- (NSString *)pathForComponent:(DCXComponent *)component withError:(NSError **)errorPtr;


#pragma mark - Child Nodes

/**
 * \brief Get the list of child nodes for the specified node.
 *
 * \param node The node for which to return the list of child nodes.  Can be nil in which case the
 * list of children of the root-level of the manifest will be returned.
 *
 * \return An NSArray of DCXNode objects which can be empty if the provided node doesn't
 * have any children.
 */
- (NSArray *)getChildrenOf:(DCXNode *)node;

/**
 * \brief Returns the child node with the given id or nil if it node doesn't exist.
 *
 * \param componentId The id of the requested child node.
 *
 * \return The child node with the given id or nil if it doesn't exist.
 */
- (DCXNode *)getChildWithId:(NSString *)nodeId;

/**
 * \brief Returns the child node with the given absolute path or nil.
 *
 * \param absPath The absolute path of the requested child node.
 *
 * \return The child node with the given absolute path or nil.
 */
- (DCXNode *)getChildWithAbsolutePath:(NSString *)absPath;

/**
 * \brief Locates the given child node in the manifest and returns its parent the parent DCXNode.
 * Returns nil if not found.
 *
 * \param component The component to return the parent for.
 *
 * \return The DCXNode that is the parent of child. Returns nil if not found.
 */
- (DCXNode *)findParentOfChild:(DCXNode *)node foundIndex:(NSUInteger *)index;

@end
