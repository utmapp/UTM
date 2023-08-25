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

#import <TargetConditionals.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
#import "UTMLegacyQemuConfiguration+Constants.h"
#import "UTMLegacyQemuConfiguration+Display.h"
#import "UTMLegacyQemuConfiguration+Sharing.h"
#import "UTMLegacyQemuConfiguration+System.h"

extern const NSString *const kUTMConfigDisplayKey;

const NSString *const kUTMConfigConsoleOnlyKey = @"ConsoleOnly";
const NSString *const kUTMConfigDisplayFitScreenKey = @"DisplayFitScreen";
const NSString *const kUTMConfigDisplayRetinaKey = @"DisplayRetina";
const NSString *const kUTMConfigDisplayUpscalerKey = @"DisplayUpscaler";
const NSString *const kUTMConfigDisplayDownscalerKey = @"DisplayDownscaler";
const NSString *const kUTMConfigConsoleThemeKey = @"ConsoleTheme";
const NSString *const kUTMConfigConsoleTextColorKey = @"ConsoleTextColor";
const NSString *const kUTMConfigConsoleBackgroundColorKey = @"ConsoleBackgroundColor";
const NSString *const kUTMConfigConsoleFontKey = @"ConsoleFont";
const NSString *const kUTMConfigConsoleFontSizeKey = @"ConsoleFontSize";
const NSString *const kUTMConfigConsoleBlinkKey = @"ConsoleBlink";
const NSString *const kUTMConfigConsoleResizeCommandKey = @"ConsoleResizeCommand";
const NSString *const kUTMConfigDisplayCardKey = @"DisplayCard";

@interface UTMLegacyQemuConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMLegacyQemuConfiguration (Display)

#pragma mark - Migration

- (void)migrateDisplayConfigurationIfNecessary {
    if (self.displayUpscaler.length == 0) {
        self.displayUpscaler = @"linear";
    }
    if (self.displayDownscaler.length == 0) {
        self.displayDownscaler = @"linear";
    }
    if (self.consoleFont.length == 0) {
        self.consoleFont = @"Menlo-Regular";
    } else if (![[UTMLegacyQemuConfiguration supportedConsoleFonts] containsObject:self.consoleFont]) {
        // migrate to new fully-formed name
#if TARGET_OS_OSX
        NSFont *font = [NSFont fontWithName:self.consoleFont size:1];
#else
        UIFont *font = [UIFont fontWithName:self.consoleFont size:1];
#endif
        if (font) {
            self.consoleFont = font.fontName;
        }
    }
    if (self.consoleTheme.length == 0) {
        self.consoleTheme = @"Default";
    }
    if (self.consoleTextColor == nil) {
        self.consoleTextColor = @"#ffffff";
    }
    if (self.consoleBackgroundColor == nil) {
        self.consoleBackgroundColor = @"#000000";
    }
    if (self.consoleFontSize.integerValue == 0) {
        self.consoleFontSize = @12;
    }
    if (!self.displayCard) {
        if ([self.systemTarget hasPrefix:@"pc"] || [self.systemTarget hasPrefix:@"q35"]) {
            self.displayCard = @"qxl-vga";
        } else if ([self.systemTarget isEqualToString:@"virt"] || [self.systemTarget hasPrefix:@"virt-"]) {
            self.displayCard = @"virtio-ramfb";
        } else {
            self.displayCard = @"VGA";
        }
    }
    if (self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayFitScreenKey] == nil) {
        // automatically enable fit-screen if other SPICE features are used
        self.displayFitScreen = self.shareClipboardEnabled || self.shareDirectoryEnabled;
    }
}

#pragma mark - Display settings

- (void)setDisplayConsoleOnly:(BOOL)displayConsoleOnly {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleOnlyKey] = @(displayConsoleOnly);
}

- (BOOL)displayConsoleOnly {
    return [self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleOnlyKey] boolValue];
}

- (void)setDisplayFitScreen:(BOOL)displayFitScreen {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayFitScreenKey] = @(displayFitScreen);
}

- (BOOL)displayFitScreen {
    return [self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayFitScreenKey] boolValue];
}

- (void)setDisplayRetina:(BOOL)displayRetina {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayRetinaKey] = @(displayRetina);
}

- (BOOL)displayRetina {
    return [self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayRetinaKey] boolValue];
}

- (void)setDisplayUpscaler:(NSString *)displayUpscaler {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayUpscalerKey] = displayUpscaler;
}

- (NSString *)displayUpscaler {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayUpscalerKey];
}

- (MTLSamplerMinMagFilter)displayUpscalerValue {
    if ([self.displayUpscaler isEqualToString:@"nearest"]) {
        return MTLSamplerMinMagFilterNearest;
    } else {
        return MTLSamplerMinMagFilterLinear;
    }
}

- (void)setDisplayDownscaler:(NSString *)displayDownscaler {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayDownscalerKey] = displayDownscaler;
}

- (NSString *)displayDownscaler {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayDownscalerKey];
}

- (MTLSamplerMinMagFilter)displayDownscalerValue {
    if ([self.displayDownscaler isEqualToString:@"nearest"]) {
        return MTLSamplerMinMagFilterNearest;
    } else {
        return MTLSamplerMinMagFilterLinear;
    }
}

- (void)setConsoleTheme:(NSString *)consoleTheme {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleThemeKey] = consoleTheme;
}

- (NSString *)consoleTheme {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleThemeKey];
}

- (void)setConsoleTextColor:(NSString *)consoleTextColor {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleTextColorKey] = consoleTextColor;
}

- (NSString *)consoleTextColor {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleTextColorKey];
}

- (void)setConsoleBackgroundColor:(NSString *)consoleBackgroundColor {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleBackgroundColorKey] = consoleBackgroundColor;
}

- (NSString *)consoleBackgroundColor {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleBackgroundColorKey];
}

- (void)setConsoleFont:(NSString *)consoleFont {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleFontKey] = consoleFont;
}

- (NSString *)consoleFont {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleFontKey];
}

- (void)setConsoleFontSize:(NSNumber *)consoleFontSize {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleFontSizeKey] = consoleFontSize;
}

- (NSNumber *)consoleFontSize {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleFontSizeKey];
}

- (void)setConsoleCursorBlink:(BOOL)consoleCursorBlink {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleBlinkKey] = @(consoleCursorBlink);
}

- (BOOL)consoleCursorBlink {
    return [self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleBlinkKey] boolValue];
}

- (void)setConsoleResizeCommand:(NSString *)consoleResizeCommand {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleResizeCommandKey] = consoleResizeCommand;
}

- (NSString *)consoleResizeCommand {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleResizeCommandKey];
}

- (void)setDisplayCard:(NSString *)displayCard {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayCardKey] = displayCard;
}

- (NSString *)displayCard {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayCardKey];
}

@end
