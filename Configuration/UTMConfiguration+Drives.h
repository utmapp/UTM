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

typedef NS_ENUM(NSUInteger, UTMDiskImageType) {
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

- (void)migrateDriveConfigurationIfNecessary;

- (NSUInteger)countDrives;
- (NSUInteger)newDrive:(NSString *)name type:(UTMDiskImageType)type interface:(NSString *)interface;
- (nullable NSString *)driveImagePathForIndex:(NSUInteger)index;
- (void)setImagePath:(NSString *)path forIndex:(NSUInteger)index;
- (nullable NSString *)driveInterfaceTypeForIndex:(NSUInteger)index;
- (void)setDriveInterfaceType:(NSString *)interfaceType forIndex:(NSUInteger)index;
- (UTMDiskImageType)driveImageTypeForIndex:(NSUInteger)index;
- (void)setDriveImageType:(UTMDiskImageType)type forIndex:(NSUInteger)index;
- (void)moveDriveIndex:(NSUInteger)index to:(NSUInteger)newIndex;
- (void)removeDriveAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
