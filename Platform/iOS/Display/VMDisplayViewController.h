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
#import "CSInput.h"

@class VMKeyboardButton;
@class VMUSBDevicesViewController;
@protocol VMDisplayViewControllerDelegate;

@interface VMDisplayViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIView *displayView;
@property (strong, nonatomic) IBOutlet UIInputView *inputAccessoryView;
@property (weak, nonatomic) IBOutlet UIVisualEffectView *placeholderView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *placeholderIndicator;
@property (weak, nonatomic) IBOutlet UIButton *resumeBigButton;
@property (strong, nonatomic) IBOutletCollection(VMKeyboardButton) NSArray *customKeyModifierButtons;

@property (weak, nonatomic) id<VMDisplayViewControllerDelegate> delegate;

@property (nonatomic) VMUSBDevicesViewController *usbDevicesViewController;

@property (nonatomic) BOOL hasAutoSave;
@property (nonatomic, readwrite) BOOL prefersStatusBarHidden;

@property (nonatomic, strong) NSMutableArray<UIKeyCommand *> *mutableKeyCommands;

@property (nonatomic, strong) NSMutableArray<NSObject *> *notifications;

- (void)showKeyboard;
- (void)hideKeyboard;

@end
