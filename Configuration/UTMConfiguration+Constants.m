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

#import <TargetConditionals.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#endif
#import "UTMConfiguration+Constants.h"

@implementation UTMConfiguration (Constants)

#pragma mark - Constant supported values

+ (NSArray<NSString *>*)supportedOptions:(NSString *)key pretty:(BOOL)pretty {
    if ([key isEqualToString:@"networkCards"]) {
        if (pretty) {
            return [self supportedNetworkCardsForArchitecturePretty:@"x86_64"];
        } else {
            return [self supportedNetworkCardsForArchitecture:@"x86_64"];
        }
    } else if ([key isEqualToString:@"soundCards"]) {
        if (pretty) {
            return [self supportedSoundCardsForArchitecture:@"x86_64"];
        } else {
            return [self supportedSoundCardsForArchitecture:@"x86_64"];
        }
    } else if ([key isEqualToString:@"architectures"]) {
        if (pretty) {
            return [self supportedArchitecturesPretty];
        } else {
            return [self supportedArchitectures];
        }
    } else if ([key isEqualToString:@"bootDevices"]) {
        if (pretty) {
            return [self supportedBootDevicesPretty];
        } else {
            return [self supportedBootDevices];
        }
    } else if ([key isEqualToString:@"imageTypes"]) {
        if (pretty) {
            return [self supportedImageTypesPretty];
        } else {
            return [self supportedImageTypes];
        }
    } else if ([key isEqualToString:@"driveInterfaces"]) {
        return [self supportedDriveInterfaces];
    } else if ([key isEqualToString:@"scalers"]) {
        if (pretty) {
            return [self supportedScalersPretty];
        } else {
            return [self supportedScalers];
        }
    } else if ([key isEqualToString:@"consoleThemes"]) {
        return [self supportedConsoleThemes];
    } else if ([key isEqualToString:@"consoleFonts"]) {
        return [self supportedConsoleFonts];
    } else if ([key isEqualToString:@"displayCard"]) {
        if (pretty) {
            return [self supportedDisplayCardsForArchitecturePretty:@"x86_64"];
        } else {
            return [self supportedDisplayCardsForArchitecture:@"x86_64"];
        }
    }
    return @[];
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

+ (NSArray<NSString *>*)supportedImageTypesPretty {
    return @[
             NSLocalizedString(@"None", "UTMConfiguration"),
             NSLocalizedString(@"Disk Image", "UTMConfiguration"),
             NSLocalizedString(@"CD/DVD (ISO) Image", "UTMConfiguration"),
             NSLocalizedString(@"BIOS", "UTMConfiguration"),
             NSLocalizedString(@"Linux Kernel", "UTMConfiguration"),
             NSLocalizedString(@"Linux RAM Disk", "UTMConfiguration"),
             NSLocalizedString(@"Linux Device Tree Binary", "UTMConfiguration")
             ];
}

+ (NSArray<NSString *>*)supportedImageTypes {
    return @[
             @"none",
             @"disk",
             @"cd",
             @"bios",
             @"kernel",
             @"initrd",
             @"dtb"
             ];
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
             @"nvme",
             @"usb",
             @"none"
             ];
}

+ (NSArray<NSString *>*)supportedDriveInterfacesPretty {
    return @[
             @"IDE",
             @"SCSI",
             @"SD Card",
             @"MTD (NAND/NOR)",
             @"Floppy",
             @"PC System Flash",
             @"VirtIO",
             @"NVMe",
             @"USB",
             @"None (Advanced)"
             ];
}

+ (NSArray<NSString *>*)supportedScalersPretty {
    return @[
        NSLocalizedString(@"Linear", "UTMConfiguration"),
        NSLocalizedString(@"Nearest Neighbor", "UTMConfiguration"),
    ];
}

+ (NSArray<NSString *>*)supportedScalers {
    return @[
        @"linear",
        @"nearest",
    ];
}

+ (NSArray<NSString *>*)supportedConsoleThemes {
    return @[
        @"Default"
    ];
}

#if !TARGET_OS_OSX
+ (NSArray<NSString *>*)supportedConsoleFonts {
    static NSMutableArray<NSString *> *families;
    if (!families) {
        families = [NSMutableArray new];
        for (NSString *family in UIFont.familyNames) {
            UIFont *font = [UIFont fontWithName:family size:1];
            if (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitMonoSpace) {
                [families addObject:family];
            }
        }
    }
    return families;
}
#else
+ (NSArray<NSString *>*)supportedConsoleFonts {
    return @[];
}
#endif

+ (NSArray<NSString *> *)supportedNetworkModes {
    return @[
        @"none",
        @"emulated",
        @"shared",
        @"bridged",
    ];
}

+ (NSArray<NSString *> *)supportedNetworkModesPretty {
    return @[
        NSLocalizedString(@"None", "UTMConfiguration"),
        NSLocalizedString(@"Emulated VLAN", "UTMConfiguration"),
        NSLocalizedString(@"Shared Network", "UTMConfiguration"),
        NSLocalizedString(@"Bridged (Advanced)", "UTMConfiguration"),
    ];
}

+ (NSString *)diskImagesDirectory {
    return @"Images";
}

+ (NSString *)debugLogName {
    return @"debug.log";
}

@end
