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

#import "UTMQemuConfiguration.h"
#import "UTMQemuConfiguration+Drives.h"

NS_ASSUME_NONNULL_BEGIN

@interface UTMQemuConfiguration (Defaults)

- (void)loadDefaults;
- (void)loadDefaultsForTarget:(nullable NSString *)target architecture:(nullable NSString *)architecture;
+ (NSString *)defaultDriveInterfaceForTarget:(nullable NSString *)target architecture:(nullable NSString *)architecture type:(UTMDiskImageType)type;
+ (NSString *)defaultCPUForTarget:(NSString *)target architecture:(NSString *)architecture;

@end

NS_ASSUME_NONNULL_END
