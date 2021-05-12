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

#import "UTMConfiguration.h"

typedef NS_ENUM(NSInteger, UTMDiskImageType) {
    UTMDiskImageTypeNone,
    UTMDiskImageTypeDisk,
    UTMDiskImageTypeCD,
    UTMDiskImageTypeBIOS,
    UTMDiskImageTypeKernel,
    UTMDiskImageTypeInitrd,
    UTMDiskImageTypeDTB,
    UTMDiskImageTypeMax
};

NS_ASSUME_NONNULL_BEGIN

@interface UTMConfiguration (Drives)

@property (nonatomic, readonly) NSURL *imagesPath;
@property (nonatomic, readonly) NSInteger countDrives;
@property (nonatomic, nullable, readonly) NSArray<NSString *> *orphanedDrives;

- (void)migrateDriveConfigurationIfNecessary;
- (void)recoverOrphanedDrives;

- (NSInteger)newDrive:(NSString *)name path:(NSString *)path type:(UTMDiskImageType)type interface:(NSString *)interface;
- (NSInteger)newRemovableDrive:(NSString *)name type:(UTMDiskImageType)type interface:(NSString *)interface;
- (nullable NSString *)driveNameForIndex:(NSInteger)index;
- (void)setDriveName:(NSString *)name forIndex:(NSInteger)index;
- (nullable NSString *)driveImagePathForIndex:(NSInteger)index;
- (void)setImagePath:(NSString *)path forIndex:(NSInteger)index;
- (nullable NSString *)driveInterfaceTypeForIndex:(NSInteger)index;
- (void)setDriveInterfaceType:(NSString *)interfaceType forIndex:(NSInteger)index;
- (UTMDiskImageType)driveImageTypeForIndex:(NSInteger)index;
- (void)setDriveImageType:(UTMDiskImageType)type forIndex:(NSInteger)index;
- (BOOL)driveRemovableForIndex:(NSInteger)index;
- (void)setDriveRemovable:(BOOL)isRemovable forIndex:(NSInteger)index;
- (void)moveDriveIndex:(NSInteger)index to:(NSInteger)newIndex;
- (void)removeDriveAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
