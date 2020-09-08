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

@class VMConfigTogglePickerCell;

NS_ASSUME_NONNULL_BEGIN

@interface VMConfigDriveDetailViewController : VMConfigViewController

// removable
@property (weak, nonatomic) IBOutlet UISwitch *removableToggle;
@property (nonatomic) BOOL removable;

// image source
@property (weak, nonatomic) IBOutlet UITableViewCell *existingPathCell;
@property (weak, nonatomic) IBOutlet UILabel *existingPathLabel;
@property (nonatomic, nullable, copy) NSString *imageName;

// image type
@property (weak, nonatomic) IBOutlet VMConfigTogglePickerCell *imageTypePickerCell;
@property (nonatomic, assign) UTMDiskImageType imageType;
@property (strong, nonatomic) IBOutletCollection(UITableViewCell) NSArray *driveTypeCells;

// drive location
@property (weak, nonatomic) IBOutlet VMConfigTogglePickerCell *driveLocationPickerCell;
@property (nonatomic, nullable, strong) NSString *driveInterfaceType;

@property (nonatomic, assign) NSUInteger driveIndex;
@property (nonatomic, assign) BOOL valid;

- (IBAction)removableToggleChanged:(UISwitch *)sender;
- (IBAction)saveButtonPressed:(UIBarButtonItem *)sender;

@end

NS_ASSUME_NONNULL_END
