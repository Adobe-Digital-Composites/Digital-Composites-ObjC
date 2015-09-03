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

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "DCX.h"

@interface DigitalCompositesOSXTests : XCTestCase

@end

@implementation DigitalCompositesOSXTests
{
    NSFileManager   *_fm;
    NSString        *_tempPath;
}

#pragma mark - Helpers

// Helper method to create a temporary directory.
-(NSString*) createTemporaryDirectoryWithError:(NSError**)errorPtr
{
    if (_tempPath == nil) {
        NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
        NSString *dirName = [NSString stringWithFormat:@"temp%f", time];
        _tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName];
        NSError *error;
        [_fm createDirectoryAtPath:_tempPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error != nil) {
            _tempPath = nil;
        }
    }
    
    return _tempPath;
}

// Helper method to create a temporary directory and copy over an asset
-(NSString*) createTemporaryDirectoryWithContents:(NSString*)contentsToCopy withError:(NSError**)errorPtr
{
    NSString *path = [self createTemporaryDirectoryWithError:errorPtr];
    
    if (path != nil) {
        NSString *destPath = [path stringByAppendingPathComponent:[contentsToCopy lastPathComponent]];
        if ([_fm copyItemAtPath:contentsToCopy toPath:destPath error:errorPtr]) {
            return destPath;
        }
    }
    
    return nil;
}

-(NSString*) pathForTestAsset:(NSString*)nameOfTestAsset
{
    NSString* xcTestBundlePath = nil;
#if ( TARGET_OS_IPHONE )
    xcTestBundlePath = [[NSBundle bundleForClass:[self class]] bundlePath];
#else
    xcTestBundlePath = [[NSBundle bundleForClass:[self class]] resourcePath];
#endif
    return [xcTestBundlePath stringByAppendingPathComponent:nameOfTestAsset];
}

#pragma mark - Setup Teardown

- (void)setUp {
    [super setUp];
    
    _tempPath = nil;
    _fm = [NSFileManager defaultManager];
}

- (void)tearDown {
    if (_tempPath != nil) {
        // delete the temp directory
        [_fm removeItemAtPath:_tempPath error:nil];
    }
    [super tearDown];
}

#pragma mark - Tests - Instantiation & Basic Editing

/*
 * Creates a new empty composite, populates it with nodes and components, and commits it to loca storage
 */
