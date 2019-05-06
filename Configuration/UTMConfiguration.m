//
// Copyright © 2019 Halts. All rights reserved.
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

const NSString *const kUTMConfigSystemKey = @"System";
const NSString *const kUTMConfigDisplayKey = @"Display";
const NSString *const kUTMConfigInputKey = @"Input";
const NSString *const kUTMConfigNetworkingKey = @"Networking";
const NSString *const kUTMConfigPrintingKey = @"Printing";
const NSString *const kUTMConfigSoundKey = @"Sound";
const NSString *const kUTMConfigSharingKey = @"Sharing";
const NSString *const kUTMConfigDrivesKey = @"Drives";

const NSString *const kUTMConfigArchitectureKey = @"Architecture";
const NSString *const kUTMConfigMemoryKey = @"Memory";
const NSString *const kUTMConfigCPUCountKey = @"CPUCount";
const NSString *const kUTMConfigTargetKey = @"Target";
const NSString *const kUTMConfigBootDeviceKey = @"BootDevice";
const NSString *const kUTMConfigAddArgsKey = @"AddArgs";

const NSString *const kUTMConfigConsoleOnlyKey = @"ConsoleOnly";
const NSString *const kUTMConfigFixedResolutionKey = @"FixedResolution";
const NSString *const kUTMConfigFixedResolutionWidthKey = @"FixedResolutionWidth";
const NSString *const kUTMConfigFixedResolutionHeightKey = @"FixedResolutionHeight";
const NSString *const kUTMConfigZoomScaleKey = @"ZoomScale";
const NSString *const kUTMConfigZoomLetterboxKey = @"ZoomLetterbox";

const NSString *const kUTMConfigTouchscreenModeKey = @"TouchscreenMode";
const NSString *const kUTMConfigDirectInputKey = @"DirectInput";

const NSString *const kUTMConfigNetworkEnabledKey = @"NetworkEnabled";
const NSString *const kUTMConfigLocalhostOnlyKey = @"LocalhostOnly";
const NSString *const kUTMConfigIPSubnetKey = @"IPSubnet";
const NSString *const kUTMConfigDHCPStartKey = @"DHCPStart";

const NSString *const kUTMConfigPrintEnabledKey = @"PrintEnabled";

const NSString *const kUTMConfigSoundEnabledKey = @"SoundEnabled";

const NSString *const kUTMConfigChipboardSharingKey = @"ClipboardSharing";

const NSString *const kUTMConfigImagePathKey = @"ImagePath";
const NSString *const kUTMConfigInterfaceTypeKey = @"InterfaceType";
const NSString *const kUTMConfigCdromKey = @"Cdrom";

@interface UTMConfiguration ()

@end

@implementation UTMConfiguration {
    NSMutableDictionary *_rootDict;
    NSMutableDictionary *_systemDict;
    NSMutableDictionary *_displayDict;
    NSMutableDictionary *_inputDict;
    NSMutableDictionary *_networkingDict;
    NSMutableDictionary *_printingDict;
    NSMutableDictionary *_soundDict;
    NSMutableDictionary *_sharingDict;
    NSMutableArray<NSMutableDictionary *> *_drivesDicts;
}

#pragma mark - Constant supported values

+ (NSArray<NSString *>*)supportedArchitecturesPretty {
    return @[
             @"Alpha",
             @"ARM (aarch32)",
             @"ARM64 (aarch64)",
             @"CRIS",
             @"HPPA",
             @"i386 (x86)",
             @"LatticeMico32 (lm32)",
             @"m68k",
             @"Microblaze",
             @"Microblaze (Little Endian)",
             @"MIPS",
             @"MIPS (Little Endian)",
             @"MIPS64",
             @"MIPS64 (Little Endian)",
             @"Moxie",
             @"NIOS2",
             @"OpenRISC",
             @"PowerPC",
             @"PowerPC64",
             @"RISC-V32",
             @"RISC-V64",
             @"S390x (zSeries)",
             @"SH4",
             @"SH4 (Big Endian)",
             @"SPARC",
             @"SPARC64",
             @"TriCore",
             @"Unicore32",
             @"x86_64",
             @"Xtensa",
             @"Xtensa (Big Endian)"
             ];
}

