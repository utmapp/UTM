//
// Copyright © 2019 Halts. All rights reserved.
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

NS_ASSUME_NONNULL_BEGIN

@interface UTMConfiguration : NSObject

@property (nonatomic, weak, readonly) NSDictionary *dictRepresentation;

+ (NSArray<NSString *>*)supportedArchitecturesPretty;
+ (NSArray<NSString *>*)supportedArchitectures;
+ (NSArray<NSString *>*)supportedBootDevicesPretty;
+ (NSArray<NSString *>*)supportedBootDevices;
+ (NSArray<NSString *>*)supportedTargetsForArchitecture:(NSString *)architecture;
+ (NSArray<NSString *>*)supportedResolutions;
+ (NSArray<NSString *>*)supportedDriveInterfaces;
+ (NSString *)diskImagesDirectory;
+ (NSString *)defaultDriveInterface;

@property (nonatomic, nullable, copy) NSString *name;
@property (nonatomic, nullable, copy) NSURL *existingPath;

@property (nonatomic, nullable, copy) NSString *systemArchitecture;
@property (nonatomic, nullable, copy) NSNumber *systemMemory;
@property (nonatomic, nullable, copy) NSNumber *systemCPUCount;
@property (nonatomic, nullable, copy) NSString *systemTarget;
@property (nonatomic, nullable, copy) NSString *systemBootDevice;
@property (nonatomic, nullable, copy) NSString *systemAddArgs;

@property (nonatomic, assign) BOOL displayConsoleOnly;
@property (nonatomic, assign) BOOL displayFixedResolution;
@property (nonatomic, nullable, copy) NSNumber *displayFixedResolutionWidth;
@property (nonatomic, nullable, copy) NSNumber *displayFixedResolutionHeight;
@property (nonatomic, assign) BOOL displayZoomScale;
@property (nonatomic, assign) BOOL displayZoomLetterBox;

@property (nonatomic, assign) BOOL inputTouchscreenMode;
@property (nonatomic, assign) BOOL inputDirect;

@property (nonatomic, assign) BOOL networkEnabled;
@property (nonatomic, assign) BOOL networkLocalhostOnly;
@property (nonatomic, nullable, copy) NSString *networkIPSubnet;
@property (nonatomic, nullable, copy) NSString *networkDHCPStart;

@property (nonatomic, assign) BOOL printEnabled;

@property (nonatomic, assign) BOOL soundEnabled;

@property (nonatomic, assign) BOOL sharingClipboardEnabled;

- (id)initDefaults:(NSString *)name;
- (id)initWithDictionary:(NSMutableDictionary *)dictionary name:(NSString *)name path:(NSURL *)path;
- (NSUInteger)countDrives;
- (NSUInteger)newDrive:(NSString *)name interface:(NSString *)interface isCdrom:(BOOL)isCdrom;
- (nullable NSString *)driveImagePathForIndex:(NSUInteger)index;
- (void)setImagePath:(NSString *)path forIndex:(NSUInteger)index;
- (nullable NSString *)driveInterfaceTypeForIndex:(NSUInteger)index;
- (void)setDriveInterfaceType:(NSString *)interfaceType forIndex:(NSUInteger)index;
- (BOOL)driveIsCdromForIndex:(NSUInteger)index;
- (void)setDriveIsCdrom:(BOOL)isCdrom forIndex:(NSUInteger)index;
- (void)moveDriveIndex:(NSUInteger)index to:(NSUInteger)newIndex;
- (void)removeDriveAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
