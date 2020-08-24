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

#import "UIViewController+Extensions.h"
#import "VMDisplayMetalViewController+Keyboard.h"
#import "UTMLogging.h"
#import "UTMVirtualMachine.h"
#import "VMKeyboardView.h"
#import "VMKeyboardButton.h"

@implementation VMDisplayMetalViewController (Keyboard)

#pragma mark - Software Keyboard

- (BOOL)inputViewIsFirstResponder {
    return self.keyboardView.isFirstResponder;
}

- (void)updateKeyboardAccessoryFrame {
    if (self.inputAccessoryView.safeAreaInsets.bottom > 0) {
        self.keyboardView.softKeyboardVisible = YES;
    } else {
        self.keyboardView.softKeyboardVisible = NO;
    }
}

- (void)keyboardView:(nonnull VMKeyboardView *)keyboardView didPressKeyDown:(int)scancode {
    [self sendExtendedKey:kCSInputKeyPress code:scancode];
}

- (void)keyboardView:(nonnull VMKeyboardView *)keyboardView didPressKeyUp:(int)scancode {
    [self sendExtendedKey:kCSInputKeyRelease code:scancode];
    [self resetModifierToggles];
}

- (IBAction)keyboardDonePressed:(UIButton *)sender {
    [self.keyboardView resignFirstResponder];
}

- (IBAction)keyboardPastePressed:(UIButton *)sender {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSString *string = pasteboard.string;
    if (string) {
        UTMLog(@"Pasting: %@", string);
        [self.keyboardView insertText:string];
    } else {
        UTMLog(@"No string to paste.");
    }
}

- (void)resetModifierToggles {
    for (VMKeyboardButton *button in self.customKeyModifierButtons) {
        if (button.toggled) {
            [self sendExtendedKey:kCSInputKeyRelease code:button.scanCode];
            dispatch_async(dispatch_get_main_queue(), ^{
                button.toggled = NO;
            });
        }
    }
}

- (IBAction)customKeyTouchDown:(VMKeyboardButton *)sender {
    if (!sender.toggleable) {
        [self sendExtendedKey:kCSInputKeyPress code:sender.scanCode];
    }
}

- (IBAction)customKeyTouchUp:(VMKeyboardButton *)sender {
    if (sender.toggleable) {
        sender.toggled = !sender.toggled;
    } else {
        [self resetModifierToggles];
    }
    if (sender.toggleable && sender.toggled) {
        [self sendExtendedKey:kCSInputKeyPress code:sender.scanCode];
    } else {
        [self onDelay:0.05f action:^{
            [self sendExtendedKey:kCSInputKeyRelease code:sender.scanCode];
        }];
    }
}

#pragma mark - Hardware Keyboard (< iOS 13.4)

static NSString *kAllKeys = @"`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./ \t\r\n\b";

- (void)handleKeyCommand:(UIKeyCommand *)command {
    NSString *key = command.input;
    int scancode = 0;
    if (command.modifierFlags & UIKeyModifierAlphaShift) {
        [self sendExtendedKey:kCSInputKeyPress code:0x3A];
    }
    if (command.modifierFlags & UIKeyModifierShift) {
        [self sendExtendedKey:kCSInputKeyPress code:0x2A];
    }
    if (command.modifierFlags & UIKeyModifierControl) {
        [self sendExtendedKey:kCSInputKeyPress code:0x1D];
    }
    if (command.modifierFlags & UIKeyModifierAlternate) {
        [self sendExtendedKey:kCSInputKeyPress code:0x38];
    }
    if (command.modifierFlags & UIKeyModifierCommand) {
        [self sendExtendedKey:kCSInputKeyPress code:0xE05B];
    }
    if ([key isEqualToString:UIKeyInputEscape])
        scancode = 0x01;
    else if ([key isEqualToString:UIKeyInputUpArrow])
        scancode = 0xE048;
    else if ([key isEqualToString:UIKeyInputDownArrow])
        scancode = 0xE050;
    else if ([key isEqualToString:UIKeyInputLeftArrow])
        scancode = 0xE04B;
    else if ([key isEqualToString:UIKeyInputRightArrow])
        scancode = 0xE04D;
    if (scancode != 0) {
        [self sendExtendedKey:kCSInputKeyPress code:scancode];
    } else {
        [self.keyboardView insertText:key];
    }
    [self onDelay:0.05f action:^{
        if (scancode != 0) {
            [self sendExtendedKey:kCSInputKeyRelease code:scancode];
        }
        if (command.modifierFlags & UIKeyModifierAlphaShift) {
            [self sendExtendedKey:kCSInputKeyRelease code:0x3A];
        }
        if (command.modifierFlags & UIKeyModifierShift) {
            [self sendExtendedKey:kCSInputKeyRelease code:0x2A];
        }
        if (command.modifierFlags & UIKeyModifierControl) {
            [self sendExtendedKey:kCSInputKeyRelease code:0x1D];
        }
        if (command.modifierFlags & UIKeyModifierAlternate) {
            [self sendExtendedKey:kCSInputKeyRelease code:0x38];
        }
        if (command.modifierFlags & UIKeyModifierCommand) {
            [self sendExtendedKey:kCSInputKeyRelease code:0xE05B];
        }
        [self resetModifierToggles];
    }];
}

