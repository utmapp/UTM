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

// Parts taken from ish: https://github.com/tbodt/ish/blob/master/app/BarButton.m
//  Created by Theodore Dubois on 9/22/18.
//  Licensed under GNU General Public License 3.0

#import "VMKeyboardButton.h"

extern UIAccessibilityTraits UIAccessibilityTraitToggle;

@implementation VMKeyboardButton

- (void)setup {
    self.layer.cornerRadius = 5;
    self.layer.shadowOffset = CGSizeMake(0, 1);
    self.layer.shadowOpacity = 0.4;
    self.layer.shadowRadius = 0;
    self.backgroundColor = self.defaultColor;
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            self.keyAppearance = UIKeyboardAppearanceDark;
        } else {
            self.keyAppearance = UIKeyboardAppearanceLight;
        }
    } else {
        self.keyAppearance = UIKeyboardAppearanceLight;
    }
    self.accessibilityTraits |= UIAccessibilityTraitKeyboardKey;
    if (self.toggleable) {
        self.accessibilityTraits |= 0x20000000000000;
    }
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setup];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            self.keyAppearance = UIKeyboardAppearanceDark;
        } else {
            self.keyAppearance = UIKeyboardAppearanceLight;
        }
    }
}

- (UIColor *)primaryColor {
    if (self.keyAppearance == UIKeyboardAppearanceLight)
        return UIColor.whiteColor;
    else
        return [UIColor colorWithRed:1 green:1 blue:1 alpha:77/255.];
}
- (UIColor *)secondaryColor {
    if (self.keyAppearance == UIKeyboardAppearanceLight)
        return [UIColor colorWithRed:172/255. green:180/255. blue:190/255. alpha:1];
    else
        return [UIColor colorWithRed:147/255. green:147/255. blue:147/255. alpha:66/255.];
}
- (UIColor *)defaultColor {
    if (self.secondary)
        return self.secondaryColor;
    return self.primaryColor;
}
- (UIColor *)highlightedColor {
    if (!self.secondary)
        return self.secondaryColor;
    return self.primaryColor;
}

- (void)chooseBackground {
    if (self.selected || self.highlighted || (self.toggleable && self.toggled)) {
        self.backgroundColor = self.highlightedColor;
    } else {
        [UIView animateWithDuration:0 delay:0.1 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            self.backgroundColor = self.defaultColor;
        } completion:nil];
    }
    if (self.keyAppearance == UIKeyboardAppearanceLight) {
        self.tintColor = UIColor.blackColor;
    } else {
        self.tintColor = UIColor.whiteColor;
    }
    [self setTitleColor:self.tintColor forState:UIControlStateNormal];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self chooseBackground];
}

- (void)setToggled:(BOOL)toggled {
    _toggled = toggled;
    [self chooseBackground];
}

- (void)setKeyAppearance:(UIKeyboardAppearance)keyAppearance {
    _keyAppearance = keyAppearance;
    [self chooseBackground];
}

- (NSString *)accessibilityValue {
    if (self.toggleable) {
        return self.selected ? @"1" : @"0";
    }
    return nil;
}

- (void)prepareForInterfaceBuilder {
    [super prepareForInterfaceBuilder];
    [self setup];
}

@end