+ (NSArray<NSString *>*)supportedArchitectures {
    return @[
             @"alpha",
             @"arm",
             @"aarch64",
             @"cris",
             @"hppa",
             @"i386",
             @"lm32",
             @"m68k",
             @"microblaze",
             @"microblazeel",
             @"mips",
             @"mipsel",
             @"mips64",
             @"mips64el",
             @"moxie",
             @"nios2",
             @"or1k",
             @"ppc",
             @"ppc64",
             @"riscv32",
             @"riscv64",
             @"s390x",
             @"sh4",
             @"sh4eb",
             @"sparc",
             @"sparc64",
             @"tricore",
             @"unicore32",
             @"x86_64",
             @"xtensa",
             @"xtensaeb"
             ];
}

+ (NSArray<NSString *>*)supportedBootDevicesPretty {
    return @[
             NSLocalizedString(@"Hard Disk", "Configuration boot device"),
             NSLocalizedString(@"CD/DVD", "Configuration boot device"),
             NSLocalizedString(@"Floppy", "Configuration boot device")
             ];
}

+ (NSArray<NSString *>*)supportedBootDevices {
    return @[
             @"hdd",
             @"cd",
             @"floppy"
             ];
}

+ (NSArray<NSString *>*)supportedTargetsForArchitecture:(NSString *)architecture {
    return @[];
}

+ (NSArray<NSString *>*)supportedResolutions {
    return @[
             @"320x240",
             @"640x480",
             @"800x600",
             @"1024x600",
             @"1136x640",
             @"1280x720",
             @"1334x750",
             @"1280x800",
             @"1280x1024",
             @"1920x1080",
             @"2436x1125",
             @"2048x1536",
             @"2560x1440",
             @"2732x2048"
             ];
}

+ (NSArray<NSString *>*)supportedDriveInterfaces {
    return @[
             @"ide",
             @"scsi",
             @"sd",
             @"mtd",
             @"floppy",
             @"pflash",
             @"virtio",
             @"none"
             ];
}

+ (NSString *)diskImagesDirectory {
    return @"Images";
}

+ (NSString *)defaultDriveInterface {
    return [self supportedDriveInterfaces][0];
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
        self.systemArchitecture = @"x86_64";
        self.systemMemory = @512;
        self.systemCPUCount = @2;
        self.systemBootDevice = @"CD/DVD";
        self.displayFixedResolutionWidth = @800;
        self.displayFixedResolutionHeight = @600;
        self.displayFixedResolution = NO;
        self.networkEnabled = YES;
        self.printEnabled = YES;
        self.soundEnabled = YES;
        self.sharingClipboardEnabled = YES;
        self.existingPath = nil;
    }
    return self;
}

- (id)initWithDictionary:(NSMutableDictionary *)dictionary name:(NSString *)name path:(NSURL *)path {
    self = [self init];
    if (self) {
        _rootDict = dictionary;
        self.name = name;
        self.existingPath = path;
    }
    return self;
}

#pragma mark - Properties

- (void)setSystemArchitecture:(NSString *)systemArchitecture {
    _rootDict[kUTMConfigSystemKey][kUTMConfigArchitectureKey] = systemArchitecture;
}

- (NSString *)systemArchitecture {
    return _rootDict[kUTMConfigSystemKey][kUTMConfigArchitectureKey];
}

- (void)setSystemMemory:(NSNumber *)systemMemory {
    _rootDict[kUTMConfigSystemKey][kUTMConfigMemoryKey] = systemMemory;
}

- (NSNumber *)systemMemory {
    return _rootDict[kUTMConfigSystemKey][kUTMConfigMemoryKey];
}

- (void)setSystemCPUCount:(NSNumber *)systemCPUCount {
    _rootDict[kUTMConfigSystemKey][kUTMConfigCPUCountKey] = systemCPUCount;
}

- (NSNumber *)systemCPUCount {
    return _rootDict[kUTMConfigSystemKey][kUTMConfigCPUCountKey];
}

