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

#import "UTMConfiguration+Constants.h"
#import "UTMConfiguration+Miscellaneous.h"
#import "UTM-Swift.h"

extern const NSString *const kUTMConfigInputKey;
extern const NSString *const kUTMConfigSoundKey;
extern const NSString *const kUTMConfigDebugKey;
extern const NSString *const kUTMConfigInfoKey;

const NSString *const kUTMConfigTouchscreenModeKey = @"TouchscreenMode";
const NSString *const kUTMConfigDirectInputKey = @"DirectInput";
const NSString *const kUTMConfigInputLegacyKey = @"InputLegacy";
const NSString *const kUTMConfigInputInvertScrollKey = @"InputInvertScroll";

const NSString *const kUTMConfigSoundEnabledKey = @"SoundEnabled";
const NSString *const kUTMConfigSoundCardDeviceKey = @"SoundCard";

const NSString *const kUTMConfigDebugLogKey = @"DebugLog";
const NSString *const kUTMConfigIgnoreAllConfigurationKey = @"IgnoreAllConfiguration";

const NSString *const kUTMConfigIconKey = @"Icon";
const NSString *const kUTMConfigIconCustomKey = @"IconCustom";
const NSString *const kUTMConfigNotesKey = @"Notes";

@interface UTMConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMConfiguration (Miscellaneous)

#pragma mark - Migration

- (void)migrateMiscellaneousConfigurationIfNecessary {
    // Add categories that may not have existed before
    if (!self.rootDict[kUTMConfigDebugKey]) {
        self.rootDict[kUTMConfigDebugKey] = [NSMutableDictionary dictionary];
    }
    if (!self.rootDict[kUTMConfigInfoKey]) {
        self.rootDict[kUTMConfigInfoKey] = [NSMutableDictionary dictionary];
    }
    if (!self.soundCard) {
        self.soundCard = @"AC97";
    } else if ([self.soundCard isEqualToString:@"hda"]) {
        self.soundCard = @"intel-hda"; // migrate name
    } else if ([self.soundCard isEqualToString:@"pcspk"]) {
        self.soundEnabled = NO; // no longer supported
    }
    // Migrate input settings
    [self.rootDict[kUTMConfigInputKey] removeObjectForKey:kUTMConfigTouchscreenModeKey];
    [self.rootDict[kUTMConfigInputKey] removeObjectForKey:kUTMConfigDirectInputKey];
    if (!self.rootDict[kUTMConfigInputKey][kUTMConfigInputLegacyKey]) {
        self.inputLegacy = NO;
    }
}

#pragma mark - Other properties

- (void)setInputLegacy:(BOOL)inputDirect {
    [self propertyWillChange];
    self.rootDict[kUTMConfigInputKey][kUTMConfigInputLegacyKey] = @(inputDirect);
}

- (BOOL)inputLegacy {
    return [self.rootDict[kUTMConfigInputKey][kUTMConfigInputLegacyKey] boolValue];
}

- (void)setInputScrollInvert:(BOOL)inputScrollInvert {
    [self propertyWillChange];
    self.rootDict[kUTMConfigInputKey][kUTMConfigInputInvertScrollKey] = @(inputScrollInvert);
}

- (BOOL)inputScrollInvert {
    return [self.rootDict[kUTMConfigInputKey][kUTMConfigInputInvertScrollKey] boolValue];
}

- (void)setSoundEnabled:(BOOL)soundEnabled {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSoundKey][kUTMConfigSoundEnabledKey] = @(soundEnabled);
}

- (BOOL)soundEnabled {
    return [self.rootDict[kUTMConfigSoundKey][kUTMConfigSoundEnabledKey] boolValue];
}

- (void)setSoundCard:(NSString *)soundCard {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSoundKey][kUTMConfigSoundCardDeviceKey] = soundCard;
}

- (NSString *)soundCard {
    return self.rootDict[kUTMConfigSoundKey][kUTMConfigSoundCardDeviceKey];
}

- (BOOL)debugLogEnabled {
    return [self.rootDict[kUTMConfigDebugKey][kUTMConfigDebugLogKey] boolValue];
}

- (void)setDebugLogEnabled:(BOOL)debugLogEnabled {
    [self propertyWillChange];
    self.rootDict[kUTMConfigDebugKey][kUTMConfigDebugLogKey] = @(debugLogEnabled);
}

- (BOOL)ignoreAllConfiguration {
    return [self.rootDict[kUTMConfigDebugKey][kUTMConfigIgnoreAllConfigurationKey] boolValue];
}

- (void)setIgnoreAllConfiguration:(BOOL)ignoreAllConfiguration {
    [self propertyWillChange];
    self.rootDict[kUTMConfigDebugKey][kUTMConfigIgnoreAllConfigurationKey] = @(ignoreAllConfiguration);
}

- (void)setIcon:(NSString *)icon {
    [self propertyWillChange];
    self.rootDict[kUTMConfigInfoKey][kUTMConfigIconKey] = icon;
}

- (nullable NSString *)icon {
    return self.rootDict[kUTMConfigInfoKey][kUTMConfigIconKey];
}

- (void)setIconCustom:(BOOL)iconCustom {
    [self propertyWillChange];
    self.rootDict[kUTMConfigInfoKey][kUTMConfigIconCustomKey] = @(iconCustom);
}

- (BOOL)iconCustom {
    return [self.rootDict[kUTMConfigInfoKey][kUTMConfigIconCustomKey] boolValue];
}

- (void)setNotes:(NSString *)notes {
    [self propertyWillChange];
    self.rootDict[kUTMConfigInfoKey][kUTMConfigNotesKey] = notes;
}

- (nullable NSString *)notes {
    return self.rootDict[kUTMConfigInfoKey][kUTMConfigNotesKey];
}

@end
