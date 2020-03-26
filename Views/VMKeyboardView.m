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

// Parts taken from launcher-mobile
/*
 * launcher-mobile: a multiplatform flexVDI/SPICE client
 *
 * Copyright (C) 2016 flexVDI (Flexible Software Solutions S.L.)
 *
 * This file is part of launcher-mobile.
 *
 * launcher-mobile is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * launcher-mobile is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with launcher-mobile.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "VMKeyboardView.h"
#import "ctype.h"

typedef struct {
    char tc;
    int prekey;
    int special_prekey;
    int special_key;
    int key;
} key_mapping_t;

typedef struct {
    char tc;
    char ext1;
    char ext2;
    int prekey;
    int special_prekey;
    int special_key;
    int key;
} ext_key_mapping_t;

const ext_key_mapping_t pc104_es_ext[] = {
    {194, 161, 0, 0x0, 0x0, 0x0, 0x0d}, // ¡
    {194, 191, 0, 0x0, 0x0, 0x36, 0x0d}, // ¿
    {194, 186, 0, 0x0, 0x0, 0x0, 0x29}, // º
    {194, 170, 0, 0x0, 0x0, 0x36, 0x29}, // ª
    {194, 169, 0, 0x0, 0x0, 0x1d, 0x2e}, // Ctrl + C
    {194, 174, 0, 0x0, 0x0, 0x1d, 0x13},
    
    {195, 177, 0, 0x0, 0x0, 0x0, 0x27}, // ñ
    {195, 145, 0, 0x0, 0x0, 0x36, 0x27}, // ñ
    {195, 167, 0, 0x0, 0x0, 0x0, 0x2b}, // ç
    {195, 135, 0, 0x0, 0x0, 0x36, 0x2b}, // Ç
    {195, 161, 0, 0x28, 0x0, 0x0, 0x1e}, // á
    {195, 169, 0, 0x28, 0x0, 0x0, 0x12}, // é
    {195, 173, 0, 0x28, 0x0, 0x0, 0x17}, // í
    {195, 179, 0, 0x28, 0x0, 0x0, 0x18}, // ó
    {195, 186, 0, 0x28, 0x0, 0x0, 0x16}, // ú
    {195, 188, 0, 0x28, 0x36, 0x0, 0x16}, // ü
    {195, 129, 0, 0x28, 0x0, 0x36, 0x1e}, // Á
    {195, 137, 0, 0x28, 0x0, 0x36, 0x12}, // É
    {195, 141, 0, 0x28, 0x0, 0x36, 0x17}, // Í
    {195, 147, 0, 0x28, 0x0, 0x36, 0x18}, // Ó
    {195, 154, 0, 0x28, 0x0, 0x36, 0x16}, // Ú
    {195, 156, 0, 0x28, 0x36, 0x36, 0x16}, // Ü
    {195, 159, 0, 0x0, 0x0, 0x1d, 0x30}, // Ctrl + B
    
    {197, 147, 0, 0x0, 0x0, 0x38, 0x0f}, // Alt + Tab
    
    {198, 146, 0, 0x0, 0x0, 0x1d, 0x21}, // Ctrl + F
    
    {206, 169, 0, 0x0, 0x0, 0x1d, 0x2c}, // Ctrl + Z
    
    {226, 130, 172, 0x0, 0x0, 0x138, 0x12}, // Euro
    {226, 137, 164, 0x0, 0x0, 0x138, 0x29}, // Backslash
    {226, 136, 145, 0x0, 0x0, 0x1d, 0x2d}, // Ctrl + X
    {226, 136, 154, 0x0, 0x0, 0x1d, 0x2f}, // Ctrl + V
    {226, 136, 130, 0x0, 0x0, 0x1d, 0x20} // Ctrl + D
};

const key_mapping_t pc104_es[] = {
    {9, 0x0, 0x0, 0x0, 0xf}, // Tab
    {'a', 0x0, 0x0, 0x0, 0x1e},
    {'b', 0x0, 0x0, 0x0, 0x30},
    {'c', 0x0, 0x0, 0x0, 0x2e},
    {'d', 0x0, 0x0, 0x0, 0x20},
    {'e', 0x0, 0x0, 0x0, 0x12},
    {'f', 0x0, 0x0, 0x0, 0x21},
    {'g', 0x0, 0x0, 0x0, 0x22},
    {'h', 0x0, 0x0, 0x0, 0x23},
    {'i', 0x0, 0x0, 0x0, 0x17},
    {'j', 0x0, 0x0, 0x0, 0x24},
    {'k', 0x0, 0x0, 0x0, 0x25},
    {'l', 0x0, 0x0, 0x0, 0x26},
    {'m', 0x0, 0x0, 0x0, 0x32},
    {'n', 0x0, 0x0, 0x0, 0x31},
    {'o', 0x0, 0x0, 0x0, 0x18},
    {'p', 0x0, 0x0, 0x0, 0x19},
    {'q', 0x0, 0x0, 0x0, 0x10},
    {'r', 0x0, 0x0, 0x0, 0x13},
    {'s', 0x0, 0x0, 0x0, 0x1f},
    {'t', 0x0, 0x0, 0x0, 0x14},
    {'u', 0x0, 0x0, 0x0, 0x16},
    {'v', 0x0, 0x0, 0x0, 0x2f},
    {'w', 0x0, 0x0, 0x0, 0x11},
    {'x', 0x0, 0x0, 0x0, 0x2d},
    {'y', 0x0, 0x0, 0x0, 0x15},
    {'z', 0x0, 0x0, 0x0, 0x2c},
    {'1', 0x0, 0x0, 0x0, 0x02},
    {'2', 0x0, 0x0, 0x0, 0x03},
    {'3', 0x0, 0x0, 0x0, 0x04},
    {'4', 0x0, 0x0, 0x0, 0x05},
    {'5', 0x0, 0x0, 0x0, 0x06},
    {'6', 0x0, 0x0, 0x0, 0x07},
    {'7', 0x0, 0x0, 0x0, 0x08},
    {'8', 0x0, 0x0, 0x0, 0x09},
    {'9', 0x0, 0x0, 0x0, 0x0a},
    {'0', 0x0, 0x0, 0x0, 0x0b},
    {' ', 0x0, 0x0, 0x0, 0x39},
    {'!', 0x0, 0x0, 0x36, 0x02},
    {'@', 0x0, 0x0, 0x138, 0x03},
    {'"', 0x0, 0x0, 0x36, 0x03},
    {'\'', 0x0, 0x0, 0x0, 0x0c},
    {'#', 0x0, 0x0, 0x138, 0x04},
    {'~', 0x0, 0x0, 0x138, 0x05},
    {'$', 0x0, 0x0, 0x36, 0x05},
    {'%', 0x0, 0x0, 0x36, 0x06},
    {'&', 0x0, 0x0, 0x36, 0x07},
    {'/', 0x0, 0x0, 0x36, 0x08},
    {'(', 0x0, 0x0, 0x36, 0x09},
    {')', 0x0, 0x0, 0x36, 0x0a},
    {'=', 0x0, 0x0, 0x36, 0x0b},
    {'?', 0x0, 0x0, 0x36, 0x0c},
    {'-', 0x0, 0x0, 0x0, 0x35},
    {'_', 0x0, 0x0, 0x36, 0x35},
    {';', 0x0, 0x0, 0x36, 0x33},
    {',', 0x0, 0x0, 0x0, 0x33},
    {'.', 0x0, 0x0, 0x0, 0x34},
    {':', 0x0, 0x0, 0x36, 0x34},
    {'{', 0x0, 0x0, 0x138, 0x28},
    {'}', 0x0, 0x0, 0x138, 0x2b},
    {'[', 0x0, 0x0, 0x138, 0x1a},
    {']', 0x0, 0x0, 0x138, 0x1b},
    {'*', 0x0, 0x0, 0x36, 0x1b},
    {'+', 0x0, 0x0, 0x0, 0x1b},
    {'\\', 0x0, 0x0, 0x138, 0x29},
    {'|', 0x0, 0x0, 0x138, 0x02},
    {'^', 0x0, 0x0, 0x36, 0x1a},
    {'`', 0x0, 0x0, 0x0, 0x1a},
    {'<', 0x0, 0x0, 0x0, 0x56},
    {'>', 0x0, 0x0, 0x36, 0x56},
    {'\r', 0x0, 0x0, 0x0, 0x1c},
    {'\n', 0x0, 0x0, 0x0, 0x1c},
    {'\'', 0x0, 0x0, 0x0, 0x28},
    {'"', 0x0, 0x0, 0x36, 0x28},
    {'\t', 0x0, 0x0, 0x0, 0x0F},
    {'\b', 0x0, 0x0, 0x0, 0x0E},
};

const ext_key_mapping_t pc104_us_ext[] = {
    {195, 167, 0, 0x0, 0x0, 0x1d, 0x2e}, // Ctrl + C
    {197, 147, 0, 0x0, 0x0, 0x38, 0x0f}, // Alt + Tab
    {198, 146, 0, 0x0, 0x0, 0x1d, 0x21}, // Ctrl + F
    {206, 169, 0, 0x0, 0x0, 0x1d, 0x2c}, // Ctrl + Z
    {226, 137, 136, 0x0, 0x0, 0x1d, 0x2d}, // Ctrl + X
    {226, 136, 154, 0x0, 0x0, 0x1d, 0x2f}, // Ctrl + V
    {226, 136, 171, 0x0, 0x0, 0x1d, 0x30}, // Ctrl + B
    {226, 136, 130, 0x0, 0x0, 0x1d, 0x20} // Ctrl + D
};

const key_mapping_t pc104_us[] = {
    {9, 0x0, 0x0, 0x0, 0xf}, // Tab
    {'a', 0x0, 0x0, 0x0, 0x1e},
    {'b', 0x0, 0x0, 0x0, 0x30},
    {'c', 0x0, 0x0, 0x0, 0x2e},
    {'d', 0x0, 0x0, 0x0, 0x20},
    {'e', 0x0, 0x0, 0x0, 0x12},
    {'f', 0x0, 0x0, 0x0, 0x21},
    {'g', 0x0, 0x0, 0x0, 0x22},
    {'h', 0x0, 0x0, 0x0, 0x23},
    {'i', 0x0, 0x0, 0x0, 0x17},
    {'j', 0x0, 0x0, 0x0, 0x24},
    {'k', 0x0, 0x0, 0x0, 0x25},
    {'l', 0x0, 0x0, 0x0, 0x26},
    {'m', 0x0, 0x0, 0x0, 0x32},
    {'n', 0x0, 0x0, 0x0, 0x31},
    {'o', 0x0, 0x0, 0x0, 0x18},
    {'p', 0x0, 0x0, 0x0, 0x19},
    {'q', 0x0, 0x0, 0x0, 0x10},
    {'r', 0x0, 0x0, 0x0, 0x13},
    {'s', 0x0, 0x0, 0x0, 0x1f},
    {'t', 0x0, 0x0, 0x0, 0x14},
    {'u', 0x0, 0x0, 0x0, 0x16},
    {'v', 0x0, 0x0, 0x0, 0x2f},
    {'w', 0x0, 0x0, 0x0, 0x11},
    {'x', 0x0, 0x0, 0x0, 0x2d},
    {'y', 0x0, 0x0, 0x0, 0x15},
    {'z', 0x0, 0x0, 0x0, 0x2c},
    {'1', 0x0, 0x0, 0x0, 0x02},
    {'2', 0x0, 0x0, 0x0, 0x03},
    {'3', 0x0, 0x0, 0x0, 0x04},
    {'4', 0x0, 0x0, 0x0, 0x05},
    {'5', 0x0, 0x0, 0x0, 0x06},
    {'6', 0x0, 0x0, 0x0, 0x07},
    {'7', 0x0, 0x0, 0x0, 0x08},
    {'8', 0x0, 0x0, 0x0, 0x09},
    {'9', 0x0, 0x0, 0x0, 0x0a},
    {'0', 0x0, 0x0, 0x0, 0x0b},
    {' ', 0x0, 0x0, 0x0, 0x39},
    {'!', 0x0, 0x0, 0x36, 0x02},
    {'@', 0x0, 0x0, 0x36, 0x03},
    {'"', 0x0, 0x0, 0x36, 0x28},
    {'\'', 0x0, 0x0, 0x0, 0x28},
    {'#', 0x0, 0x0, 0x36, 0x04},
    {'~', 0x0, 0x0, 0x36, 0x29},
    {'$', 0x0, 0x0, 0x36, 0x05},
    {'%', 0x0, 0x0, 0x36, 0x06},
    {'&', 0x0, 0x0, 0x36, 0x08},
    {'/', 0x0, 0x0, 0x0, 0x35},
    {'(', 0x0, 0x0, 0x36, 0x0a},
    {')', 0x0, 0x0, 0x36, 0x0b},
    {'=', 0x0, 0x0, 0x0, 0x0d},
    {'+', 0x0, 0x0, 0x36, 0x0d},
    {'?', 0x0, 0x0, 0x36, 0x35},
    {'-', 0x0, 0x0, 0x0, 0x0c},
    {'_', 0x0, 0x0, 0x36, 0x0c},
    {';', 0x0, 0x0, 0x0, 0x27},
    {',', 0x0, 0x0, 0x0, 0x33},
    {'.', 0x0, 0x0, 0x0, 0x34},
    {':', 0x0, 0x0, 0x36, 0x27},
    {'{', 0x0, 0x0, 0x36, 0x1a},
    {'}', 0x0, 0x0, 0x36, 0x1b},
    {'[', 0x0, 0x0, 0x0, 0x1a},
    {']', 0x0, 0x0, 0x0, 0x1b},
    {'*', 0x0, 0x0, 0x36, 0x09},
    {'+', 0x0, 0x0, 0x0, 0x1b},
    {'\\', 0x0, 0x0, 0x0, 0x2b},
    {'|', 0x0, 0x0, 0x36, 0x2b},
    {'^', 0x0, 0x0, 0x36, 0x07},
    {'`', 0x0, 0x0, 0x0, 0x29},
    {'<', 0x0, 0x0, 0x36, 0x33},
    {'>', 0x0, 0x0, 0x36, 0x34},
    {'\r', 0x0, 0x0, 0x0, 0x1c},
    {'\n', 0x0, 0x0, 0x0, 0x1c},
    {'\'', 0x0, 0x0, 0x0, 0x28},
    {'"', 0x0, 0x0, 0x36, 0x28},
    {'\t', 0x0, 0x0, 0x0, 0x0F},
    {'\b', 0x0, 0x0, 0x0, 0x0E},
};

const int kLargeAccessoryViewHeight = 68;
const int kSmallAccessoryViewHeight = 45;
const int kSafeAreaHeight = 25;

static int indexForChar(const key_mapping_t *table, size_t table_len, char tc) {
    int i;
    
    for (i = 0; i < table_len; i++) {
        if (tc == table[i].tc) {
            return i;
        }
    }
    
    return -1;
}

static int indexForExtChar(const ext_key_mapping_t *table, size_t table_len, char tc, char ext1, char ext2) {
    int i;
    
    for (i = 0; i < table_len; i++) {
        if (tc == table[i].tc &&
            ext1 == table[i].ext1) {
            if (ext2 != 0 && ext2 == table[i].ext2) {
                return i;
            } else if (ext2 == 0) {
                return i;
            }
        }
    }
    
    return -1;
}

@implementation VMKeyboardView {
    const key_mapping_t *_map;
    size_t _map_len;
    const ext_key_mapping_t *_ext_map;
    size_t _ext_map_len;
}

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

- (void)configureTables {
    NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
    
    if ([language isEqual:@"es-ES"]) {
        _map = pc104_es;
        _map_len = sizeof(pc104_es)/sizeof(pc104_es[0]);
        _ext_map = pc104_es_ext;
        _ext_map_len = sizeof(pc104_es_ext)/sizeof(pc104_es_ext[0]);
    } else {
        _map = pc104_us;
        _map_len = sizeof(pc104_us)/sizeof(pc104_us[0]);
        _ext_map = pc104_us_ext;
        _ext_map_len = sizeof(pc104_us_ext)/sizeof(pc104_us_ext[0]);
    }
}

- (void)setSoftKeyboardVisible:(BOOL)softKeyboardVisible {
    _softKeyboardVisible = softKeyboardVisible;
    [self updateAccessoryViewHeight];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateAccessoryViewHeight];
}

- (void)updateAccessoryViewHeight {
    CGRect currentFrame = self.inputAccessoryView.frame;
    CGFloat height;
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular && self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular) {
        // we want large keys
        height = kLargeAccessoryViewHeight;
    } else {
        height = kSmallAccessoryViewHeight;
    }
    if (self.softKeyboardVisible) {
        height += kSafeAreaHeight;
    }
    if (height != currentFrame.size.height) {
        currentFrame.size.height = height;
        self.inputAccessoryView.frame = currentFrame;
        [self reloadInputViews];
    }
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
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [text enumerateSubstringsInRange:NSMakeRange(0, text.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
            const char *seq = [substring UTF8String];
            [self insertUTF8Sequence:seq];
            // we need to pause a bit or the keypress will be too fast!
            [NSThread sleepForTimeInterval:0.001f];
        }];
    });
}

- (void)insertUTF8Sequence:(const char *)ctext {
    unsigned long ctext_len = strlen(ctext);
    NSLog(@"ctext length=%lu\n", ctext_len);
    unsigned char tc = ctext[0];
    
    int keycode = 0;
    int special = 0;
    int prekey = 0;
    int prekey_special = 0;
    int is_upper = false;
    int index = -1;
    
    if (!_map) {
        [self configureTables];
    }
    
    if (isalpha(tc)) {
        if (isupper(tc)) {
            tc = tolower(tc);
            is_upper = true;
        }
    }
    
    switch (ctext_len) {
        case 1:
            NSLog(@"char=%d\n", tc);
            index = indexForChar(_map, _map_len, tc);
            if (index != -1) {
                keycode = _map[index].key;
                special = _map[index].special_key;
            }
            break;
        case 2:
            NSLog(@"char=%d\n", tc);
            NSLog(@"ext1=%d\n", (unsigned char) ctext[1]);
            index = indexForExtChar(_ext_map, _ext_map_len, tc, ctext[1], 0);
            if (index != -1) {
                keycode = _ext_map[index].key;
                special = _ext_map[index].special_key;
                prekey = _ext_map[index].prekey;
                prekey_special = _ext_map[index].special_prekey;
            }
            break;
        case 3:
            NSLog(@"char=%d\n", tc);
            NSLog(@"ext1=%d\n", (unsigned char) ctext[1]);
            NSLog(@"ext2=%d\n", (unsigned char) ctext[2]);
            index = indexForExtChar(_ext_map, _ext_map_len, tc, ctext[1], ctext[2]);
            if (index != -1) {
                keycode = _ext_map[index].key;
                special = _ext_map[index].special_key;
                prekey = _ext_map[index].prekey;
                prekey_special = _ext_map[index].special_prekey;
            }
            break;
    }
    
    if (keycode) {
        if (is_upper) {
            special = 0x2A;
        }
        
        if (prekey) {
            if (prekey_special) {
                [self.delegate keyboardView:self didPressKeyDown:special];
            }
            [self.delegate keyboardView:self didPressKeyDown:prekey];
            [NSThread sleepForTimeInterval:0.05f];
            [self.delegate keyboardView:self didPressKeyUp:prekey];
            if (prekey_special) {
                [self.delegate keyboardView:self didPressKeyUp:special];
            }
        }
        
        if (special) {
            [self.delegate keyboardView:self didPressKeyDown:special];
        }
        
        [self.delegate keyboardView:self didPressKeyDown:keycode];
        [NSThread sleepForTimeInterval:0.05f];
        [self.delegate keyboardView:self didPressKeyUp:keycode];
        
        if (special) {
            [self.delegate keyboardView:self didPressKeyUp:special];
        }
    }
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

@end
