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
#import "UTMConfiguration+System.h"

extern const NSString *const kUTMConfigSystemKey;

static const NSString *const kUTMConfigArchitectureKey = @"Architecture";
static const NSString *const kUTMConfigMemoryKey = @"Memory";
static const NSString *const kUTMConfigCPUCountKey = @"CPUCount";
static const NSString *const kUTMConfigTargetKey = @"Target";
static const NSString *const kUTMConfigBootDeviceKey = @"BootDevice";
static const NSString *const kUTMConfigJitCacheSizeKey = @"JITCacheSize";
static const NSString *const kUTMConfigForceMulticoreKey = @"ForceMulticore";
static const NSString *const kUTMConfigAddArgsKey = @"AddArgs";

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
}

#pragma mark - System Properties

- (void)setSystemArchitecture:(NSString *)systemArchitecture {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigArchitectureKey] = systemArchitecture;
}

- (NSString *)systemArchitecture {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigArchitectureKey];
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

#pragma mark - Additional arguments array handling

- (NSUInteger)countArguments {
    return [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] count];
}

- (NSUInteger)newArgument:(NSString *)argument {
    if (![self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] isKindOfClass:[NSMutableArray class]]) {
        self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] = [NSMutableArray array];
    }
    NSUInteger index = [self countArguments];
    self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index] = argument;
    
    return index;
}

- (nullable NSString *)argumentForIndex:(NSUInteger)index {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index];
}

- (void)updateArgumentAtIndex:(NSUInteger)index withValue:(NSString*)argument {
    self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index] = argument;
}

- (void)moveArgumentIndex:(NSUInteger)index to:(NSUInteger)newIndex {
    NSString *arg = self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey][index];
    [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] removeObjectAtIndex:index];
    [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] insertObject:arg atIndex:newIndex];
}

- (void)removeArgumentAtIndex:(NSUInteger)index {
    [self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] removeObjectAtIndex:index];
}

- (NSArray *)systemArguments {
    return self.rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey];
}

@end
