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

@class CSUSBDevice;
@class CSUSBManager;

NS_ASSUME_NONNULL_BEGIN

@protocol CSUSBManagerDelegate <NSObject>

- (void)spiceUsbManager:(CSUSBManager *)usbManager deviceError:(NSString *)error forDevice:(CSUSBDevice *)device;
- (void)spiceUsbManager:(CSUSBManager *)usbManager deviceAttached:(CSUSBDevice *)device;
- (void)spiceUsbManager:(CSUSBManager *)usbManager deviceRemoved:(CSUSBDevice *)device;

@end

NS_ASSUME_NONNULL_END
