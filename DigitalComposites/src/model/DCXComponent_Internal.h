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

@interface DCXComponent()

/** The manifest the component is a part of. */
@property (nonatomic, readonly, weak) DCXManifest *manifest;

#pragma mark - Initializers

/**
 * \brief Initializes with a dictionary containing the properties of the component.
 * This initializer is used when constructing a component from a parsed manifest.
 * Notice that the initializer doesn't check the dictionary for validity.
 *
 * \param compDict    The NSDictionary containing the properties of the component.
 * \param manifest    The DCXManifest that conatins the component.
 * \param parentPath  The paren path of the component.
 */
- (instancetype)initWithDictionary:(NSDictionary *)compDict andManifest:(DCXManifest *)manifest
          withParentPath:(NSString *)parentPath;


#pragma mark - Convenience methods

/**
 * \brief Constructs a component from a dictionary containing the properties of the component.
 * This method is used by DCXManifest when constructing one of its components.
 * Notice that the method doesn't check the dictionary for validity.
 *
 * \param compDict    The NSDictionary containing the properties of the component.
 * \param manifest    The DCXManifest that conatins the component.
 * \param parentPath  The paren path of the component.
 */
+ (instancetype)componentFromDictionary:(NSDictionary *)compDict andManifest:(DCXManifest *)manifest
               withParentPath:(NSString *)parentPath;

#pragma mark - Properties

/** The dictionary that was used to construct this component. */
@property (nonatomic, readonly) NSDictionary *dict;

@end
