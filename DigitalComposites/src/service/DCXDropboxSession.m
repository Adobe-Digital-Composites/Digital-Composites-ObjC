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

#import "DCXSession_Internal.h"
#import "DCXDropboxSession.h"

#import "DCXHTTPService.h"
#import "DCXHTTPRequest.h"
#import "DCXHTTPResponse.h"

#import "DCXComposite_Internal.h"
#import "DCXManifest.h"
#import "DCXMutableComponent.h"
#import "DCXConstants_Internal.h"

#import "DCXResourceItem.h"

#import "DCXUtils.h"
#import "DCXError.h"
#import "DCXErrorUtils.h"

NSURL *DropboxApiBaseUrl;
NSURL *DropboxContentBaseUrl;

// Hardcoded (for now) lookup table that determines the sync group of
// the href of a composite.
static NSDictionary *DCXTypeSyncGroups = nil;

@implementation DCXDropboxSession

-(id) initWithHTTPService:(DCXHTTPService *)service
{
    self = [super initWithHTTPService:service];
    if (self != nil) {
        DropboxApiBaseUrl = [NSURL URLWithString:@"https://api.dropbox.com/1/"];
        DropboxContentBaseUrl = [NSURL URLWithString:@"https://api-content.dropbox.com/1/"];
    }
    
    return self;
}

#pragma mark - Composite

-(DCXResourceItem*) resourceForComposite:(DCXComposite *)composite
{
    DCXResourceItem *resource = nil;
    
    if (composite.href != nil) {
        resource = [DCXResourceItem resourceFromHref:composite.href];
        resource.type = @"application/vnd.adobe.directory+json";
        DCXManifest *manifest = composite.manifest;
        if (manifest != nil) {
            resource.name = manifest.compositeId;
        } else {
            resource.name = [composite.href lastPathComponent];
        }
    }
    
    return resource;
}

-(DCXHTTPRequest*) createComposite:(DCXComposite *)composite
                   requestPriority:(NSOperationQueuePriority)priority
                      handlerQueue:(NSOperationQueue *)queue
                 completionHandler:(DCXCompositeRequestCompletionHandler)handler
{
    NSString *href = composite.href;
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"fileops/create_folder"
                                                                                 relativeToURL:DropboxApiBaseUrl]];
    urlRequest.HTTPMethod = @"POST";
    
    NSData *data = [[self paramsStringFromDictionary:@{
                                                       @"root": @"sandbox",
                                                       @"path": href
                                                       }] dataUsingEncoding:NSUTF8StringEncoding];

    __block DCXHTTPRequest *request = nil;
    
    request = [self getResponseFor:urlRequest streamToOrFrom:nil
                              data:data requestPriority:priority
                 completionHandler:^(DCXHTTPResponse *response) {
                     NSError *error = nil;
                     int statusCode = response.statusCode;
                     if(request.progress.isCancelled) {
                         error = [DCXErrorUtils ErrorWithCode:DCXErrorCancelled
                                                                domain:DCXErrorDomain
                                                               details:nil];
                     } else if (response.error != nil || (statusCode != 200 && statusCode != 201)) {
                         error = [self errorFromResponse:response andPath:nil details:nil];
                     }
                     
                     [self callCompositeCompletionHandler:handler onQueue:queue
                                            withComposite:(error == nil ? composite : nil)
                                                 andError:error];
                 }];
    
    return request;
}

-(DCXHTTPRequest*) deleteComposite:(DCXComposite *)composite
                   requestPriority:(NSOperationQueuePriority)priority
                      handlerQueue:(NSOperationQueue *)queue
                 completionHandler:(DCXCompositeRequestCompletionHandler)handler
{
    NSString *href = composite.href;
    if ( href == nil ) {
        NSAssert(href != nil, @"Composite is missing href.");
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"fileops/delete"
                                                                              relativeToURL:DropboxApiBaseUrl]];
    request.HTTPMethod = @"POST";
    
    NSData *data = [[self paramsStringFromDictionary:@{@"root": @"sandbox",
                                                       @"path": href
                                                       }] dataUsingEncoding:NSUTF8StringEncoding];
    
    return [self getResponseFor:request streamToOrFrom:nil data:data
                requestPriority:priority
              completionHandler:^(DCXHTTPResponse *response) {
                  NSError *error = nil;
                  
                  int statusCode = response.statusCode;
                  if (response.error == nil && (statusCode == 200 || statusCode == 204 || statusCode == 404)) {
                      // Nothing to update
                  } else {
                      error = [self errorFromResponse:response andPath:nil details:nil];
                  }
                  
                  [self callCompositeCompletionHandler:handler onQueue:queue
                                         withComposite:composite andError:error];
              }];
}

