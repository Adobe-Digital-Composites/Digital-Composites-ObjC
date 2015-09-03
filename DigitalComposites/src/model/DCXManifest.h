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
@class DCXMutableComponent;
@class DCXMutableNode;
@class DCXResourceItem;
@class DCXComponent;

/**
 * \class DCXManifest
 * \brief Represents and manages a manifest of a composite.
 */
@interface DCXManifest : NSObject <NSCopying>


#pragma mark - Initializers

/**
 \brief Designated initializer. Intitalizes a manifest from the contents of an
 NSDictionary. Doesn't do any validation of the dictionary other than making
 sure that it has a name and a type.
 
 \param dictionary NSDictionary derived from the JSON model of a manifest file.
 \param errorPtr Gets set if the dictionary passed in is invalid.
 */
- (instancetype)initWithDictionary:(NSMutableDictionary*)dictionary withError:(NSError**)errorPtr;

/**
 \brief Initializes a manifest for a new empty composite.
 
 \param name The name of the composite represented by this manifest.
 \param type The mime type of the composite represented by this manifest.
 */
- (instancetype)initWithName:(NSString*)name andType:(NSString*)type;

/**
 \brief Initializes a manifest from NSData containing the JSON model of a manifest file.
 
 \param data NSData representing the JSON model of a manifest file.
 \param errorPtr Gets set if the data cannot be parsed as valid JSON.
 */
- (instancetype)initWithData:(NSData *)data withError:(NSError**)errorPtr;


#pragma mark - Storage

/** The manifest in serialized form for local storage. */
- (NSData*) localData;

/** The manifest in serialized form for remote storage. */
- (NSData*) remoteData;

/**
 \brief Write the manifest to local storage.
 
 \param path The path of the file to write to.
 \param newSaveId YES if a new manifestSaveId field should be written to the manifest's local section
 \param errorPtr Gets set if something goes wrong.
 */
- (BOOL) writeToFile:(NSString*)path generateNewSaveId:(BOOL)newSaveId withError:(NSError**) errorPtr;

/**
 \brief Remove all service-related data from the manifest so that
 it can be pushed again to the same or a different service.
 
 Removes all service-related links, etags and the service identifier.
 Removes any deleted components.
 Sets states of composite and components to modified.
 
 \note This method doesn't rest the ids of the composite or its
 child nodes/components. Thus if you push the composite to the same
 service again you cannot push it to the same service as long as
 the original composite still exists on that service. If you literally
 want to push this composite as a duplicate of the original composite
 you'll want to call resetIdentity instead.
 */
-(void) resetBinding;

/**
 \brief Assigns new ids to the composite and all of its child nodes and
 components. Also removes service-related data from the manifest so that
 it can be pushed again to the same or a different service.
 
 Removes all service-related links, etags and the service identifier.
 Removes any deleted components.
 Generates new ids for the manifest, children and components.
 Sets states of composite and components to modified.
 */
-(void) resetIdentity;


#pragma mark - Convenience Constructor Methods

/**
 \brief Creates a manifest for a new empty composite.
 
 \param name The name of the composite represented by this manifest.
 \param type The mime type of the composite represented by this manifest.
 */
+ (instancetype)manifestWithName:(NSString*)name andType:(NSString*)type;

/**
 \brief Creates a manifest from a manifest file.
 
 \param path NSString containg the path of the manifest file to read and parse.
 \param errorPtr Gets set if the file cannot be read or the data from the file cannot be parsed as valid JSON.
 */
+ (instancetype)manifestWithContentsOfFile:(NSString*)path withError:(NSError**)errorPtr;


/** Dictionary of all components keyed by component id. Component objects are of type DCXComponent.*/
@property (nonatomic, readonly) NSDictionary *allComponents;

/** Dictionary of all children keyed by node id. Children objects are of type DCXNode.*/
@property (nonatomic, readonly) NSDictionary *allChildren;

/** The modification time of the composite described in the manifest. */
@property (nonatomic, readwrite) NSString *modified;


#pragma mark - Components

/**
 \brief Returns the component with the given absolute path or nil.
 
 \param absPath The absolute path of the requested component.
 
 \return The component with the given absolute path or nil.
 */
-(DCXComponent*) componentWithAbsolutePath:(NSString*)absPath;

/**
 \brief Locates the given component in the manifest and returns its parent which is either
 a DCXNode or the DCXManifest. Returns nil if not found.
 
 \param component The component to return the parent for.
 
 \return The given component in the manifest and returns DCXNode. Returns nil if not found.
 */
