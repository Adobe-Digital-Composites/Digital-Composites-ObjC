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

#import "DropboxAccount.h"

NSString *const DropboxAppName      = @"DigitalCompositesApp";
NSString *const DropboxAppKey       = @"7taw8nns9yzoyso";           // TODO
NSString *const DropboxAppSecret    = @"bfngu77u1okf3wj";
NSString *const DropboxRedirectUrl  = @"http://localhost/callback/authCode";

@implementation DropboxAccount {
    NSString *_authState;
    NSString *_authCode;
    NSString *_authUid;
    NSString *_errorCode;
    NSString *_errorDescription;
}

-(id) init
{
    if (self = [super init]) {
        _authState = [[NSUUID UUID] UUIDString];
    }
    
    return self;
}

-(BOOL) isAuthenticated
{
    return _authCode != nil;
}

-(BOOL) hasToken
{
    return _authToken != nil;
}

-(NSString *)percentEncode:(NSString*)string
{
    return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                     kCFAllocatorDefault,
                                                                     (__bridge CFStringRef)(string),
                                                                     NULL,
                                                                     (CFStringRef)@":/?#[]@!$&'()*+,;=%",
                                                                     kCFStringEncodingUTF8
                                                                     ));
}

-(NSURL*) authWebViewUrl
{
    NSAssert(DropboxAppKey != nil && DropboxAppKey.length > 0, @"The variable DropboxAppKey must be set.");
    
    NSString *urlString = @"https://www.dropbox.com/1/oauth2/authorize";
    
    urlString = [urlString stringByAppendingString: @"?response_type="];
    urlString = [urlString stringByAppendingString: [self percentEncode:@"code"]];
    urlString = [urlString stringByAppendingString: @"&client_id="];
    urlString = [urlString stringByAppendingString: [self percentEncode:DropboxAppKey]];
    urlString = [urlString stringByAppendingString: @"&redirect_uri="];
    urlString = [urlString stringByAppendingString: [self percentEncode:DropboxRedirectUrl]];
    urlString = [urlString stringByAppendingString: @"&state="];
    urlString = [urlString stringByAppendingString: [self percentEncode:_authState]];
    
    return [NSURL URLWithString:urlString];
}

-(BOOL) shouldCloseAuthWebViewBasedOnNavigationTo:(NSURL *)url
{
    NSString *urlString = url.absoluteString;
    if ([urlString hasPrefix:DropboxRedirectUrl]) {
        NSString *returnedState = nil;
        NSString *params = url.query;
        NSArray *elements = [params componentsSeparatedByString:@"&"];
        for (NSString *element in elements) {
            NSArray *keyVal = [element componentsSeparatedByString:@"="];
            if (keyVal.count > 0) {
                NSString *key = [keyVal objectAtIndex:0];
                NSString *value = (keyVal.count == 2) ? [keyVal lastObject] : nil;
                
                if ([key isEqualToString:@"code"]) {
                    _authCode = value;
                } else if ([key isEqualToString:@"state"]) {
                    returnedState = value;
                } else if ([key isEqualToString:@"error"]) {
                    _errorCode = value;
                } else if ([key isEqualToString:@"error_description"]) {
                    _errorDescription = value;
                }
            }
        }
        if (_errorDescription != nil) {
            _error = [NSError errorWithDomain:@"DropboxErrorDomain" code:[_errorCode integerValue] userInfo:@{NSLocalizedDescriptionKey: _errorDescription}];
        }
        if (![returnedState isEqualToString:_authState]) {
            // Potential CSRF attack -- see http://tools.ietf.org/html/rfc6819#section-4.4.1.8
            _authCode = nil;
        }
        
        return YES;
    }
    return NO;
}

-(void) getTokenUsingQueue:(NSOperationQueue *)queue completionHandler:(void (^)(NSString *, NSError *))handler
{
    NSAssert(DropboxAppKey != nil && DropboxAppKey.length > 0, @"The variable DropboxAppKey must be set.");
    NSAssert(DropboxAppSecret != nil && DropboxAppSecret.length > 0, @"The variable DropboxAppSecret must be set.");
    
    NSURL *url = [NSURL URLWithString:@"https://api.dropbox.com/1/oauth2/token"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSString *params = @"code=";
    params = [params stringByAppendingString:_authCode];
    params = [params stringByAppendingString:@"&grant_type="];
    params = [params stringByAppendingString:@"authorization_code"];
    params = [params stringByAppendingString:@"&client_id="];
    params = [params stringByAppendingString:DropboxAppKey];
    params = [params stringByAppendingString:@"&client_secret="];
    params = [params stringByAppendingString:DropboxAppSecret];
    params = [params stringByAppendingString:@"&redirect_uri="];
    params = [params stringByAppendingString:DropboxRedirectUrl];
    
    request.HTTPMethod = @"POST";
    request.HTTPBody = [params dataUsingEncoding:NSUTF8StringEncoding];
    
    [NSURLConnection sendAsynchronousRequest:request queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        
                               NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                               NSInteger statusCode = httpResponse.statusCode;
                               // Expected response, indicating successful authentication and
                               // return of a token, is 200.
                               if(data && statusCode == 200) {
                                   id parsedResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                   if (parsedResponse != nil && [parsedResponse isKindOfClass: [NSDictionary class]]) {
                                       _authToken = [parsedResponse objectForKey:@"access_token"];
                                       if(_authToken != nil) {
                                           handler(_authToken, nil);
                                           return;
                                       }
                                   }
                               }
                               
                               // If we didn't get back a token, make sure errorPtr is set before
                               // returning. There are a couple of cases that are not errors as far
                               // as NSURLConnection is concerned, but they are from our point of view.
        
                               if (data && statusCode == 400) {
                                   error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUserCancelledAuthentication userInfo:nil];
                               } else if (data) {
                                   error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil];
                               }
                               
                               handler(nil, error);
                           }];
    
}

@end
