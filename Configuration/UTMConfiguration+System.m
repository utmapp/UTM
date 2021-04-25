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
#import "UTMConfiguration+Defaults.h"
#import "UTMConfiguration+System.h"
#import "UTM-Swift.h"

extern const NSString *const kUTMConfigSystemKey;

static const NSString *const kUTMConfigArchitectureKey = @"Architecture";
static const NSString *const kUTMConfigCPUKey = @"CPU";
static const NSString *const kUTMConfigCPUFlagsKey = @"CPUFlags";
static const NSString *const kUTMConfigMemoryKey = @"Memory";
static const NSString *const kUTMConfigCPUCountKey = @"CPUCount";
static const NSString *const kUTMConfigTargetKey = @"Target";
static const NSString *const kUTMConfigBootDeviceKey = @"BootDevice";
static const NSString *const kUTMConfigJitCacheSizeKey = @"JITCacheSize";
static const NSString *const kUTMConfigForceMulticoreKey = @"ForceMulticore";
static const NSString *const kUTMConfigAddArgsKey = @"AddArgs";
static const NSString *const kUTMConfigSystemUUIDKey = @"SystemUUID";
static const NSString *const kUTMConfigMachinePropertiesKey = @"MachineProperties";

@interface UTMConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMConfiguration (System)

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
        NSInteger index = [UTMConfiguration defaultTargetIndexForArchitecture:self.systemArchitecture];
        self.rootDict[kUTMConfigSystemKey][kUTMConfigTargetKey] = [UTMConfiguration supportedTargetsForArchitecture:self.systemArchitecture][index];
    }
    // Fix issue with boot order
    NSArray<NSString *> *bootPretty = [UTMConfiguration supportedBootDevicesPretty];
    if ([bootPretty containsObject:self.systemBootDevice]) {
        NSInteger index = [bootPretty indexOfObject:self.systemBootDevice];
        self.systemBootDevice = [UTMConfiguration supportedBootDevices][index];
    }
    // Default CPU
    if ([self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUKey] length] == 0) {
        self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUKey] = [UTMConfiguration defaultCPUForTarget:self.systemTarget architecture:self.systemArchitecture];
    }
    // Older versions hard codes properties
    if ([self.version integerValue] < 2) {
        NSString *machineProp = [UTMConfiguration defaultMachinePropertiesForTarget:self.systemTarget];
        if (machineProp && self.systemMachineProperties.length == 0) {
            self.systemMachineProperties = machineProp;
        }
    }
    // iOS 14 uses bootindex and systemBootDevice is deprecated
    if (@available(iOS 14, *)) {
        self.systemBootDevice = @"";
    }
}

#pragma mark - System Properties

- (void)setSystemArchitecture:(NSString *)systemArchitecture {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigArchitectureKey] = systemArchitecture;
}

- (NSString *)systemArchitecture {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigArchitectureKey];
}

- (void)setSystemCPU:(NSString *)systemCPU {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUKey] = systemCPU;
}

- (NSString *)systemCPU {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUKey];
}

- (void)setSystemMemory:(NSNumber *)systemMemory {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigMemoryKey] = systemMemory;
}

- (NSNumber *)systemMemory {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigMemoryKey];
}

- (void)setSystemCPUCount:(NSNumber *)systemCPUCount {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUCountKey] = systemCPUCount;
}

- (NSNumber *)systemCPUCount {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUCountKey];
}

- (void)setSystemTarget:(NSString *)systemTarget {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigTargetKey] = systemTarget;
}

- (NSString *)systemTarget {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigTargetKey];
}

- (void)setSystemBootDevice:(NSString *)systemBootDevice {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigBootDeviceKey] = systemBootDevice;
}

- (NSString *)systemBootDevice {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigBootDeviceKey];
}

- (NSNumber *)systemJitCacheSize {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigJitCacheSizeKey];
}

- (void)setSystemJitCacheSize:(NSNumber *)systemJitCacheSize {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigJitCacheSizeKey] = systemJitCacheSize;
}

- (BOOL)systemForceMulticore {
    return [self.rootDict[kUTMConfigSystemKey][kUTMConfigForceMulticoreKey] boolValue];
}

- (void)setSystemForceMulticore:(BOOL)systemForceMulticore {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigForceMulticoreKey] = @(systemForceMulticore);
}

- (NSString *)systemUUID {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigSystemUUIDKey];
}

- (void)setSystemUUID:(NSString *)systemUUID {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigSystemUUIDKey] = systemUUID;
}

- (NSString *)systemMachineProperties {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigMachinePropertiesKey];
}

- (void)setSystemMachineProperties:(NSString *)systemMachineProperties {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigMachinePropertiesKey] = systemMachineProperties;
}

#pragma mark - Additional arguments array handling

- (NSInteger)countArguments {
    return [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] count];
}

- (NSInteger)newArgument:(NSString *)argument {
    if (![self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] isKindOfClass:[NSMutableArray class]]) {
        self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] = [NSMutableArray array];
    }
    [self propertyWillChange];
    NSInteger index = [self countArguments];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index] = argument;
    
    return index;
}

- (nullable NSString *)argumentForIndex:(NSInteger)index {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index];
}

- (void)updateArgumentAtIndex:(NSInteger)index withValue:(NSString*)argument {
    [self propertyWillChange];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index] = argument;
}

- (void)moveArgumentIndex:(NSInteger)index to:(NSInteger)newIndex {
    NSString *arg = self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index];
    [self propertyWillChange];
    [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] removeObjectAtIndex:index];
    [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] insertObject:arg atIndex:newIndex];
}

- (void)removeArgumentAtIndex:(NSInteger)index {
    [self propertyWillChange];
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
    NSUInteger index = [flags indexOfObjectIdenticalTo:CPUFlag];
    if (index != NSNotFound) {
        return (NSInteger)index;
    }
    [self propertyWillChange];
    [flags addObject:CPUFlag];
    return flags.count - 1;
}

- (void)removeCPUFlag:(NSString *)CPUFlag {
    NSMutableArray<NSString *> *flags = self.rootDict[kUTMConfigSystemKey][kUTMConfigCPUFlagsKey];
    [self propertyWillChange];
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

@end
