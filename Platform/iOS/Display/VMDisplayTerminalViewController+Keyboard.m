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

#import "UTMVirtualMachine+Terminal.h"
#import "UTMLogging.h"
#import "VMDisplayTerminalViewController+Keyboard.h"
#import "VMKeyboardButton.h"
#import "VMKeyboardView.h"
#import "WKWebView+Workarounds.h"

@implementation VMDisplayTerminalViewController (Keyboard)

#pragma mark - Translate keycode

static const uint8_t ps2_to_js_table[] = {
    0x00, 0x1b, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36,
    0x37, 0x38, 0x39, 0x30, 0xbd, 0xbb, 0x08, 0x09,
    0x51, 0x57, 0x45, 0x52, 0x54, 0x59, 0x55, 0x49,
    0x4f, 0x50, 0xdb, 0xdd, 0x0d, 0x11, 0x41, 0x53,
    0x44, 0x46, 0x47, 0x48, 0x4a, 0x4b, 0x4c, 0xba,
    0xde, 0xc0, 0x10, 0xdc, 0x5a, 0x58, 0x43, 0x56,
    0x42, 0x4e, 0x4d, 0xbc, 0xbe, 0xbf, 0x10, 0x2a,
    0x12, 0x20, 0x14, 0x70, 0x71, 0x72, 0x73, 0x74,
    0x75, 0x76, 0x77, 0x78, 0x79, 0x90, 0x91, 0x67,
    0x68, 0x69, 0x6d, 0x64, 0x65, 0x66, 0x6b, 0x61,
    0x62, 0x63, 0x60, 0x6e, 0x00, 0x00, 0x00, 0x7a,
    0x7b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static const uint8_t ps2_to_js_extended_table[] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x0d, 0x11, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x24,
    0x26, 0x21, 0x00, 0x25, 0x00, 0x27, 0x00, 0x23,
    0x28, 0x22, 0x2d, 0x2e, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x5b, 0x5c, 0x5d, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static int ps2CodeToJs(int ps2Code) {
    int jsCode = 0;
    if (ps2Code < 0x80) {
        jsCode = ps2_to_js_table[ps2Code & 0x7F];
    } else if ((ps2Code & 0xFF00) == 0xE000 && (ps2Code & 0xFF) < 0x80) {
        jsCode = ps2_to_js_extended_table[ps2Code & 0x7F];
    }
    return jsCode;
}

#pragma mark - Key handler

- (IBAction)keyboardDonePressed:(UIButton *)sender {
    self.keyboardVisible = NO;
}

- (IBAction)keyboardPastePressed:(UIButton *)sender {
    UIPasteboard* pasteboard = [UIPasteboard generalPasteboard];
    NSString* string = pasteboard.string;
    if (string != nil) {
        [self.vm sendInput: string];
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
        NSString* jsString = [NSString stringWithFormat: @"programmaticKeyDown(%d);", ps2CodeToJs(sender.scanCode)];
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
        NSString* jsString = [NSString stringWithFormat: @"programmaticKeyUp(%d);", ps2CodeToJs(sender.scanCode)];
        [self.webView evaluateJavaScript:jsString completionHandler:nil];
    }
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
    [self updateKeyboardAccessoryFrame];
    UTMLog(@"Trait collection did change");
}

- (BOOL)inputViewIsFirstResponder {
    return [self.webView findContentView].isFirstResponder;
}

- (void)updateKeyboardAccessoryFrame {
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
        [[self.webView findContentView] reloadInputViews];
    }
}

#pragma mark - Trigger keyboard with hardware key press

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (@available(iOS 13.4, *)) {
        if (presses.count > 0 && !self.keyboardVisible) {
            self.keyboardVisible = YES;
        }
    }
    [super pressesBegan:presses withEvent:event];
}

@end
