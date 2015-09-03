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

#import "CompositeListViewController.h"
#import "DropboxAccount.h"
#import "DropboxAuthViewController.h"
#import "CompositeDetailsViewController.h"

@interface CompositeListViewController ()
@property (nonatomic, retain) IBOutlet UITableView *tableView;
@end

@implementation CompositeListViewController {
    DCXHTTPService *service;
    DCXDropboxSession *session;
    DropboxAccount *dropboxAccount;
    
    UIRefreshControl *refresher;
    
    NSMutableArray *compositeList;
    NSString *documentRootPath;
    
    UIAlertView *newCompositePrompt;
    NSString *newCompositeName;
    
    NSMutableDictionary *pullsInProgress;
    NSMutableDictionary *pushesInProgress;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    pullsInProgress = [NSMutableDictionary dictionary];
    pushesInProgress = [NSMutableDictionary dictionary];
    
    // Set up the root directory for local composite storage. In this sample
    // we use a temp directory. A real app would use a more persistent location.
    compositeList = [NSMutableArray array];
    NSString *dirName = [NSString stringWithFormat:@"dcx%f", [[NSDate date] timeIntervalSince1970]];
    documentRootPath = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName];
    
    dropboxAccount = [[DropboxAccount alloc] init];
    
    // Dropbox uses two base URLs -- one for content and one for APIs
    // Ideally we would use two service objects. For now we just use
    // one service object with a nil base URL.
    service = [[DCXHTTPService alloc] initWithUrl:nil additionalHTTPHeaders:nil];
    session = [[DCXDropboxSession alloc] initWithHTTPService:service];
    service.delegate = self;
    
    // Add a Refresh Control
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    tableViewController.tableView = self.tableView;
    refresher = [[UIRefreshControl alloc] init];
    // Configure Refresh Control
    [refresher addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    // Configure View Controller
    [tableViewController setRefreshControl:refresher];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) refresh:(id)sender
{
    [self updateListOfComposites];
}

#pragma mark - IBActions

-(IBAction) handleNewCompositeButton:(id)sender
{
    [self promptForCompositeName];
}

- (IBAction)unwindToContainerVC:(UIStoryboardSegue *)segue {
    DCXComposite *composite = ((CompositeDetailsViewController*)segue.sourceViewController).composite;
    if (composite.committedCompositeState == DCXAssetStateModified) {
        [self pushComposite:composite];
    }
}

#pragma mark - DCX

-(NSString*) hrefForCompositeId:(NSString*)compositeId
{
    return [NSString stringWithFormat:@"/%@", compositeId];
}

-(NSString*) localStoragePathForCompositeId:(NSString*)compositeId
{
    return [documentRootPath stringByAppendingPathComponent:compositeId];
}

-(void) pushComposite:(DCXComposite*)composite
{
    NSString *compositeId = composite.compositeId;
    
    @synchronized(pushesInProgress) {
        if (pushesInProgress[compositeId] == nil) {
            pushesInProgress[compositeId] = [DCXCompositeXfer pushComposite:composite usingSession:session
                                                            requestPriority:NSOperationQueuePriorityNormal
                                                               handlerQueue:[NSOperationQueue mainQueue]
                                                          completionHandler:^(BOOL success, NSError *error) {
                                                              if (error != nil) {
                                                                  NSLog(@"Push failed: %@", error.description);
                                                              } else {
                                                                  // Accept
                                                                  [composite acceptPushWithError:&error];
                                                                  if (error != nil) {
                                                                      NSLog(@"Accept failed: %@", error.description);
                                                                  } else {
                                                                      UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;
                                                                      [refresher beginRefreshing];
                                                                      [self updateListOfComposites];
                                                                  }
                                                              }
                                                          }];
        }
    }
}

