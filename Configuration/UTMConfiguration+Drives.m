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
#import "UTMConfiguration+Drives.h"
#import "UTM-Swift.h"

extern const NSString *const kUTMConfigDrivesKey;

static const NSString *const kUTMConfigDriveNameKey = @"DriveName";
static const NSString *const kUTMConfigImagePathKey = @"ImagePath";
static const NSString *const kUTMConfigImageTypeKey = @"ImageType";
static const NSString *const kUTMConfigInterfaceTypeKey = @"InterfaceType";
static const NSString *const kUTMConfigRemovableKey = @"Removable";
static const NSString *const kUTMConfigCdromKey = @"Cdrom";

@interface UTMConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMConfiguration (Drives)

#pragma mark - Images Path

- (NSURL *)imagesPath {
    if (self.existingPath) {
        return [self.existingPath URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory] isDirectory:YES];
    } else {
        return [[NSFileManager defaultManager].temporaryDirectory URLByAppendingPathComponent:[UTMConfiguration diskImagesDirectory] isDirectory:YES];
    }
}

#pragma mark - Migration

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
    BOOL hasEmpty = NO;
    for (NSInteger i = 0; i < self.countDrives; i++) {
        if ([self driveNameForIndex:i] == nil) {
            hasEmpty = YES;
            break;
        }
    }
    if (hasEmpty) { // reset all names if any are empty
        for (NSInteger i = 0; i < self.countDrives; i++) {
            [self setDriveName:[NSString stringWithFormat:@"drive%ld", i] forIndex:i];
        }
    }
}

#pragma mark - Orphan drives

// ensure user can delete the drive image from the interface if something wrong happens
- (NSArray<NSString *> *)orphanedDrives {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray<NSURL *> *files = [manager contentsOfDirectoryAtURL:self.imagesPath includingPropertiesForKeys:nil options:0 error:nil];
    if (files.count == 0) {
        return nil; // empty or does not exist
    }
    // find existing drives
    NSMutableSet<NSString *> *existing = [NSMutableSet set];
    for (NSInteger i = 0; i < self.countDrives; i++) {
        if (![self driveRemovableForIndex:i]) {
            [existing addObject:[self driveImagePathForIndex:i]];
        }
    }
    // add any missing drives
    NSMutableArray<NSString *> *orphans = [NSMutableArray array];
    for (NSURL *file in files) {
        NSString *name = [file lastPathComponent];
        if (![existing containsObject:name]) {
            [orphans addObject:name];
        }
    }
    return orphans;
}

- (void)recoverOrphanedDrives {
    NSArray<NSString *> *orphans = self.orphanedDrives;
    for (NSInteger i = 0; i < orphans.count; i++) {
        NSString *name = [NSUUID UUID].UUIDString;
        [self newDrive:name path:orphans[i] type:UTMDiskImageTypeNone interface:@""];
    }
}

#pragma mark - Drives array handling

- (NSInteger)countDrives {
    return [self.rootDict[kUTMConfigDrivesKey] count];
}

- (NSInteger)newDrive:(NSString *)name path:(NSString *)path type:(UTMDiskImageType)type interface:(NSString *)interface {
    NSInteger index = [self countDrives];
    NSString *strType = [UTMConfiguration supportedImageTypes][type];
    NSMutableDictionary *drive = [[NSMutableDictionary alloc] initWithDictionary:@{
        kUTMConfigDriveNameKey: name,
        kUTMConfigImagePathKey: path,
        kUTMConfigImageTypeKey: strType,
        kUTMConfigInterfaceTypeKey: interface
    }];
    [self propertyWillChange];
    [self.rootDict[kUTMConfigDrivesKey] addObject:drive];
    return index;
}

- (NSInteger)newRemovableDrive:(NSString *)name type:(UTMDiskImageType)type interface:(NSString *)interface {
    NSInteger index = [self countDrives];
    NSString *strType = [UTMConfiguration supportedImageTypes][type];
    NSMutableDictionary *drive = [[NSMutableDictionary alloc] initWithDictionary:@{
        kUTMConfigDriveNameKey: name,
        kUTMConfigRemovableKey: @(YES),
        kUTMConfigImageTypeKey: strType,
        kUTMConfigInterfaceTypeKey: interface
    }];
    [self propertyWillChange];
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
    [self propertyWillChange];
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
    [self propertyWillChange];
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
    [self propertyWillChange];
    self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigInterfaceTypeKey] = interfaceType;
}

- (UTMDiskImageType)driveImageTypeForIndex:(NSInteger)index {
    if (index >= self.countDrives) {
        return UTMDiskImageTypeDisk;
    }
    NSString *strType = self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigImageTypeKey];
    NSInteger type = [[UTMConfiguration supportedImageTypes] indexOfObject:strType];
    if (type == NSNotFound || type >= UTMDiskImageTypeMax) {
        return UTMDiskImageTypeDisk;
    } else {
        return (UTMDiskImageType)type;
    }
}

- (void)setDriveImageType:(UTMDiskImageType)type forIndex:(NSInteger)index {
    NSString *strType = [UTMConfiguration supportedImageTypes][type];
    [self propertyWillChange];
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
    [self propertyWillChange];
}

- (void)moveDriveIndex:(NSInteger)index to:(NSInteger)newIndex {
    NSMutableDictionary *drive = self.rootDict[kUTMConfigDrivesKey][index];
    [self propertyWillChange];
    [self.rootDict[kUTMConfigDrivesKey] removeObjectAtIndex:index];
    [self.rootDict[kUTMConfigDrivesKey] insertObject:drive atIndex:newIndex];
}

- (void)removeDriveAtIndex:(NSInteger)index {
    [self propertyWillChange];
    [self.rootDict[kUTMConfigDrivesKey] removeObjectAtIndex:index];
}

@end
