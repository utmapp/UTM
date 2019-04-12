//
// Copyright © 2019 Halts. All rights reserved.
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

@interface VMConfigDisplayViewController : VMConfigViewController<UIPickerViewDelegate, UIPickerViewDataSource>

@property (weak, nonatomic) IBOutlet UITableViewCell *graphicsTypeFullCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *graphicsTypeConsoleCell;
@property (weak, nonatomic) IBOutlet UISwitch *resolutionFixedSwitch;
@property (weak, nonatomic) IBOutlet UITableViewCell *maxResolutionCell;
@property (weak, nonatomic) IBOutlet UILabel *maxResolutionLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *maxResolutionPickerCell;
@property (weak, nonatomic) IBOutlet UIPickerView *maxResolutionPicker;
@property (nonatomic, assign) BOOL maxResolutionPickerActive;
@property (weak, nonatomic) IBOutlet UISwitch *zoomScaleFitSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *zoomLetterboxSwitch;
@property (strong, nonatomic) IBOutletCollection(UITableViewCell) NSArray *displayTypeCells;
@property (strong, nonatomic) IBOutletCollection(UITableViewCell) NSArray *displayTypeCellsWithoutPicker;
@property (strong, nonatomic) IBOutletCollection(UITableViewCell) NSArray *consoleTypeCells;

@property (nonatomic, assign) BOOL consoleOnly;
@property (nonatomic, nullable, strong) NSString *maxResolution;

- (IBAction)resolutionFixedSwitchChanged:(UISwitch *)sender;
- (IBAction)zoomScaleFitSwitchChanged:(UISwitch *)sender;
- (IBAction)zoomLetterboxSwitchChanged:(UISwitch *)sender;

@end

NS_ASSUME_NONNULL_END