- (void)setSystemTarget:(NSString *)systemTarget {
    _rootDict[kUTMConfigSystemKey][kUTMConfigTargetKey] = systemTarget;
}

- (NSString *)systemTarget {
    return _rootDict[kUTMConfigSystemKey][kUTMConfigTargetKey];
}

- (void)setSystemBootDevice:(NSString *)systemBootDevice {
    _rootDict[kUTMConfigSystemKey][kUTMConfigBootDeviceKey] = systemBootDevice;
}

- (NSString *)systemBootDevice {
    return _rootDict[kUTMConfigSystemKey][kUTMConfigBootDeviceKey];
}

- (void)setSystemAddArgs:(NSString *)systemAddArgs {
    _rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey] = systemAddArgs;
}

- (NSString *)systemAddArgs {
    return _rootDict[kUTMConfigSystemKey][kUTMConfigAddArgsKey];
}

- (void)setDisplayConsoleOnly:(BOOL)displayConsoleOnly {
    _rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleOnlyKey] = [NSNumber numberWithBool:displayConsoleOnly];
}

- (BOOL)displayConsoleOnly {
    return [_rootDict[kUTMConfigDisplayKey][kUTMConfigConsoleOnlyKey] boolValue];
}

- (void)setDisplayFixedResolution:(BOOL)displayFixedResolution {
    _rootDict[kUTMConfigDisplayKey][kUTMConfigFixedResolutionKey] = [NSNumber numberWithBool:displayFixedResolution];
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
    _rootDict[kUTMConfigDisplayKey][kUTMConfigZoomScaleKey] = [NSNumber numberWithBool:displayZoomScale];
}

- (BOOL)displayZoomScale {
    return [_rootDict[kUTMConfigDisplayKey][kUTMConfigZoomScaleKey] boolValue];
}

- (void)setDisplayZoomLetterBox:(BOOL)displayZoomLetterBox {
    _rootDict[kUTMConfigDisplayKey][kUTMConfigZoomLetterboxKey] = [NSNumber numberWithBool:displayZoomLetterBox];
}

- (BOOL)displayZoomLetterBox {
    return [_rootDict[kUTMConfigDisplayKey][kUTMConfigZoomLetterboxKey] boolValue];
}

- (void)setInputTouchscreenMode:(BOOL)inputTouchscreenMode {
    _rootDict[kUTMConfigInputKey][kUTMConfigTouchscreenModeKey] = [NSNumber numberWithBool:inputTouchscreenMode];
}

- (BOOL)inputTouchscreenMode {
    return [_rootDict[kUTMConfigInputKey][kUTMConfigTouchscreenModeKey] boolValue];
}

- (void)setInputDirect:(BOOL)inputDirect {
    _rootDict[kUTMConfigInputKey][kUTMConfigDirectInputKey] = [NSNumber numberWithBool:inputDirect];
}

- (BOOL)inputDirect {
    return [_rootDict[kUTMConfigInputKey][kUTMConfigDirectInputKey] boolValue];
}

- (void)setNetworkEnabled:(BOOL)networkEnabled {
    _rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkEnabledKey] = [NSNumber numberWithBool:networkEnabled];
}

- (BOOL)networkEnabled {
    return [_rootDict[kUTMConfigNetworkingKey][kUTMConfigNetworkEnabledKey] boolValue];
}

- (void)setNetworkLocalhostOnly:(BOOL)networkLocalhostOnly {
    _rootDict[kUTMConfigNetworkingKey][kUTMConfigLocalhostOnlyKey] = [NSNumber numberWithBool:networkLocalhostOnly];
}

- (BOOL)networkLocalhostOnly {
    return [_rootDict[kUTMConfigNetworkingKey][kUTMConfigLocalhostOnlyKey] boolValue];
}

- (void)setNetworkIPSubnet:(NSString *)networkIPSubnet {
    _rootDict[kUTMConfigNetworkingKey][kUTMConfigIPSubnetKey] = networkIPSubnet;
}

- (NSString *)networkIPSubnet {
    return _rootDict[kUTMConfigNetworkingKey][kUTMConfigIPSubnetKey];
}

