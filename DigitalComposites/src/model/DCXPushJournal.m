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

#import "DCXPushJournal.h"

#import "DCXComposite_Internal.h"
#import "DCXError.h"
#import "DCXConstants.h"
#import "DCXManifest.h"
#import "DCXMutableComponent.h"

#import "DCXCopyUtils.h"
#import "DCXErrorUtils.h"
#import "DCXUtils.h"

// Keys used in a push context
NSString *const DCXPushJournalFormatVersionKey              = @"push-journal-format-version";
NSString *const DCXPushJournalCompositeHrefKey              = @"composite-href";
NSString *const DCXPushJournalCompositeDeletedKey           = @"composite-deleted";
NSString *const DCXPushJournalCompositeCreatedKey           = @"composite-created";
NSString *const DCXPushJournalComponentsUploadedKey         = @"uploaded-components";
NSString *const DCXPushJournalEtagKey                       = @"etag";
NSString *const DCXPushJournalLengthKey                     = @"length";
NSString *const DCXPushJournalVersionKey                    = @"version";
NSString *const DCXPushJournalFileKey                       = @"file";
NSString *const DCXPushJournalPushCompletedKey              = @"push-completed";
NSString *const DCXPushJournalCurrentBranchEtagKey          = @"current-branch-etag";

@implementation DCXPushJournal{
    
    NSMutableDictionary *_dict;
    
    NSMutableDictionary *_uploadedComponents;
    
    DCXComposite __weak *_weakComposite;
}

// Private method used for testing only
-(NSDictionary *)dict
{
    return _dict;
}

-(instancetype) initWithDictionary:(NSDictionary*)dict andPath:(NSString*)filePath andComposite:(DCXComposite*)composite
{
    if (self = [super init]) {        
        _dict = [DCXCopyUtils deepMutableCopyOfDictionary:dict];
        _filePath = filePath;
        _weakComposite = composite;
        
        _uploadedComponents = [_dict objectForKey:DCXPushJournalComponentsUploadedKey];
    }
    
    return self;
}

-(instancetype) initWithComposite:(DCXComposite *)composite data:(NSData*)data path:(NSString*)filePath
         failIfInvalid:(BOOL)failIfInvalid withError:(NSError**)errorPtr
{
    NSError* error;
    
    if (data == nil && !failIfInvalid) {
        return [self initWithDictionary:[DCXPushJournal emptyJournalDictForComposite:composite ] andPath:filePath andComposite:composite];
    }
    
    // parse the data
    id dict = [DCXUtils JSONObjectWithData:data options:0 error:&error];
    if (dict == nil || ![dict isKindOfClass: [NSDictionary class]]) {
        error = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidJournal domain:DCXErrorDomain
                                      underlyingError:error details:@"Failed to parse the journal data."];
    }
    
    if(error == nil) {
        // verify the dictionary
        NSString *href = [dict objectForKey:DCXPushJournalCompositeHrefKey];
        NSNumber *journalFormatVersion = [dict objectForKey:DCXPushJournalFormatVersionKey];
        if (![journalFormatVersion isEqualToNumber:@1]) {
            error = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidJournal domain:DCXErrorDomain
                                                  details:[NSString stringWithFormat:@"Format version expected: %@ -- found: %@.", @1, [dict objectForKey:DCXPushJournalFormatVersionKey]]];
        } else if (composite.href != nil && href != nil && ![href isEqualToString:composite.href]) {
            error = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidJournal domain:DCXErrorDomain
                                                  details:@"Composite's and journal's hrefs don't match."];
        } else if ([dict objectForKey:DCXPushJournalComponentsUploadedKey] == nil) {
            error = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidJournal domain:DCXErrorDomain
                                                  details:@"No uploaded-components section found."];
        }
    }
    
    if (error == nil) {
        return [self initWithDictionary:dict andPath:filePath andComposite:composite];
    } else {
        if (errorPtr != nil) *errorPtr = error;
        if (failIfInvalid) {
            return nil;
        }
        return [self initWithDictionary:[DCXPushJournal emptyJournalDictForComposite:composite] andPath:filePath andComposite:composite];
    }
}

+(NSDictionary*) emptyJournalDictForComposite:(DCXComposite*)composite
{
    if (composite.href == nil) {
        return @{ DCXPushJournalFormatVersionKey: @1,
                  DCXPushJournalComponentsUploadedKey: @{}
                  };
    } else {
        return @{ DCXPushJournalFormatVersionKey: @1,
                  DCXPushJournalCompositeHrefKey: composite.href,
                  DCXPushJournalComponentsUploadedKey: @{}
                  };
    }
}

