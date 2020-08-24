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

@interface VMConfigSystemViewController : VMConfigViewController

@property (weak, nonatomic) IBOutlet UITextField *memorySizeField;
@property (weak, nonatomic) IBOutlet UITextField *cpuCountField;
@property (weak, nonatomic) IBOutlet UITextField *jitCacheSizeField;
@property (weak, nonatomic) IBOutlet UILabel *totalRamLabel;
@property (weak, nonatomic) IBOutlet UILabel *estimatedRamLabel;
@property (weak, nonatomic) IBOutlet UILabel *cpuCoresLabel;
@property (weak, nonatomic) IBOutlet UIPickerView *architecturePicker;
@property (weak, nonatomic) IBOutlet UIPickerView *targetPicker;

@property (nonatomic) NSInteger memorySize;
@property (nonatomic) NSInteger jitCacheSize;
@property (nonatomic, readonly) NSUInteger totalRam;
@property (nonatomic, readonly) NSUInteger estimatedRam;
@property (nonatomic) NSInteger cpuCount;

- (BOOL)memorySizeFieldValid:(UITextField *)sender;
- (BOOL)cpuCountFieldValid:(UITextField *)sender;
- (BOOL)jitCacheSizeFieldValid:(UITextField *)sender;

@end

NS_ASSUME_NONNULL_END
