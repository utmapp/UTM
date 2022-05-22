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

#import "UTMQemuConfiguration.h"
#import "UTMQemuConfiguration+Constants.h"
#import "UTMQemuConfiguration+Defaults.h"
#import "UTMQemuConfiguration+Display.h"
#import "UTMQemuConfiguration+Drives.h"
#import "UTMQemuConfiguration+Miscellaneous.h"
#import "UTMQemuConfiguration+Networking.h"
#import "UTMQemuConfiguration+Sharing.h"
#import "UTMQemuConfiguration+System.h"
#import "UTM-Swift.h"
#import <CommonCrypto/CommonDigest.h>
#import <TargetConditionals.h>

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
const NSString *const kUTMConfigVersionKey = @"ConfigurationVersion";

const NSInteger kCurrentConfigurationVersion = 2;

const NSString *const kUTMConfigAppleVirtualizationKey = @"isAppleVirtualization";

@interface UTMQemuConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMQemuConfiguration {
    NSMutableDictionary *_rootDict;
}

@synthesize rootDict = _rootDict;

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

- (NSURL *)iconUrl {
    if (self.iconCustom) {
        if (self.selectedCustomIconPath != nil) {
            return self.selectedCustomIconPath;
        } else if (self.icon == nil) {
            return nil;
        } else {
            return [self.existingPath URLByAppendingPathComponent:self.icon];
        }
    } else {
        if (self.icon == nil) {
            return nil;
        } else {
            return [[NSBundle mainBundle] URLForResource:self.icon withExtension:@"png" subdirectory:@"Icons"];
        }
    }
}

#pragma mark - Migration

- (void)migrateConfigurationIfNecessary {
    [self migrateMiscellaneousConfigurationIfNecessary];
    [self migrateDriveConfigurationIfNecessary];
    [self migrateNetworkConfigurationIfNecessary];
    [self migrateSystemConfigurationIfNecessary];
    [self migrateDisplayConfigurationIfNecessary];
    [self migrateSharingConfigurationIfNecessary];
    self.version = @(kCurrentConfigurationVersion);
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
        if (![self reloadConfigurationWithDictionary:dictionary name:name path:path]) {
            return nil;
        }
    }
    return self;
}

#pragma mark - Dictionary representation

- (NSDictionary *)dictRepresentation {
    return (NSDictionary *)_rootDict;
}

- (NSUUID *)legacyUuidFromName {
    NSData *rawName = [self.name dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(rawName.bytes, (CC_LONG)rawName.length, hash.mutableBytes);
    return [[NSUUID alloc] initWithUUIDBytes:hash.bytes];
}

- (NSURL *)socketUrlWithSuffix:(NSString *)suffix {
#if TARGET_OS_IPHONE
    NSURL* parentDir = [[NSFileManager defaultManager] temporaryDirectory];
#else
    NSURL* parentDir = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@OS_STRINGIFY(UTM_APP_GROUP)];
#endif
    NSString *name = self.systemUUID;
    if (!name) {
        name = [self legacyUuidFromName].UUIDString;
    }
    NSString* ioFileName = [NSString stringWithFormat: @"%@.%@", name, suffix];
    NSURL* ioFile = [parentDir URLByAppendingPathComponent:ioFileName];
    return ioFile;
}

- (NSURL*)spiceSocketURL {
    return [self socketUrlWithSuffix:@"spice"];
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
    self.version = @(kCurrentConfigurationVersion);
    [self loadDefaults];
}

- (BOOL)reloadConfigurationWithDictionary:(NSDictionary *)dictionary name:(NSString *)name path:(NSURL *)path {
    if ([dictionary[kUTMConfigAppleVirtualizationKey] boolValue]) {
        return NO; // do not parse Apple config
    }
    if ([dictionary[kUTMConfigVersionKey] intValue] > kCurrentConfigurationVersion) {
        return NO; // do not parse if version is too high
    }
    [self propertyWillChange];
    _rootDict = CFBridgingRelease(CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (__bridge CFDictionaryRef)dictionary, kCFPropertyListMutableContainers));
    self.name = name;
    self.existingPath = path;
    self.selectedCustomIconPath = nil;
    [self migrateConfigurationIfNecessary];
    return YES;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return [[UTMQemuConfiguration alloc] initWithDictionary:_rootDict name:self.name path:nil];
}

#pragma mark - Settings

- (void)setVersion:(NSNumber *)version {
    [self propertyWillChange];
    self.rootDict[kUTMConfigVersionKey] = version;
}

- (NSNumber *)version {
    return self.rootDict[kUTMConfigVersionKey];
}

- (BOOL)isAppleVirtualization {
    return NO;
}

@end
