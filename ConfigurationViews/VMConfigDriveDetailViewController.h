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
#import "UTMConfiguration+Drives.h"
#import "VMConfigViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMConfigDriveDetailViewController : VMConfigViewController<UIPickerViewDelegate, UIPickerViewDataSource>

@property (weak, nonatomic) IBOutlet UILabel *existingPathLabel;

// image type
@property (weak, nonatomic) IBOutlet UILabel *imageTypeLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *imageTypePickerCell;
@property (weak, nonatomic) IBOutlet UIPickerView *imageTypePicker;
@property (weak, nonatomic) IBOutlet UITableViewCell *imageTypeCell;
@property (nonatomic, assign) BOOL imageTypePickerActive;
@property (nonatomic, assign) UTMDiskImageType imageType;

// drive location
@property (weak, nonatomic) IBOutlet UILabel *driveLocationLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *driveLocationPickerCell;
@property (weak, nonatomic) IBOutlet UIPickerView *driveLocationPicker;
@property (weak, nonatomic) IBOutlet UITableViewCell *driveLocationCell;
@property (nonatomic, assign) BOOL driveLocationPickerActive;
@property (nonatomic, nullable, strong) NSString *driveInterfaceType;

@property (weak, nonatomic) IBOutlet UISwitch *isCdromSwitch;
@property (nonatomic, assign) NSUInteger driveIndex;
@property (nonatomic, assign) BOOL valid;

@end

NS_ASSUME_NONNULL_END