- (void)testInstantiateNewComposite {
    NSError *error = nil;
    
    // Create a new empty composite leaving path, id and href undefined
    DCXComposite *composite = [DCXComposite compositeWithName:@"n" andType:@"t" andPath:nil andId:nil andHref:nil];
    XCTAssertNotNil(composite);
    XCTAssertNotNil(composite.compositeId);
    
    // Now we use the id of the new composite to set up the local storage path
    composite.path = [[self createTemporaryDirectoryWithError:&error] stringByAppendingPathComponent:composite.compositeId];
    XCTAssertNil(error);
    XCTAssertNotNil(composite.path);
    
    // Get the current branch and use it to add some nodes and components
    DCXMutableBranch *current = composite.current;
    
    // Create a pages node at the root
    DCXNode *pagesNode = [current addChild:[DCXMutableNode nodeWithType:@"nt1" path:@"pages" name:@"nn1"]
                                  toParent:current.rootNode withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(pagesNode);
    XCTAssertNotNil(pagesNode.nodeId);
    // Can we find the new node by its id?
    XCTAssertEqualObjects([current getChildWithId:pagesNode.nodeId], pagesNode);
    
    // Now we can add a page node as a child of pagesNode
    DCXNode *pageNode = [current addChild:[DCXMutableNode nodeWithType:@"nt2" path:@"page 1" name:@"nn2"]
                                 toParent:pagesNode withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(pageNode);
    XCTAssertNotNil(pageNode.nodeId);
    // Can we find the new node by its absolute path?
    XCTAssertEqualObjects([current getChildWithAbsolutePath:@"/pages/page 1"], pageNode);
    
    // Now add a component:
    NSString *testAssetPath = [self pathForTestAsset:@"Component.png"];
    DCXComponent *pageComponent = [current addComponent:@"cn1" withId:nil withType:@"image/png"
                                       withRelationship:@"rendition" withPath:@"rendition.png"
                                                toChild:pageNode fromFile:testAssetPath copy:YES
                                              withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(pageComponent);
    XCTAssertNotNil(pageComponent.componentId);
    XCTAssertEqual([current getAllComponents].count, 1);
    // Can we find the new component by its absolute path?
    XCTAssertEqualObjects([current getComponentWithAbsolutePath:@"/pages/page 1/rendition.png"], pageComponent);
    
    // Commit to local storage and check for the existence of the expected files
    [composite commitChangesWithError:&error];
    XCTAssertNil(error);
    XCTAssertTrue([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"manifest"]]);
    XCTAssertTrue([_fm fileExistsAtPath:[current pathForComponent:pageComponent withError:&error]]);
    XCTAssertNil(error);
    
    NSArray *problems = [composite verifyIntegrityWithLogging:YES shouldBeComplete:YES];
    XCTAssertEqual(problems.count, 0);
}

/*
 * Creates a composite object based on an href.
 */
- (void)testInstantiateRemoteComposite {
    NSError *error = nil;
    NSString *compositeId = @"i";
    NSString *compositeHref = @"h";
    NSString *compositePath = [[self createTemporaryDirectoryWithError:&error] stringByAppendingPathComponent:compositeId];
    XCTAssertNil(error);
    
    DCXComposite *composite = [DCXComposite compositeFromHref:compositeHref andId:compositeId andPath:compositePath];
    XCTAssertNotNil(composite);
    XCTAssertEqualObjects(composite.href, compositeHref);
    XCTAssertEqualObjects(composite.compositeId, compositeId);
    XCTAssertEqualObjects(composite.path, compositePath);
    XCTAssertNil(composite.current); // We should not yet have a current branch since we haven't pulled the composite yet
    
    XCTAssertFalse([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"manifest"]]); // No manifest!
    
    NSArray *problems = [composite verifyIntegrityWithLogging:YES shouldBeComplete:YES];
    XCTAssertEqual(problems.count, 0);
}

/*
 * Creates a composite object based on a composite in local storage, edits and commits it.
 */
- (void)testInstantiateLocalComposite {
    NSError *error = nil;
    
    // Copy over existing unbound composite
    NSString *compositePath = [self createTemporaryDirectoryWithContents:[self pathForTestAsset:@"unbound/"] withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(compositePath);
    
    // Instantiate composite object
    DCXComposite *composite = [DCXComposite compositeFromPath:compositePath withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(composite);
    DCXMutableBranch *current = composite.current;
    XCTAssertNotNil(current);
    
    // Make a change to a node -- need to make a mutable copy
    DCXMutableNode *pageNode = [[current getChildWithAbsolutePath:@"/pages/page 1"] mutableCopy];
    XCTAssertNotNil(pageNode);
    [pageNode setValue:@"v" forKey:@"custom#key"];
    [current updateChild:pageNode withError:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([[current getChildWithAbsolutePath:@"/pages/page 1"] valueForKey:@"custom#key"], @"v");
    
    // Update a component
    DCXComponent *pageComponent = [current getComponentWithAbsolutePath:@"/pages/page 1/rendition.png"];
    XCTAssertNotNil(pageComponent);
    [current updateComponent:pageComponent fromFile:[self pathForTestAsset:@"Component.png"] copy:YES withError:&error];
    XCTAssertNil(error);
    
    // Commit to local storage and check for the existence of the expected files
    [composite commitChangesWithError:&error];
    XCTAssertNil(error);
    XCTAssertTrue([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"manifest"]]);
    XCTAssertTrue([_fm fileExistsAtPath:[current pathForComponent:pageComponent withError:&error]]);
    XCTAssertNil(error);
    
    NSArray *problems = [composite verifyIntegrityWithLogging:YES shouldBeComplete:YES];
    XCTAssertEqual(problems.count, 0);
}

#pragma mark - Tests - Branch Management

/*
 * Resolves the conflicts between a previously pulled branch and current.
 */
- (void)testResolvePulledBranch {
    NSError *error = nil;
    NSString *compositePath = [self createTemporaryDirectoryWithContents:[self pathForTestAsset:@"pulled/"] withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(compositePath);
    
    // Instantiate composite object based
    DCXComposite *composite = [DCXComposite compositeFromPath:compositePath withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(composite);
    DCXMutableBranch *current = composite.current;
    XCTAssertNotNil(current);
    XCTAssertNotNil(composite.pulled);
    
    // Conflict resolution: we copy over a component that we had added in current
    DCXMutableBranch *resolvedBranch = [composite.pulled mutableCopy];
    DCXComponent *newComponent = [current getComponentWithAbsolutePath:@"/rendition.png"];
    XCTAssertNotNil(newComponent);
    [resolvedBranch copyComponent:newComponent from:current toChild:resolvedBranch.rootNode newPath:nil withError:&error];
    XCTAssertNil(error);
    
    // Now we resolve the pull
    BOOL success = [composite resolvePullWithBranch:resolvedBranch withError:&error];
    XCTAssertNil(error);
    XCTAssertTrue(success);
    
    // Verify
    XCTAssertTrue([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"manifest"]]);
    XCTAssertTrue([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"base.manifest"]]);
    XCTAssertFalse([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"pull.manifest"]]);
    
    XCTAssertNotNil(current);
    XCTAssertEqualObjects(current.etag, @"ee");
    XCTAssertEqualObjects(composite.committedCompositeState, @"modified");
    newComponent = [current getComponentWithAbsolutePath:@"/rendition.png"];
    XCTAssertNotNil(newComponent);
    XCTAssertEqualObjects(newComponent.state, @"modified");
    
    NSArray *problems = [composite verifyIntegrityWithLogging:YES shouldBeComplete:YES];
    XCTAssertEqual(problems.count, 0);
}


/*
 * Resolves the pulled branch of a newly pulled composite.
 */
- (void)testResolveFirstPulledBranch {
    NSError *error = nil;
    NSString *compositePath = [self createTemporaryDirectoryWithContents:[self pathForTestAsset:@"pulledNew/"] withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(compositePath);
    
    // Instantiate composite object based on its href (since we do not yet have a "current" manifest yet)
    DCXComposite *composite = [DCXComposite compositeFromHref:@"h" andId:@"i" andPath:compositePath];
    XCTAssertNil(error);
    XCTAssertNotNil(composite);
    XCTAssertNil(composite.current);
    XCTAssertNotNil(composite.pulled);
    
    // Now we resolve the pull
    BOOL success = [composite resolvePullWithBranch:nil withError:&error];
    XCTAssertNil(error);
    XCTAssertTrue(success);
    
    // Verify
    XCTAssertTrue([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"manifest"]]);
    XCTAssertTrue([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"base.manifest"]]);
    XCTAssertFalse([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"pull.manifest"]]);
    
    DCXMutableBranch *current = composite.current;
    XCTAssertNotNil(current);
    XCTAssertEqualObjects(current.etag, @"e");
    
    NSArray *problems = [composite verifyIntegrityWithLogging:YES shouldBeComplete:YES];
    XCTAssertEqual(problems.count, 0);
}

