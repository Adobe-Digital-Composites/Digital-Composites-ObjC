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

NSString *const DCXManifestType             = @"application/vnd.adobe.dcx-manifest+json";

// Keys used in a manifest
NSString *const DCXIdManifestKey            = @"id";
NSString *const DCXNameManifestKey          = @"name";
NSString *const DCXTypeManifestKey          = @"type";
NSString *const DCXCreatedManifestKey       = @"created";
NSString *const DCXModifiedManifestKey      = @"modified";
NSString *const DCXStateManifestKey         = @"state";
NSString *const DCXEtagManifestKey          = @"etag";
NSString *const DCXPathManifestKey          = @"path";
NSString *const DCXRelationshipManifestKey  = @"rel";
NSString *const DCXWidthManifestKey         = @"width";
NSString *const DCXHeightManifestKey        = @"height";
NSString *const DCXComponentsManifestKey    = @"components";
NSString *const DCXChildrenManifestKey      = @"children";
NSString *const DCXLinksManifestKey         = @"_links";
NSString *const DCXHrefManifestKey          = @"href";
NSString *const DCXLengthManifestKey        = @"length";
NSString *const DCXVersionManifestKey       = @"version";

NSString *const DCXLocalDataManifestKey     = @"local";
NSString *const DCXLocalVersionManifestKey  = @"version";
NSString *const DCXLocalStorageAssetIdMapManifestKey  = @"copyOnWrite#storageIds";
NSString *const DCXCompositeHrefManifestKey = @"compositeHref";
NSString *const DCXManifestEtagManifestKey  =  @"manifestEtag";
NSString *const DCXManifestSaveIdManifestKey = @"manifestSaveId";

// States for components/documents in DCXManifests
NSString * const DCXAssetStateUnmodified        = @"unmodified";
NSString * const DCXAssetStateModified          = @"modified";
NSString * const DCXAssetStatePendingDelete     = @"pendingDelete";
NSString * const DCXAssetStateCommittedDelete   = @"committedDelete";

// other
NSString *const DCXManifestName             = @"manifest";