-(DCXNode*) findParentOfComponent:(DCXComponent*)component;

/**
 \brief Get the list of components at the root of the manifest
 
 \return An NSArray of DCXComponent objects.
 */
-(NSArray*) components;

/**
 \brief Get the list of components for the specified child node.
 
 \param node The node for which to return the list of components of.
 
 \return An NSArray of DCXComponent objects.
 */
-(NSArray*) componentsOfChild:(DCXNode*)node;

/**
 \brief Update the component specified by component.
 
 \param component The component to update.
 \param errorPtr Optional. Gets set to an error on failure.
 
 \return The updated DCXComponent.
 
 \warning This method makes a shallow copy of the dictionary backing
 the component in order to incorporate it into the manifest. It is the
 caller's responsibility to avoid multipe components sharing the same
 deeper nested data.
 */
-(DCXComponent*) updateComponent:(DCXComponent*)component withError:(NSError**)errorPtr;

/** Add component as a new component to the root-level component list of the manifest.
 
 \param component The component to add.
 \param sourceManifest The source manifest of the component being added
 \param newPath Optional new path.
 \param errorPtr Optional. Gets set to an error on failure.
 
 \return The added DCXComponent.
 
 \warning This method makes a shallow copy of the dictionary backing
 the component in order to incorporate it into the manifest. It is the
 caller's responsibility to avoid multipe components sharing the same
 deeper nested data.
 */
-(DCXComponent*) addComponent:(DCXComponent*)component fromManifest:(DCXManifest*)sourceManifest
                           newPath:(NSString*)newPath withError:(NSError**)errorPtr;

/** Add component as a new component to a specific child node in the manifest.
 
 \param component The component to add.
 \param sourceManifest The source manifest of the component being added
 \param node The node to add the component to.
 \param newPath Optional new path.
 \param errorPtr Optional. Gets set to an error on failure.
 
 \return The added DCXComponent.
 
 \warning This method makes a shallow copy of the dictionary backing
 the component in order to incorporate it into the manifest. It is the
 caller's responsibility to avoid multipe components sharing the same
 deeper nested data.
 */
-(DCXComponent*) addComponent:(DCXComponent*)component fromManifest:(DCXManifest*)sourceManifest
                           toChild:(DCXNode*)node newPath:(NSString*)newPath withError:(NSError**)errorPtr;

-(DCXComponent*) replaceComponent:(DCXComponent *)component fromManifest:(DCXManifest*)sourceManifest withError:(NSError**)errorPtr;

/** Moves the existing component to a different child node.
 
 \param component The component to move.
 \param node The node to move the component to.
 
 \return The moved DCXComponent.
 
 \note Component must already exist within the manifest.
 */
-(DCXComponent*) moveComponent:(DCXComponent*)component toChild:(DCXNode *)node
                          withError:(NSError**)errorPtr;

/** Convenience method to modify the modification state of the component.
 
 \param component The component.
 \param modified Whether the component's state should be modified (YES) or unmodified (NO)
 
 \return The updated DCXComponent.
 */
-(DCXComponent*) setComponent:(DCXComponent*)component modified:(BOOL)modified;

/**
 \brief Returns YES if the component's asset is bound to a resource on the server.
 
 \param component The component.
 */
-(BOOL) componentIsBound:(DCXComponent*)component;

/** Removes the component from the manifest
 
 \param component The component to remove.
 
 \return The deleted DCXComponent.
 */
-(DCXComponent*) removeComponent:(DCXComponent*)component;

/** Removes all components from the manifest and its children
 */
-(void) removeAllComponents;

/** Removes all components from the manifest root level
 */
-(void) removeAllComponentsFromRoot;

/**
 Removes all components from the specified child node.
 
 \param node the node to remove components from
 */
-(void) removeAllComponentsFromChild:(DCXNode*)node;

/**
 \brief Inserts all components descended from the manifest node into resultArray
 
 \param node        A manifest node
 \param resultArray A mutable array into which to insert the resulting components
 */
- (void) componentsDescendedFromParent:(DCXNode *)node intoArray:(NSMutableArray*)resultArray;


#pragma mark - Children (DCXNode)

/**
 \brief Returns the child node with the given absolute path or nil.
 
 \param absPath The absolute path of the requested child node.
 
 \return The child node with the given absolute path or nil.
 */
-(DCXNode*) childWithAbsolutePath:(NSString*)absPath;

