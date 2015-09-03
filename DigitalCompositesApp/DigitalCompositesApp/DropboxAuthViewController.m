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

#import "DropboxAuthViewController.h"
#import "CompositeListViewController.h"
#import "DropboxAccount.h"

@implementation DropboxAuthViewController {
    UINavigationBar *toolbar;
    UIWebView       *webView;
}

#pragma mark View Management

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Set up the toolbar
    toolbar = [[UINavigationBar alloc] init];
    
    UINavigationItem *navItem = [[UINavigationItem alloc] init];
    navItem.title = @"Dropbox Authentication";
    navItem.leftBarButtonItem  = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(authCancel:)];
    [toolbar pushNavigationItem:navItem animated:NO];
    
    [self.view addSubview:toolbar];

    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeTop   relatedBy:NSLayoutRelationEqual toItem:toolbar attribute:NSLayoutAttributeTop   multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeLeft  relatedBy:NSLayoutRelationEqual toItem:toolbar attribute:NSLayoutAttributeLeft  multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:toolbar attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    
    // Set up the web view
    webView = [[UIWebView alloc] init];
    [self.view addSubview:webView];
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[webView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(webView)]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[toolbar][webView]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(webView,toolbar)]];
    
    // Load the request
    NSURLRequest *request = [NSURLRequest requestWithURL:_account.authWebViewUrl];
    webView.delegate = self;
    [webView loadRequest:request];
    
}

#pragma mark Web View Delegate

-(BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([_account shouldCloseAuthWebViewBasedOnNavigationTo:request.URL]) {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        CompositeListViewController *strongViewController = self.documentsController;
        if (strongViewController != nil) {
            [strongViewController dropboxCodeRequestComplete];
        }
        return NO;
    }
    return YES;
}

#pragma mark Misc

- (void)authCancel:(id)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    CompositeListViewController *strongViewController = self.documentsController;
    if (strongViewController != nil) {
        [strongViewController dropboxCodeRequestComplete];
    }
}

@end
