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

#import "UTMLegacyQemuConfiguration.h"
#import "UTMLegacyQemuConfiguration+Display.h"
#import "UTMLegacyQemuConfiguration+Drives.h"
#import "UTMLegacyQemuConfiguration+Miscellaneous.h"
#import "UTMLegacyQemuConfiguration+Networking.h"
#import "UTMLegacyQemuConfiguration+Sharing.h"
#import "UTMLegacyQemuConfiguration+System.h"
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

@interface UTMLegacyQemuConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMLegacyQemuConfiguration {
    NSMutableDictionary *_rootDict;
}

@synthesize rootDict = _rootDict;

- (void)setName:(NSString *)name {
    _name = name;
}

- (void)setExistingPath:(NSURL *)existingPath {
    _existingPath = existingPath;
}

- (void)setSelectedCustomIconPath:(NSURL *)selectedCustomIconPath {
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

- (BOOL)reloadConfigurationWithDictionary:(NSDictionary *)dictionary name:(NSString *)name path:(NSURL *)path {
    if ([dictionary[kUTMConfigAppleVirtualizationKey] boolValue]) {
        return NO; // do not parse Apple config
    }
    if ([dictionary[kUTMConfigVersionKey] intValue] > kCurrentConfigurationVersion) {
        return NO; // do not parse if version is too high
    }
    _rootDict = CFBridgingRelease(CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (__bridge CFDictionaryRef)dictionary, kCFPropertyListMutableContainers));
    self.name = name;
    self.existingPath = path;
    self.selectedCustomIconPath = nil;
    [self migrateConfigurationIfNecessary];
    return YES;
}

#pragma mark - Settings

- (void)setVersion:(NSNumber *)version {
    self.rootDict[kUTMConfigVersionKey] = version;
}

- (NSNumber *)version {
    return self.rootDict[kUTMConfigVersionKey];
}

@end
