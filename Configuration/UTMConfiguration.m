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

#import "UTMConfiguration.h"
#import "UTMConfiguration+Constants.h"
#import "UTMConfiguration+Drives.h"
#import "UTMConfiguration+Networking.h"
#import "UTMConfiguration+System.h"

const NSString *const kUTMConfigSystemKey = @"System";
const NSString *const kUTMConfigDisplayKey = @"Display";
const NSString *const kUTMConfigInputKey = @"Input";
const NSString *const kUTMConfigNetworkingKey = @"Networking";
const NSString *const kUTMConfigPrintingKey = @"Printing";
const NSString *const kUTMConfigSoundKey = @"Sound";
const NSString *const kUTMConfigSharingKey = @"Sharing";
const NSString *const kUTMConfigDrivesKey = @"Drives";
const NSString *const kUTMConfigDebugKey = @"Debug";

const NSString *const kUTMConfigConsoleOnlyKey = @"ConsoleOnly";
const NSString *const kUTMConfigFixedResolutionKey = @"FixedResolution";
const NSString *const kUTMConfigFixedResolutionWidthKey = @"FixedResolutionWidth";
const NSString *const kUTMConfigFixedResolutionHeightKey = @"FixedResolutionHeight";
const NSString *const kUTMConfigZoomScaleKey = @"ZoomScale";
const NSString *const kUTMConfigZoomLetterboxKey = @"ZoomLetterbox";

const NSString *const kUTMConfigTouchscreenModeKey = @"TouchscreenMode";
const NSString *const kUTMConfigDirectInputKey = @"DirectInput";
const NSString *const kUTMConfigInputLegacyKey = @"InputLegacy";

const NSString *const kUTMConfigPrintEnabledKey = @"PrintEnabled";

const NSString *const kUTMConfigSoundEnabledKey = @"SoundEnabled";
const NSString *const kUTMConfigSoundCardDeviceKey = @"SoundCard";

const NSString *const kUTMConfigChipboardSharingKey = @"ClipboardSharing";

const NSString *const kUTMConfigDebugLogKey = @"DebugLog";

@interface UTMConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMConfiguration {
    NSMutableDictionary *_rootDict;
}

@synthesize rootDict = _rootDict;



#pragma mark - Migration

- (void)migrateConfigurationIfNecessary {
    // Add Debug dict if not exists
    if (!_rootDict[kUTMConfigDebugKey]) {
        _rootDict[kUTMConfigDebugKey] = [NSMutableDictionary dictionary];
    }
    
    if (!_rootDict[kUTMConfigSoundKey][kUTMConfigSoundCardDeviceKey]) {
        _rootDict[kUTMConfigSoundKey][kUTMConfigSoundCardDeviceKey] = [UTMConfiguration supportedSoundCardDevices][0];
    }
    // Migrate input settings
    [_rootDict[kUTMConfigInputKey] removeObjectForKey:kUTMConfigTouchscreenModeKey];
    [_rootDict[kUTMConfigInputKey] removeObjectForKey:kUTMConfigDirectInputKey];
    if (!_rootDict[kUTMConfigInputKey][kUTMConfigInputLegacyKey]) {
        self.inputLegacy = NO;
    }
    // Migrate other settings
    [self migrateDriveConfigurationIfNecessary];
    [self migrateNetworkConfigurationIfNecessary];
    [self migrateSystemConfigurationIfNecessary];
}

#pragma mark - Initialization

- (id)initDefaults:(NSString *)name {
    self = [self init];
    if (self) {
        _rootDict = [[NSMutableDictionary alloc] initWithCapacity:8];
        _rootDict[kUTMConfigSystemKey] = [[NSMutableDictionary alloc] init];
        _rootDict[kUTMConfigDisplayKey] = [[NSMutableDictionary alloc] init];
        _rootDict[kUTMConfigInputKey] = [[NSMutableDictionary alloc] init];
        _rootDict[kUTMConfigNetworkingKey] = [[NSMutableDictionary alloc] init];
        _rootDict[kUTMConfigPrintingKey] = [[NSMutableDictionary alloc] init];
        _rootDict[kUTMConfigSoundKey] = [[NSMutableDictionary alloc] init];
        _rootDict[kUTMConfigSharingKey] = [[NSMutableDictionary alloc] init];
        _rootDict[kUTMConfigDrivesKey] = [[NSMutableArray alloc] init];
        _rootDict[kUTMConfigDebugKey] = [[NSMutableDictionary alloc] init];
        self.systemArchitecture = @"x86_64";
        self.systemMemory = @512;
        self.systemCPUCount = @1;
        self.systemBootDevice = @"CD/DVD";
        self.systemJitCacheSize = @0;
        self.systemForceMulticore = NO;
        self.displayFixedResolutionWidth = @800;
        self.displayFixedResolutionHeight = @600;
        self.displayFixedResolution = NO;
        self.networkEnabled = YES;
        self.printEnabled = YES;
        self.soundEnabled = YES;
        self.soundCard = @"ac97";
        self.networkCard = @"rtl8139";
        self.sharingClipboardEnabled = YES;
        self.name = name;
        self.existingPath = nil;
        self.debugLogEnabled = NO;
    }
    return self;
}

