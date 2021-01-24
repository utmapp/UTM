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

#import "UTMQemu.h"

NS_ASSUME_NONNULL_BEGIN

@interface UTMQemuSystem : UTMQemu

@property (nonatomic) UTMConfiguration *configuration;
@property (nonatomic) NSURL *imgPath;
@property (nonatomic, nullable) NSString *snapshot;
@property (nonatomic) NSInteger qmpPort;
@property (nonatomic) NSInteger spicePort;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfiguration:(UTMConfiguration *)configuration imgPath:(NSURL *)imgPath;
- (void)updateArgvWithUserOptions:(BOOL)userOptions;
- (void)startWithCompletion:(void(^)(BOOL, NSString *))completion;

@end

NS_ASSUME_NONNULL_END
