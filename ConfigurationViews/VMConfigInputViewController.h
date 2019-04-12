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

@interface VMConfigInputViewController : VMConfigViewController

@property (weak, nonatomic) IBOutlet UITableViewCell *pointerStyleTouchscreenCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *pointerStyleTrackpadCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *inputReceiverDirectCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *inputReceiverServerCell;

@property (nonatomic, assign) BOOL inputTouchscreenMode;
@property (nonatomic, assign) BOOL inputDirect;

@end

NS_ASSUME_NONNULL_END
