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

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(15.0))
@interface UTMIOUSBHostDevice : NSObject <NSSecureCoding, NSCopying>

/// A user-readable description of the device
@property (nonatomic, nullable, readonly) NSString *name;

/// USB manufacturer if available
@property (nonatomic, nullable, readonly) NSString *usbManufacturerName;

/// USB product if available
@property (nonatomic, nullable, readonly) NSString *usbProductName;

/// USB device serial if available
@property (nonatomic, nullable, readonly) NSString *usbSerial;

/// USB vendor ID
@property (nonatomic, readonly) NSInteger usbVendorId;

/// USB product ID
@property (nonatomic, readonly) NSInteger usbProductId;

/// USB bus number
@property (nonatomic, readonly) NSInteger usbBusNumber;

/// USB port number
@property (nonatomic, readonly) NSInteger usbPortNumber;

/// USB device signature
@property (nonatomic, nullable, readonly) NSData *usbSignature;

/// Unique identifier for this device (used for restoring)
@property (nonatomic, nullable, readonly) NSUUID *uuid;

/// Is the device currently connected to a guest?
@property (nonatomic, readonly) BOOL isCaptured;

/// IOService corrosponding to this device
@property (nonatomic, readonly) io_service_t ioService;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/// Create a new USB device from an IOService handle
/// - Parameter service: IOService handle
- (instancetype)initWithService:(io_service_t)service NS_SWIFT_UNAVAILABLE("Create from UTMIOUSBHostManager.");

@end

NS_ASSUME_NONNULL_END
