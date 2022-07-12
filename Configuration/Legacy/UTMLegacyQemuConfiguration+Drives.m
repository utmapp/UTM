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
#import "UTMLegacyQemuConfiguration+Drives.h"

extern const NSString *const kUTMConfigDrivesKey;

static const NSString *const kUTMConfigDriveNameKey = @"DriveName";
static const NSString *const kUTMConfigImagePathKey = @"ImagePath";
static const NSString *const kUTMConfigImageTypeKey = @"ImageType";
static const NSString *const kUTMConfigInterfaceTypeKey = @"InterfaceType";
static const NSString *const kUTMConfigRemovableKey = @"Removable";
static const NSString *const kUTMConfigCdromKey = @"Cdrom";

@interface UTMLegacyQemuConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMLegacyQemuConfiguration (Drives)

#pragma mark - Images Path

- (NSURL *)imagesPath {
    if (self.existingPath) {
        return [self.existingPath URLByAppendingPathComponent:[UTMLegacyQemuConfiguration diskImagesDirectory] isDirectory:YES];
    } else {
        return [[NSFileManager defaultManager].temporaryDirectory URLByAppendingPathComponent:[UTMLegacyQemuConfiguration diskImagesDirectory] isDirectory:YES];
    }
}

#pragma mark - Migration

static BOOL ValidQemuIdentifier(NSString *name) {
    NSCharacterSet *chset = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-._"];
    for (int i = 0; i < name.length; i++) {
        unichar ch = [name characterAtIndex:i];
        if (![chset characterIsMember:ch]) {
            return NO;
        }
        if (i == 0 && !isalpha(ch)) {
            return NO;
        }
    }
    return YES;
}

- (void)migrateDriveConfigurationIfNecessary {
    // Migrate Cdrom => ImageType
    [self.rootDict[kUTMConfigDrivesKey] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!obj[kUTMConfigImageTypeKey]) {
            if ([obj[kUTMConfigCdromKey] boolValue]) {
                [self setDriveImageType:UTMDiskImageTypeCD forIndex:idx];
            } else {
                [self setDriveImageType:UTMDiskImageTypeDisk forIndex:idx];
            }
            [obj removeObjectForKey:kUTMConfigCdromKey];
        }
    }];
    // add drive name
    BOOL hasInvalid = NO;
    for (NSInteger i = 0; i < self.countDrives; i++) {
        NSString *name = [self driveNameForIndex:i];
        if (name == nil || !ValidQemuIdentifier(name)) {
            hasInvalid = YES;
            break;
        }
    }
    if (hasInvalid) { // reset all names if any are empty
        for (NSInteger i = 0; i < self.countDrives; i++) {
            [self setDriveName:[NSString stringWithFormat:@"drive%ld", i] forIndex:i];
        }
    }
}

#pragma mark - Drives array handling

- (NSInteger)countDrives {
    return [self.rootDict[kUTMConfigDrivesKey] count];
}

- (NSInteger)newDrive:(NSString *)name path:(NSString *)path type:(UTMDiskImageType)type interface:(NSString *)interface {
    NSInteger index = [self countDrives];
    NSString *strType = [UTMLegacyQemuConfiguration supportedImageTypes][type];
    NSMutableDictionary *drive = [[NSMutableDictionary alloc] initWithDictionary:@{
        kUTMConfigDriveNameKey: name,
        kUTMConfigImagePathKey: path,
        kUTMConfigImageTypeKey: strType,
        kUTMConfigInterfaceTypeKey: interface
    }];
    [self.rootDict[kUTMConfigDrivesKey] addObject:drive];
    return index;
}

- (NSInteger)newRemovableDrive:(NSString *)name type:(UTMDiskImageType)type interface:(NSString *)interface {
    NSInteger index = [self countDrives];
    NSString *strType = [UTMLegacyQemuConfiguration supportedImageTypes][type];
    NSMutableDictionary *drive = [[NSMutableDictionary alloc] initWithDictionary:@{
        kUTMConfigDriveNameKey: name,
        kUTMConfigRemovableKey: @(YES),
        kUTMConfigImageTypeKey: strType,
        kUTMConfigInterfaceTypeKey: interface
    }];
    [self.rootDict[kUTMConfigDrivesKey] addObject:drive];
    return index;
}

- (nullable NSString *)driveNameForIndex:(NSInteger)index {
    if (index >= self.countDrives) {
        return nil;
    } else {
        return self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigDriveNameKey];
    }
}

- (void)setDriveName:(NSString *)name forIndex:(NSInteger)index {
    self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigDriveNameKey] = name;
}

- (nullable NSString *)driveImagePathForIndex:(NSInteger)index {
    if (index >= self.countDrives) {
        return nil;
    } else {
        return self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigImagePathKey];
    }
}

- (void)setImagePath:(NSString *)path forIndex:(NSInteger)index {
    self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigImagePathKey] = path;
}

- (nullable NSString *)driveInterfaceTypeForIndex:(NSInteger)index {
    if (index >= self.countDrives) {
        return nil;
    } else {
        return self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigInterfaceTypeKey];
    }
}

- (void)setDriveInterfaceType:(NSString *)interfaceType forIndex:(NSInteger)index {
    self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigInterfaceTypeKey] = interfaceType;
}

- (UTMDiskImageType)driveImageTypeForIndex:(NSInteger)index {
    if (index >= self.countDrives) {
        return UTMDiskImageTypeDisk;
    }
    NSString *strType = self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigImageTypeKey];
    NSInteger type = [[UTMLegacyQemuConfiguration supportedImageTypes] indexOfObject:strType];
    if (type == NSNotFound || type >= UTMDiskImageTypeMax) {
        return UTMDiskImageTypeDisk;
    } else {
        return (UTMDiskImageType)type;
    }
}

- (void)setDriveImageType:(UTMDiskImageType)type forIndex:(NSInteger)index {
    NSString *strType = [UTMLegacyQemuConfiguration supportedImageTypes][type];
    self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigImageTypeKey] = strType;
}

- (BOOL)driveRemovableForIndex:(NSInteger)index {
    if (index >= self.countDrives) {
        return NO;
    } else {
        return [self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigRemovableKey] boolValue];
    }
}

- (void)setDriveRemovable:(BOOL)isRemovable forIndex:(NSInteger)index {
    self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigRemovableKey] = @(isRemovable);
    if (isRemovable) {
        [self.rootDict[kUTMConfigDrivesKey][index] removeObjectForKey:kUTMConfigImagePathKey];
    }
}

- (void)moveDriveIndex:(NSInteger)index to:(NSInteger)newIndex {
    NSMutableDictionary *drive = self.rootDict[kUTMConfigDrivesKey][index];
    [self.rootDict[kUTMConfigDrivesKey] removeObjectAtIndex:index];
    [self.rootDict[kUTMConfigDrivesKey] insertObject:drive atIndex:newIndex];
}

- (void)removeDriveAtIndex:(NSInteger)index {
    [self.rootDict[kUTMConfigDrivesKey] removeObjectAtIndex:index];
}

@end