#pragma mark - Manifest


-(NSString*) getHrefForManifestOfComposite:(DCXComposite*)composite
{
    return [composite.href stringByAppendingPathComponent:@"manifest"];
}

-(DCXResourceItem*) resourceForManifest:(DCXManifest*)manifest ofComposite:(DCXComposite*)composite
{
    DCXResourceItem *resource = [[DCXResourceItem alloc] init];
    resource.type = DCXManifestType;
    resource.href = [self getHrefForManifestOfComposite:composite];
    resource.etag = manifest.etag;
    
    return resource;
}

-(DCXHTTPRequest*) updateManifest:(DCXManifest *)manifest ofComposite:(DCXComposite *)composite
                           requestPriority:(NSOperationQueuePriority)priority handlerQueue:(NSOperationQueue *)queue
                         completionHandler:(DCXManifestRequestCompletionHandler)handler
{
    NSDictionary *params = manifest.etag == nil ? @{ @"overwrite": @"true" } : @{ @"overwrite": @"true", @"parent_rev": manifest.etag };
    NSString *href = [self getHrefForManifestOfComposite:composite];
    NSString *urlString = [@"files_put/sandbox" stringByAppendingPathComponent:href];
    NSURL *url = [self urlFromString:urlString andParams:params relativeToUrl:DropboxContentBaseUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"PUT";
    
    return [self getResponseFor:request streamToOrFrom:nil data:manifest.remoteData requestPriority:priority
              completionHandler:^(DCXHTTPResponse *response) {
                  
                  NSError *error = nil;
                  int statusCode = response.statusCode;
                  DCXManifest *updatedManifest = nil;
                  
                  if (response.error == nil && (statusCode == 200 || statusCode == 201 || statusCode == 204)) {
                      
                      int statusCode = response.statusCode;
                      if (response.error == nil && (statusCode == 200 || statusCode == 201 || statusCode == 204)) {
                          NSDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:response.data options:0 error:&error];
                          if (parsedData != nil && [parsedData isKindOfClass: [NSDictionary class]]) {
                              NSString *newEtag = parsedData[@"rev"];
                              if (newEtag != nil) {
                                  // Update the manifest
                                  updatedManifest          = [manifest copy];
                                  updatedManifest.etag     = newEtag;
                              } else {
                                  error = [DCXErrorUtils ErrorWithCode:DCXErrorUnexpectedResponse
                                                                         domain:DCXErrorDomain
                                                                       response:response
                                                                        details:@"Response is missing the 'rev' property"];
                          }
                          }
                      } else {
                          error = [self errorFromResponse:response andPath:nil details:nil];
                      }
                  }
                  [self callManifestCompletionHandler:handler onQueue:queue
                                         withManifest:(error == nil ? updatedManifest : nil) andError:error];
                  
              }];
}

