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

#import "VMDisplayTerminalViewController+Keyboard.h"
#import "VMKeyboardButton.h"
#import "VMKeyboardView.h"

@implementation VMDisplayTerminalViewController (Keyboard)

- (IBAction)keyboardDonePressed:(UIButton *)sender {
    self.keyboardVisible = NO;
}

- (IBAction)keyboardPastePressed:(UIButton *)sender {
    UIPasteboard* pasteboard = [UIPasteboard generalPasteboard];
    NSString* string = pasteboard.string;
    if (string != nil) {
        [self.terminal sendInput: string];
    }
}

- (void)resetModifierToggles {
    for (VMKeyboardButton *button in self.customKeyModifierButtons) {
        if (button.toggled) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self customKeyTouchUp:button];
            });
        }
    }
}

- (IBAction)customKeyTouchDown:(VMKeyboardButton *)sender {
    if (!sender.toggleable) {
        NSString* jsString = [NSString stringWithFormat: @"programmaticKeyDown(%d);", [sender scanCode]];
        [self.webView evaluateJavaScript:jsString completionHandler:nil];
    }
}

- (IBAction)customKeyTouchUp:(VMKeyboardButton *)sender {
    if (sender.toggleable) {
        sender.toggled = !sender.toggled;
    }
    
    if (sender.toggleable) {
        NSString* jsKey = [self jsModifierForScanCode: sender.scanCode];
        if (jsKey == nil) {
            return;
        }
        
        NSString* jsTemplate = sender.toggled ? @"modifierDown(\"%@\");" : @"modifierUp(\"%@\");";
        NSString* jsString = [NSString stringWithFormat: jsTemplate, jsKey];
        [self.webView evaluateJavaScript:jsString completionHandler: nil];
    } else {
        NSString* jsString = [NSString stringWithFormat: @"programmaticKeyUp(%d);", [sender scanCode]];
        [self.webView evaluateJavaScript:jsString completionHandler:nil];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    [self updateAccessoryViewHeight];
    self.keyboardVisible = YES;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.keyboardVisible = NO;
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    [self updateAccessoryViewHeight];
}

- (NSString* _Nullable)jsModifierForScanCode: (int) scanCode {
    if (scanCode == 29) {
        return @"ctrlKey";
    } else if (scanCode == 56) {
        return @"altKey";
    } else if (scanCode == 57435) {
        return @"metaKey";
    } else if (scanCode == 42) {
        return @"shiftKey";
    } else {
        return nil;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateAccessoryViewHeight];
    NSLog(@"Trait collection did change");
}

- (void)updateAccessoryViewHeight {
    CGRect currentFrame = self.inputAccessoryView.frame;
    CGFloat height;
    if (self.largeScreen) {
        // we want large keys
        height = kLargeAccessoryViewHeight;
    } else {
        height = kSmallAccessoryViewHeight;
    }
    if (self.inputAccessoryView.safeAreaInsets.bottom > 0) { // only key strip
        height += kSafeAreaHeight;
    }
    if (height != currentFrame.size.height) {
        currentFrame.size.height = height;
        self.inputAccessoryView.frame = currentFrame;
        [self reloadInputViews];
    }
}

@end
