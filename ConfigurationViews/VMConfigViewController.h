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
#import "StaticDataTableViewController.h"
#import "UTMConfigurationDelegate.h"

@class VMConfigTextField;
@class VMConfigSwitch;
@class VMConfigTogglePickerCell;

NS_ASSUME_NONNULL_BEGIN

@interface VMConfigViewController : StaticDataTableViewController<UTMConfigurationDelegate, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource>

@property (nonatomic, assign) BOOL doneLoadingConfiguration;
@property (nonatomic, strong) IBOutletCollection(UIView) NSArray *configControls;
@property (nonatomic, strong) IBOutletCollection(VMConfigTogglePickerCell) NSArray *configPickerToggles;

- (void)pickerCell:(nonnull UITableViewCell *)pickerCell setActive:(BOOL)active;
- (void)showAlert:(NSString *)msg completion:(nullable void (^)(UIAlertAction *action))completion;
- (void)showUnimplementedAlert;

- (void)hidePickersAnimated:(BOOL)animated;

- (IBAction)configTextEditChanged:(VMConfigTextField *)sender;
- (IBAction)configTextFieldEditEnd:(VMConfigTextField *)sender;
- (IBAction)configSwitchChanged:(VMConfigSwitch *)sender;


@end

NS_ASSUME_NONNULL_END
