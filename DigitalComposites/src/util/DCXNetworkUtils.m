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

#import "DCXNetworkUtils.h"

@implementation DCXNetworkUtils

#pragma mark HTTP Request and Response header helpers

+ (NSDictionary *)lowerCaseKeyedCopyOfDictionary:(NSDictionary *)source
{
    // The algorithm below is essentially doing this:
    //          NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:[source count]];
    //          [source  enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    //              [result setObject:obj forKey:[key lowercaseString]];
    //          }];
    //          return result;
    // However, profiled on an iPad3, the implementation below only takes 60% of the time the more
    // straight-forward implementation above takes. This is most likely because the implementation above
    // a) constructs the dictionary one by one and b) makes more Objective C message calls.

    NSInteger count = [source count];
    id __unsafe_unretained objects[count];
    id __unsafe_unretained mixedCaseKeys[count];

    [source getObjects:objects andKeys:mixedCaseKeys];
    id lowerCaseKeys[count];

    for (NSUInteger i = 0; i < count; i++)
    {
        lowerCaseKeys[i] = [mixedCaseKeys[i] lowercaseString];
    }

    return [NSDictionary dictionaryWithObjects:objects forKeys:lowerCaseKeys count:count];
}

+ (NSString *)rfc2047DecodeValue:(NSString *)inputValue
{
    // if inputValue doesn't conform to utf-8?b? (base64) or utf-8?q? (ascii) encoding, return it unchanged.
    NSString *returnString = inputValue;

    if ([inputValue hasPrefix:@"=?"] && [inputValue hasSuffix:@"?="])
    {
        // Remove the string delimiters =? and ?=
        NSString *decodedValue = [inputValue substringFromIndex:2];
        decodedValue = [decodedValue substringToIndex:[decodedValue length] - 2];

        NSString *utf8Prefix = @"utf-8?";
        NSString *base64Prefix = @"b?";
        NSString *asciiPrefix = @"q?";

        if ([[decodedValue lowercaseString] hasPrefix:utf8Prefix])
        {
            decodedValue = [decodedValue substringFromIndex:[utf8Prefix length]];

            if ([[decodedValue lowercaseString] hasPrefix:base64Prefix])
            {
                decodedValue = [decodedValue substringFromIndex:[base64Prefix length]];
                NSData *encodedData = [[NSData alloc] initWithBase64EncodedString:decodedValue options:0];
                NSString *decodedString = [[NSString alloc] initWithData:encodedData encoding:NSUTF8StringEncoding];

                if ([decodedString length] > 0)
                {
                    returnString = decodedString;
                }
            }
            else if ([[decodedValue lowercaseString] hasPrefix:asciiPrefix])
            {
                decodedValue = [decodedValue substringFromIndex:[asciiPrefix length]];
                returnString = decodedValue;
            }
        }
    }

    return returnString;
}

+ (NSString *)rfc5987EncodeValue:(NSString *)inputValue
                          forKey:(NSString *)inputKey
{
    NSString *returnString = inputValue;
    NSString *lcKey = [inputKey lowercaseString];

    // Each key/value pair has a different format and therefore requires different rules to decide what to encode.
    // If key is not found or if the value doesn't match the pattern return the original input value.

    // x-device-id: <value>; name=<param-value>
    if ([lcKey hasPrefix:@"x-device-id"])
    {
        NSMutableString *newKey = [NSMutableString stringWithCapacity:inputValue.length];
        NSArray *substrings = [inputValue componentsSeparatedByString:@";"];

        if (substrings.count == 2)
        {
            [newKey appendFormat:@"%@;", substrings[0]];

            NSString *params = substrings[1];
            NSArray *paramString = [params componentsSeparatedByString:@"="];

            if (paramString.count == 2)
            {
                [newKey appendString:paramString[0]];

                NSString *paramValue = paramString[1];

                if (![paramValue canBeConvertedToEncoding:NSASCIIStringEncoding])
                {
                    [newKey appendFormat:@"*=utf-8''%@", [paramValue stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                    returnString = newKey;
                }
            }
        }
    }

    return returnString;
}

+ (NSDictionary *)decodeResponseHeaders:(NSDictionary *)source
{
    // A better performing alternative to [NSDictionary enumerateKeysAndObjectsUsingBlock:].
    // See comments in lowerCaseKeyedCopyOfDictionary.

    NSInteger count = [source count];
    id __unsafe_unretained keys[count];
    id __unsafe_unretained escapedValues[count];
    id unescapedValues[count];

    [source getObjects:escapedValues andKeys:keys];

    for (NSUInteger i = 0; i < count; i++)
    {
        unescapedValues[i] = [self rfc2047DecodeValue:escapedValues[i]];
    }

    return [NSDictionary dictionaryWithObjects:unescapedValues forKeys:keys count:count];
}

+ (NSDictionary *)encodeRequestHeaders:(NSDictionary *)source
{
    // A better performing alternative to [NSDictionary enumerateKeysAndObjectsUsingBlock:].
    // See comments in lowerCaseKeyedCopyOfDictionary.

    NSInteger count = [source count];
    id __unsafe_unretained keys[count];
    id __unsafe_unretained unescapedValues[count];
    id escapedValues[count];

    [source getObjects:unescapedValues andKeys:keys];

    for (NSUInteger i = 0; i < count; i++)
    {
        escapedValues[i] = [self rfc5987EncodeValue:unescapedValues[i] forKey:keys[i]];
    }

    return [NSDictionary dictionaryWithObjects:escapedValues forKeys:keys count:count];
}

@end