-(DCXHTTPRequest*) getHeaderInfoForManifestOfComposite:(DCXComposite*)composite
                                                requestPriority:(NSOperationQueuePriority)priority
                                                   handlerQueue:(NSOperationQueue *)queue
                                              completionHandler:(DCXResourceRequestCompletionHandler)handler
{
    DCXResourceItem *resource = [self resourceForManifest:composite.manifest ofComposite:composite];
    
    NSDictionary *params = @{ @"list": @"false",};
    NSString *urlString = [@"metadata/sandbox" stringByAppendingPathComponent:resource.href];
    NSURL *url = [self urlFromString:urlString andParams:params relativeToUrl:DropboxApiBaseUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    return [self getResponseFor:request streamToOrFrom:nil data:nil requestPriority:priority
              completionHandler:^(DCXHTTPResponse *response) {
                  
                  NSError *error = nil;
                  int statusCode = response.statusCode;
                  if (response.error == nil && (statusCode == 200 || statusCode == 304)) {
                      // Parse returned data
                      NSDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:response.data options:0 error:&error];
                      if (parsedData != nil && [parsedData isKindOfClass: [NSDictionary class]]) {
                          resource.etag = parsedData[@"rev"];
                      }
                  } else {
                      error = [self errorFromResponse:response andPath:nil details:nil];
                  }
                  
                  [self callCompletionHandler:handler onQueue:queue
                                 withResource:resource andError:error];
              }];
}

