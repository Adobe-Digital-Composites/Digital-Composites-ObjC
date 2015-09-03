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

#import "DCXBranch.h"

/**
 * Gives read-write access to the DOM of a specific branch of a composite.
 */
@interface DCXMutableBranch : DCXBranch


/** The name of the composite described in the manifest. */
@property (nonatomic) NSString *name;

/** The mime type of the composite described in the manifest. */
@property (nonatomic) NSString *type;

/** The links of the manifest. */
@property (nonatomic) NSDictionary *links;

/** The etag of the composite branch. Can be nil for a new composite. */
@property (nonatomic) NSString *etag;

/** Is YES if the branch has in-memory changes that haven't been committed to local storage yet. */
@property (nonatomic, readonly) BOOL isDirty;

/**
 * \brief Sets the value for the named attribute key.
 *
 * \param value The new value of the attribute. Must not be nil.
 * \param key The name of the attribute.
 */
- (void)setValue:(id)value forKey:(NSString *)key;

/**
 * \brief Removes a named attribute from the branch. Use this to remove attributes
 * that are not exposed as separate properties.
 *
 * \param key The name of the attribute.
 */
- (void)removeValueForKey:(NSString *)key;

/**
 * \brief Marks the composite for deletion by setting its compositeState property to DCXAssetStatePendingDelete
 *
 * \note Throws an NSInternalInconsistencyException if the current compositeState is DCXAssetStateCommittedDelete,
 * which indicates that the composite has already been deleted from the server
 */
- (void)markCompositeForDeletion;

#pragma mark - Components

/**
 * \brief Add the file sourceFile as a component to the composite branch by copying or moving it to the
 * appropriate location in local storage and adding it to the manifest. The compositeState of the
 * manifest will be marked as modified but the changed manifest will not be written to
 * local storage. Use commitChangesWithError: to persist your changes to local storage once
 * your are done modifying the composite branch.
 *
 * \param name        The name of the component.
 * \param componentId The id of the component. Can be nil in which case a UUID will be generated.
 * \param type        The type of the component.
 * \param rel         The relationship of the component. Can be nil.
 * \param path        The path of the component relative to the component directory. Must not be nil.
 *                  Note that for local storage schemes other than DCXLocalStorageSchemeDirectories
 *                  this path does not specify the actual path to the component on the local filesystem.
 * \param node        The child node to add the new component to. Can be nil.
 * \param sourceFile  The path of the asset file for the component. Must not be nil.
 * \param copy        If YES the file gets copied, if NO it gets moved and renamed.  Ignored if sourceFile
 *                  refers to the current component location defined by the local storage scheme.
 *
 * \param errorPtr    Gets set if an error occurs while copying the asset file.
 *
 * \return            The new component.
 */
- (DCXComponent *)addComponent:(NSString *)name withId:(NSString *)componentId withType:(NSString *)type
                   withRelationship:(NSString *)rel withPath:(NSString *)path
                            toChild:(DCXNode *)node
                           fromFile:(NSString *)sourceFile copy:(BOOL)copy
                          withError:(NSError **)errorPtr;


/**
 * \brief Add the file sourceFile as a component to the composite branch by copying or moving it to the
 * appropriate location in local storage and adding it to the manifest.  If specified, sourceHref identifies
 * the server resource that can provide the component, although the resource will not be accessed until
 * the composite is pushed or the component is explicitly downloaded.
 * At least one of the sourceFile and sourceHref parameters must be specified. If both sourceFile and sourceHref
 * are specified then they are expected to refer to the same file although this is not verified.
 * The compositeState of the manifest will be marked as modified but the changed manifest will not be written to
 * local storage. Use commitChangesWithError: to persist your changes to local storage once
 * your are done modifying the composite branch.
 *
 * \param component   The component object.
 * \param node        The child node to add the new component to. Can be nil.
 * \param sourceFile  The path of the asset file for the component. May be nil only if sourceHref is not nil.
 * Note that for local storage schemes other than DCXLocalStorageSchemeDirectories
 * this path does not specify the actual path to the component on the local filesystem.
 *
 * \param copy        If YES the file gets copied, if NO it gets moved and renamed.  Ignored if sourceFile
 * refers to the current component location defined by the local storage scheme.
 *
 * \param errorPtr    Gets set if an error occurs while copying the asset file.
 *
 * \return            The new component.
 */
