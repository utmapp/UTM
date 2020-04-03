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

NS_ASSUME_NONNULL_BEGIN

@interface UTMConfiguration (Constants)

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

@end

NS_ASSUME_NONNULL_END