+(instancetype) journalForComposite:(DCXComposite *)composite persistedAt:(NSString*)filePath error:(NSError**)errorPtr
{
    NSAssert(composite != nil, @"Parameter composite must not be nil");
    NSAssert(filePath != nil, @"Parameter filePath must not be nil");
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfFile:filePath options:0 error:&error];
        if (data != nil) {
            return [[self alloc] initWithComposite:composite data:data path:filePath failIfInvalid:NO withError:errorPtr];
        }
        if (errorPtr != nil) *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidJournal
                                                                        domain:DCXErrorDomain
                                                               underlyingError:error path:filePath details:@"Failed to read from journal file."];
    }
        
    return [[self alloc] initWithDictionary:[self emptyJournalDictForComposite:composite] andPath:filePath andComposite:composite];
}

+(instancetype) journalForComposite:(DCXComposite *)composite fromFile:(NSString *)filePath error:(NSError *__autoreleasing *)errorPtr
{
    NSAssert(composite != nil, @"Parameter composite must not be nil");
    NSAssert(filePath != nil, @"Parameter filePath must not be nil");
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfFile:filePath options:0 error:&error];
        if (data != nil) {
            return [[self alloc] initWithComposite:composite data:data path:filePath failIfInvalid:YES withError:errorPtr];
        }
        if (errorPtr != nil) *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidJournal
                                                                        domain:DCXErrorDomain
                                                               underlyingError:error path:filePath details:@"Failed to read from journal file."];
    } else {
        if (errorPtr != NULL) {
            *errorPtr = [DCXErrorUtils ErrorWithCode:DCXErrorInvalidJournal domain:DCXErrorDomain
                                              underlyingError:nil path:filePath details:@"Could not find journal file."];
        }
    }
    
    return nil;
}

- (NSData*)data
{
    return [NSJSONSerialization dataWithJSONObject:_dict options:0 error:nil];
}

- (NSString*) compositeHref
{
    return _dict == nil ? nil : [_dict objectForKey:DCXPushJournalCompositeHrefKey];
}

-(BOOL) updateManifestWithJournalEtag:(DCXManifest*)manifest
{
    if (self.hasManifestData) {
        manifest.etag = [_dict objectForKey:DCXPushJournalEtagKey];
        return YES;
    } else {
        return NO;
    }
}

-(NSString *) currentBranchEtag
{
    return [_dict objectForKey:DCXPushJournalCurrentBranchEtagKey];
}

-(void) recordCurrentBranchEtag:(NSString *)etag
{
    if ( etag != nil ) {
        [_dict setObject:etag forKey:DCXPushJournalCurrentBranchEtagKey];
        if ( self.hasManifestData ) {
            // Updating the current etag requires that we also clear the etag for a previously pushed manifest
            // and mark the journal as being incomplete
            [_dict removeObjectForKey:DCXPushJournalEtagKey];
            [self clearPushCompleted];
        }
    }
    else {
        [_dict removeObjectForKey:DCXPushJournalCurrentBranchEtagKey];
    }
    [self writeToFileWithError:nil];
}

-(void) recordUploadedManifest:(DCXManifest *)manifest
{
    if (manifest.etag != nil) {
        [_dict setObject:manifest.etag forKey:DCXPushJournalEtagKey];
        [_dict setObject:manifest.compositeHref forKey:DCXPushJournalCompositeHrefKey];
        [_dict setObject:@1 forKey:DCXPushJournalPushCompletedKey];
    }
    [self writeToFileWithError:nil];
}

-(BOOL) isEmpty
{
    return _dict == nil || (  [[_dict objectForKey:DCXPushJournalComponentsUploadedKey] count] == 0
                           && !self.isComplete);
}

-(BOOL) isComplete
{
    return ([_dict objectForKey:DCXPushJournalPushCompletedKey] != nil && self.hasManifestData) || self.compositeHasBeenDeleted;
}

-(BOOL) compositeHasBeenDeleted
{
    return _dict != nil && [_dict objectForKey:DCXPushJournalCompositeDeletedKey] != nil;
}

-(BOOL) compositeHasBeenCreated
{
    return _dict != nil && [_dict objectForKey:DCXPushJournalCompositeCreatedKey] != nil;
}