/**
 \brief Locates the given child node in the manifest and returns its parent which is either
 a DCXNode or the DCXManifest. Returns nil if not found.
 
 \param component The component to return the parent for.
 
 \return The given component in the manifest and returns DCXNode. Returns nil if not found.
 */
-(DCXNode*) findParentOfChild:(DCXNode*)node foundIndex:(NSUInteger*)index;

/**
 
 \brief Get the list of child nodes at the root of the manifest
 
 \return An NSArray of DCXNode objects.
 */
-(NSArray*) children;

/**
 \brief Get the list of child nodes for the specified node.
 
 \param node The node for which to return the list of child nodes.
 
 \return An NSArray of DCXNode objects.
 */
-(NSArray*) childrenOf:(DCXNode*)node;

/**
 \brief Update the node specified by node.
 
 \param node The node to update.
 
 \return The updated child as a DCXNode.
 
 \warning This method makes a shallow copy of the dictionary backing
 the manifest node in order to incorporate it into the manifest. It is the
 caller's responsibility to avoid multipe components sharing the same
 deeper nested data.
 */
-(DCXNode*) updateChild:(DCXNode*)node withError:(NSError**)errorPtr;

/** Add node as a new child node to the manifest.
 
 \param node The node to add.
 
 \return The added child as a DCXNode.
 
 \warning This method makes a shallow copy of the dictionary backing
 the manifest node in order to incorporate it into the manifest. It is the
 caller's responsibility to avoid multipe components sharing the same
 deeper nested data.
 */
-(DCXNode*) addChild:(DCXNode*)node withError:(NSError**)errorPtr;

/** Add node as a new child node to a node in the manifest.
 
 \param node The node to add.
 \param parentNode The node to add the child node to.
 
 \return The added child as a DCXNode.
 
 \warning This method makes a shallow copy of the dictionary backing
 the manifest node in order to incorporate it into the manifest. It is the
 caller's responsibility to avoid multipe components sharing the same
 deeper nested data.
 */
-(DCXNode*) addChild:(DCXNode*)node toParent:(DCXNode*)parentNode
                        withError:(NSError**)errorPtr;

/** Insert node as a new child node to the manifest at the specified index.
 
 \param node The node to add.
 \param index The index where to add this child node.
 
 \return The added child as a DCXNode.
 
 \warning This method makes a shallow copy of the dictionary backing
 the manifest node in order to incorporate it into the manifest. It is the
 caller's responsibility to avoid multipe components sharing the same
 deeper nested data.
 */
-(DCXNode*) insertChild:(DCXNode*)node atIndex:(NSUInteger)index
                           withError:(NSError**)errorPtr;

/** Insert node as a new child node to a node in the manifest at the specified index.
 
 \param node The node to add.
 \param parentNode The node to add the child node to.
 \param index The index where to add this child node.
 
 \return The added child as a DCXNode.
 
 \warning This method makes a shallow copy of the dictionary backing
 the manifest node in order to incorporate it into the manifest. It is the
 caller's responsibility to avoid multipe components sharing the same
 deeper nested data.
 */
-(DCXNode*) insertChild:(DCXNode*)node parent:(DCXNode*)parentNode
                             atIndex:(NSUInteger)index withError:(NSError**)errorPtr;

/** Insert the complete node from a different manifest of the same composite as a new child node to
 a node in the manifest at the specified index.
 
 \param node            The node to add.
 \param parentNode      The node to add the child node to.
 \param index           The index where to add this child node.
 \param replaceExisting If YES then the existing node will get replaced (parentNode and index will get ignored)
 \param newPath         Optional. The new path for the node.
 \param addedComponents Optional NSMutableArray of the new components that have been added.
 \param removedComponents Optional NSMutableArray of the component that have been removed.
 \param errorPtr        Gets set to an error if something goes wrong.
 
 \return The added child as a DCXNode.
 
 \warning This method makes a shallow copy of the dictionary backing
 the manifest node in order to incorporate it into the manifest. It is the
 caller's responsibility to avoid multipe components sharing the same
 deeper nested data.
 */
-(DCXNode*) insertChild:(DCXNode*)node fromManifest:(DCXManifest*)manifest
                              parent:(DCXNode*)parentNode atIndex:(NSUInteger)index
                     replaceExisting:(BOOL)replaceExisting
                             newPath:(NSString *)newPath
                         forceNewIds:(BOOL)forceNewIds
                     addedComponents:(NSMutableArray *)addedComponents
                addedComponentOrgIds:(NSMutableArray *)addedComponentOrgIds
                   removedComponents:(NSMutableArray *)removedComponents
                           withError:(NSError**)errorPtr;

