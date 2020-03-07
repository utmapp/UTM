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

#import "VMDisplayMetalViewController.h"
#import "VMKeyboardViewDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMDisplayMetalViewController (Keyboard) <VMKeyboardViewDelegate>

@property (nonatomic, readonly) NSArray<UIKeyCommand *> *keyCommands;

- (IBAction)keyboardDonePressed:(UIButton *)sender;
- (IBAction)keyboardPastePressed:(UIButton *)sender;
- (IBAction)customKeyTouchDown:(VMKeyboardButton *)sender;
- (IBAction)customKeyTouchUp:(VMKeyboardButton *)sender;

- (void)keyboardWillShow:(NSNotification *)notification;
- (void)keyboardWillHide:(NSNotification *)notification;
- (void)keyboardWillChangeFrame:(NSNotification *)notification;

@end

NS_ASSUME_NONNULL_END