- (DCXComponent *)addComponent:(DCXComponent *)component
                            toChild:(DCXNode *)node
                           fromFile:(NSString *)sourceFile copy:(BOOL)copy
                          withError:(NSError **)errorPtr;


/**
 * \brief Update the the component by copying or moving sourceFile to the appropriate location
 * in local storage and updating the component record. The compositeState of the
 * manifest will be marked as modified but the changed manifest will not be written to
 * local storage. Use commitChangesWithError: to persist your changes to local storage once
 * your are done modifying the composite.
 *
 * \param component   The component.
 * \param sourceFile  The asset file for the component. Can be nil in which case only the properties of
 *                  the component will be updated.
 * \param copy        If YES the file gets copied, if NO it gets moved and renamed.
 * \param errorPtr    Gets set if an error occurs while copying the asset file.
 *
 * \return            The updated component.
 */
- (DCXComponent *)updateComponent:(DCXComponent *)component
                              fromFile:(NSString *)sourceFile copy:(BOOL)copy
                             withError:(NSError **)errorPtr;

/** Moves the existing component to a different child node.
 *
 * \param component   The component to move.
 * \param node        The node to move the component to. If nil the component will get moved to the root level.
 * \param errorPtr    Gets set in the case of a failure.
 *
 * \return            The moved DCXComponent or nil in the case of a failure.
 *
 * \note Component must already exist within the branch.
 */
- (DCXComponent *)moveComponent:(DCXComponent *)component toChild:(DCXNode *)node
                           withError:(NSError **)errorPtr;

/** Copies the existing component from a different composite branch to the specified
 * child node. Fails if it already exists in this branch.
 *
 * \param component   The component to copy.
 * \param branch      The branch that contains the component. May be a branch on either the same or a different composite.
 * \param node        The node to copy the component to. If nil the component will get copied to the root level.
 * \param errorPtr    Gets set in the case of a failure.
 *
 * \return            The copied DCXComponent or nil in the case of a failure.
 */
- (DCXComponent *)copyComponent:(DCXComponent *)component from:(DCXBranch *)branch
                             toChild:(DCXNode *)node withError:(NSError **)errorPtr;

/** Copies the existing component from a different composite branch to the specified
 * child node. Assigns newPath to the path property of the component and also assigns a new id to it.
 *
 * \param component   The component to copy.
 * \param branch      The branch that contains the component. May be a branch on either the same or a different composite.
 * \param node        The node to copy the component to. If nil the component will get copied to the root level.
 * \param newPath     The new path for the component.
 * \param errorPtr    Gets set in the case of a failure.
 *
 * \return            The copied DCXComponent or nil in the case of a failure.
 */
- (DCXComponent *)copyComponent:(DCXComponent *)component from:(DCXBranch *)branch
                             toChild:(DCXNode *)node newPath:(NSString *)newPath
                           withError:(NSError **)errorPtr;

/** Updates the existing component from a different branch of the same composite in place. Fails if
 * it the component doesn't exist in this branch.
 *
 * \param component   The component to copy.
 * \param branch      The branch that contains the component. Must be a branch on the same composite.
 * \param errorPtr    Gets set in the case of a failure.
 *
 * \return            The copied DCXComponent or nil in the case of a failure.
 */
- (DCXComponent *)updateComponent:(DCXComponent *)component from:(DCXBranch *)branch
                             withError:(NSError **)errorPtr;

/**
 * \brief Removes the component from the branch.
 *
 * \param component   The component to remove.
 *
 * \return            The removed component.
 */
- (DCXComponent *)removeComponent:(DCXComponent *)component;

#pragma mark - Child Nodes

/**
 * \brief Update the node specified by node.
 *
 * \param node    The node to update.
 *
 * \return        The updated node.
 *
 * \warning This method makes a shallow copy of the dictionary backing the manifest node in order to
 * incorporate it into the manifest. It is the caller's responsibility to avoid multipe components
 * sharing the same deeper nested data.
 */
- (DCXNode *)updateChild:(DCXNode *)node withError:(NSError **)errorPtr;

/**
 * \brief Add node as a new child node at the end of the list of children of parent node.
 *
 * \param node        The node to add.
 * \param parentNode  The node to add the child node to. Can be nil in which case the node will be added
 *                  to the list of children at the root of the manifest.
 * \return            The added node.
 *
 * \warning This method makes a shallow copy of the dictionary backing the manifest node in order to
 * incorporate it into the manifest. It is the caller's responsibility to avoid multipe components
 * sharing the same deeper nested data.
 */
