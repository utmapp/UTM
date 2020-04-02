//
// Copyright © 2019 osy. All rights reserved.
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

#import <Foundation/Foundation.h>

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

@interface UTMConfiguration : NSObject<NSCopying>

@property (nonatomic, weak, readonly) NSDictionary *dictRepresentation;

+ (NSArray<NSString *>*)supportedOptions:(NSString *)key pretty:(BOOL)pretty;
+ (NSArray<NSString *>*)supportedArchitecturesPretty;
+ (NSArray<NSString *>*)supportedArchitectures;
+ (NSArray<NSString *>*)supportedBootDevicesPretty;
+ (NSArray<NSString *>*)supportedBootDevices;
+ (NSArray<NSString *>*)supportedImageTypesPretty;
+ (NSArray<NSString *>*)supportedImageTypes;
+ (NSArray<NSString *>*)supportedSoundCardDevices;
+ (NSArray<NSString *>*)supportedSoundCardDevicesPretty;
+ (NSArray<NSString *>*)supportedTargetsForArchitecture:(NSString *)architecture;
+ (NSArray<NSString *>*)supportedTargetsForArchitecturePretty:(NSString *)architecture;
+ (NSInteger)defaultTargetIndexForArchitecture:(NSString *)architecture;
+ (NSArray<NSString *>*)supportedResolutions;
+ (NSArray<NSString *>*)supportedDriveInterfaces;
+ (NSString *)diskImagesDirectory;
+ (NSString *)defaultDriveInterface;
+ (NSString *)debugLogName;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, nullable, copy) NSURL *existingPath;

@property (nonatomic, nullable, copy) NSString *systemArchitecture;
@property (nonatomic, nullable, copy) NSNumber *systemMemory;
@property (nonatomic, nullable, copy) NSNumber *systemCPUCount;
@property (nonatomic, nullable, copy) NSString *systemTarget;
@property (nonatomic, nullable, copy) NSString *systemBootDevice;
@property (nonatomic, nullable, copy) NSNumber *systemJitCacheSize;
@property (nonatomic, assign) BOOL systemForceMulticore;

@property (nonatomic, assign) BOOL displayConsoleOnly;
@property (nonatomic, assign) BOOL displayFixedResolution;
@property (nonatomic, nullable, copy) NSNumber *displayFixedResolutionWidth;
@property (nonatomic, nullable, copy) NSNumber *displayFixedResolutionHeight;
@property (nonatomic, assign) BOOL displayZoomScale;
@property (nonatomic, assign) BOOL displayZoomLetterBox;

@property (nonatomic, assign) BOOL inputLegacy;

@property (nonatomic, assign) BOOL networkEnabled;
@property (nonatomic, assign) BOOL networkLocalhostOnly;
@property (nonatomic, nullable, copy) NSString *networkIPSubnet;
@property (nonatomic, nullable, copy) NSString *networkDHCPStart;

@property (nonatomic, assign) BOOL printEnabled;

@property (nonatomic, assign) BOOL soundEnabled;
@property (nonatomic, nullable, copy) NSString *soundCard;

@property (nonatomic, assign) BOOL sharingClipboardEnabled;

@property (nonatomic, assign) BOOL debugLogEnabled;

- (void)migrateConfigurationIfNecessary;
- (id)initDefaults:(NSString *)name;
- (id)initWithDictionary:(NSMutableDictionary *)dictionary name:(NSString *)name path:(NSURL *)path;

- (NSUInteger)countArguments;
- (NSUInteger)newArgument:(NSString *)argument;
- (nullable NSString *)argumentForIndex:(NSUInteger)index;
- (void)moveArgumentIndex:(NSUInteger)index to:(NSUInteger)newIndex;
- (void)updateArgumentAtIndex:(NSUInteger)index withValue:(NSString*)argument;
- (void)removeArgumentAtIndex:(NSUInteger)index;
- (NSArray *)systemArguments;

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
- (NSURL*)terminalInputOutputURL;

@end

NS_ASSUME_NONNULL_END
