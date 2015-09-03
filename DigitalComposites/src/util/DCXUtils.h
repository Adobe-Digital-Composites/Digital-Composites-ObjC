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

@interface DCXUtils : NSObject

/**
 * \brief Returns YES if the given string is a valid path property for a component or node.
 *
 * A path is valid if all of its components (derived by splitting it with the forward
 * slash / as a separator) fulfill these criteria:
 * - it must be 1 to 255 characters long
 * - it must not end with a . (dot)
 * - it must not contain any of the following characters
 *  o U+0022 " QUOTATION MARK
 *  o U+002A * ASTERISK
 *  o U+002F / SOLIDUS
 *  o U+003A : COLON
 *  o U+003C < LESS-THAN SIGN
 *  o U+003E > GREATER-THAN SIGN
 *  o U+003F ? QUESTION MARK
 *  o U+005C \ REVERSE SOLIDUS
 *  o The C0 controls, U+0000 through U+001F and U+007F
 *
 * \param path The string to verify.
 *
 * \return YES if the given string is a valid path property for a component or node.
 */
+ (BOOL)isValidPath:(NSString *)path;

/**
 * \brief Wrapper for constructing an object from an NSData object containing JSON.
 *
 * Checks for for nil data pointer in order to avoid unexpected illegal argument exception.
 */
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)errorPtr;

@end
