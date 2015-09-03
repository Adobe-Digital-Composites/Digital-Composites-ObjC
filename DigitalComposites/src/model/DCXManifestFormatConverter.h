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

extern const NSUInteger DCXManifestFormatVersion;

/**
 * \brief Converter for the various versions of manifests.
 */
@interface DCXManifestFormatConverter : NSObject

/**
 * \brief Updates the manifest dictionary dict from the specified version to the current version of the manifest format.
 *
 * \param dict The dictionary containing the manifest.
 * \param fversion The current format version of the manifest.
 * \param errorPtr Gets set to an NSError if the manifest cannot be converted.
 *
 * \return YES is successful.
 */
+ (BOOL)updateManifestDictionary:(NSMutableDictionary *)dict fromVersion:(NSUInteger)fversion withError:(NSError **)errorPtr;
@end
