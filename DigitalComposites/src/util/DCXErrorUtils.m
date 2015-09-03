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


#import "DCXError.h"
#import "DCXErrorUtils.h"
#import "DCXHTTPResponse.h"

@implementation DCXErrorUtils

static NSDictionary *httpErrorMapping = nil;
+ (void)createHttpErrorMapping
{
    httpErrorMapping = @{
        NSURLErrorDomain: @{
            @(NSURLErrorUnknown):                          @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorBadURL):                           @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorUnsupportedURL):                   @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorDataLengthExceedsMaximum):         @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorDNSLookupFailed):                  @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorHTTPTooManyRedirects):             @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorResourceUnavailable):              @[DCXErrorDomain,   @(DCXErrorUnexpectedResponse)],
            @(NSURLErrorRedirectToNonExistentLocation):    @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorBadServerResponse):                @[DCXErrorDomain,   @(DCXErrorUnexpectedResponse)],
            @(NSURLErrorCancelled):                        @[DCXErrorDomain, @(DCXErrorCancelled)],
            @(NSURLErrorUserCancelledAuthentication):      @[DCXErrorDomain, @(DCXErrorCancelled)],
            @(NSURLErrorUserAuthenticationRequired):       @[DCXErrorDomain, @(DCXErrorAuthenticationFailed)],
            @(NSURLErrorZeroByteResource):                 @[DCXErrorDomain,   @(DCXErrorUnexpectedResponse)],
            @(NSURLErrorCannotDecodeRawData):              @[DCXErrorDomain,   @(DCXErrorUnexpectedResponse)],
            @(NSURLErrorCannotDecodeContentData):          @[DCXErrorDomain,   @(DCXErrorUnexpectedResponse)],
            @(NSURLErrorCannotParseResponse):              @[DCXErrorDomain,   @(DCXErrorUnexpectedResponse)],
            @(NSURLErrorFileDoesNotExist):                 @[DCXErrorDomain, @(DCXErrorFileDoesNotExist)],
            @(NSURLErrorFileIsDirectory):                  @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorNoPermissionsToReadFile):          @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorSecureConnectionFailed):           @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorServerCertificateHasBadDate):      @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorServerCertificateUntrusted):       @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorServerCertificateHasUnknownRoot):  @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorServerCertificateNotYetValid):     @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorClientCertificateRejected):        @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorCannotLoadFromNetwork):            @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorTimedOut):                         @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorCannotFindHost):                   @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorCannotConnectToHost):              @[DCXErrorDomain, @(DCXErrorNetworkFailure)],
            @(NSURLErrorDownloadDecodingFailedMidStream):  @[DCXErrorDomain,   @(DCXErrorUnexpectedResponse)],
            @(NSURLErrorDownloadDecodingFailedToComplete): @[DCXErrorDomain,   @(DCXErrorUnexpectedResponse)],
            @(NSURLErrorCannotCreateFile):                 @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorCannotOpenFile):                   @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorCannotCloseFile):                  @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorCannotWriteToFile):                @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorCannotRemoveFile):                 @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorCannotMoveFile):                   @[DCXErrorDomain, @(DCXErrorBadRequest)],
            @(NSURLErrorNetworkConnectionLost):            @[DCXErrorDomain, @(DCXErrorOffline)],
            @(NSURLErrorNotConnectedToInternet):           @[DCXErrorDomain, @(DCXErrorOffline)]
        },
        NSPOSIXErrorDomain: @{
            @(ENETDOWN):                                   @[DCXErrorDomain, @(DCXErrorOffline)],          /* = 50  Network is down */
            @(ENETUNREACH):                                @[DCXErrorDomain, @(DCXErrorOffline)],          /* = 51  Network is unreachable */
            @(ENETRESET):                                  @[DCXErrorDomain, @(DCXErrorOffline)],          /* = 52  Network dropped connection on reset */
            @(ETIMEDOUT):                                  @[DCXErrorDomain, @(DCXErrorNetworkFailure)],   /* = 60  Operation timed out */
            @(ECONNREFUSED):                               @[DCXErrorDomain,   @(DCXErrorUnexpectedResponse)], /* = 61  Connection refused */
            @(ECONNABORTED):                               @[DCXErrorDomain, @(DCXErrorNetworkFailure)],   /* = 53  Software caused connection abort */
            @(ECONNRESET):                                 @[DCXErrorDomain,   @(DCXErrorUnexpectedResponse)], /* = 54  Connection reset by peer */
            @(ENOBUFS):                                    @[DCXErrorDomain, @(DCXErrorNetworkFailure)],   /* = 55  No buffer space available */
            @(EISCONN):                                    @[DCXErrorDomain, @(DCXErrorNetworkFailure)],   /* = 56  Socket is already connected */
            @(ENOTCONN):                                   @[DCXErrorDomain, @(DCXErrorNetworkFailure)],   /* = 57  Socket is not connected */
            @(ESHUTDOWN):                                  @[DCXErrorDomain, @(DCXErrorNetworkFailure)],   /* = 58  Can't send after socket shutdown */
            @(EHOSTDOWN):                                  @[DCXErrorDomain, @(DCXErrorNetworkFailure)],   /* = 64  Host is down */
            @(EHOSTUNREACH):                               @[DCXErrorDomain, @(DCXErrorNetworkFailure)],   /* = 65  No route to host */
            @(ELOOP):                                      @[DCXErrorDomain, @(DCXErrorNetworkFailure)],   /* = 62  Too many levels of symbolic links */
            @(ENAMETOOLONG):                               @[DCXErrorDomain, @(DCXErrorBadRequest)],       /* = 63  File name too long */
            @(ETOOMANYREFS):                               @[DCXErrorDomain, @(DCXErrorNetworkFailure)]
        },                                                                                                                   /*       We do apparently not use CFNetwork yet, commenting this out for now
                                                                                                                              * (NSString*)kCFErrorDomainCFNetwork: @{
                                                                                                                              * @(kCFErrorHTTPAuthenticationTypeUnsupported):  @(DCXErrorBadRequest),
                                                                                                                              * @(kCFErrorHTTPBadCredentials):                 @(DCXErrorBadRequest),
                                                                                                                              * @(kCFErrorHTTPConnectionLost):                 @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFErrorHTTPParseFailure):                   @(DCXErrorUnexpectedResponse),
                                                                                                                              * @(kCFErrorHTTPRedirectionLoopDetected):        @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFErrorHTTPBadURL):                         @(DCXErrorBadRequest),
                                                                                                                              * @(kCFErrorHTTPProxyConnectionFailure):         @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFErrorHTTPBadProxyCredentials):            @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFErrorPACFileError):                       @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFErrorPACFileAuth):                        @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFErrorHTTPSProxyConnectionFailure):        @(DCXErrorNetworkFailure),
                                                                                                                              * // Error codes for CFURLConnection and CFURLProtocol
                                                                                                                              * @(kCFURLErrorUnknown):                         @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorBadURL):                          @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorTimedOut):                        @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorUnsupportedURL):                  @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorCannotFindHost):                  @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorCannotConnectToHost):             @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorDNSLookupFailed):                 @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorHTTPTooManyRedirects):            @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorResourceUnavailable):             @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorRedirectToNonExistentLocation):   @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorBadServerResponse):               @(DCXErrorUnexpectedResponse),
                                                                                                                              * @(kCFURLErrorUserCancelledAuthentication):     @(DCXErrorCancelled),
                                                                                                                              * @(kCFURLErrorUserAuthenticationRequired):      @(DCXErrorAuthenticationFailed),
                                                                                                                              * @(kCFURLErrorZeroByteResource):                @(DCXErrorUnexpectedResponse),
                                                                                                                              * @(kCFURLErrorCannotDecodeRawData):             @(DCXErrorUnexpectedResponse),
                                                                                                                              * @(kCFURLErrorCannotDecodeContentData):         @(DCXErrorUnexpectedResponse),
                                                                                                                              * @(kCFURLErrorCannotParseResponse):             @(DCXErrorUnexpectedResponse),
                                                                                                                              * @(kCFURLErrorInternationalRoamingOff):         @(DCXErrorOffline),
                                                                                                                              * @(kCFURLErrorCallIsActive):                    @(DCXErrorOffline),
                                                                                                                              * @(kCFURLErrorDataNotAllowed):                  @(DCXErrorOffline),
                                                                                                                              * @(kCFURLErrorRequestBodyStreamExhausted):      @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorFileDoesNotExist):                @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorFileIsDirectory):                 @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorNoPermissionsToReadFile):         @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorDataLengthExceedsMaximum):        @(DCXErrorBadRequest),
                                                                                                                              * // SSL errors
                                                                                                                              * @(kCFURLErrorSecureConnectionFailed):          @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorServerCertificateHasBadDate):     @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorServerCertificateUntrusted):      @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorServerCertificateHasUnknownRoot): @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorServerCertificateNotYetValid):    @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorClientCertificateRejected):       @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorClientCertificateRequired):       @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorCannotLoadFromNetwork):           @(DCXErrorNetworkFailure),
                                                                                                                              * // Download and file I/O errors
                                                                                                                              * @(kCFURLErrorCannotCreateFile):                @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorCannotOpenFile):                  @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorCannotCloseFile):                 @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorCannotWriteToFile):               @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorCannotRemoveFile):                @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorCannotMoveFile):                  @(DCXErrorBadRequest),
                                                                                                                              * @(kCFURLErrorDownloadDecodingFailedMidStream): @(DCXErrorNetworkFailure),
                                                                                                                              * @(kCFURLErrorDownloadDecodingFailedToComplete):@(DCXErrorNetworkFailure),
                                                                                                                              *
                                                                                                                              * @(kCFURLErrorNetworkConnectionLost):           @(DCXErrorOffline),
                                                                                                                              * @(kCFURLErrorNotConnectedToInternet):          @(DCXErrorOffline),
                                                                                                                              * @(kCFURLErrorCancelled):                       @(DCXErrorCancelled)
                                                                                                                              * }*/
        NSCocoaErrorDomain: @{
            @(NSFileNoSuchFileError):                      @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Attempt to do a file system operation on a non-existent file
            @(NSFileLockingError):                         @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Couldn't get a lock on file
            @(NSFileReadUnknownError):                     @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Read error (reason unknown)
            @(NSFileReadNoPermissionError):                @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Read error (permission problem)
            @(NSFileReadInvalidFileNameError):             @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Read error (invalid file name)
            @(NSFileReadCorruptFileError):                 @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Read error (file corrupt, bad format, etc)
            @(NSFileReadNoSuchFileError):                  @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Read error (no such file)
            @(NSFileReadInapplicableStringEncodingError):  @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Read error (string encoding not applicable) also NSStringEncodingErrorKey
            @(NSFileReadUnsupportedSchemeError):           @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Read error (unsupported URL scheme)
            @(NSFileReadTooLargeError):                    @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Read error (file too large)
            @(NSFileReadUnknownStringEncodingError):       @[DCXErrorDomain,   @(DCXErrorFileReadFailure)],    // Read error (string encoding of file contents could not be determined)
            @(NSFileWriteUnknownError):                    @[DCXErrorDomain,   @(DCXErrorFileWriteFailure)],   // Write error (reason unknown)
            @(NSFileWriteNoPermissionError):               @[DCXErrorDomain,   @(DCXErrorFileWriteFailure)],   // Write error (permission problem)
            @(NSFileWriteInvalidFileNameError):            @[DCXErrorDomain,   @(DCXErrorFileWriteFailure)],   // Write error (invalid file name)
            @(NSFileWriteFileExistsError):                 @[DCXErrorDomain,   @(DCXErrorFileWriteFailure)],   // Write error (file exists)
            @(NSFileWriteInapplicableStringEncodingError): @[DCXErrorDomain,   @(DCXErrorFileWriteFailure)],   // Write error (string encoding not applicable) also NSStringEncodingErrorKey
            @(NSFileWriteUnsupportedSchemeError):          @[DCXErrorDomain,   @(DCXErrorFileWriteFailure)],   // Write error (unsupported URL scheme)
            @(NSFileWriteOutOfSpaceError):                 @[DCXErrorDomain,   @(DCXErrorFileWriteFailure)],   // Write error (out of disk space)
            @(NSFileWriteVolumeReadOnlyError):             @[DCXErrorDomain,   @(DCXErrorFileWriteFailure)]    // Write error (readonly volume)
        }
    };
}

