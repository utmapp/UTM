//
// Copyright © 2019 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "VMConfigDriveCreateViewController.h"
#import "UTMQemuImg.h"

extern NSString *const kUTMErrorDomain;

@interface VMConfigDriveCreateViewController ()

@end

@implementation VMConfigDriveCreateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _imageExpanding = self.imageExpandingSwitch.on;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshViewFromConfiguration];
}

- (void)refreshViewFromConfiguration {
    self.imagePathField.text = self.changePath.lastPathComponent;
    // TODO: allow resizing, change format
    if (self.existingPath) {
        self.imageSizeField.enabled = NO;
        self.imageExpandingSwitch.enabled = NO;
    }
}

- (void)setExistingPath:(NSURL *)existingPath {
    _existingPath = existingPath;
    self.changePath = existingPath;
    [self refreshViewFromConfiguration];
}

#pragma mark - Operations

- (void)showAlert:(NSString *)msg completion:(nullable void (^)(UIAlertAction *action))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK button") style:UIAlertActionStyleDefault handler:completion];
    [alert addAction:okay];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (BOOL)createDisk:(NSError * _Nullable *)err {
    __block NSError *perr = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    UTMQemuImg *imgCreate = [[UTMQemuImg alloc] init];
    imgCreate.op = kUTMQemuImgCreate;
    imgCreate.outputPath = self.changePath;
    imgCreate.sizeMiB = self.size;
    imgCreate.compressed = self.imageExpanding;
    [imgCreate startWithCompletion:^(BOOL success, NSString *msg){
        if (!success) {
            if (!msg) {
                msg = NSLocalizedString(@"Disk creation failed.", @"VMConfigDriveCreateViewController");
            }
            perr = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    if (err) {
        *err = perr;
    }
    return (perr == nil);
}

- (void)workWithIndicator:(NSString *)msg block:(void(^)(void))block completion:(void (^)(void))completion  {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(10, 5, 50, 50)];
    spinner.hidesWhenStopped = YES;
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    [spinner startAnimating];
    [alert.view addSubview:spinner];
    [self presentViewController:alert animated:YES completion:nil];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        block();
        dispatch_async(dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:completion];
        });
    });
}

#pragma mark - Event handlers

- (IBAction)imageExpandingSwitchChanged:(UISwitch *)sender {
    _imageExpanding = sender.on;
}


- (IBAction)imagePathFieldChanged:(UITextField *)sender {
    // TODO: validate input
    // check if existing file
    self.changePath = [self.imagesPath URLByAppendingPathComponent:sender.text];
    if (!self.shownExistingWarning && ![self.changePath isEqual:self.existingPath] && [[NSFileManager defaultManager] fileExistsAtPath:self.changePath.path]) {
        [self showAlert:NSLocalizedString(@"A file already exists for this name, if you proceed, it will be replaced.", @"VMConfigDriveCreateViewController") completion:^(UIAlertAction *action){
            self.shownExistingWarning = YES;
        }];
    }
}

- (IBAction)imageSizeFieldChanged:(UITextField *)sender {
    // TODO: validate input
    _size = [self.imageSizeField.text intValue];
    if (self.size == 0) {
        [self showAlert:NSLocalizedString(@"Invalid size", @"VMConfigDriveCreateViewController") completion:nil];
    }
}

- (IBAction)saveButtonPressed:(UIBarButtonItem *)sender {
    [self.view endEditing:YES];
    if (!self.existingPath) {
        if (!self.changePath) {
            [self showAlert:NSLocalizedString(@"Invalid name", @"VMConfigDriveCreateViewController") completion:nil];
        } else if (self.size == 0) {
            [self showAlert:NSLocalizedString(@"Invalid size", @"VMConfigDriveCreateViewController") completion:nil];
        } else {
            __block NSError *err;
            [self workWithIndicator:NSLocalizedString(@"Creating disk...", @"VMConfigDriveCreateViewController") block:^{
                BOOL isdir;
                BOOL direxists = NO;
                // create images directory
                if (![[NSFileManager defaultManager] fileExistsAtPath:self.imagesPath.path isDirectory:&isdir]) {
                    if ([[NSFileManager defaultManager] createDirectoryAtURL:self.imagesPath withIntermediateDirectories:NO attributes:nil error:&err]) {
                        direxists = YES;
                    }
                } else if (!isdir) {
                    err = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot create directory for disk image.", @"VMConfigDriveCreateViewController")}];
                } else {
                    direxists = YES;
                }
                if (direxists) {
                    [self createDisk:&err];
                }
            } completion:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (err) {
                        [self showAlert:err.localizedDescription completion:^(UIAlertAction *action){
                            [self.navigationController popViewControllerAnimated:YES];
                        }];
                    } else {
                        [self.navigationController popViewControllerAnimated:YES];
                    }
                });
            }];
        }
    } else if (![self.changePath isEqual:self.existingPath]) {
        if (![[NSFileManager defaultManager] moveItemAtURL:self.existingPath toURL:self.changePath error:nil]) {
            [self showAlert:NSLocalizedString(@"Error renaming file", @"VMConfigDriveCreateViewController") completion:nil];
        }
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
