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

#import <UIKit/UIKit.h>
#import "VMConfigViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMConfigDriveCreateViewController : VMConfigViewController

@property (weak, nonatomic) IBOutlet UITextField *imageSizeField;
@property (weak, nonatomic) IBOutlet UISwitch *imageExpandingSwitch;
@property (weak, nonatomic) IBOutlet UITextField *imagePathField;

@property (nonatomic, strong) NSURL *imagesPath;
@property (nonatomic, nullable, strong) NSURL *existingPath;
@property (nonatomic, strong) NSURL *changePath;
@property (nonatomic, readonly) NSInteger size;
@property (nonatomic, readonly) BOOL imageExpanding;
@property (nonatomic, assign) BOOL shownExistingWarning;

- (IBAction)imageExpandingSwitchChanged:(UISwitch *)sender;
- (IBAction)imagePathFieldChanged:(UITextField *)sender;
- (IBAction)imageSizeFieldChanged:(UITextField *)sender;
- (IBAction)saveButtonPressed:(UIBarButtonItem *)sender;

@end

NS_ASSUME_NONNULL_END