+ (NSError *)ErrorFromOSNetworkError:(NSError *)underlyingError
                         defaultCode:(NSInteger)defaultCode
                       defaultDomain:(NSString *)defaultDomain
                                 URL:(NSURL *)URL
                        responseData:(id)data
                      httpStatusCode:(NSInteger)status
                             headers:(id)headers
                                path:(NSString *)path
                             details:(NSString *)details
{
    NSString *localData = nil;

    if (data == nil)
    {
        localData = @"[no data]";
    }
    else if ([data isKindOfClass:[NSData class]])
    {
        localData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }

    NSMutableDictionary *userDict = nil;
    NSInteger code = defaultCode;
    NSString *domain = defaultDomain;

    if (underlyingError != nil && [underlyingError.domain isEqualToString:domain])
    {
        userDict = [underlyingError.userInfo mutableCopy];

        if (userDict == nil)
        {
            userDict = [NSMutableDictionary dictionary];
        }

        code = underlyingError.code;
        underlyingError = [userDict objectForKey:NSUnderlyingErrorKey];
    }
    else
    {
        userDict = [NSMutableDictionary dictionary];

        if (httpErrorMapping == nil)
        {
            [self createHttpErrorMapping];
        }

        NSDictionary *domainHash = [httpErrorMapping objectForKey:underlyingError.domain];

        if (domainHash != nil)
        {
            NSArray *errorTuple = [domainHash objectForKey:@(underlyingError.code)];

            if (errorTuple != nil && errorTuple.count == 2)
            {
                domain = errorTuple[0];
                code = [errorTuple[1] integerValue];
            }
        }
    }

    if (URL != nil)
    {
        [userDict setObject:URL.absoluteString forKey:DCXRequestURLStringKey];
    }

    [userDict setObject:[NSNumber numberWithLong:status]  forKey:DCXHTTPStatusKey];

    if (localData != nil)
    {
        [userDict setObject:localData forKey:DCXResponseDataKey];
    }

    if (headers != nil)
    {
        [userDict setObject:headers forKey:DCXResponseHeadersKey];
    }

    if (underlyingError != nil)
    {
        [userDict setObject:underlyingError forKey:NSUnderlyingErrorKey];
    }

    if (details != nil)
    {
        [userDict setObject:details forKey:DCXErrorDetailsStringKey];
    }

    if (path != nil)
    {
        [userDict setObject:path forKey:DCXErrorPathKey];
    }

    return [NSError errorWithDomain:domain code:code userInfo:userDict];
}