- (id)initWithDictionary:(NSMutableDictionary *)dictionary name:(NSString *)name path:(NSURL *)path {
    self = [self init];
    if (self) {
        _rootDict = dictionary;
        self.name = name;
        self.existingPath = path;
        
        [self migrateConfigurationIfNecessary];
    }
    return self;
}

#pragma mark - Other properties

- (void)setDisplayConsoleOnly:(BOOL)displayConsoleOnly {
    self.rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleOnlyKey] = @(displayConsoleOnly);
}

- (BOOL)displayConsoleOnly {
    return [_rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleOnlyKey] boolValue];
}

- (void)setDisplayFixedResolution:(BOOL)displayFixedResolution {
    _rootDict[kUTMConfigDisplayKey][kUTMConfigFixedResolutionKey] = @(displayFixedResolution);
}

- (BOOL)displayFixedResolution {
    return [_rootDict[kUTMConfigDisplayKey][kUTMConfigFixedResolutionKey] boolValue];
}

- (void)setDisplayFixedResolutionWidth:(NSNumber *)displayFixedResolutionWidth {
    _rootDict[kUTMConfigDisplayKey][kUTMConfigFixedResolutionWidthKey] = displayFixedResolutionWidth;
}

- (NSNumber *)displayFixedResolutionWidth {
    return _rootDict[kUTMConfigDisplayKey][kUTMConfigFixedResolutionWidthKey];
}

- (void)setDisplayFixedResolutionHeight:(NSNumber *)displayFixedResolutionHeight {
    _rootDict[kUTMConfigDisplayKey][kUTMConfigFixedResolutionHeightKey] = displayFixedResolutionHeight;
}

- (NSNumber *)displayFixedResolutionHeight {
    return _rootDict[kUTMConfigDisplayKey][kUTMConfigFixedResolutionHeightKey];
}

- (void)setDisplayZoomScale:(BOOL)displayZoomScale {
    _rootDict[kUTMConfigDisplayKey][kUTMConfigZoomScaleKey] = @(displayZoomScale);
}

- (BOOL)displayZoomScale {
    return [_rootDict[kUTMConfigDisplayKey][kUTMConfigZoomScaleKey] boolValue];
}

- (void)setDisplayZoomLetterBox:(BOOL)displayZoomLetterBox {
    _rootDict[kUTMConfigDisplayKey][kUTMConfigZoomLetterboxKey] = @(displayZoomLetterBox);
}

- (BOOL)displayZoomLetterBox {
    return [_rootDict[kUTMConfigDisplayKey][kUTMConfigZoomLetterboxKey] boolValue];
}

- (void)setInputLegacy:(BOOL)inputDirect {
    _rootDict[kUTMConfigInputKey][kUTMConfigInputLegacyKey] = @(inputDirect);
}

- (BOOL)inputLegacy {
    return [_rootDict[kUTMConfigInputKey][kUTMConfigInputLegacyKey] boolValue];
}

- (void)setPrintEnabled:(BOOL)printEnabled {
    _rootDict[kUTMConfigPrintingKey][kUTMConfigPrintEnabledKey] = @(printEnabled);
}

- (BOOL)printEnabled {
    return [_rootDict[kUTMConfigPrintingKey][kUTMConfigPrintEnabledKey] boolValue];
}

- (void)setSoundEnabled:(BOOL)soundEnabled {
    _rootDict[kUTMConfigSoundKey][kUTMConfigSoundEnabledKey] = @(soundEnabled);
}

- (BOOL)soundEnabled {
    return [_rootDict[kUTMConfigSoundKey][kUTMConfigSoundEnabledKey] boolValue];
}

- (void)setSoundCard:(NSString *)soundCard {
    _rootDict[kUTMConfigSoundKey][kUTMConfigSoundCardDeviceKey] = soundCard;
}

- (NSString *)soundCard {
    return _rootDict[kUTMConfigSoundKey][kUTMConfigSoundCardDeviceKey];
}

- (void)setSharingClipboardEnabled:(BOOL)sharingClipboardEnabled {
    _rootDict[kUTMConfigSharingKey][kUTMConfigChipboardSharingKey] = @(sharingClipboardEnabled);
}

- (BOOL)sharingClipboardEnabled {
    return [_rootDict[kUTMConfigSharingKey][kUTMConfigChipboardSharingKey] boolValue];
}

- (BOOL)debugLogEnabled {
    return [self.rootDict[kUTMConfigDebugKey][kUTMConfigDebugLogKey] boolValue];
}

- (void)setDebugLogEnabled:(BOOL)debugLogEnabled {
    self.rootDict[kUTMConfigDebugKey][kUTMConfigDebugLogKey] = @(debugLogEnabled);
}

#pragma mark - Dictionary representation

- (NSDictionary *)dictRepresentation {
    return (NSDictionary *)_rootDict;
}

- (NSURL*)terminalInputOutputURL {
    NSURL* tmpDir = [[NSFileManager defaultManager] temporaryDirectory];
    NSString* ioFileName = [NSString stringWithFormat: @"%@.terminal", self.name];
    NSURL* ioFile = [tmpDir URLByAppendingPathComponent: ioFileName];
    return ioFile;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    NSMutableDictionary* dictRepresentation = [[self dictRepresentation] mutableCopy];
    return [[UTMConfiguration alloc] initWithDictionary:dictRepresentation name:_name path:_existingPath];
}

@end
