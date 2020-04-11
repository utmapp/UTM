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

const NSString *const kUTMConfigSystemKey = @"System";
const NSString *const kUTMConfigDisplayKey = @"Display";
const NSString *const kUTMConfigInputKey = @"Input";
const NSString *const kUTMConfigNetworkingKey = @"Networking";
const NSString *const kUTMConfigPrintingKey = @"Printing";
const NSString *const kUTMConfigSoundKey = @"Sound";
const NSString *const kUTMConfigSharingKey = @"Sharing";
const NSString *const kUTMConfigDrivesKey = @"Drives";
const NSString *const kUTMConfigDebugKey = @"Debug";

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
        self.systemTarget = @"pc";
        self.systemMemory = @512;
        self.systemCPUCount = @1;
        self.systemBootDevice = @"cd";
        self.systemJitCacheSize = @0;
        self.systemForceMulticore = NO;
        self.systemUUID = [[NSUUID UUID] UUIDString];
        self.displayUpscaler = @"linear";
        self.displayDownscaler = @"linear";
        self.consoleFont = @"Menlo";
        self.consoleTheme = @"Default";
        self.networkEnabled = YES;
        self.soundEnabled = YES;
        self.soundCard = @"ac97";
        self.networkCard = @"rtl8139";
        self.shareClipboardEnabled = YES;
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
