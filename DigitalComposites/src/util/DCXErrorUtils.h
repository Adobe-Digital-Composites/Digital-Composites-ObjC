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

#import <Foundation/Foundation.h>

@class DCXHTTPResponse;

/**
 * \brief A set of convenience methods that help constructing errors.
 */
@interface DCXErrorUtils : NSObject

/**
 * \brief Construct an error with the given code and other params.
 *
 * \param code    The error code
 * \param domain  The error domain
 * \param URL     An optional NSURL to be recorded in the userInfo via the DCXRequestURLStringKey
 * \param data    An optional data pointer to be recorded in the userInfo via the DCXResponseDataKey
 * \param status  The status code to be recorded in the userInfo via the DCXHTTPStatusKey
 * \param headers An optional pointer to the response headers to be recorded in the userInfo via the DCXResponseHeadersKey
 * \param error   An optional NSError to be recorded in the userInfo via the NSUnderlyingErrorKey
 * \param details An optional NSString to be recorded in the userInfo via the DCXErrorDetailsStringKey
 */
+ (NSError *)ErrorWithCode:(NSInteger)code
                    domain:(NSString *)domain
                       URL:(NSURL *)URL
              responseData:(id)data
            httpStatusCode:(NSInteger)status
                   headers:(id)headers
           underlyingError:(NSError *)error
                   details:(NSString *)details;


/**
 * \brief Construct an error with the given code and other params.
 *
 * \param code    The error code
 * \param domain  The error domain
 * \param details An optional NSString to be recorded in the userInfo via the DCXDetailsStringKey
 */
+ (NSError *)ErrorWithCode:(NSInteger)code
                    domain:(NSString *)domain
                   details:(NSString *)details;


/**
 * \brief Construct an error with the given code and other params.
 *
 * \param code    The error code
 * \param domain  The error domain
 * \param error   An optional NSError to be recorded in the userInfo via the NSUnderlyingErrorKey
 * \param details An optional NSString to be recorded in the userInfo via the DCXDetailsStringKey
 */
+ (NSError *)ErrorWithCode:(NSInteger)code
                    domain:(NSString *)domain
           underlyingError:(NSError *)error
                   details:(NSString *)details;


/**
 * \brief Construct an error with the given code and other params.
 *
 * \param code    The error code
 * \param domain  The error domain
 * \param error   An optional NSError to be recorded in the userInfo via the NSUnderlyingErrorKey
 * \param path    An optional NSString containing a path of a file to be recorded in the userInfo via the DCXPathKey
 * \param details An optional NSString to be recorded in the userInfo via the DCXDetailsStringKey
 */
+ (NSError *)ErrorWithCode:(NSInteger)code
                    domain:(NSString *)domain
           underlyingError:(NSError *)error
                      path:(NSString *)path
                   details:(NSString *)details;


/**
 * \brief Construct an error with the given code and other params.
 *
 * \param code        The error code
 * \param domain      The error domain
 * \param userInfo    An optional NSDictionary to be used as the userInfo property of the error
 */
+ (NSError *)ErrorWithCode:(NSInteger)code
                    domain:(NSString *)domain
                  userInfo:(NSDictionary *)userInfo;


/**
 * \brief Construct an error with the given code and other params.
 *
 * \param response        DCXHTTPResponse to be used to populate the new error with relevant data
 * \param path            Optional NSString containing a path of a file to be recorded in the userInfo via the DCXPathKey
 * \param defaultCode     Error code to be used if the response doesn't imply a better one
 * \param defaultDomain   The error domain of the deafult error code
 * \param details         Optional NSString to be recorded in the userInfo via the DCXDetailsStringKey
 */
+ (NSError *)ErrorFromResponse:(DCXHTTPResponse *)response
                       andPath:(NSString *)path
                   defaultCode:(NSInteger)defaultCode
                 defaultDomain:(NSString *)domain
                       details:(NSString *)details;


/**
 * \brief Construct an error with the given code and other params.
 *
 * \param code        The error code
 * \param domain      The error domain
 * \param response    A DCXHTTPResponse to be used to populate the new error with relevant data
 * \param details     An optional NSString to be recorded in the userInfo via the DCXDetailsStringKey
 */
+ (NSError *)ErrorWithCode:(int)code
                    domain:(NSString *)domain
                  response:(DCXHTTPResponse *)response
                   details:(NSString *)details;


/**
 * \brief Construct an error with the given code and other params.
 *
 * \param code        The error code
 * \param domain      The error domain
 * \param response    DCXHTTPResponse to be used to populate the new error with relevant data
 * \param error       Optional NSError to be recorded in the userInfo via the NSUnderlyingErrorKey
 * \param details     Optional NSString to be recorded in the userInfo via the DCXDetailsStringKey
 */
+ (NSError *)ErrorWithCode:(int)code
                    domain:(NSString *)domain
                  response:(DCXHTTPResponse *)response
           underlyingError:(NSError *)error
                   details:(NSString *)details;

/**
 * \brief Indicates whether the given error is a Digital Composite error
 *
 * \param error   The error object
 */
+ (BOOL)IsDCXError:(NSError *)error;

@end