+ (NSError *)ErrorFromResponse:(DCXHTTPResponse *)response
                       andPath:(NSString *)path
                   defaultCode:(NSInteger)defaultCode
                 defaultDomain:(NSString *)defaultDomain
                       details:(NSString *)details
{
    return [self ErrorFromOSNetworkError:response.error
                             defaultCode:defaultCode
                           defaultDomain:defaultDomain
                                     URL:response.URL
                            responseData:response.data
                          httpStatusCode:response.statusCode
                                 headers:response.headers
                                    path:path
                                 details:details];
}

+ (NSError *)ErrorWithCode:(NSInteger)code
                    domain:(NSString *)domain
                   details:(NSString *)details
{
    return [NSError errorWithDomain:domain code:code userInfo:details == nil ? nil : @{DCXErrorDetailsStringKey: details}];
}

+ (NSError *)ErrorWithCode:(NSInteger)code
                    domain:(NSString *)domain
           underlyingError:(NSError *)error
                   details:(NSString *)details
{
    NSMutableDictionary *userDict = [NSMutableDictionary dictionary];

    if (error != nil)
    {
        [userDict setObject:error forKey:NSUnderlyingErrorKey];
    }

    if (details != nil)
    {
        [userDict setObject:details forKey:DCXErrorDetailsStringKey];
    }

    return [NSError errorWithDomain:domain code:code userInfo:userDict];
}

