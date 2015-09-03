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


#import "CompositeDetailsViewController.h"
#import <DigitalComposites/DigitalComposites.h>

@interface CompositeDetailsViewController ()
@property (nonatomic, retain) IBOutlet UIImageView *imageView;
@end

@implementation CompositeDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.composite != nil) {
        NSError *error = nil;
        DCXBranch *current = self.composite.current;
        self.navigationItem.title = current.name;
        DCXComponent *component = [current getComponentWithAbsolutePath:@"/image.jpg"];
        NSString *imapeFilePath = [current pathForComponent:component withError:&error];
        if (error != nil) {
            NSLog(@"Could not find component file: %@", error.description);
        } else {
            self.imageView.image = [UIImage imageWithContentsOfFile:imapeFilePath];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
 */


#pragma mark - DCX

-(void) deleteComposite
{
    
}

-(void) replacePhotoWithJPGImageAtPath:(NSString*)photoPath
{
    NSError *error = nil;
    DCXMutableBranch *current = self.composite.current;
    DCXComponent *component = [current getComponentWithAbsolutePath:@"/image.jpg"];
    component = [current updateComponent:component fromFile:photoPath copy:NO withError:&error];
    if (error != nil) {
        NSLog(@"Update component failed: %@", error.description);
    } else {
        UIImage *newImage = [UIImage imageWithContentsOfFile:[current pathForComponent:component withError:&error]];
        self.imageView.image = newImage;
    }
}

#pragma mark - Button Handlers

-(IBAction) handleChangePhotoButton:(id)sender
{
    [self selectPhoto];
}

-(IBAction) saveComposite:(id)sender
{
    NSError *error = nil;
    [self.composite commitChangesWithError:&error];
    if (error != nil) {
        NSLog(@"Committing changes failed: %@", error.description);
    } else {
        [self performSegueWithIdentifier:@"unwind" sender:self];
    }
}


#pragma mark - Misc

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
    [self replacePhotoWithJPGImageAtPath:imagePath];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:NULL];
}

@end
