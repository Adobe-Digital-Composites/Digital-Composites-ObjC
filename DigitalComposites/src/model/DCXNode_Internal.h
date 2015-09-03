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

@class DCXManifest;

@interface DCXNode()

#pragma mark - Initializers

/** The manifest the node is a part of. */
@property (nonatomic, readonly, weak) DCXManifest *manifest;

/**
 * \brief Initializer
 *
 * \param dict        The dictionary to initialize with.
 * \param manifest    The manifest to initialize with.
 * \param parentPath  The parent path of the node.
 */
- (instancetype)initWithDictionary:(NSDictionary *)dict andManifest:(DCXManifest *)manifest
          withParentPath:(NSString *)parentPath;



#pragma mark - Convenience methods

/**
 * \brief Constructs a manifest node from a dictionary containing the properties of the node.
 * This method is used by the DCXManifest constructing a node from a parsed manifest.
 * Notice that the method doesn't check the dictionary for validity.
 *
 * \param nodeDict    The NSDictionary containing the properties of the component.
 * \param manifest    The manifest the node is a descendent of.
 * \param parentPath  The paren path of the node.
 */
+ (instancetype)nodeFromDictionary:(NSDictionary *)nodeDict andManifest:(DCXManifest *)manifest
          withParentPath:(NSString *)parentPath;

@end
