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
#import <Virtualization/Virtualization.h>
#import "UTMIOUSBHostManagerDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface UTMIOUSBHostManager : NSObject

/// Delegate to handle USB connect/disconnect events
@property (nonatomic, weak) id<UTMIOUSBHostManagerDelegate> delegate API_AVAILABLE(macos(15.0));

@property (nonatomic, readonly) NSArray<UTMIOUSBHostDevice *> *connectedDevices API_AVAILABLE(macos(15.0));

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithVirtualMachineQueue:(dispatch_queue_t)virtualMachineQueue NS_DESIGNATED_INITIALIZER API_AVAILABLE(macos(15.0));

/// Enumerate all currently connected USB devices
- (void)usbDevicesWithCompletion:(void (^)(NSArray<UTMIOUSBHostDevice *> *devices, NSError * _Nullable error))completion API_AVAILABLE(macos(15.0));

/// Connect a USB device to a running VZVirtualMachine
/// - Parameters:
///   - usbDevice: USB device to connect
///   - virtualMachine: Virtual machine to connect to
///   - completion: Return error
- (void)connectUsbDevice:(UTMIOUSBHostDevice *)usbDevice toVirtualMachine:(VZVirtualMachine *)virtualMachine withCompletion:(void (^)(NSError * _Nullable error))completion API_AVAILABLE(macos(15.0));

/// Disconnect a USB device from a running VZVirtualMachine
/// - Parameters:
///   - usbDevice: USB device to disconnect
///   - virtualMachine: Virtual machine to disconnect from
///   - completion: Return error
- (void)disconnectUsbDevice:(UTMIOUSBHostDevice *)usbDevice toVirtualMachine:(VZVirtualMachine *)virtualMachine withCompletion:(void (^)(NSError * _Nullable error))completion API_AVAILABLE(macos(15.0));

/// Restore connected devices to a virtual machine before it is started
/// - Parameters:
///   - usbDevice: USB device to restore
///   - virtualMachineConfiguration: Virtual machine configuration to restore to
///   - completion: Return error
- (void)restoreUsbDevice:(UTMIOUSBHostDevice *)usbDevices toVirtualMachineConfiguration:(VZVirtualMachineConfiguration *)virtualMachineConfiguration withCompletion:(void (^)(NSError * _Nullable error))completion API_AVAILABLE(macos(15.0));

/// Called when the virtual machine stops to make sure internal state matches
- (void)synchronize API_AVAILABLE(macos(15.0));

/// Called when the virtual machine starts to make sure internal state matches already captured devices
/// - Parameter virtualMachine: Virtual machine to synchronize with
- (void)synchronizeWithVirtualMachine:(nullable VZVirtualMachine *)virtualMachine API_AVAILABLE(macos(15.0));

@end

NS_ASSUME_NONNULL_END
