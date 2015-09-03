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

#import "DCXHTTPResponse.h"

#import "DCXError.h"

@implementation DCXHTTPResponse

- (id)init
{
    self = [super init];

    if (self)
    {
        _error = nil;
        _data = nil;
        _statusCode = 0;
        _URL = nil;
        _headers = nil;
        _bytesSent = 0;
        _bytesReceived = 0;
    }

    return self;
}

- (NSString *)description
{
    NSString *result;

    if (self.error)
    {
        result = [NSString stringWithFormat:@"{ \"status-code\" : %d, \"error\" : { \"code\" : %d, \"description\" : \"%@\", \"data\" : %@ } }", self.statusCode, (int)self.error.code, self.error.localizedDescription, [NSString stringWithUTF8String:[self.error.userInfo[DCXResponseDataKey] bytes]]];
    }
    else
    {
        NSString *dataString = [NSString stringWithUTF8String:[self.data bytes]];

        // If self.data is not null terminated, try and parse the data without it
        if (dataString == nil)
        {
            dataString = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
        }

        result = [NSString stringWithFormat:@"{ \"status-code\" : %d, \"data\" : %@ }", self.statusCode, dataString];
    }

    return result;
}

@end