-(void) newCompositeWithName:(NSString*)name andJPGImageAtPath:(NSString*)imagePath
{
    NSError *error;
    
    // Create new composite
    NSString *type = @"application/vnd.dcx.sample+dcx";
    DCXComposite *composite = [DCXComposite compositeWithName:name
                                                      andType:type
                                                      andPath:nil
                                                        andId:nil
                                                      andHref:nil];
    
    // We use the composite id as directory name both in Dropbox and in local storage
    composite.href = [self hrefForCompositeId:composite.compositeId];
    composite.path = [self localStoragePathForCompositeId:composite.compositeId];
    
    // Add the image as a component to the root of the composite
    DCXMutableBranch *current = composite.current;
    DCXComponent *component = [current addComponent:nil withId:nil withType:@"image/jpg"
                                   withRelationship:@"rendition" withPath:@"image.jpg" toChild:current.rootNode
                                           fromFile:imagePath copy:NO withError:&error];
    if (component != nil) {
        
        // Commit to local storage
        [composite commitChangesWithError:&error];
        
        if (error != nil) {
            NSLog(@"Commit changes failed: %@", error.description);
        } else {
            // Push
            [DCXCompositeXfer pushComposite:composite usingSession:session
                            requestPriority:NSOperationQueuePriorityNormal
                               handlerQueue:[NSOperationQueue mainQueue]
                          completionHandler:^(BOOL success, NSError *error) {
                              if (error != nil) {
                                  NSLog(@"Push failed: %@", error.description);
                              } else {
                                  // Accept
                                  [composite acceptPushWithError:&error];
                                  if (error != nil) {
                                      NSLog(@"Accept failed: %@", error.description);
                                  } else {
                                      UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;
                                      [refresher beginRefreshing];
                                      [self updateListOfComposites];
                                  }
                              }
                          }];
        }
    } else {
        NSLog(@"Adding the component failed: %@", error.description);
    }
}

-(DCXComposite*) getCompositeWithId:(NSString*)compositeId
{
    DCXComposite *composite = nil;
    NSString *localStoragePath = [self localStoragePathForCompositeId:compositeId];
    
    // First try to instantiate the composite from local storage
    composite = [DCXComposite compositeFromPath:localStoragePath withError:nil];
    
    if (composite == nil) {
        composite = [DCXComposite compositeFromHref:[self hrefForCompositeId:compositeId] andId:compositeId
                                            andPath:localStoragePath];
    }
    
    return composite;
}

-(void) pullMinimalCompositeWithId:(NSString*)compositeId
{
    @synchronized(pullsInProgress) {
        if (pullsInProgress[compositeId] == nil) {
            DCXComposite *composite = [self getCompositeWithId:compositeId];
            
            pullsInProgress[compositeId] = [DCXCompositeXfer pullMinimalComposite:composite usingSession:session
                                                                  requestPriority:NSOperationQueuePriorityNormal handlerQueue:[NSOperationQueue mainQueue]
                                                                completionHandler:^(DCXBranch *branch, NSError *error) {
                                                                    if (error != nil) {
                                                                        NSLog(@"Pull minimal failed: %@", error.description);
                                                                    } else {
                                                                        // Since we are not editing composites in this sample app
                                                                        // we can pass nil as branch which means that we just make
                                                                        // the pulled branch current.
                                                                        [composite resolvePullWithBranch:nil withError:&error];
                                                                        if (error != nil) {
                                                                            NSLog(@"Resolve failed: %@", error.description);
                                                                        } else {
                                                                            [self.tableView reloadData];
                                                                        }
                                                                    }
                                                                    @synchronized(pullsInProgress) {
                                                                        [pullsInProgress removeObjectForKey:compositeId];
                                                                    }
                                                                }];
        }
    }
}

-(NSString*) getNameOfCompositeWithId:(NSString*)compositeId
{
    DCXComposite *composite = [DCXComposite compositeFromPath:[self localStoragePathForCompositeId:compositeId] withError:nil];
    return (composite == nil) ? nil : composite.current.name;
}