+ (NSError *)ErrorWithCode:(NSInteger)code
                    domain:(NSString *)domain
           underlyingError:(NSError *)error
                      path:(NSString *)path
                   details:(NSString *)details
{
    NSMutableDictionary *userDict = [NSMutableDictionary dictionary];

    if (error != nil)
    {
        [userDict setObject:error forKey:NSUnderlyingErrorKey];
    }

    if (details != nil)
    {
        [userDict setObject:details forKey:DCXErrorDetailsStringKey];
    }

    if (path != nil)
    {
        [userDict setObject:path forKey:DCXErrorPathKey];
    }

    return [NSError errorWithDomain:domain code:code userInfo:userDict];
}

+ (NSError *)ErrorWithCode:(int)code
                    domain:(NSString *)domain
                  response:(DCXHTTPResponse *)response
                   details:(NSString *)details
{
    return [self ErrorWithCode:code
                        domain:domain
                           URL:response.URL
                  responseData:response.data
                httpStatusCode:response.statusCode
                       headers:response.headers
               underlyingError:response.error
                       details:details];
}

+ (NSError *)ErrorWithCode:(int)code
                    domain:(NSString *)domain
                  response:(DCXHTTPResponse *)response
           underlyingError:(NSError *)error
                   details:(NSString *)details
{
    return [self ErrorWithCode:code
                        domain:domain
                           URL:response.URL
                  responseData:response.data
                httpStatusCode:response.statusCode
                       headers:response.headers
               underlyingError:error
                       details:details];
}

