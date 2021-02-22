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
+ (NSArray<NSString *>*)supportedBootDevicesPretty;
+ (NSArray<NSString *>*)supportedBootDevices;
+ (NSArray<NSString *>*)supportedImageTypesPretty;
+ (NSArray<NSString *>*)supportedImageTypes;
+ (NSArray<NSString *>*)supportedResolutions;
+ (NSArray<NSString *>*)supportedDriveInterfaces;
+ (NSArray<NSString *>*)supportedDriveInterfacesPretty;
+ (NSArray<NSString *>*)supportedScalersPretty;
+ (NSArray<NSString *>*)supportedScalers;
+ (NSArray<NSString *>*)supportedConsoleThemes API_AVAILABLE(ios(11));
+ (NSArray<NSString *>*)supportedConsoleFonts API_AVAILABLE(ios(11));
+ (NSString *)diskImagesDirectory;
+ (NSString *)debugLogName;

@end

@interface UTMConfiguration (ConstantsGenerated)

+ (NSArray<NSString *>*)supportedArchitectures;
+ (NSArray<NSString *>*)supportedArchitecturesPretty;
+ (nullable NSArray<NSString *>*)supportedCpusForArchitecture:(nullable NSString *)architecture;
+ (nullable NSArray<NSString *>*)supportedCpusForArchitecturePretty:(nullable NSString *)architecture;
+ (nullable NSArray<NSString *>*)supportedCpuFlagsForArchitecture:(nullable NSString *)architecture;
+ (nullable NSArray<NSString *>*)supportedTargetsForArchitecture:(nullable NSString *)architecture;
+ (nullable NSArray<NSString *>*)supportedTargetsForArchitecturePretty:(nullable NSString *)architecture;
+ (NSInteger)defaultTargetIndexForArchitecture:(nullable NSString *)architecture;
+ (nullable NSArray<NSString *>*)supportedDisplayCardsForArchitecture:(nullable NSString *)architecture;
+ (nullable NSArray<NSString *>*)supportedDisplayCardsForArchitecturePretty:(nullable NSString *)architecture;
+ (nullable NSArray<NSString *>*)supportedNetworkCardsForArchitecture:(nullable NSString *)architecture;
+ (nullable NSArray<NSString *>*)supportedNetworkCardsForArchitecturePretty:(nullable NSString *)architecture;
+ (nullable NSArray<NSString *>*)supportedSoundCardsForArchitecture:(nullable NSString *)architecture;
+ (nullable NSArray<NSString *>*)supportedSoundCardsForArchitecturePretty:(nullable NSString *)architecture;

@end

NS_ASSUME_NONNULL_END
