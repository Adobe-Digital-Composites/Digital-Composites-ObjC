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

@implementation DCXResource

#pragma mark NSCopying protocol

- (instancetype)copyWithZone:(NSZone *)zone
{
    DCXResource *copy = [[[self class] allocWithZone:zone] init];

    copy->_href = [_href copy];
    copy->_name = [_name copy];
    copy->_type = [_type copy];
    copy->_etag = [_etag copy];
    copy->_isCollection = _isCollection;
    copy->_created = [_created copy];
    copy->_modified = [_modified copy];

    return copy;
}

// These two methods cause that two resources are considered equal if they have the same href. This
// allows us to efficiently store and find resources in collections.

- (BOOL)isEqual:(id)other
{
    if (other == self)
    {
        return YES;
    }

    if (!other || ![other isKindOfClass:[self class]])
    {
        return NO;
    }

    return [self->_href isEqualToString:((DCXResource *)other)->_href];
}

- (NSUInteger)hash
{
    return [self.href hash];
}

- (NSString *)description
{
    NSDictionary *dict = @{
        @"internal-id": (self.internalID) ? self.internalID : @"unknown",
        @"href": (self.href) ? self.href : @"unknown",
        @"name": (self.name) ? self.href : @"unknown",
        @"type": (self.type) ? self.type : @"unknown"
    };

    return [dict description];
}

@end
