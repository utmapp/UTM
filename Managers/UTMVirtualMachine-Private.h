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

@interface UTMVirtualMachine ()

@property (nonatomic, strong) NSURL *parentPath;
@property (nonatomic, readwrite) UTMViewState *viewState;
@property (nonatomic) UTMLogging *logging;
@property (nonatomic, assign, readwrite) UTMVMState state;

- (instancetype)init;
- (nullable instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithConfiguration:(id<UTMConfigurable>)configuration withDestinationURL:(NSURL *)dstUrl;

- (BOOL)loadConfigurationWithReload:(BOOL)reload error:(NSError * _Nullable __autoreleasing *)err;
- (NSDictionary *)loadPlist:(NSURL *)path withError:(NSError **)err;
- (BOOL)savePlist:(NSURL *)path dict:(NSDictionary *)dict withError:(NSError **)err;
- (void)loadViewState;
- (void)saveViewState;

@end

NS_ASSUME_NONNULL_END
