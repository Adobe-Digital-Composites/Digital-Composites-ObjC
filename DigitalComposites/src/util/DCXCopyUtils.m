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

#import "DCXCopyUtils.h"

@implementation DCXCopyUtils

+ (NSMutableDictionary *)deepMutableCopyOfDictionary:(NSDictionary *)source
{
    NSMutableDictionary *mutableCopy = [NSMutableDictionary dictionaryWithCapacity:[source count]];
    NSArray *keys = [source allKeys];

    for (id key in keys)
    {
        id object = [source objectForKey:key];

        if ([object isKindOfClass:[NSDictionary class]])
        {
            [mutableCopy setObject:[self deepMutableCopyOfDictionary:object] forKey:key];
        }
        else if ([object isKindOfClass:[NSArray class]])
        {
            [mutableCopy setObject:[self deepMutableCopyOfArray:object] forKey:key];
        }
        else
        {
            [mutableCopy setObject:object forKey:key];
        }
    }

    return mutableCopy;
}

+ (NSMutableArray *)deepMutableCopyOfArray:(NSArray *)source
{
    NSInteger n = [source count];
    NSMutableArray *mutableCopy = [NSMutableArray arrayWithCapacity:n];

    for (int i = 0; i < n; i++)
    {
        id object = [source objectAtIndex:i];

        if ([object isKindOfClass:[NSDictionary class]])
        {
            [mutableCopy insertObject:[self deepMutableCopyOfDictionary:object] atIndex:i];
        }
        else if ([object isKindOfClass:[NSArray class]])
        {
            [mutableCopy insertObject:[self deepMutableCopyOfArray:object] atIndex:i];
        }
        else
        {
            [mutableCopy insertObject:object atIndex:i];
        }
    }

    return mutableCopy;
}

@end