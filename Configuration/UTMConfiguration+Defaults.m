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

- (void)loadDefaultsForTarget:(NSString *)target {
    if ([target hasPrefix:@"pc"] || [target hasPrefix:@"q35"]) {
        self.soundCard = @"ac97";
        self.networkCard = @"rtl8139";
        self.shareClipboardEnabled = YES;
    } else if ([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        self.soundCard = @"hda";
        self.networkCard = @"virtio-net-pci";
        self.shareClipboardEnabled = YES;
    } else if ([target isEqualToString:@"mac99"]) {
        self.soundEnabled = NO;
    } else if ([target isEqualToString:@"isapc"]) {
        self.inputLegacy = YES; // no USB support
    }
    NSString *machineProp = [UTMConfiguration defaultMachinePropertiesForTarget:target];
    if (machineProp) {
        self.systemMachineProperties = machineProp;
    }
}

+ (nullable NSString *)defaultMachinePropertiesForTarget:(NSString *)target {
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

@end
