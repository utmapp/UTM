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

@interface UTMNewDrive : NSObject

@property (nonatomic, assign) BOOL valid;
@property (nonatomic, nullable, strong) NSNumber *sizeMB;
@property (nonatomic, assign) BOOL isQcow2;

@end

@interface UTMConfiguration : NSObject

@property (nonatomic, weak, readonly) NSDictionary *dictRepresentation;

+ (NSArray<NSString *>*)supportedArchitecturesPretty;
+ (NSArray<NSString *>*)supportedArchitectures;
+ (NSArray<NSString *>*)supportedBootDevices;
+ (NSArray<NSString *>*)supportedTargetsForArchitecture:(NSString *)architecture;
+ (NSArray<NSString *>*)supportedResolutions;
+ (NSArray<NSString *>*)supportedDriveInterfaces;

@property (nonatomic, nullable, strong) NSString *name;
@property (nonatomic, nullable, strong) NSString *changeName;

@property (nonatomic, nullable, strong) NSString *systemArchitecture;
@property (nonatomic, nullable, strong) NSNumber *systemMemory;
@property (nonatomic, nullable, strong) NSNumber *systemCPUCount;
@property (nonatomic, nullable, strong) NSString *systemTarget;
@property (nonatomic, nullable, strong) NSString *systemBootDevice;
@property (nonatomic, nullable, strong) NSString *systemAddArgs;

@property (nonatomic, assign) BOOL displayConsoleOnly;
@property (nonatomic, assign) BOOL displayFixedResolution;
@property (nonatomic, nullable, strong) NSNumber *displayFixedResolutionWidth;
@property (nonatomic, nullable, strong) NSNumber *displayFixedResolutionHeight;
@property (nonatomic, assign) BOOL displayZoomScale;
@property (nonatomic, assign) BOOL displayZoomLetterBox;

@property (nonatomic, assign) BOOL inputTouchscreenMode;
@property (nonatomic, assign) BOOL inputDirect;

@property (nonatomic, assign) BOOL networkEnabled;
@property (nonatomic, assign) BOOL networkLocalhostOnly;
@property (nonatomic, nullable, strong) NSString *networkIPSubnet;
@property (nonatomic, nullable, strong) NSString *networkDHCPStart;

@property (nonatomic, assign) BOOL printEnabled;

@property (nonatomic, assign) BOOL soundEnabled;

@property (nonatomic, assign) BOOL sharingClipboardEnabled;

- (id)initWithDefaults;
- (NSUInteger)countDrives;
- (NSUInteger)newDefaultDrive;
- (nullable NSString *)driveImagePathForIndex:(NSUInteger)index;
- (void)setImagePath:(NSString *)path forIndex:(NSUInteger)index;
- (nullable NSString *)driveInterfaceTypeForIndex:(NSUInteger)index;
- (void)setDriveInterfaceType:(NSString *)interfaceType forIndex:(NSUInteger)index;
- (BOOL)driveIsCdromForIndex:(NSUInteger)index;
- (void)setDriveIsCdrom:(BOOL)isCdrom forIndex:(NSUInteger)index;
- (void)moveDriveIndex:(NSUInteger)index to:(NSUInteger)newIndex;
- (nullable UTMNewDrive *)driveNewParamsAtIndex:(NSUInteger)index;
- (void)removeDriveAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
