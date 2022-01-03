//
// Copyright © 2021 osy. All rights reserved.
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

#import "UTMVirtualMachine.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kUTMBundleConfigFilename;

@interface UTMVirtualMachine ()

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *subtitle;

@property (nonatomic, nullable, readonly) NSURL *icon;
@property (nonatomic, nullable, readonly) NSString *notes;

@property (nonatomic, readonly) NSString *systemTarget;
@property (nonatomic, readonly) NSString *systemArchitecture;
@property (nonatomic, readonly) NSString *systemMemory;

@property (nonatomic, readwrite, nullable) NSURL *path;
@property (nonatomic, readwrite, copy) id<UTMConfigurable> config;
@property (nonatomic, readwrite, nullable) UTMScreenshot *screenshot;

+ (BOOL)isAppleVMForPath:(NSURL *)path;
- (NSURL *)packageURLForName:(NSString *)name;
- (void)changeState:(UTMVMState)state;
- (void)errorTriggered:(nullable NSString *)msg;

- (BOOL)loadConfigurationWithReload:(BOOL)reload error:(NSError * _Nullable __autoreleasing *)err;

@end

NS_ASSUME_NONNULL_END
