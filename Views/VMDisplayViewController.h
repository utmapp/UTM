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

@class VMKeyboardButton;
@class VMKeyboardView;

NS_ASSUME_NONNULL_BEGIN

IB_DESIGNABLE @interface VMDisplayViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIView *controlView;
@property (weak, nonatomic) IBOutlet UIView *mainView;
@property (strong, nonatomic) IBOutlet UIInputView *inputAccessoryView;
@property (weak, nonatomic) IBOutlet VMKeyboardView *keyboardView;
@property (weak, nonatomic) IBOutlet UIView *toolbarAccessoryView;
@property (weak, nonatomic) IBOutlet UIButton *powerExitButton;
@property (weak, nonatomic) IBOutlet UIButton *pauseResumeButton;
@property (weak, nonatomic) IBOutlet UIButton *restartButton;
@property (weak, nonatomic) IBOutlet UIButton *zoomButton;
@property (weak, nonatomic) IBOutlet UIVisualEffectView *placeholderView;
@property (weak, nonatomic) IBOutlet UIImageView *placeholderImageView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *placeholderIndicator;
@property (weak, nonatomic) IBOutlet UIButton *resumeBigButton;
@property (strong, nonatomic) IBOutletCollection(VMKeyboardButton) NSArray *customKeyButtons;
@property (strong, nonatomic) IBOutletCollection(VMKeyboardButton) NSArray *customKeyModifierButtons;

- (IBAction)changeDisplayZoom:(UIButton *)sender;
- (IBAction)pauseResumePressed:(UIButton *)sender;
- (IBAction)powerPressed:(UIButton *)sender;
- (IBAction)restartPressed:(UIButton *)sender;
- (IBAction)showKeyboardButton:(UIButton *)sender;
- (IBAction)hideToolbarButton:(UIButton *)sender;

@end

NS_ASSUME_NONNULL_END
