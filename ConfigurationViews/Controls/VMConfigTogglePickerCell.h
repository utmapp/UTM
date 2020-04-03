//
// Copyright © 2020 osy. All rights reserved.
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

@class VMConfigLabel;
@class VMConfigPickerView;

NS_ASSUME_NONNULL_BEGIN

IB_DESIGNABLE
@interface VMConfigTogglePickerCell : UITableViewCell

@property (nonatomic, strong) IBOutletCollection(UITableViewCell) NSArray *toggleVisibleCells;
@property (nonatomic, weak) IBOutlet VMConfigPickerView *picker;
@property (nonatomic, weak) IBOutlet VMConfigLabel *label;
@property (nonatomic) IBInspectable BOOL cellsVisible;

@end

NS_ASSUME_NONNULL_END