/*
 * Accepts a previously pushed branch as the new current branch.
 */
- (void)testAcceptFirstPushedBranch {
    NSError *error = nil;
    NSString *compositePath = [self createTemporaryDirectoryWithContents:[self pathForTestAsset:@"pushedNew/"] withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(compositePath);
    
    // Instantiate composite object
    DCXComposite *composite = [DCXComposite compositeFromPath:compositePath withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(composite);
    XCTAssertNotNil(composite.current);
    XCTAssertNotNil(composite.pushed);
    
    // Now we accept the push
    BOOL success = [composite acceptPushWithError:&error];
    XCTAssertNil(error);
    XCTAssertTrue(success);
    
    // Verify
    XCTAssertTrue([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"manifest"]]);
    XCTAssertTrue([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"base.manifest"]]);
    XCTAssertFalse([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"push.manifest"]]);
    
    DCXMutableBranch *current = composite.current;
    XCTAssertNotNil(current);
    XCTAssertEqualObjects(current.etag, @"e");
    
    NSArray *problems = [composite verifyIntegrityWithLogging:YES shouldBeComplete:YES];
    XCTAssertEqual(problems.count, 0);
}

/*
 * Accepts a previously pushed branch as the new current branch.
 */
- (void)testAcceptPushedBranchWithUncommittedChanges {
    NSError *error = nil;
    NSString *compositePath = [self createTemporaryDirectoryWithContents:[self pathForTestAsset:@"pushed/"] withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(compositePath);
    
    // Instantiate composite object
    DCXComposite *composite = [DCXComposite compositeFromPath:compositePath withError:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(composite);
    XCTAssertNotNil(composite.current);
    XCTAssertNotNil(composite.pushed);
    
    // Make local changes
    DCXMutableBranch *current = composite.current;
    NSString *testAssetPath = [self pathForTestAsset:@"Component.png"];
    DCXComponent *uncommittedComponent = [current addComponent:@"cn23" withId:nil withType:@"image/png"
                                              withRelationship:@"rendition" withPath:@"otherRendition.png"
                                                       toChild:current.rootNode fromFile:testAssetPath copy:YES
                                                     withError:&error];
    
    // Now we accept the push
    BOOL success = [composite acceptPushWithError:&error];
    XCTAssertNil(error);
    XCTAssertTrue(success);
    
    // Verify
    XCTAssertTrue([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"manifest"]]);
    XCTAssertTrue([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"base.manifest"]]);
    XCTAssertFalse([_fm fileExistsAtPath:[composite.path stringByAppendingPathComponent:@"push.manifest"]]);
    
    XCTAssertNotNil(current);
    XCTAssertEqualObjects(current.etag, @"ee");
    XCTAssertEqualObjects([current getComponentWithAbsolutePath:@"/otherRendition.png"].componentId, uncommittedComponent.componentId);
    
    NSArray *problems = [composite verifyIntegrityWithLogging:YES shouldBeComplete:YES];
    XCTAssertEqual(problems.count, 0);
}

@end
