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

typedef void * _Nullable (* _Nonnull UTMQemuThreadEntry)(void * _Nullable args);

@class UTMConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface UTMQemu : NSObject

@property (nonatomic) NSArray<NSString *> *argv;
@property (nonatomic) dispatch_semaphore_t done;
@property (nonatomic) NSInteger status;
@property (nonatomic) NSInteger fatal;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (void)pushArgv:(nullable NSString *)arg;
- (void)clearArgv;
- (BOOL)didLoadDylib:(nonnull void *)handle;
- (void)startDylib:(nonnull NSString *)dylib entry:(UTMQemuThreadEntry)entry completion:(void(^)(BOOL,NSString *))completion;

@end

NS_ASSUME_NONNULL_END
