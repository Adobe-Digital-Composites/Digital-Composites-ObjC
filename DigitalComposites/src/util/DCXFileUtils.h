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
 * \brief File-related utilities.
 */
@interface DCXFileUtils : NSObject

/**
 * \brief Moves a file atomically to a new path, replacing an already existing file. Create the
 * necessary directories.
 *
 * \param sourcePath The file to move.
 * \param destPath The destination path.
 * \param errorPtr Gets set to an error if something goes wrong.
 *
 * \return YES if successful.
 */

+ (BOOL)moveFileAtomicallyFrom:(NSString *)sourcePath to:(NSString *)destPath withError:(NSError **)errorPtr;

/**
 * \brief Updates the modification date of the file at filePath
 *
 * \param filePath    The path to the file whose mod date should get updated.
 * \param errorPtr    Gets set to an error if something goes wrong.
 *
 * \return            YES if successful.
 */

+ (BOOL)touch:(NSString *)filePath withError:(NSError **)errorPtr;

@end
