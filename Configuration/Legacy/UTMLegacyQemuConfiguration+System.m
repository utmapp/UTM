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

#import "UTMLegacyQemuConfiguration+Constants.h"
#import "UTMLegacyQemuConfiguration+System.h"

extern const NSString *const kUTMConfigSystemKey;

static const NSString *const kUTMConfigArchitectureKey = @"Architecture";
static const NSString *const kUTMConfigCPUKey = @"CPU";
static const NSString *const kUTMConfigCPUFlagsKey = @"CPUFlags";
static const NSString *const kUTMConfigMemoryKey = @"Memory";
static const NSString *const kUTMConfigCPUCountKey = @"CPUCount";
static const NSString *const kUTMConfigTargetKey = @"Target";
static const NSString *const kUTMConfigBootDeviceKey = @"BootDevice";
static const NSString *const kUTMConfigBootUefiKey = @"BootUefi";
static const NSString *const kUTMConfigRngEnabledKey = @"RngEnabled";
static const NSString *const kUTMConfigJitCacheSizeKey = @"JITCacheSize";
static const NSString *const kUTMConfigForceMulticoreKey = @"ForceMulticore";
static const NSString *const kUTMConfigAddArgsKey = @"AddArgs";
static const NSString *const kUTMConfigSystemUUIDKey = @"SystemUUID";
static const NSString *const kUTMConfigMachinePropertiesKey = @"MachineProperties";
static const NSString *const kUTMConfigUseHypervisorKey = @"UseHypervisor";
static const NSString *const kUTMConfigRTCUseLocalTimeKey = @"RTCUseLocalTime";
static const NSString *const kUTMConfigForcePs2ControllerKey = @"ForcePS2Controller";

@interface UTMLegacyQemuConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMLegacyQemuConfiguration (System)

#pragma mark - Migration

- (void)migrateSystemConfigurationIfNecessary {
    // Migrates QEMU arguments from a single string to the first object in an array.
    if ([self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] isKindOfClass:[NSString class]]) {
        NSString *currentArgs = self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey];
        
        self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] = [[NSMutableArray alloc] init];
        self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][0] = currentArgs;
    }
    // Migrate default target
    if ([self.rootDict[kUTMConfigSystemKey][kUTMConfigTargetKey] length] == 0) {
        self.rootDict[kUTMConfigSystemKey][kUTMConfigTargetKey] = [UTMLegacyQemuConfiguration defaultTargetForArchitecture:self.systemArchitecture];
    }
    // Fix issue with boot order
    NSArray<NSString *> *bootPretty = [UTMLegacyQemuConfiguration supportedBootDevicesPretty];
    if ([bootPretty containsObject:self.systemBootDevice]) {
        NSInteger index = [bootPretty indexOfObject:self.systemBootDevice];
        self.systemBootDevice = [UTMLegacyQemuConfiguration supportedBootDevices][index];
    }
    // Default CPU
    if ([self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUKey] length] == 0) {
        self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUKey] = @"default";
    }
    // iOS 14 uses bootindex and systemBootDevice is deprecated
    if (@available(iOS 14, *)) {
        self.systemBootDevice = @"";
    }
    // migrate global use hypervisor to per-vm
    if (![self.rootDict[kUTMConfigSystemKey] objectForKey:kUTMConfigUseHypervisorKey]) {
        self.useHypervisor = self.defaultUseHypervisor;
    }
    // Set UEFI boot to default on for virt* and off otherwise
    if (self.rootDict[kUTMConfigSystemKey][kUTMConfigBootUefiKey] == nil) {
        self.systemBootUefi = [self.systemTarget hasPrefix:@"virt"];
    }
    // Set RNG enabled default for pc* and virt*
    if (self.rootDict[kUTMConfigSystemKey][kUTMConfigRngEnabledKey] == nil) {
        self.systemRngEnabled = [self.systemTarget hasPrefix:@"pc"] || [self.systemTarget hasPrefix:@"q35"] || [self.systemTarget hasPrefix:@"virt"];
    }
    if (self.rootDict[kUTMConfigSystemKey][kUTMConfigRTCUseLocalTimeKey] == nil) {
        self.rtcUseLocalTime = YES; // used to be default, now only for Windows
    }
    // PS/2 controller used to always be enabled by default for pc/q35
    if (self.rootDict[kUTMConfigSystemKey][kUTMConfigForcePs2ControllerKey] == nil) {
        self.forcePs2Controller = [self.systemTarget hasPrefix:@"pc"] || [self.systemTarget hasPrefix:@"q35"];
    }
}

#pragma mark - System Properties

- (void)setSystemArchitecture:(NSString *)systemArchitecture {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigArchitectureKey] = systemArchitecture;
}

- (NSString *)systemArchitecture {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigArchitectureKey];
}

- (void)setSystemCPU:(NSString *)systemCPU {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUKey] = systemCPU;
}

- (NSString *)systemCPU {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUKey];
}

- (void)setSystemMemory:(NSNumber *)systemMemory {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigMemoryKey] = systemMemory;
}

- (NSNumber *)systemMemory {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigMemoryKey];
}

- (void)setSystemCPUCount:(NSNumber *)systemCPUCount {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUCountKey] = systemCPUCount;
}

