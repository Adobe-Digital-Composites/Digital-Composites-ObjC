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

#import "DCXResource.h"

/**
 * \class DCXResourceItem
 * \brief Represents an individual resource that resides on the server.
 */
@interface DCXResourceItem : DCXResource<NSCopying>

/**
 * \brief Creates a resource pointing to an href.
 *
 * \param href The path of the resource on the server.  The caller is responsible for properly percent-escaping
 * the path components.  See RFC 3986 specifications, sections 2.2 and 2.3.
 *
 * \return The newly created resource.
 */
+ (instancetype)resourceFromHref:(NSString *)href;

/**
 * \brief Percent-espace characters in an asset name
 *
 * \param asset Input string, typically a path component to a resource on the server.  Characters other
 * than "unreserved" (ALPHA | DIGIT | - | . | _ | ~) are percent-escaped.  See RFC 3986 spec, Section 2.3.
 *
 * \return Updated asset string
 */
+ (NSString *)escapeAssetName:(NSString *)asset;

/**
 * \brief Validate asset name
 *
 * \param asset Input string, typically a path component to a resource on the server.  The method validates that
 * the string conforms to the server naming conventions.  The method expects an unescaped asset name string.
 *
 * \return Whether the asset input string is valid.
 */
+ (BOOL)validAssetName:(NSString *)asset;

/**
 * Initialize a resource object from data on disk, plus a known content type.
 * Typically, the content type is recorded in the associated manifest.
 *
 * \param path the path of the file
 * \param type the content type
 * \param errorPtr the error to set
 */
+ (instancetype)resourceWithContentsOfFile:(NSString *)path andContentType:(NSString *)type withError:(NSError **)errorPtr;

/**
 * Initialize a resource object from JSON data with a default content type of "application/json"
 *
 * \param jsonData the json data
 * \param errorPtr the error to set
 */
+ (instancetype)resourceWithJSONData:(id)jsonData withError:(NSError **)errorPtr;

/**
 * Initialize a resource object from JSON data.
 *
 * \param jsonData the json data
 * \param type the content type
 * \param errorPtr the error to set
 */
+ (instancetype)resourceWithJSONData:(id)jsonData andContentType:(NSString *)type withError:(NSError **)errorPtr;


/** The bytes that compose this resource. */
@property (nonatomic) NSData *data;

/** The path to the local file representing the resource. */
@property (nonatomic) NSString *path;

/** The content length of this resource. */
@property (nonatomic) NSNumber *length;

/** The version number of this resource. */
@property (nonatomic) NSString *version;

@end