- (NSArray<UIKeyCommand *> *)keyCommands {
    // In iOS 13.4, we use the event handlers pressesBegan and pressesEnded
    if (@available(iOS 13.4, *)) {
        return nil;
    }
    
    if (_keyCommands != nil)
        return _keyCommands;
    NSArray<NSString *> *specialKeys = @[UIKeyInputEscape, UIKeyInputUpArrow, UIKeyInputDownArrow,
                                         UIKeyInputLeftArrow, UIKeyInputRightArrow];
    _keyCommands = [NSMutableArray new];
    for (int i = 0; i < 32; i++) {
        NSInteger modifier = 0;
        if (i & 1) {
            modifier |= UIKeyModifierAlphaShift;
        }
        if (i & 2) {
            modifier |= UIKeyModifierShift;
        }
        if (i & 4) {
            modifier |= UIKeyModifierControl;
        }
        if (i & 8) {
            modifier |= UIKeyModifierAlternate;
        }
        if (i & 16) {
            modifier |= UIKeyModifierCommand;
        }
        // add all normal keys
        [kAllKeys enumerateSubstringsInRange:NSMakeRange(0, kAllKeys.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
            [self addKey:substring toCommands:self->_keyCommands withModifiers:modifier];
        }];
        // add special keys
        for (NSString *key in specialKeys) {
            [self addKey:key toCommands:_keyCommands withModifiers:modifier];
        }
        // add just modifier keys
        if (modifier) {
            [self addKey:@"" toCommands:_keyCommands withModifiers:modifier];
        }
    }
    return _keyCommands;
}

- (void)addKey:(NSString *)key toCommands:(NSMutableArray<UIKeyCommand *> *)commands withModifiers:(UIKeyModifierFlags)modifiers {
    UIKeyCommand *command = [UIKeyCommand keyCommandWithInput:key
                                                modifierFlags:modifiers
                                                       action:@selector(handleKeyCommand:)];
    [commands addObject:command];
    
}

#pragma mark - iOS 13.4+ key event handling

// from: https://download.microsoft.com/download/1/6/1/161ba512-40e2-4cc9-843a-923143f3456c/translate.pdf
static const uint8_t hid_to_ps2_table[] = {
    0x00, 0xff, 0xfc, 0x00, 0x1e, 0x30, 0x2e, 0x20,
    0x12, 0x21, 0x22, 0x23, 0x17, 0x24, 0x25, 0x26,
    0x32, 0x31, 0x18, 0x19, 0x10, 0x13, 0x1f, 0x14,
    0x16, 0x2f, 0x11, 0x2d, 0x15, 0x2c, 0x02, 0x03,
    0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b,
    0x1c, 0x01, 0x0e, 0x0f, 0x39, 0x0c, 0x0d, 0x1a,
    0x1b, 0x2b, 0x2b, 0x27, 0x28, 0x29, 0x33, 0x34,
    0x35, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x40,
    0x41, 0x42, 0x43, 0x44, 0x57, 0x58, 0x00, 0x46,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x45, 0x00, 0x37, 0x4a, 0x4e,
    0x00, 0x4f, 0x50, 0x51, 0x4b, 0x4c, 0x4d, 0x47,
    0x48, 0x49, 0x52, 0x53, 0x56, 0x00, 0x00, 0x59,
    0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b,
    0x6c, 0x6d, 0x6e, 0x76, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0x00, 0x73,
    0x70, 0x7d, 0x79, 0x7b, 0x5c, 0x00, 0x00, 0x00,
    0xf2, 0xf1, 0x78, 0x77, 0x76, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x1d, 0x2a, 0x38, 0x00, 0x00, 0x36, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static const uint8_t hid_to_ps2_extended_table[] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x37, 0x00,
    0x00, 0x52, 0x47, 0x49, 0x53, 0x4f, 0x51, 0x4d,
    0x4b, 0x50, 0x48, 0x00, 0x35, 0x00, 0x00, 0x00,
    0x1c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x5d, 0x5e, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x5b, 0x1d, 0x00, 0x38, 0x5c,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static int API_AVAILABLE(ios(13.4)) hidToPs2(UIKeyboardHIDUsage hidCode) {
    int ps2Code = 0;
    if (hidCode < 0x100) {
        ps2Code = hid_to_ps2_table[hidCode & 0xFF];
        if (!ps2Code) {
            ps2Code = hid_to_ps2_extended_table[hidCode & 0xFF];
            if (ps2Code) {
                ps2Code |= 0xE000;
            }
        }
    }
    return ps2Code;
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    BOOL didHandleEvent = NO;
    for (UIPress *press in presses) {
        if (@available(iOS 13.4, *)) {
            int code = hidToPs2(press.key.keyCode);
            if (code) {
                [self sendExtendedKey:kCSInputKeyPress code:code];
                didHandleEvent = YES;
            }
        }
    }
    if (!didHandleEvent) {
        [super pressesBegan:presses withEvent:event];
    }
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    BOOL didHandleEvent = NO;
    for (UIPress *press in presses) {
        if (@available(iOS 13.4, *)) {
            int code = hidToPs2(press.key.keyCode);
            if (code) {
                [self sendExtendedKey:kCSInputKeyRelease code:code];
                didHandleEvent = YES;
            }
            [self resetModifierToggles];
        }
    }
    if (!didHandleEvent) {
        [super pressesEnded:presses withEvent:event];
    }
}

@end