- (DCXNode *)addChild:(DCXNode *)node toParent:(DCXNode *)parentNode
                         withError:(NSError **)errorPtr;

/**
 * \brief Insert node as a new child node into the list of children of parent node at the given index.
 *
 * \param node        The node to insert.
 * \param parentNode  The node whose children list to insert the child node into. Can be nil in which
 *                  case the node will be inserted into the list of children at the root of the manifest.
 * \param index       The index where to add this child node.
 *
 * \return            The inserted child.
 *
 * \warning This method makes a shallow copy of the dictionary backing the manifest node in order to
 * incorporate it into the manifest. It is the caller's responsibility to avoid multipe components
 * sharing the same deeper nested data.
 */
- (DCXNode *)insertChild:(DCXNode *)node parent:(DCXNode *)parentNode
                              atIndex:(NSUInteger)index withError:(NSError **)errorPtr;

/**
 * \brief Moves a node from its current parent/index to a new parent/index.
 *
 * \param node        The node to move.
 * \param parentNode  The node whose children list to move the child node to. Can be nil in which
 *                  case the node will be move to the list of children at the root of the manifest.
 * \param index       The index where to add this child node.
 *
 * \return            The moved child.
 *
 * \note              node must already be a child node of the branch.
 */
- (DCXNode *)moveChild:(DCXNode *)node toParent:(DCXNode *)parentNode
                            toIndex:(NSUInteger)index withError:(NSError **)errorPtr;

/**
 * \brief Copies the node including all its components and sub nodes from the specified composite branch
 * to the specified parent/index. Fails if the node already exists in this branch.
 *
 * \param node        The node to copy.
 * \param branch      The branch containing the node. May be on the same or a different composite.
 * \param parentNode  The node whose children list to copy the child node to. Can be nil in which
 *                  case the node will be copied to the list of children at the root of the manifest.
 * \param index       The index where to add this child node.
 * \param errorPtr    Gets set in the case of a failure.
 *
 * \return            The copied child or nil in the case of a failure.
 *
 * \note copyChild may only be called on composites using the copy-on-write local storage scheme.
 */
- (DCXNode *)copyChild:(DCXNode *)node from:(DCXBranch *)branch
                           toParent:(DCXNode *)parentNode toIndex:(NSUInteger)index
                          withError:(NSError **)errorPtr;

/**
 * \brief Copies the node including all its components and sub nodes from the specified composite branch
 * to the specified parent/index. Assigns the given newPath as the path of the new
 * child node and ensures that all copied nodes and components get new ids.
 *
 * \param node        The node to copy.
 * \param branch      The branch containing the node. May be on the same or a different composite.
 * \param parentNode  The node whose children list to copy the child node to. Can be nil in which
 *                  case the node will be copied to the list of children at the root of the manifest.
 * \param index       The index where to add this child node.
 * \param newPath     The new path for the child node.
 * \param errorPtr    Gets set in the case of a failure.
 *
 * \return            The copied child or nil in the case of a failure.
 *
 * \note copyChild may only be called on composites using the copy-on-write local storage scheme.
 */
- (DCXNode *)copyChild:(DCXNode *)node from:(DCXBranch *)branch
                           toParent:(DCXNode *)parentNode toIndex:(NSUInteger)index
                           withPath:(NSString *)newPath withError:(NSError **)errorPtr;

/**
 * \brief Updates the node including all its components and sub nodes from the specified branch of the
 * same composite. Fails if the node doesn't exist in this branch.
 *
 * \param node        The node to update. Must be a node from branch.
 * \param branch      The branch containing the node. Must be on the same composite.
 * \param errorPtr    Gets set in the case of a failure.
 *
 * \return            The updated child node or nil in the case of a failure.
 *
 * \note This version of updateChild may only be called on composites using the copy-on-write local storage scheme.
 */
- (DCXNode *)updateChild:(DCXNode *)node from:(DCXBranch *)branch
                            withError:(NSError **)errorPtr;

/** Removes the node from the manifest.
 *
 * \param node The node to remove.
 *
 * \return The removed child as a DCXNode.
 */
- (DCXNode *)removeChild:(DCXNode *)node;

@end
