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

#import "VMDisplayMetalViewController+Keyboard.h"
#import "UTMVirtualMachine.h"
#import "VMKeyboardView.h"
#import "VMKeyboardButton.h"

@implementation VMDisplayMetalViewController (Keyboard)

#pragma mark - Software Keyboard

- (void)keyboardWillShow:(NSNotification *)notification {
    [self updateKeyboardAccessoryFrame];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.keyboardVisible = NO;
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    [self updateKeyboardAccessoryFrame];
}

- (void)updateKeyboardAccessoryFrame {
    if (self.inputAccessoryView.safeAreaInsets.bottom > 0) {
        self.keyboardView.softKeyboardVisible = YES;
    } else {
        self.keyboardView.softKeyboardVisible = NO;
    }
}

- (void)keyboardView:(nonnull VMKeyboardView *)keyboardView didPressKeyDown:(int)scancode {
    [self sendExtendedKey:SEND_KEY_PRESS code:scancode];
}

- (void)keyboardView:(nonnull VMKeyboardView *)keyboardView didPressKeyUp:(int)scancode {
    [self sendExtendedKey:SEND_KEY_RELEASE code:scancode];
    [self resetModifierToggles];
}

- (IBAction)keyboardDonePressed:(UIButton *)sender {
    [self.keyboardView resignFirstResponder];
}

- (IBAction)keyboardPastePressed:(UIButton *)sender {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSString *string = pasteboard.string;
    if (string) {
        NSLog(@"Pasting: %@", string);
        [self.keyboardView insertText:string];
    } else {
        NSLog(@"No string to paste.");
    }
}

- (void)resetModifierToggles {
    for (VMKeyboardButton *button in self.customKeyModifierButtons) {
        if (button.toggled) {
            [self sendExtendedKey:SEND_KEY_RELEASE code:button.scanCode];
            dispatch_async(dispatch_get_main_queue(), ^{
                button.toggled = NO;
            });
        }
    }
}

- (IBAction)customKeyTouchDown:(VMKeyboardButton *)sender {
    if (!sender.toggleable) {
        [self sendExtendedKey:SEND_KEY_PRESS code:sender.scanCode];
    }
}

- (IBAction)customKeyTouchUp:(VMKeyboardButton *)sender {
    if (sender.toggleable) {
        sender.toggled = !sender.toggled;
    } else {
        [self resetModifierToggles];
    }
    if (sender.toggleable && sender.toggled) {
        [self sendExtendedKey:SEND_KEY_PRESS code:sender.scanCode];
    } else {
        [self onDelay:0.05f action:^{
            [self sendExtendedKey:SEND_KEY_RELEASE code:sender.scanCode];
        }];
    }
}

#pragma mark - Hardware Keyboard

static NSString *kAllKeys = @"`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./ \t\r\n\b";

- (void)handleKeyCommand:(UIKeyCommand *)command {
    NSString *key = command.input;
    int scancode = 0;
    if (command.modifierFlags & UIKeyModifierAlphaShift) {
        [self sendExtendedKey:SEND_KEY_PRESS code:0x3A];
    }
    if (command.modifierFlags & UIKeyModifierShift) {
        [self sendExtendedKey:SEND_KEY_PRESS code:0x2A];
    }
    if (command.modifierFlags & UIKeyModifierControl) {
        [self sendExtendedKey:SEND_KEY_PRESS code:0x1D];
    }
    if (command.modifierFlags & UIKeyModifierAlternate) {
        [self sendExtendedKey:SEND_KEY_PRESS code:0x38];
    }
    if (command.modifierFlags & UIKeyModifierCommand) {
        [self sendExtendedKey:SEND_KEY_PRESS code:0xE05B];
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
        [self sendExtendedKey:SEND_KEY_PRESS code:scancode];
    } else {
        [self.keyboardView insertText:key];
    }
    [self onDelay:0.05f action:^{
        if (scancode != 0) {
            [self sendExtendedKey:SEND_KEY_RELEASE code:scancode];
        }
        if (command.modifierFlags & UIKeyModifierAlphaShift) {
            [self sendExtendedKey:SEND_KEY_RELEASE code:0x3A];
        }
        if (command.modifierFlags & UIKeyModifierShift) {
            [self sendExtendedKey:SEND_KEY_RELEASE code:0x2A];
        }
        if (command.modifierFlags & UIKeyModifierControl) {
            [self sendExtendedKey:SEND_KEY_RELEASE code:0x1D];
        }
        if (command.modifierFlags & UIKeyModifierAlternate) {
            [self sendExtendedKey:SEND_KEY_RELEASE code:0x38];
        }
        if (command.modifierFlags & UIKeyModifierCommand) {
            [self sendExtendedKey:SEND_KEY_RELEASE code:0xE05B];
        }
    }];
}

- (NSArray<UIKeyCommand *> *)keyCommands {
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

@end