/** Moves the existing child node to the manifest at the specified index.
 
 \param node        The node to move.
 \param index       The index where to move this child to.
 \param errorPtr    Gets set to an error if something goes wrong.
 
 \return            The moved child as a DCXNode.
 */
-(DCXNode*) moveChild:(DCXNode*)node toIndex:(NSUInteger)index
                         withError:(NSError**)errorPtr;

/** Moves the existing child node to a node in the manifest at the specified index.
 
 \param node        The node to move.
 \param parentNode  The node to move the child node to.
 \param index       The index where to move this child node to.
 \param errorPtr    Gets set to an error if something goes wrong.
 
 \return            The moved child as a DCXNode.
 
 */
-(DCXNode*) moveChild:(DCXNode*)node toParent:(DCXNode*)parentNode
                           toIndex:(NSUInteger)index withError:(NSError**)errorPtr;

/** Removes the node from the manifest.
 
 \param node The node to remove.
 \param removedComponents Optional NSMutableArray of the component that have been removed.
 
 \return The removed child as a DCXNode.
 */
-(DCXNode*) removeChild:(DCXNode*)node removedComponents:(NSMutableArray*)removedComponents;

/** Removes all children from the manifest.
 \param removedComponents Optional NSMutableArray of the component that have been removed.
 */
-(void) removeAllChildrenWithRemovedComponents:(NSMutableArray*)removedComponents;

/** Removes all children from the child node.
 
 \param node The node to remove all children from.
 \param removedComponents Optional NSMutableArray of the component that have been removed.
 
 */
-(void) removeAllChildrenFromParent:(DCXNode*)node removedComponents:(NSMutableArray*)removedComponents;

/**
 \brief A date formatter for dates in the manifest
 */
+ (NSDateFormatter*)dateFormatter;

/**
 Parses RFC3339 dates as they appear in the manifest.
 */
+ (NSDate *)parseDate:(NSString*)dateStr;

/**
 \brief The absolute index of the manifest node within the hierarchy for child nodes of the
 manifest.
 
 \param node The manifest node of
 
 \return The absolute index of the manifest node within the hierarchy for child nodes of the
 manifest. NSNotFound if the node is not a child of this manifest.
 */
-(NSUInteger) absoluteIndexOf:(DCXNode*)node;

-(NSMutableArray*) verifyIntegrityWithLogging:(BOOL)doLog withBranchName:(NSString*)name;

/**
 \brief This returns an Array of elements which is specific to the Manifest dictionary.
 These are the values which will be used to construct the manifest dictionary. These will also
 be consulted when constructing Root Node of the manifest (i.e. these props will NOT be included in
 the root node dictionary )
 */
+ (NSArray*) manifestSpecificProperties;


#pragma mark - Properties


/** The id of the composite described in the manifest. */
@property (nonatomic) NSString *compositeId;

/** The name of the composite described in the manifest. */
@property (nonatomic) NSString *name;

/** The mime type of the composite described in the manifest. */
@property (nonatomic) NSString *type;

/** The links of the manifest. */
@property (nonatomic) NSDictionary *links;

/** The state of the composite. */
@property (nonatomic) NSString *compositeState;

/** The etag of the manifest asset on the server. */
@property (nonatomic) NSString *etag;

/** The href of the composite on the server. */
@property (nonatomic) NSString *compositeHref;

/** Is YES if the manifest has in-memory changes that haven't been committed to local storage yet. */
@property (nonatomic) BOOL isDirty;

/** Is YES if the manifest is bound to a specific composite on the server. */
@property (nonatomic, readonly) BOOL isBound;

/** A unique ID that is updated whenever the writeToFile method is called
 * with the generateNewSaveId parameter set to YES.
 */
@property (nonatomic, readonly) NSString *saveId;

/** Reference to the root node of the manifest */
@property (nonatomic, readonly) DCXMutableNode *rootNode;

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

/**
 * \brief Sets the value for the named attribute key.
 *
 * \param value The new value of the attribute. Must not be nil.
 * \param key The name of the attribute.
 */
- (void)setValue:(id)value forKey:(NSString *)key;

/**
 * \brief Removes a named attribute from the manifest. Use this to remove attributes
 * that are not exposed as separate properties.
 *
 * \param key The name of the attribute.
 */
- (void)removeValueForKey:(NSString *)key;

@end