- (void)setNetworkDHCPStart:(NSString *)networkDHCPStart {
    _rootDict[kUTMConfigNetworkingKey][kUTMConfigDHCPStartKey] = networkDHCPStart;
}

- (NSString *)networkDHCPStart {
    return _rootDict[kUTMConfigNetworkingKey][kUTMConfigDHCPStartKey];
}

- (void)setPrintEnabled:(BOOL)printEnabled {
    _rootDict[kUTMConfigPrintingKey][kUTMConfigPrintEnabledKey] = [NSNumber numberWithBool:printEnabled];
}

- (BOOL)printEnabled {
    return [_rootDict[kUTMConfigPrintingKey][kUTMConfigPrintEnabledKey] boolValue];
}

- (void)setSoundEnabled:(BOOL)soundEnabled {
    _rootDict[kUTMConfigSoundKey][kUTMConfigSoundEnabledKey] = [NSNumber numberWithBool:soundEnabled];
}

- (BOOL)soundEnabled {
    return [_rootDict[kUTMConfigSoundKey][kUTMConfigSoundEnabledKey] boolValue];
}

- (void)setSharingClipboardEnabled:(BOOL)sharingClipboardEnabled {
    _rootDict[kUTMConfigSharingKey][kUTMConfigChipboardSharingKey] = [NSNumber numberWithBool:sharingClipboardEnabled];
}

- (BOOL)sharingClipboardEnabled {
    return [_rootDict[kUTMConfigSharingKey][kUTMConfigChipboardSharingKey] boolValue];
}

#pragma mark - Dictionary representation

- (NSDictionary *)dictRepresentation {
    return (NSDictionary *)_rootDict;
}

#pragma mark - Drives array handling

- (NSUInteger)countDrives {
    return [_rootDict[kUTMConfigDrivesKey] count];
}

- (NSUInteger)newDrive:(NSString *)name interface:(NSString *)interface isCdrom:(BOOL)isCdrom {
    NSUInteger index = [self countDrives];
    NSMutableDictionary *drive = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                   kUTMConfigImagePathKey: name,
                                                                                   kUTMConfigInterfaceTypeKey: interface,
                                                                                   kUTMConfigCdromKey: [NSNumber numberWithBool:isCdrom]
                                                                                   }];
    [_rootDict[kUTMConfigDrivesKey] addObject:drive];
    return index;
}

- (nullable NSString *)driveImagePathForIndex:(NSUInteger)index {
    return _rootDict[kUTMConfigDrivesKey][index][kUTMConfigImagePathKey];
}

- (void)setImagePath:(NSString *)path forIndex:(NSUInteger)index {
    _rootDict[kUTMConfigDrivesKey][index][kUTMConfigImagePathKey] = path;
}

- (nullable NSString *)driveInterfaceTypeForIndex:(NSUInteger)index {
    return _rootDict[kUTMConfigDrivesKey][index][kUTMConfigInterfaceTypeKey];
}

- (void)setDriveInterfaceType:(NSString *)interfaceType forIndex:(NSUInteger)index {
    _rootDict[kUTMConfigDrivesKey][index][kUTMConfigInterfaceTypeKey] = interfaceType;
}

- (BOOL)driveIsCdromForIndex:(NSUInteger)index {
    return [_rootDict[kUTMConfigDrivesKey][index][kUTMConfigCdromKey] boolValue];
}

- (void)setDriveIsCdrom:(BOOL)isCdrom forIndex:(NSUInteger)index {
    _rootDict[kUTMConfigDrivesKey][index][kUTMConfigCdromKey] = [NSNumber numberWithBool:isCdrom];
}

- (void)moveDriveIndex:(NSUInteger)index to:(NSUInteger)newIndex {
    NSMutableDictionary *drive = _rootDict[kUTMConfigDrivesKey][index];
    [_rootDict[kUTMConfigDrivesKey] removeObjectAtIndex:index];
    [_rootDict[kUTMConfigDrivesKey] insertObject:drive atIndex:newIndex];
}

- (void)removeDriveAtIndex:(NSUInteger)index {
    [_rootDict[kUTMConfigDrivesKey] removeObjectAtIndex:index];
}

@end
