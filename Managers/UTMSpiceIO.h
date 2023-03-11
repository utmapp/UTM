//
// Copyright © 2022 osy. All rights reserved.
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
#import "UTMSpiceIODelegate.h"
#if defined(WITH_QEMU_TCI)
@import CocoaSpiceNoUsb;
#else
@import CocoaSpice;
#endif

@class UTMConfigurationWrapper;
@class UTMQemuMonitor;

typedef void (^ioConnectCompletionHandler_t)(UTMQemuMonitor * _Nullable, NSError * _Nullable);

NS_ASSUME_NONNULL_BEGIN

@interface UTMSpiceIO : NSObject<CSConnectionDelegate>

@property (nonatomic, readonly, nonnull) UTMConfigurationWrapper* configuration;
@property (nonatomic, readonly, nullable) CSDisplay *primaryDisplay;
@property (nonatomic, readonly, nullable) CSInput *primaryInput;
@property (nonatomic, readonly, nullable) CSPort *primarySerial;
@property (nonatomic, readonly) NSArray<CSDisplay *> *displays;
@property (nonatomic, readonly) NSArray<CSPort *> *serials;
#if !defined(WITH_QEMU_TCI)
@property (nonatomic, readonly, nullable) CSUSBManager *primaryUsbManager;
#endif
@property (nonatomic, weak, nullable) id<UTMSpiceIODelegate> delegate;
@property (nonatomic, readonly) BOOL isConnected;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfiguration:(UTMConfigurationWrapper *)configuration NS_DESIGNATED_INITIALIZER;
- (void)changeSharedDirectory:(NSURL *)url;

- (BOOL)startWithError:(NSError **)err;
- (void)connectWithCompletion:(ioConnectCompletionHandler_t)block;
- (void)disconnect;

- (void)screenshotWithCompletion:(screenshotCallback_t)completion;

@end

NS_ASSUME_NONNULL_END