-(void) recordUploadedComponent:(DCXComponent *)component fromPath:(NSString*)filePath
{
    NSMutableDictionary *componentData = [NSMutableDictionary dictionaryWithCapacity:4];
    if (component.etag != nil) {
        [componentData setObject:component.etag forKey:DCXPushJournalEtagKey];
    }
    if (component.length != nil) {
        [componentData setObject:component.length forKey:DCXPushJournalLengthKey];
    }
    if (component.version != nil) {
        [componentData setObject:component.version forKey:DCXPushJournalVersionKey];
    }
    [componentData setObject:filePath forKey:DCXPushJournalFileKey];
    
    @synchronized(self) {
        
        [_uploadedComponents setObject:componentData forKey:component.componentId];
        [self clearPushCompleted]; // mark the journal as being incomplete
        [self writeToFileWithError:nil];
    }
}

-(BOOL) hasUploadedComponent:(DCXComponent *)component fromPath:(NSString*)filePath
{
    BOOL hasBeenUploaded = NO;
    @synchronized(self) {
        NSDictionary *componentRecord = [_uploadedComponents objectForKey:component.componentId];
        if (componentRecord != nil && [componentRecord[DCXPushJournalFileKey] isEqualToString:filePath]) {
            hasBeenUploaded = YES;
        }
    }
    return hasBeenUploaded;
}

-(DCXMutableComponent*) getUploadedComponent:(DCXComponent*)component fromPath:(NSString *)filePath
{
    DCXMutableComponent *result = nil;
    
    @synchronized(self) {
        NSDictionary *componentRecord = [_uploadedComponents objectForKey:component.componentId];
        if (componentRecord != nil) {
            if (filePath == nil || [componentRecord[DCXPushJournalFileKey] isEqualToString:filePath]) {
                result = [component mutableCopy];
                [self copyPropertiesFrom:componentRecord toComponent:result];
            } else {
                // We have previously pushed a different file so we clear this entry
                [_uploadedComponents removeObjectForKey:component.componentId];
                [self clearPushCompleted]; // mark the journal as being incomplete
                [self writeToFileWithError:nil];
            }
        }
    }
    
    return result;
}

-(void) clearComponent:(DCXComponent*)component
{
    @synchronized(self) {
        [_uploadedComponents removeObjectForKey:component.componentId];
        
        [self clearPushCompleted]; // mark the journal as being incomplete
        [self writeToFileWithError:nil];
    }
}


-(BOOL) writeToFileWithError:(NSError**)errorPtr
{
    NSString *fileToWriteTo = self.filePath;
    
    // Make sure the directory we write to exists
    NSString *destDir = [fileToWriteTo stringByDeletingLastPathComponent];
    return [[NSFileManager defaultManager] createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:errorPtr]
                    && [self.data writeToFile:self.filePath options:NSDataWritingAtomic error:errorPtr];
}

-(void) setCompositeHref:(NSString *)href
{
    if (_dict != nil) {
        if (href == nil) {
            [_dict removeObjectForKey:DCXPushJournalCompositeHrefKey];
        } else {
            [_dict setObject:href forKey:DCXPushJournalCompositeHrefKey];
        }
        [self writeToFileWithError:nil];
    }
}

-(void) recordCompositeHasBeenDeleted:(BOOL)deleted
{
    if (_dict != nil) {
        if (!deleted) {
            [_dict removeObjectForKey:DCXPushJournalCompositeDeletedKey];
        } else {
            [_dict setObject:@1 forKey:DCXPushJournalCompositeDeletedKey];
        }
        [self writeToFileWithError:nil];
    }
}

-(void) recordCompositeHasBeenCreated:(BOOL)created
{
    if (_dict != nil) {
        if (!created) {
            [_dict removeObjectForKey:DCXPushJournalCompositeCreatedKey];
        } else {
            [_dict setObject:@1 forKey:DCXPushJournalCompositeCreatedKey];
        }
        [self writeToFileWithError:nil];
    }
}

-(BOOL) deleteFileWithError:(NSError**)errorPtr
{
    if (_filePath == nil) {
        return YES;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.filePath]) {
        return YES;
    } else {
        return [fm removeItemAtPath:self.filePath error:errorPtr];
    }
}

// helper methods

-(BOOL) hasManifestData
{
    return [_dict objectForKey:DCXPushJournalEtagKey] != nil;
}

-(void) clearPushCompleted
{
    if ( [_dict objectForKey:DCXPushJournalPushCompletedKey] != nil ) {
        [_dict removeObjectForKey:DCXPushJournalPushCompletedKey];
        DCXComposite *composite = _weakComposite;
        [composite discardPushedManifest]; // since pushed branch can no longer be accepted
    }
}

-(void) copyPropertiesFrom:(NSDictionary*)dict toComponent:(DCXMutableComponent*)component
{
    component.etag = [dict objectForKey:DCXPushJournalEtagKey];
    component.length = [dict objectForKey:DCXPushJournalLengthKey];
    component.version = [dict objectForKey:DCXPushJournalVersionKey];
}

@end
