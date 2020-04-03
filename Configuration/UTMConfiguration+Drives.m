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

extern const NSString *const kUTMConfigDrivesKey;

static const NSString *const kUTMConfigImagePathKey = @"ImagePath";
static const NSString *const kUTMConfigImageTypeKey = @"ImageType";
static const NSString *const kUTMConfigInterfaceTypeKey = @"InterfaceType";
static const NSString *const kUTMConfigCdromKey = @"Cdrom";

@interface UTMConfiguration ()

@property (nonatomic, readonly) NSMutableDictionary *rootDict;

@end

@implementation UTMConfiguration (Drives)

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
}

#pragma mark - Drives array handling

- (NSUInteger)countDrives {
    return [self.rootDict[kUTMConfigDrivesKey] count];
}

- (NSUInteger)newDrive:(NSString *)name type:(UTMDiskImageType)type interface:(NSString *)interface {
    NSUInteger index = [self countDrives];
    NSString *strType = [UTMConfiguration supportedImageTypes][type];
    NSMutableDictionary *drive = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                   kUTMConfigImagePathKey: name,
                                                                                   kUTMConfigImageTypeKey: strType,
                                                                                   kUTMConfigInterfaceTypeKey: interface
                                                                                   }];
    [self.rootDict[kUTMConfigDrivesKey] addObject:drive];
    return index;
}

- (nullable NSString *)driveImagePathForIndex:(NSUInteger)index {
    return self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigImagePathKey];
}

- (void)setImagePath:(NSString *)path forIndex:(NSUInteger)index {
    self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigImagePathKey] = path;
}

- (nullable NSString *)driveInterfaceTypeForIndex:(NSUInteger)index {
    return self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigInterfaceTypeKey];
}

- (void)setDriveInterfaceType:(NSString *)interfaceType forIndex:(NSUInteger)index {
    self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigInterfaceTypeKey] = interfaceType;
}

- (UTMDiskImageType)driveImageTypeForIndex:(NSUInteger)index {
    NSString *strType = self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigImageTypeKey];
    NSUInteger type = [[UTMConfiguration supportedImageTypes] indexOfObject:strType];
    if (type == NSNotFound || type >= UTMDiskImageTypeMax) {
        return UTMDiskImageTypeDisk;
    } else {
        return (UTMDiskImageType)type;
    }
}

- (void)setDriveImageType:(UTMDiskImageType)type forIndex:(NSUInteger)index {
    NSString *strType = [UTMConfiguration supportedImageTypes][type];
    self.rootDict[kUTMConfigDrivesKey][index][kUTMConfigImageTypeKey] = strType;
}

- (void)moveDriveIndex:(NSUInteger)index to:(NSUInteger)newIndex {
    NSMutableDictionary *drive = self.rootDict[kUTMConfigDrivesKey][index];
    [self.rootDict[kUTMConfigDrivesKey] removeObjectAtIndex:index];
    [self.rootDict[kUTMConfigDrivesKey] insertObject:drive atIndex:newIndex];
}

- (void)removeDriveAtIndex:(NSUInteger)index {
    [self.rootDict[kUTMConfigDrivesKey] removeObjectAtIndex:index];
}

@end
