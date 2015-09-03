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

#import "DCXConstants.h"

#pragma mark - Manifest Keys

/** The 'id' key */
extern NSString *const DCXIdManifestKey;
/** The 'name' key */
extern NSString *const DCXNameManifestKey;
/** The 'type' key */
extern NSString *const DCXTypeManifestKey;
/** The 'created' key */
extern NSString *const DCXCreatedManifestKey;
/** The 'modified' key */
extern NSString *const DCXModifiedManifestKey;
/** The 'state' key */
extern NSString *const DCXStateManifestKey;
/** The 'etag' key */
extern NSString *const DCXEtagManifestKey;
/** The 'path' key */
extern NSString *const DCXPathManifestKey;
/** The 'rel' key */
extern NSString *const DCXRelationshipManifestKey;
/** The 'width' key */
extern NSString *const DCXWidthManifestKey;
/** The 'height' key */
extern NSString *const DCXHeightManifestKey;
/** The 'components' collection */
extern NSString *const DCXComponentsManifestKey;
/** The 'children' collection */
extern NSString *const DCXChildrenManifestKey;
/** The '_links' collection */
extern NSString *const DCXLinksManifestKey;
/** The content length in a manifest */
extern NSString *const DCXLengthManifestKey;
/** The version number in a manifest */
extern NSString *const DCXVersionManifestKey;

/** A place to store local data */
extern NSString *const DCXLocalDataManifestKey;
/** The version of the format of the local node */
extern NSString *const DCXLocalVersionManifestKey;
/** The local storage asset id of a component */
extern NSString *const DCXLocalStorageAssetIdMapManifestKey;
/** The href of the composite */
extern NSString *const DCXCompositeHrefManifestKey;
/** The etag of the manifest */
extern NSString *const DCXManifestEtagManifestKey;
/** The collaboration type of the composite on the server */
extern NSString *const DCXCollaborationManifestKey;
/** A unique ID generated for each save of the manifest file */
extern NSString *const DCXManifestSaveIdManifestKey;

/** The mime type of a manifest */
extern NSString *const DCXManifestType;

#pragma mark - Other

/** The name for the manifest in a document collection */
extern NSString *const DCXManifestName;
