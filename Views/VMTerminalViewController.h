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
#import <WebKit/WebKit.h>
#import "UTMVirtualMachine.h"
#import "UTMVirtualMachineDelegate.h"
#import "UTMTerminalIO.h"
#import "UTMTerminal.h"
#import "UTMTerminalDelegate.h"
#import "VMKeyboardButton.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMTerminalViewController : UIViewController <UTMTerminalDelegate, UTMVirtualMachineDelegate, WKScriptMessageHandler, UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet WKWebView *webView;
@property (weak, nonatomic) IBOutlet UIView *toolbarAccessoryView;
@property (weak, nonatomic) IBOutlet UIInputView *inputAccessoryView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *webViewTopConstraint;
@property (weak, nonatomic) IBOutlet UIButton *powerExitButton;
@property (weak, nonatomic) IBOutlet UIButton *pauseResumeButton;
@property (weak, nonatomic) IBOutlet UIButton *restartButton;
@property (weak, nonatomic) IBOutlet UIButton *keyboardButton;
@property (nonatomic) BOOL toolbarVisible;
@property (nonatomic, weak) UTMTerminal* terminal;
@property (nonatomic, strong, nullable) UTMVirtualMachine* vm;

- (IBAction)pauseResumePressed:(UIButton *)sender;
- (IBAction)powerPressed:(UIButton *)sender;
- (IBAction)restartPressed:(UIButton *)sender;
- (IBAction)showKeyboardPressed:(UIButton *)sender;
- (IBAction)hideToolbarPressed:(UIButton *)sender;

- (IBAction)customKeyTouchDown:(VMKeyboardButton *)sender;
- (IBAction)customKeyTouchUp:(VMKeyboardButton *)sender;
- (IBAction)keyboardPastePressed:(UIButton *)sender;
- (IBAction)keyboardDonePressed:(UIButton *)sender;

@end

NS_ASSUME_NONNULL_END