-(DCXHTTPRequest*) getManifest:(DCXManifest*)manifest ofComposite:(DCXComposite*)composite
                        requestPriority:(NSOperationQueuePriority)priority
                           handlerQueue:(NSOperationQueue *)queue
                      completionHandler:(DCXManifestRequestCompletionHandler)handler
{
    NSDictionary *params = manifest.etag == nil ? nil : @{ @"rev": manifest.etag };
    NSString *href = [self getHrefForManifestOfComposite:composite];
    NSString *urlString = [@"files/sandbox" stringByAppendingPathComponent:href];
    NSURL *url = [self urlFromString:urlString andParams:params relativeToUrl:DropboxContentBaseUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    return [self getResponseFor:request streamToOrFrom:nil data:nil
                requestPriority:priority
              completionHandler:^(DCXHTTPResponse *response) {
                  
                  DCXManifest *downloadedManifest = nil;
                  NSError *error = nil;
                  int statusCode = response.statusCode;
                  
                  if (response.error == nil && (statusCode == 200 || statusCode == 304)) {
                      if (statusCode == 200) {
                          downloadedManifest = [[DCXManifest alloc] initWithData:response.data withError:&error];
                          if (error == nil) {
                              NSDictionary *headers = response.headers;
                              NSString *metadata = [headers objectForKey:@"x-dropbox-metadata"];
                              NSString *newEtag = nil;
                              
                              // Parse returned data
                              NSDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:[metadata dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
                              if (parsedData != nil && [parsedData isKindOfClass: [NSDictionary class]]) {
                                  newEtag = parsedData[@"rev"];
                              }
                              
                              if (newEtag != nil) {
                                  // Update the manifest
                                  downloadedManifest.etag = newEtag;
                                  downloadedManifest.compositeHref = composite.href;
                              } else {
                                  error = [DCXErrorUtils ErrorWithCode:DCXErrorUnexpectedResponse
                                                                         domain:DCXErrorDomain response:response
                                                                        details:@"Missing 'rev' metadata field"];
                              }
                          }
                      }
                  } else {
                      error = [self errorFromResponse:response andPath:nil details:nil];
                  }
                  
                  [self callManifestCompletionHandler:handler onQueue:queue
                                         withManifest:(error == nil ? downloadedManifest : nil) andError:error];
              }];
}

#pragma mark - Component

-(NSString*) getHrefForComponent:(DCXComponent*)component ofComposite:(DCXComposite*)composite
{
    return [composite.href stringByAppendingPathComponent:component.componentId];
}

-(DCXHTTPRequest*) uploadComponent:(DCXComponent *)component ofComposite:(DCXComposite *)composite
                                   fromPath:(NSString *)path componentIsNew:(BOOL)isNew
                            requestPriority:(NSOperationQueuePriority)priority handlerQueue:(NSOperationQueue *)queue
                          completionHandler:(DCXComponentRequestCompletionHandler)handler
{
    NSDictionary *params = @{ @"overwrite": @"true" };
    NSString *href = [self getHrefForComponent:component ofComposite:composite];
    NSString *urlString = [@"files_put/sandbox" stringByAppendingPathComponent:href];
    NSURL *url = [self urlFromString:urlString andParams:params relativeToUrl:DropboxContentBaseUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"PUT";
    
    return [self getResponseFor:request streamToOrFrom:path data:nil requestPriority:priority
              completionHandler:^(DCXHTTPResponse *response) {
                  
                  NSError *error = nil;
                  int statusCode = response.statusCode;
                  
                  if (response.error == nil && (statusCode == 200 || statusCode == 201 || statusCode == 204)) {
                      DCXMutableComponent *updatedComponent = nil;
                      if (response.data != nil) {
                          // Parse returned data
                          NSDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:response.data options:0 error:&error];
                          if (parsedData != nil && [parsedData isKindOfClass: [NSDictionary class]]) {
                              // Dropbox's rev property serves as both version and etag for our components
                              NSString *rev     = parsedData[@"rev"];
                              
                             if (rev == nil) {
                                 error = [DCXErrorUtils ErrorWithCode:DCXErrorUnexpectedResponse
                                                               domain:DCXErrorDomain response:response
                                                              details:@"Response is missing the 'rev' property"];
                             } else {
                                 updatedComponent         = [component mutableCopy];
                                 updatedComponent.etag    = rev;
                                 updatedComponent.version = rev;
                                 // TODO
                                 //updatedComponent.length  = [NSNumber numberWithLongLong:newLength];
                             }
                         }
                     }
                     
                     [self callComponentCompletionHandler:handler onQueue:queue
                                            withComponent:updatedComponent andError:error];
                  } else {
                      error = [self errorFromResponse:response andPath:component.path details:nil];
                      if (error.code == DCXErrorFileReadFailure && [error.domain isEqualToString:DCXErrorDomain]) {
                          error = [DCXErrorUtils ErrorWithCode:DCXErrorComponentReadFailure
                                                                 domain:DCXErrorDomain
                                                               userInfo:error.userInfo];
                      }
                      [self callComponentCompletionHandler:handler onQueue:queue
                                             withComponent:nil andError:error];
                  }
                  
              }];
}

-(DCXHTTPRequest*) downloadComponent:(DCXComponent *)component ofComposite:(DCXComposite *)composite
                                       toPath:(NSString *)path requestPriority:(NSOperationQueuePriority)priority
                                 handlerQueue:(NSOperationQueue *)queue
                            completionHandler:(DCXComponentRequestCompletionHandler)handler
{
    NSString *href = [self getHrefForComponent:component ofComposite:composite];
    NSString *urlString = [@"files/sandbox" stringByAppendingPathComponent:href];
    NSURL *url = [self urlFromString:urlString andParams:nil relativeToUrl:DropboxContentBaseUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    return [self getResponseFor:request streamToOrFrom:path data:nil
                requestPriority:priority
              completionHandler:^(DCXHTTPResponse *response) {
                  
                  NSError *error = nil;
                  int statusCode = response.statusCode;
                  
                  if (response.error == nil && statusCode == 200) {
                      // Various checks to make sure that we got what we expected to get.
                      NSDictionary *headers = response.headers;
                      NSString *metadata = [headers objectForKey:@"x-dropbox-metadata"];
                      NSString *newEtag = nil;
                      
                      // Parse returned data
                      NSDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:[metadata dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
                      if (parsedData != nil && [parsedData isKindOfClass: [NSDictionary class]]) {
                          newEtag = parsedData[@"rev"];
                      }
                      
                      NSNumber *newLength = [NSNumber numberWithLongLong:response.bytesReceived];
                      
                      if (newEtag == nil) {
                          error = [DCXErrorUtils ErrorWithCode:DCXErrorUnexpectedResponse
                                                                 domain:DCXErrorDomain response:response
                                                                details:@"Missing metadata field 'rev'"];
                          
                      } else if (![newEtag isEqualToString:component.etag]) {
                          error = [DCXErrorUtils ErrorWithCode:DCXErrorUnexpectedResponse
                                                                 domain:DCXErrorDomain response:response
                                                                details:[NSString stringWithFormat:@"Downloaded component has rev %@. Expected: %@",
                                                                         newEtag, component.etag]];
                      } else if (component.length != nil && ![newLength isEqualToNumber:component.length]) {
                          error = [DCXErrorUtils ErrorWithCode:DCXErrorUnexpectedResponse
                                                                 domain:DCXErrorDomain response:response
                                                                details:[NSString stringWithFormat:@"Downloaded component has a length of %@. Expected: %@",
                                                                         newLength, component.length]];
                      }
                  } else {
                      error = [self errorFromResponse:response andPath:path details:nil];
                      if (error.code == DCXErrorFileWriteFailure && [error.domain isEqualToString:DCXErrorDomain]) {
                          error = [DCXErrorUtils ErrorWithCode:DCXErrorComponentWriteFailure
                                                                 domain:DCXErrorDomain
                                                               userInfo:error.userInfo];
                      }
                  }
                  
                  [self callComponentCompletionHandler:handler onQueue:queue
                                         withComponent:(error == nil ? component : nil)
                                              andError:error];
              }];
}

-(DCXHTTPRequest*) deleteComponent:(DCXComponent *)component ofComposite:(DCXComposite *)composite
                            requestPriority:(NSOperationQueuePriority)priority handlerQueue:(NSOperationQueue *)queue
                          completionHandler:(DCXComponentRequestCompletionHandler)handler
{
    
    NSString *href = [self getHrefForComponent:component ofComposite:composite];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"fileops/delete"
                                                                              relativeToURL:DropboxApiBaseUrl]];
    request.HTTPMethod = @"POST";
    
    NSData *data = [[self paramsStringFromDictionary:@{@"root": @"sandbox",
                                                       @"path": href
                                                       }] dataUsingEncoding:NSUTF8StringEncoding];
    
    return [self getResponseFor:request streamToOrFrom:nil data:data
                requestPriority:priority
              completionHandler:^(DCXHTTPResponse *response) {
                  NSError *error = nil;
                  
                  int statusCode = response.statusCode;
                  if (response.error == nil && (statusCode == 200 || statusCode == 204 || statusCode == 404)) {
                      // Nothing to update
                  } else {
                      error = [self errorFromResponse:response andPath:nil details:nil];
                  }
                  
                  [self callComponentCompletionHandler:handler onQueue:queue
                                         withComponent:(error == nil ? component : nil) andError:error];
              }];
    
}


#pragma mark - Internal

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

-(NSString*) paramsStringFromDictionary:(NSDictionary*)params
{
    if (params != nil && params.count > 0) {
        NSString *paramsString = @"";
        for (NSString *key in params.allKeys) {
            paramsString = [paramsString stringByAppendingString:[NSString stringWithFormat:@"&%@=%@", key, [self percentEncode:params[key]]]];
        }
        return paramsString;
    } else {
        return nil;
    }
}

-(NSURL*) urlFromString:(NSString*)urlString andParams:(NSDictionary*)params relativeToUrl:(NSURL*)baseUrl
{
    NSString *paramsString = [self paramsStringFromDictionary:params];
    if (paramsString != nil) {
        urlString = [NSString stringWithFormat:@"%@?%@", urlString, paramsString];
    }
    
    return [NSURL URLWithString:urlString relativeToURL:baseUrl];
}

-(void) callCompositeCompletionHandler:(DCXCompositeRequestCompletionHandler)handler onQueue:(NSOperationQueue*)queue
                         withComposite:(DCXComposite*)composite andError:(NSError*)error
{
    if (queue != nil) {
        [queue addOperationWithBlock: ^{
            handler(composite, error);
        }];
    } else {
        handler(composite, error);
    }
}

-(void) callManifestCompletionHandler:(DCXManifestRequestCompletionHandler)handler onQueue:(NSOperationQueue*)queue
                         withManifest:(DCXManifest*)manifest andError:(NSError*)error
{
    if (queue != nil) {
        [queue addOperationWithBlock: ^{
            handler(manifest, error);
        }];
    } else {
        handler(manifest, error);
    }
}

-(void) callComponentCompletionHandler:(DCXComponentRequestCompletionHandler)handler onQueue:(NSOperationQueue*)queue
                         withComponent:(DCXComponent*)component andError:(NSError*)error
{
    if (queue != nil) {
        [queue addOperationWithBlock: ^{
            handler(component, error);
        }];
    } else {
        handler(component, error);
    }
}

@end
