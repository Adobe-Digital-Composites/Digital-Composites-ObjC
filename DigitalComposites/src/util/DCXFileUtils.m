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


#import "DCXFileUtils.h"

@implementation DCXFileUtils

+ (BOOL)moveFileAtomicallyFrom:(NSString *)sourcePath to:(NSString *)destPath withError:(NSError **)errorPtr
{
    NSFileManager *fm = [NSFileManager defaultManager];

    if ([fm fileExistsAtPath:destPath])
    {
        // Use the OS's way of ensuring an atomic replacement
        return [fm replaceItemAtURL:[NSURL fileURLWithPath:destPath]
                      withItemAtURL:[NSURL fileURLWithPath:sourcePath]
                     backupItemName:nil options:0 resultingItemURL:nil error:errorPtr];
    }
    else
    {
        // Target doesn't exist yet, we can do a simple move.
        // But first we need to make sure that we have the necessary directories
        [fm createDirectoryAtPath:[destPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES
                       attributes:0 error:nil];
        return [fm moveItemAtPath:sourcePath toPath:destPath error:errorPtr];
    }
}

+ (BOOL)touch:(NSString *)filePath withError:(NSError **)errorPtr
{
    NSFileManager *fm = [NSFileManager defaultManager];

    return [fm setAttributes:@{NSFileModificationDate: [NSDate date]} ofItemAtPath:filePath error:errorPtr];
}

@end
