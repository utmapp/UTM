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

#import "VMDisplayViewController.h"
#import "UTM-Swift.h"

@implementation VMDisplayViewController

#pragma mark - Properties

@synthesize prefersStatusBarHidden = _prefersStatusBarHidden;
@synthesize keyboardVisible = _keyboardVisible;

- (UTMQemuConfiguration *)vmQemuConfig {
    return (UTMQemuConfiguration *)self.vm.config;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES; // always hide home indicator
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)setPrefersStatusBarHidden:(BOOL)prefersStatusBarHidden {
    _prefersStatusBarHidden = prefersStatusBarHidden;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)setKeyboardVisible:(BOOL)keyboardVisible {
    if (_keyboardVisible != keyboardVisible) {
        [[NSUserDefaults standardUserDefaults] setBool:keyboardVisible forKey:@"LastKeyboardVisible"];
    }
    _keyboardVisible = keyboardVisible;
}

#pragma mark - View handling

- (BOOL)inputViewIsFirstResponder {
    return NO;
}

- (void)updateKeyboardAccessoryFrame {
}

- (void)virtualMachine:(UTMVirtualMachine *)vm didTransitionToState:(UTMVMState)state {
    static BOOL hasStartedOnce = NO;
    if (hasStartedOnce && state == kVMStopped) {
        [self terminateApplication];
    }
    switch (state) {
        case kVMStopped:
        case kVMPaused: {
            [self enterSuspendedWithIsBusy:NO];
            break;
        }
        case kVMPausing:
        case kVMStopping:
        case kVMStarting:
        case kVMResuming: {
            [self enterSuspendedWithIsBusy:YES];
            break;
        }
        case kVMStarted: {
            hasStartedOnce = YES; // auto-quit after VM ends
            [self enterLive];
            break;
        }
    }
}

- (void)virtualMachine:(UTMVirtualMachine *)vm didErrorWithMessage:(NSString *)message {
    [self.placeholderIndicator stopAnimating];
    self.resumeBigButton.hidden = YES;
    [self showAlert:message actions:nil completion:^(UIAlertAction *action){
        if (vm.state != kVMStarted && vm.state != kVMPaused) {
            [self terminateApplication];
        }
    }];
}

@end
