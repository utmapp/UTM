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
#else
#import <AppKit/AppKit.h>
#endif
#import "UTMLegacyQemuConfiguration+Constants.h"

@implementation UTMLegacyQemuConfiguration (Constants)

+ (NSString *)diskImagesDirectory {
    return @"Images";
}

#pragma mark - Constant supported values


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
             NSLocalizedString(@"None", "UTMLegacyQemuConfiguration"),
             NSLocalizedString(@"Disk Image", "UTMLegacyQemuConfiguration"),
             NSLocalizedString(@"CD/DVD (ISO) Image", "UTMLegacyQemuConfiguration"),
             NSLocalizedString(@"BIOS", "UTMLegacyQemuConfiguration"),
             NSLocalizedString(@"Linux Kernel", "UTMLegacyQemuConfiguration"),
             NSLocalizedString(@"Linux RAM Disk", "UTMLegacyQemuConfiguration"),
             NSLocalizedString(@"Linux Device Tree Binary", "UTMLegacyQemuConfiguration")
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

#if !TARGET_OS_OSX
+ (NSArray<NSString *>*)supportedConsoleFonts {
    static NSMutableArray<NSString *> *families;
    if (!families) {
        families = [NSMutableArray new];
        for (NSString *family in UIFont.familyNames) {
            UIFont *font = [UIFont fontWithName:family size:1];
            if (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitMonoSpace) {
                [families addObjectsFromArray:[UIFont fontNamesForFamilyName:family]];
            }
        }
    }
    return families;
}
#else
+ (NSArray<NSString *>*)supportedConsoleFonts {
    static NSMutableArray<NSString *> *fonts;
    if (!fonts) {
        fonts = [NSMutableArray new];
        for (NSString *fontName in [NSFontManager.sharedFontManager availableFontNamesWithTraits:NSFixedPitchFontMask]) {
            [fonts addObject:fontName];
        }
    }
    return fonts;
}
#endif

#pragma mark - Previously generated constants

+ (NSString *)defaultTargetForArchitecture:(NSString *)architecture {
    return @{
        @"alpha": @"clipper",
        @"arm": @"virt",
        @"aarch64": @"virt",
        @"avr": @"mega",
        @"cris": @"axis-dev88",
        @"hppa": @"hppa",
        @"i386": @"q35",
        @"m68k": @"mcf5208evb",
        @"microblaze": @"petalogix-s3adsp1800",
        @"microblazeel": @"petalogix-s3adsp1800",
        @"mips": @"malta",
        @"mipsel": @"malta",
        @"mips64": @"malta",
        @"mips64el": @"malta",
        @"nios2": @"10m50-ghrd",
        @"or1k": @"or1k-sim",
        @"ppc": @"g3beige",
        @"ppc64": @"pseries",
        @"riscv32": @"spike",
        @"riscv64": @"spike",
        @"rx": @"gdbsim-r5f562n7",
        @"s390x": @"s390-ccw-virtio",
        @"sh4": @"shix",
        @"sh4eb": @"shix",
        @"sparc": @"SS-5",
        @"sparc64": @"sun4u",
        @"tricore": @"tricore_testboard",
        @"x86_64": @"q35",
        @"xtensa": @"sim",
        @"xtensaeb": @"sim",
    }[architecture];
}

@end
