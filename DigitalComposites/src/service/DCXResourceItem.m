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

#import "DCXResourceItem.h"

#import "DCXError.h"
#import "DCXErrorUtils.h"

@implementation DCXResourceItem

+ (instancetype)resourceFromHref:(NSString *)href
{
    DCXResourceItem *resource = [[DCXResourceItem alloc] init];

    resource.href = href;
    resource.name = [[href lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return resource;
}

+ (NSString *)escapeAssetName:(NSString *)asset
{
    if (asset == nil)
    {
        return asset;
    }

    // Percent-escape everything except: ALPHA | DIGIT | "-" | "." | "_" | "~"
    NSMutableCharacterSet *unreservedChars = [[NSCharacterSet characterSetWithCharactersInString:@"-._~"] mutableCopy];
    [unreservedChars formUnionWithCharacterSet:[NSCharacterSet uppercaseLetterCharacterSet]];
    [unreservedChars formUnionWithCharacterSet:[NSCharacterSet lowercaseLetterCharacterSet]];
    [unreservedChars formUnionWithCharacterSet:[NSCharacterSet decimalDigitCharacterSet]];

    asset = [asset stringByAddingPercentEncodingWithAllowedCharacters:unreservedChars];
    return asset;
}

+ (BOOL)validAssetName:(NSString *)asset
{
    NSRange range;
    NSError *error = nil;

    // Asset must not contain \ : * ? " / < > | or ASCII x00 - x1F, or end with . or <space>

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[\\\\:\\*\\?\"\\/<>\\|\x00-\x1F]+|[\\ \\.]$"
                                                                           options:NSRegularExpressionAnchorsMatchLines
                                                                             error:&error];

    if (!error)
    {
        range = [regex rangeOfFirstMatchInString:asset options:0 range:NSMakeRange(0, [asset length])];
    }
    else
    {
        return NO;      // On error return asset name is invalid.
    }

    return NSEqualRanges(range, NSMakeRange(NSNotFound, 0));
}

+ (instancetype)resourceWithContentsOfFile:(NSString *)path andContentType:(NSString *)type withError:(NSError **)errorPtr
{
    DCXResourceItem *resource = [[DCXResourceItem alloc] init];

    resource.type = type;
    resource.data = [[NSFileManager defaultManager] contentsAtPath:path];
    resource.path = path;
    return resource.data != nil ? resource : nil;
}

+ (instancetype)resourceWithJSONData:(id)jsonData andContentType:(NSString *)type withError:(NSError **)errorPtr
{
    DCXResourceItem *resource = [[DCXResourceItem alloc] init];

    resource.type = type;
    resource.data = [NSJSONSerialization dataWithJSONObject:jsonData options:0 error:errorPtr];
    return resource.data != nil ? resource : nil;
}

+ (instancetype)resourceWithJSONData:(id)jsonData withError:(NSError **)errorPtr
{
    return [self resourceWithJSONData:jsonData andContentType:nil withError:errorPtr];
}

- (BOOL)isCollection
{
    return NO;
}

#pragma mark NSCopying protocol

- (instancetype)copyWithZone:(NSZone *)zone
{
    DCXResourceItem *copy = [super copyWithZone:zone];

    copy->_data = [_data copy];
    copy->_path = [_path copy];
    copy->_length = [_length copy];
    copy->_version = [_version copy];
    return copy;
}

@end
