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
#if defined(WITH_REMOTE)
#import "UTMRemoteConnectInterface.h"
#else
@import QEMUKitInternal;
#endif
#if !defined(WITH_USB)
@import CocoaSpiceNoUsb;
#else
@import CocoaSpice;
#endif

/// Options for initializing UTMSpiceIO
typedef NS_OPTIONS(NSUInteger, UTMSpiceIOOptions) {
    UTMSpiceIOOptionsNone                 = 0,
    UTMSpiceIOOptionsHasAudio             = (1 << 0),
    UTMSpiceIOOptionsHasClipboardSharing  = (1 << 1),
    UTMSpiceIOOptionsIsShareReadOnly      = (1 << 2),
    UTMSpiceIOOptionsHasDebugLog          = (1 << 3),
};

NS_ASSUME_NONNULL_BEGIN

#if defined(WITH_REMOTE)
@interface UTMSpiceIO : NSObject<CSConnectionDelegate, UTMRemoteConnectInterface>
#else
@interface UTMSpiceIO : NSObject<CSConnectionDelegate, QEMUInterface>
#endif

@property (nonatomic, readonly, nullable) CSDisplay *primaryDisplay;
@property (nonatomic, readonly, nullable) CSInput *primaryInput;
@property (nonatomic, readonly, nullable) CSPort *primarySerial;
@property (nonatomic, readonly) NSArray<CSDisplay *> *displays;
@property (nonatomic, readonly) NSArray<CSPort *> *serials;
#if defined(WITH_USB)
@property (nonatomic, readonly, nullable) CSUSBManager *primaryUsbManager;
#endif
@property (nonatomic, weak, nullable) id<UTMSpiceIODelegate> delegate;
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, nullable) LogHandler_t logHandler;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSocketUrl:(NSURL *)socketUrl options:(UTMSpiceIOOptions)options NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithHost:(NSString *)host tlsPort:(NSInteger)tlsPort serverPublicKey:(NSData *)serverPublicKey password:(NSString *)password options:(UTMSpiceIOOptions)options NS_DESIGNATED_INITIALIZER;
- (void)changeSharedDirectory:(NSURL *)url;

- (BOOL)startWithError:(NSError * _Nullable *)error;
- (BOOL)connectWithError:(NSError * _Nullable *)error;
- (void)disconnect;

- (void)screenshotWithCompletion:(screenshotCallback_t)completion;

@end

NS_ASSUME_NONNULL_END
