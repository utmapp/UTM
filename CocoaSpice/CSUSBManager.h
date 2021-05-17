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

#import <Foundation/Foundation.h>
#import "CSUSBManagerDelegate.h"

typedef struct _SpiceUsbDeviceManager SpiceUsbDeviceManager;
typedef void (^CSUSBManagerConnectionCallback)(BOOL, NSString * _Nullable);

NS_ASSUME_NONNULL_BEGIN

@interface CSUSBManager : NSObject

@property (nonatomic, weak, nullable) id<CSUSBManagerDelegate> delegate;
@property (nonatomic) BOOL isAutoConnect;
@property (nonatomic) NSString *autoConnectFilter;
@property (nonatomic) BOOL isRedirectOnConnect;
@property (nonatomic, readonly) NSInteger numberFreeChannels;
@property (nonatomic, readonly) NSArray<CSUSBDevice *> *usbDevices;
@property (nonatomic, readonly) BOOL isBusy;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUsbDeviceManager:(SpiceUsbDeviceManager *)usbDeviceManager NS_DESIGNATED_INITIALIZER;
- (BOOL)canRedirectUsbDevice:(CSUSBDevice *)usbDevice errorMessage:(NSString * _Nullable * _Nullable)errorMessage;
- (BOOL)isUsbDeviceConnected:(CSUSBDevice *)usbDevice;
- (void)connectUsbDevice:(CSUSBDevice *)usbDevice withCompletion:(CSUSBManagerConnectionCallback)completion;
- (void)disconnectUsbDevice:(CSUSBDevice *)usbDevice withCompletion:(CSUSBManagerConnectionCallback)completion;

@end

NS_ASSUME_NONNULL_END
