//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

@class UTMIOUSBHostDevice;
@class UTMIOUSBHostManager;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(15.0))
@protocol UTMIOUSBHostManagerDelegate <NSObject>

/// Called when a new USB device is attached to the host
/// - Parameters:
///   - ioUsbHostManager: USB manager instance
///   - device: Device that is attached
- (void)ioUsbHostManager:(UTMIOUSBHostManager *)ioUsbHostManager deviceAttached:(UTMIOUSBHostDevice *)device;

/// Called when a USB device is removed from the host
/// - Parameters:
///   - ioUsbHostManager: USB manager instance
///   - device: Device that is removed
- (void)ioUsbHostManager:(UTMIOUSBHostManager *)ioUsbHostManager deviceRemoved:(UTMIOUSBHostDevice *)device;

@end

NS_ASSUME_NONNULL_END