-(void) displayCompositeWithId:(NSString*)compositeId
{
    @synchronized(pullsInProgress) {
        if (pullsInProgress[compositeId] == nil) {
            DCXComposite *composite = [self getCompositeWithId:compositeId];
            pullsInProgress[compositeId] = [DCXCompositeXfer pullComposite:composite usingSession:session
                                                           requestPriority:NSOperationQueuePriorityNormal handlerQueue:[NSOperationQueue mainQueue]
                                                         completionHandler:^(DCXBranch *branch, NSError *error) {
                                                             if (error != nil) {
                                                                 NSLog(@"Pull failed: %@", error.description);
                                                             } else {
                                                                 // Since we are not editing composites in this sample app
                                                                 // we can pass nil as branch which means that we just make
                                                                 // the pulled branch current.
                                                                 [composite resolvePullWithBranch:nil withError:&error];
                                                                 if (error != nil) {
                                                                     NSLog(@"Resolve failed: %@", error.description);
                                                                 } else {
                                                                     [self displayComposite:composite];
                                                                 }
                                                             }
                                                             @synchronized(pullsInProgress) {
                                                                 [pullsInProgress removeObjectForKey:compositeId];
                                                             }
                                                         }];
        }
    }
}

#pragma mark - Dropbox Access

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

-(void) updateListOfComposites
{
    // Using the service object directly to get the list of directories at the root of our sandbox
    // which corresponds to the list of composites
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self urlFromString:@"metadata/sandbox"
                                                                                 andParams:@{
                                                                                             @"list": @"true",
                                                                                             @"include_deleted": @"false"
                                                                                             }
                                                                             relativeToUrl:[NSURL URLWithString:@"https://api.dropbox.com/1/"]]];
    
    [service getResponseForDataRequest:request requestPriority:NSOperationQueuePriorityNormal
                     completionHandler:^(DCXHTTPResponse *response) {
                         if (response.error == nil) {
                             // execute on main thread:
                             dispatch_sync(dispatch_get_main_queue(), ^{
                                 NSError *error = nil;
                                 NSDictionary *data = [NSJSONSerialization JSONObjectWithData:response.data
                                                                                      options:0
                                                                                        error:&error];
                                 if (error == nil) {
                                     // Update Model
                                     NSMutableArray *newCompositeList = [NSMutableArray array];
                                     NSArray *items = data[@"contents"];
                                     for (NSDictionary *item in items) {
                                         BOOL isDir = [item[@"is_dir"] boolValue];
                                         if (isDir) {
                                             [newCompositeList addObject:item[@"path"]];
                                         }
                                     }
                                     
                                     // Update UI
                                     NSInteger delta = newCompositeList.count - compositeList.count;
                                     if (delta < 0) {
                                         NSMutableArray *rows = [NSMutableArray arrayWithCapacity:-delta];
                                         for (int i = (int) newCompositeList.count; i < compositeList.count; i++) {
                                             [rows addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                                         }
                                         compositeList = newCompositeList;
                                         [self.tableView deleteRowsAtIndexPaths:rows withRowAnimation:UITableViewRowAnimationAutomatic];
                                         [self.tableView reloadData];
                                     } else if (delta > 0) {
                                         NSMutableArray *rows = [NSMutableArray arrayWithCapacity:delta];
                                         for (int i = (int) compositeList.count; i < newCompositeList.count; i++) {
                                             [rows addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                                         }
                                         compositeList = newCompositeList;
                                         [self.tableView insertRowsAtIndexPaths:rows withRowAnimation:UITableViewRowAnimationAutomatic];
                                         [self.tableView reloadData];
                                     }
                                     UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
                                     [refresher endRefreshing];
                                 } else {
                                     [self updateFailedWithError:error];
                                 }
                                 
                             });
                         } else {
                             [self updateFailedWithError:response.error];
                         }
                     }];
}

- (void)updateFailedWithError:(NSError*)error
{
    // TBD: Report the underlying error in some useful way.
    NSLog(@"Updating composite list failed: %@", error.description);
    UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
    [refresher endRefreshing];
}

#pragma mark - UITableViewDelegate Protocol

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *item = compositeList[indexPath.row];
    NSString *compositeId = [item lastPathComponent];
    [self displayCompositeWithId:compositeId];
}

#pragma mark - UITableViewDataSource Protocol

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return compositeList.count;
}

