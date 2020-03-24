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

@interface VMConfigExistingViewController : VMConfigViewController

@property (weak, nonatomic) IBOutlet UITextField *nameField;
@property (nonatomic, assign) BOOL nameReadOnly;
@property (weak, nonatomic) IBOutlet UITableViewCell *exportLogCell;
@property (weak, nonatomic) IBOutlet UISwitch *debugLogSwitch;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;

- (IBAction)screenTapped:(UITapGestureRecognizer *)sender;
- (IBAction)nameFieldChanged:(UITextField *)sender;
- (IBAction)cancelPressed:(id)sender;
- (IBAction)debugLogSwitchChanged:(UISwitch *)sender;

@end

NS_ASSUME_NONNULL_END
