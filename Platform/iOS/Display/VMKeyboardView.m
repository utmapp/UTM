//
// Copyright © 2019 osy. All rights reserved.
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

#import "VMKeyboardView.h"
#import "VMKeyboardMap.h"

@interface VMKeyboardView ()

@property (nullable, nonatomic) VMKeyboardMap *keyboardMap;

@end

@implementation VMKeyboardView

- (UIKeyboardType)keyboardType {
    return UIKeyboardTypeASCIICapable;
}

- (UITextAutocapitalizationType)autocapitalizationType {
    return UITextAutocapitalizationTypeNone;
}

- (UITextAutocorrectionType)autocorrectionType {
    return UITextAutocorrectionTypeNo;
}

- (UITextSpellCheckingType)spellCheckingType {
    return UITextSpellCheckingTypeNo;
}

- (UITextSmartQuotesType)smartQuotesType {
    return UITextSmartQuotesTypeNo;
}

- (UITextSmartDashesType)smartDashesType {
    return UITextSmartDashesTypeNo;
}

- (UITextSmartInsertDeleteType)smartInsertDeleteType {
    return UITextSmartInsertDeleteTypeNo;
}

- (BOOL)hasText {
    return YES;
}

- (void)deleteBackward {
    [self.delegate keyboardView:self didPressKeyDown:0x0E];
    [NSThread sleepForTimeInterval:0.05f];
    [self.delegate keyboardView:self didPressKeyUp:0x0E];
}

- (void)insertText:(nonnull NSString *)text {
    if (!self.keyboardMap) {
        self.keyboardMap = [[VMKeyboardMap alloc] init];
    }
    [self.keyboardMap mapText:text toKeyUp:^(NSInteger scanCode) {
        [self.delegate keyboardView:self didPressKeyUp:(int)scanCode];
    } keyDown:^(NSInteger scanCode) {
        [self.delegate keyboardView:self didPressKeyDown:(int)scanCode];
    } completion:^(){}];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

@end