-(UITableViewCell*) tableView:(UITableView *)view cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *item = compositeList[indexPath.row];
    UITableViewCell *cell = [view dequeueReusableCellWithIdentifier:item];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:item];
    }
    
    NSString *compositeId = [item lastPathComponent];
    NSString *compositeName = [self getNameOfCompositeWithId:compositeId];
    
    if (compositeName == nil) {
        cell.textLabel.text = [NSString stringWithFormat:@"[pulling composite id %@...]", compositeId];
        [self pullMinimalCompositeWithId:compositeId];
    } else {
        cell.textLabel.text = compositeName;
    }
    return cell;
}

#pragma mark - Authentication

-(void) authenticateWithDropbox
{
    DropboxAuthViewController *dropboxAuthController = [[DropboxAuthViewController alloc] init];
    dropboxAuthController.documentsController        = self;
    dropboxAuthController.account                    = dropboxAccount;
    dropboxAuthController.modalTransitionStyle       = UIModalTransitionStyleCoverVertical;
    dropboxAuthController.modalPresentationStyle     = UIModalPresentationPageSheet;
    
    [self presentViewController:dropboxAuthController animated:YES completion:nil];
}

-(void) dropboxCodeRequestComplete
{
    if (dropboxAccount.isAuthenticated) {
        [dropboxAccount getTokenUsingQueue:[NSOperationQueue mainQueue]
                         completionHandler:^(NSString *token, NSError *error) {
                             if (dropboxAccount.hasToken) {
                                 service.authToken = dropboxAccount.authToken;
                                 service.suspended = NO;
                             } else {
                                 [self performSelectorOnMainThread:@selector(authenticationFailedWithError:) withObject:dropboxAccount.error waitUntilDone:NO];
                             }
                         }];
    } else {
        [self performSelectorOnMainThread:@selector(authenticationFailedWithError:) withObject:dropboxAccount.error waitUntilDone:NO];
    }
}

- (void)authenticationFailedWithError:(NSError*)error
{
    // TBD: Report the underlying error in some useful way.
    NSLog(@"Authentication failed: %@", error.description);
    UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
    [refresher endRefreshing];
}

#pragma mark - DCXHTTPServiceDelegate protocol

- (BOOL)HTTPServiceAuthenticationDidFail:(DCXHTTPService *)service
{
    [self performSelectorOnMainThread:@selector(authenticateWithDropbox) withObject:nil waitUntilDone:NO];
    
    return YES;
}

-(void) HTTPServiceDidDisconnect:(DCXHTTPService *)service
{
    // TODO: Implement a button or something similar for the user to reconnect the service
}

#pragma mark - Alerts etc.

- (void)promptForCompositeName
{
    newCompositePrompt = [[UIAlertView alloc] initWithTitle:@"Name your composite" message:nil delegate:self
                                          cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
    newCompositePrompt.alertViewStyle = UIAlertViewStylePlainTextInput;
    [newCompositePrompt textFieldAtIndex:0].returnKeyType = UIReturnKeyDone;
    [newCompositePrompt textFieldAtIndex:0].delegate = self;
    [newCompositePrompt show];
}

- (void)alertView:(UIAlertView*)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    BOOL isOK = (buttonIndex == alertView.firstOtherButtonIndex);
    if ( isOK && alertView == newCompositePrompt) {
        newCompositeName  = [[newCompositePrompt textFieldAtIndex:0] text];
        [self selectPhoto];
    }
}

- (void)selectPhoto
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:NULL];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *selectedImage = info[UIImagePickerControllerEditedImage];
    
    // Write the image to disk
    NSString *imagePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [UIImageJPEGRepresentation(selectedImage, 1.0) writeToFile:imagePath atomically:YES];
    
    [picker dismissViewControllerAnimated:YES completion:NULL];
    [self newCompositeWithName:newCompositeName andJPGImageAtPath:imagePath];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:NULL];
}

-(void) displayComposite:(DCXComposite*)composite
{
    [self performSegueWithIdentifier:@"CompositeDetails" sender:composite];
}

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    CompositeDetailsViewController *controller = (CompositeDetailsViewController*) segue.destinationViewController;
    controller.composite = sender;
}

@end