- (NSNumber *)systemCPUCount {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUCountKey];
}

- (void)setSystemTarget:(NSString *)systemTarget {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigTargetKey] = systemTarget;
}

- (NSString *)systemTarget {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigTargetKey];
}

- (void)setSystemBootDevice:(NSString *)systemBootDevice {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigBootDeviceKey] = systemBootDevice;
}

- (NSString *)systemBootDevice {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigBootDeviceKey];
}

- (void)setSystemBootUefi:(BOOL)systemBootUefi {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigBootUefiKey] = @(systemBootUefi);
}

- (BOOL)systemBootUefi {
    return [self.rootDict[kUTMConfigSystemKey][kUTMConfigBootUefiKey] boolValue];
}

- (void)setSystemRngEnabled:(BOOL)systemRngEnabled {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigRngEnabledKey] = @(systemRngEnabled);
}

- (BOOL)systemRngEnabled {
    return [self.rootDict[kUTMConfigSystemKey][kUTMConfigRngEnabledKey] boolValue];
}

- (NSNumber *)systemJitCacheSize {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigJitCacheSizeKey];
}

- (void)setSystemJitCacheSize:(NSNumber *)systemJitCacheSize {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigJitCacheSizeKey] = systemJitCacheSize;
}

- (BOOL)systemForceMulticore {
    return [self.rootDict[kUTMConfigSystemKey][kUTMConfigForceMulticoreKey] boolValue];
}

- (void)setSystemForceMulticore:(BOOL)systemForceMulticore {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigForceMulticoreKey] = @(systemForceMulticore);
}

- (NSString *)systemUUID {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigSystemUUIDKey];
}

- (void)setSystemUUID:(NSString *)systemUUID {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigSystemUUIDKey] = systemUUID;
}

- (NSString *)systemMachineProperties {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigMachinePropertiesKey];
}

- (void)setSystemMachineProperties:(NSString *)systemMachineProperties {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigMachinePropertiesKey] = systemMachineProperties;
}

- (BOOL)useHypervisor {
    return [self.rootDict[kUTMConfigSystemKey][kUTMConfigUseHypervisorKey] boolValue];
}

- (void)setUseHypervisor:(BOOL)useHypervisor {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigUseHypervisorKey] = @(useHypervisor);
}

- (BOOL)rtcUseLocalTime {
    return [self.rootDict[kUTMConfigSystemKey][kUTMConfigRTCUseLocalTimeKey] boolValue];
}

- (void)setRtcUseLocalTime:(BOOL)rtcUseLocalTime {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigRTCUseLocalTimeKey] = @(rtcUseLocalTime);
}

- (BOOL)forcePs2Controller {
    return [self.rootDict[kUTMConfigSystemKey][kUTMConfigForcePs2ControllerKey] boolValue];
}

- (void)setForcePs2Controller:(BOOL)forcePs2Controller {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigForcePs2ControllerKey] = @(forcePs2Controller);
}

#pragma mark - Additional arguments array handling

- (NSInteger)countArguments {
    return [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] count];
}

- (NSInteger)newArgument:(NSString *)argument {
    if (![self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] isKindOfClass:[NSMutableArray class]]) {
        self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] = [NSMutableArray array];
    }
    NSInteger index = [self countArguments];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index] = argument;
    
    return index;
}

- (nullable NSString *)argumentForIndex:(NSInteger)index {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index];
}

- (void)updateArgumentAtIndex:(NSInteger)index withValue:(NSString*)argument {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index] = argument;
}

- (void)moveArgumentIndex:(NSInteger)index to:(NSInteger)newIndex {
    NSString *arg = self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index];
    [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] removeObjectAtIndex:index];
    [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] insertObject:arg atIndex:newIndex];
}

- (void)removeArgumentAtIndex:(NSInteger)index {
    [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] removeObjectAtIndex:index];
}

- (NSArray *)systemArguments {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey];
}

#pragma mark - CPU Flags

- (NSArray *)systemCPUFlags {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUFlagsKey];
}

- (NSInteger)newCPUFlag:(NSString *)CPUFlag {
    NSMutableArray<NSString *> *flags = self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUFlagsKey];
    if (![flags isKindOfClass:[NSMutableArray class]]) {
        flags = self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUFlagsKey] = [NSMutableArray array];
    }
    NSUInteger index = [flags indexOfObjectPassingTest:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [CPUFlag isEqualToString:obj];
    }];
    if (index != NSNotFound) {
        return (NSInteger)index;
    }
    [flags addObject:CPUFlag];
    return flags.count - 1;
}

- (void)removeCPUFlag:(NSString *)CPUFlag {
    NSMutableArray<NSString *> *flags = self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUFlagsKey];
    [flags removeObject:CPUFlag];
}

#pragma mark - Computed properties

- (BOOL)isTargetArchitectureMatchHost {
#if defined(__aarch64__)
    return [self.systemArchitecture isEqualToString:@"aarch64"];
#elif defined(__x86_64__)
    return [self.systemArchitecture isEqualToString:@"x86_64"];
#else
    return NO;
#endif
}

- (BOOL)defaultUseHypervisor {
#if TARGET_OS_IPHONE
    return NO;
#else
    return self.isTargetArchitectureMatchHost;
#endif
}

@end
