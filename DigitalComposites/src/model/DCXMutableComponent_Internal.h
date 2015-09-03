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

#import "DCXMutableComponent.h"

@interface DCXMutableComponent()

/**
 * \brief Initializes with a mutable dictionary containing the properties of the component.
 * Notice that the initializer doesn't check the dictionary for validity.
 *
 * \param compDict    The NSMutableDictionary containing the properties of the component.
 * \param manifest    The DCXManifest that conatins the component.
 * \param parentPath  The paren path of the component.
 *
 * \note  The path does not refer to the actual file path of the component on disk.
 * However, if the path contains a valid file extension then this will be preserved when
 * constructing the file's actual path on disk.
 */
- (instancetype)initWithDictionary:(NSMutableDictionary *)compDict andManifest:(DCXManifest *)manifest
          withParentPath:(NSString *)parentPath;

@end
