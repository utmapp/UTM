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
#import "UTMConfiguration+Display.h"
#import "UTMConfiguration+Drives.h"
#import "UTMConfiguration+Miscellaneous.h"
#import "UTMConfiguration+Networking.h"
#import "UTMConfiguration+Sharing.h"
#import "UTMConfiguration+System.h"
#import "UTM-Swift.h"

const NSString *const kUTMConfigSystemKey = @"System";
const NSString *const kUTMConfigDisplayKey = @"Display";
const NSString *const kUTMConfigInputKey = @"Input";
const NSString *const kUTMConfigNetworkingKey = @"Networking";
const NSString *const kUTMConfigPrintingKey = @"Printing";
const NSString *const kUTMConfigSoundKey = @"Sound";
const NSString *const kUTMConfigSharingKey = @"Sharing";
const NSString *const kUTMConfigDrivesKey = @"Drives";
const NSString *const kUTMConfigDebugKey = @"Debug";
const NSString *const kUTMConfigInfoKey = @"Info";

@interface UTMConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMConfiguration {
    NSMutableDictionary *_rootDict;
}

@synthesize rootDict = _rootDict;

#pragma mark - Migration

- (void)migrateConfigurationIfNecessary {
    [self migrateMiscellaneousConfigurationIfNecessary];
    [self migrateDriveConfigurationIfNecessary];
    [self migrateNetworkConfigurationIfNecessary];
    [self migrateSystemConfigurationIfNecessary];
    [self migrateDisplayConfigurationIfNecessary];
}

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        [self resetDefaults];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary name:(NSString *)name path:(NSURL *)path {
    self = [super init];
    if (self) {
        [self reloadConfigurationWithDictionary:dictionary name:name path:path];
    }
    return self;
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

- (void)resetDefaults {
    [self propertyWillChange];
    _rootDict = [@{
        kUTMConfigSystemKey: [NSMutableDictionary new],
        kUTMConfigDisplayKey: [NSMutableDictionary new],
        kUTMConfigInputKey: [NSMutableDictionary new],
        kUTMConfigNetworkingKey: [NSMutableDictionary new],
        kUTMConfigPrintingKey: [NSMutableDictionary new],
        kUTMConfigSoundKey: [NSMutableDictionary new],
        kUTMConfigSharingKey: [NSMutableDictionary new],
        kUTMConfigDrivesKey: [NSMutableArray new],
        kUTMConfigDebugKey: [NSMutableDictionary new],
        kUTMConfigInfoKey: [NSMutableDictionary new],
    } mutableCopy];
    self.systemArchitecture = @"x86_64";
    self.systemTarget = @"pc";
    self.systemMemory = @512;
    self.systemBootDevice = @"cd";
    self.systemUUID = [[NSUUID UUID] UUIDString];
    self.displayUpscaler = @"linear";
    self.displayDownscaler = @"linear";
    self.consoleFont = @"Menlo";
    self.consoleFontSize = @12;
    self.consoleTheme = @"Default";
    self.networkEnabled = YES;
    self.soundEnabled = YES;
    self.soundCard = @"ac97";
    self.networkCard = @"rtl8139";
    self.shareClipboardEnabled = YES;
    self.name = [NSUUID UUID].UUIDString;
    self.existingPath = nil;
    self.selectedCustomIconPath = nil;
}

- (void)reloadConfigurationWithDictionary:(NSDictionary *)dictionary name:(NSString *)name path:(NSURL *)path {
    [self propertyWillChange];
    _rootDict = CFBridgingRelease(CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (__bridge CFDictionaryRef)dictionary, kCFPropertyListMutableContainers));
    self.name = name;
    self.existingPath = path;
    self.selectedCustomIconPath = nil;
    [self migrateConfigurationIfNecessary];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return [[UTMConfiguration alloc] initWithDictionary:_rootDict name:_name path:_existingPath];
}

#pragma mark - Settings

- (void)setName:(NSString *)name {
    [self propertyWillChange];
    _name = name;
}

- (void)setExistingPath:(NSURL *)existingPath {
    [self propertyWillChange];
    _existingPath = existingPath;
}

- (void)setSelectedCustomIconPath:(NSURL *)selectedCustomIconPath {
    [self propertyWillChange];
    _selectedCustomIconPath = selectedCustomIconPath;
}

@end
