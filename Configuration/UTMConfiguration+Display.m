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

#import "UTMConfiguration+Display.h"
#import "UTM-Swift.h"

extern const NSString *const kUTMConfigDisplayKey;

const NSString *const kUTMConfigConsoleOnlyKey = @"ConsoleOnly";
const NSString *const kUTMConfigDisplayFitScreenKey = @"DisplayFitScreen";
const NSString *const kUTMConfigDisplayRetinaKey = @"DisplayRetina";
const NSString *const kUTMConfigDisplayUpscalerKey = @"DisplayUpscaler";
const NSString *const kUTMConfigDisplayDownscalerKey = @"DisplayDownscaler";
const NSString *const kUTMConfigConsoleThemeKey = @"ConsoleTheme";
const NSString *const kUTMConfigConsoleFontKey = @"ConsoleFont";
const NSString *const kUTMConfigConsoleFontSizeKey = @"ConsoleFontSize";
const NSString *const kUTMConfigConsoleBlinkKey = @"ConsoleBlink";
const NSString *const kUTMConfigConsoleResizeCommandKey = @"ConsoleResizeCommand";
const NSString *const kUTMConfigDisplayCardKey = @"DisplayCard";

@interface UTMConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMConfiguration (Display)

#pragma mark - Migration

- (void)migrateDisplayConfigurationIfNecessary {
    if (self.displayUpscaler.length == 0) {
        self.displayUpscaler = @"linear";
    }
    if (self.displayDownscaler.length == 0) {
        self.displayDownscaler = @"linear";
    }
    if (self.consoleFont.length == 0) {
        self.consoleFont = @"Menlo";
    }
    if (self.consoleTheme.length == 0) {
        self.consoleTheme = @"Default";
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
}

#pragma mark - Display settings

- (void)setDisplayConsoleOnly:(BOOL)displayConsoleOnly {
    [self propertyWillChange];
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleOnlyKey] = @(displayConsoleOnly);
}

- (BOOL)displayConsoleOnly {
    return [self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleOnlyKey] boolValue];
}

- (void)setDisplayFitScreen:(BOOL)displayFitScreen {
    [self propertyWillChange];
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayFitScreenKey] = @(displayFitScreen);
}

- (BOOL)displayFitScreen {
    return [self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayFitScreenKey] boolValue];
}

- (void)setDisplayRetina:(BOOL)displayRetina {
    [self propertyWillChange];
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayRetinaKey] = @(displayRetina);
}

- (BOOL)displayRetina {
    return [self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayRetinaKey] boolValue];
}

- (void)setDisplayUpscaler:(NSString *)displayUpscaler {
    [self propertyWillChange];
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
    [self propertyWillChange];
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
    [self propertyWillChange];
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleThemeKey] = consoleTheme;
}

- (NSString *)consoleTheme {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleThemeKey];
}

- (void)setConsoleFont:(NSString *)consoleFont {
    [self propertyWillChange];
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleFontKey] = consoleFont;
}

- (NSString *)consoleFont {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleFontKey];
}

- (void)setConsoleFontSize:(NSNumber *)consoleFontSize {
    [self propertyWillChange];
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleFontSizeKey] = consoleFontSize;
}

- (NSNumber *)consoleFontSize {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleFontSizeKey];
}

- (void)setConsoleCursorBlink:(BOOL)consoleCursorBlink {
    [self propertyWillChange];
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleBlinkKey] = @(consoleCursorBlink);
}

- (BOOL)consoleCursorBlink {
    return [self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleBlinkKey] boolValue];
}

- (void)setConsoleResizeCommand:(NSString *)consoleResizeCommand {
    [self propertyWillChange];
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleResizeCommandKey] = consoleResizeCommand;
}

- (NSString *)consoleResizeCommand {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleResizeCommandKey];
}

- (void)setDisplayCard:(NSString *)displayCard {
    [self propertyWillChange];
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayCardKey] = displayCard;
}

- (NSString *)displayCard {
    return self.rootDict[kUTMConfigDisplayKey][kUTMConfigDisplayCardKey];
}

@end
