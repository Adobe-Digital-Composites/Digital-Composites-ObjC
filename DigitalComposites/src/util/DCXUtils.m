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

#import "DCXUtils.h"
#import "DCXError.h"
#import "DCXErrorUtils.h"

@implementation DCXUtils

+(BOOL) isValidPath:(NSString *)path
{
    if (path.length > 65535) {
        return NO;
    }
    NSArray *components = [path componentsSeparatedByString:@"/"];
    if ([components count] < 1) {
        return NO;
    }
    
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[^\x00-\x1F\"*:<>?\\\x7F]*[^\x00-\x1F\"*:<>?\\.\x7F]{1}$" options:0 error:&error];
    
    for (NSString *component in components) {
        if (component.length > 255) {
            return NO;
        }
        NSTextCheckingResult *match = [regex firstMatchInString:component options:0 range:NSMakeRange(0, component.length)];
        if (!match || NSEqualRanges(match.range, NSMakeRange(NSNotFound, 0))) {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark JSON parsing

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)errorPtr
{
    if (data == nil)
    {
        if (errorPtr != NULL)
        {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorMissingJSONData
                                                       domain:DCXErrorDomain
                                                     userInfo:nil];
        }
        
        return nil;
    }
    
    return [NSJSONSerialization JSONObjectWithData:data options:opt error:errorPtr];
}


@end
