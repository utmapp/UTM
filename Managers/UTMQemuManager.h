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
#import "UTMJSONStreamDelegate.h"
#import "UTMQemuManagerDelegate.h"

@class UTMJSONStream;

NS_ASSUME_NONNULL_BEGIN

@interface UTMQemuManager : NSObject<UTMJSONStreamDelegate>

@property (nonatomic, readonly) UTMJSONStream *jsonStream;
@property (nonatomic, weak) id<UTMQemuManagerDelegate> delegate;
@property (nonatomic, assign) int retries;

- (void)connect;
- (void)disconnect;

- (void)vmPowerDownWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;
- (void)vmResetWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;
- (void)vmStopWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;
- (void)vmResumeWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;
- (void)vmQuitWithCompletion:(void (^ _Nullable)(NSError * _Nullable))completion;
- (void)vmSaveWithCompletion:(void (^ _Nullable)(NSString * _Nullable, NSError * _Nullable))completion snapshotName:(NSString *)name;
- (void)vmDeleteSaveWithCompletion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion snapshotName:(NSString *)name;

- (void)mouseIndexForAbsolute:(BOOL)absolute withCompletion:(void (^)(int64_t, NSError * _Nullable))completion;
- (void)mouseSelect:(int64_t)index withCompletion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion;

@end

NS_ASSUME_NONNULL_END
