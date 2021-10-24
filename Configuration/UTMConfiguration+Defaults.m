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

#import "UTMConfiguration+Defaults.h"
#import "UTMConfiguration+Display.h"
#import "UTMConfiguration+Miscellaneous.h"
#import "UTMConfiguration+Networking.h"
#import "UTMConfiguration+Sharing.h"
#import "UTMConfiguration+System.h"

@implementation UTMConfiguration (Defaults)

- (void)loadDefaults {
    self.systemArchitecture = @"x86_64";
    self.systemTarget = @"q35";
    [self loadDefaultsForTarget:@"q35" architecture:@"x86_64"];
    self.systemMemory = @512;
    if (@available(iOS 14, *)) {
        // use bootindex on new UI
        self.systemBootDevice = @"";
    } else {
        self.systemBootDevice = @"cd";
    }
    self.systemUUID = [[NSUUID UUID] UUIDString];
    self.displayUpscaler = @"linear";
    self.displayDownscaler = @"linear";
    self.consoleFont = @"Menlo";
    self.consoleFontSize = @12;
    self.consoleTheme = @"Default";
#if TARGET_OS_OSX
    if (@available(macOS 11.3, *)) {
        self.networkMode = @"shared";
    } else {
        self.networkMode = @"emulated";
    }
#else
    self.networkMode = @"emulated";
#endif
    self.networkCardMac = [UTMConfiguration generateMacAddress];
    self.usbRedirectionMaximumDevices = @3;
    self.name = [NSUUID UUID].UUIDString;
    self.existingPath = nil;
    self.selectedCustomIconPath = nil;
}

- (void)loadDefaultsForTarget:(nullable NSString *)target architecture:(nullable NSString *)architecture {
    if ([target hasPrefix:@"pc"] || [target hasPrefix:@"q35"]) {
        self.soundCard = @"AC97";
        self.soundEnabled = YES;
        self.networkCard = @"rtl8139";
        self.shareClipboardEnabled = YES;
        self.displayCard = @"virtio-vga-gl";
        self.systemBootUefi = YES;
    } else if ([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        self.soundCard = @"intel-hda";
        self.soundEnabled = YES;
        self.networkCard = @"virtio-net-pci";
        self.shareClipboardEnabled = YES;
        self.displayCard = @"virtio-ramfb-gl";
        self.usb3Support = NO;
        self.systemBootUefi = YES;
    } else if ([target isEqualToString:@"mac99"]) {
        self.soundCard = @"screamer";
        self.soundEnabled = YES;
    } else if ([target isEqualToString:@"isapc"]) {
        self.inputLegacy = YES; // no USB support
    } else {
        self.systemBootUefi = NO;
    }
    NSString *machineProp = [UTMConfiguration defaultMachinePropertiesForTarget:target];
    if (machineProp) {
        self.systemMachineProperties = machineProp;
    }
    if (target && architecture) {
        self.systemCPU = [UTMConfiguration defaultCPUForTarget:target architecture:architecture];
    }
}

+ (nullable NSString *)defaultMachinePropertiesForTarget:(nullable NSString *)target {
    if ([target hasPrefix:@"pc"] || [target hasPrefix:@"q35"]) {
        return @"vmport=off";
    } else if ([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        return @"highmem=off";
    } else if ([target isEqualToString:@"mac99"]) {
        return @"via=pmu";
    }
    return nil;
}

+ (NSString *)defaultDriveInterfaceForTarget:(NSString *)target type:(UTMDiskImageType)type {
    if ([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        if (type == UTMDiskImageTypeCD) {
            return @"usb";
        } else {
            return @"virtio";
        }
    }
    return @"ide";
}

+ (NSString *)defaultCPUForTarget:(NSString *)target architecture:(NSString *)architecture {
    if ([architecture isEqualToString:@"aarch64"]) {
        return @"cortex-a72";
    } else if ([architecture isEqualToString:@"arm"]) {
        return @"cortex-a15";
    } else if ([target hasPrefix:@"pc"] || [target hasPrefix:@"q35"]) {
        return @"Skylake-Client";
    } else {
        return @"default";
    }
}

@end