+ (NSError *)ErrorWithCode:(NSInteger)code
                    domain:domain
                  userInfo:(NSDictionary *)userInfo
{
    return [NSError errorWithDomain:domain code:code userInfo:userInfo];
}


+ (NSError *)ErrorWithCode:(NSInteger)code
                    domain:(NSString *)domain
                       URL:(NSURL *)URL
              responseData:(id)data
            httpStatusCode:(NSInteger)status
                   headers:(id)headers
           underlyingError:(NSError *)error
                   details:(NSString *)details
{
    if (data == nil)
    {
        data = @"[no data]";
    }

    NSMutableDictionary *userDict = [NSMutableDictionary dictionary];

    if (URL != nil)
    {
        [userDict setObject:URL.absoluteString forKey:DCXRequestURLStringKey];
    }

    [userDict setObject:[NSNumber numberWithLong:status]  forKey:DCXHTTPStatusKey];

    if (data != nil)
    {
        [userDict setObject:data forKey:DCXResponseDataKey];
    }

    if (headers != nil)
    {
        [userDict setObject:headers forKey:DCXResponseHeadersKey];
    }

    if (error != nil)
    {
        [userDict setObject:error forKey:NSUnderlyingErrorKey];
    }

    if (details != nil)
    {
        [userDict setObject:details forKey:DCXErrorDetailsStringKey];
    }

    return [NSError errorWithDomain:domain code:code userInfo:userDict];
}

+ (BOOL)IsDCXError:(NSError *)error
{
    return [error.domain isEqualToString:DCXErrorDomain];
}

@end
