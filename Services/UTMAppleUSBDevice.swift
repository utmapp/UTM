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

import Foundation
import IOKit
import AccessoryAccess

/// A host USB device that can be passed through to an Apple Virtualization guest.
///
/// `AAUSBAccessory` only exposes the raw descriptors, so the user visible properties are
/// read from the IORegistry entry of the device when it is discovered.
@available(macOS 27, *)
final class UTMAppleUSBDevice: Hashable {
    /// The accessory to capture with Virtualization
    let accessory: AAUSBAccessory

    /// IORegistry ID which uniquely identifies the device while it is plugged in
    let registryID: UInt64

    /// USB vendor ID
    let usbVendorId: Int

    /// USB product ID
    let usbProductId: Int

    /// USB manufacturer if available
    let usbManufacturerName: String?

    /// USB product if available
    let usbProductName: String?

    /// USB device serial if available
    let usbSerial: String?

    /// USB bus number
    let usbBusNumber: Int

    /// USB port number
    let usbPortNumber: Int

    /// A user-readable description of the device
    var name: String {
        if let usbProductName = usbProductName {
            return "\(usbProductName) (\(usbBusNumber):\(usbPortNumber))"
        } else {
            return String.localizedStringWithFormat(NSLocalizedString("USB Device %04X:%04X", comment: "UTMAppleUSBDevice"), usbVendorId, usbProductId)
        }
    }

    /// Identity used to remember devices across a saved virtual machine state
    var registryDevice: UTMRegistryEntry.USBDevice {
        UTMRegistryEntry.USBDevice(vendorId: usbVendorId, productId: usbProductId, serial: usbSerial)
    }

    init(accessory: AAUSBAccessory) {
        self.accessory = accessory
        registryID = accessory.registryID
        // see IOUSBDeviceDescriptor
        let descriptor = accessory.deviceDescriptorData
        usbVendorId = Int(descriptor.littleEndianUInt16(at: 8))
        usbProductId = Int(descriptor.littleEndianUInt16(at: 10))
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(registryID))
        defer {
            if entry != IO_OBJECT_NULL {
                IOObjectRelease(entry)
            }
        }
        usbManufacturerName = Self.property(of: entry, named: "USB Vendor Name") as? String
        usbProductName = Self.property(of: entry, named: "USB Product Name") as? String
        usbSerial = Self.property(of: entry, named: "USB Serial Number") as? String
        let locationID = (Self.property(of: entry, named: "locationID") as? NSNumber)?.uint32Value ?? 0
        usbBusNumber = Int(locationID >> 24)
        usbPortNumber = Self.portNumber(fromLocationID: locationID)
    }

    /// The port on the parent hub is the last non-zero nibble of the location ID below the bus number
    private static func portNumber(fromLocationID locationID: UInt32) -> Int {
        var port = 0
        var shift: UInt32 = 20
        while shift < 24 {
            let nibble = Int((locationID >> shift) & 0xF)
            if nibble == 0 {
                break
            }
            port = nibble
            if shift == 0 {
                break
            }
            shift -= 4
        }
        return port
    }

    private static func property(of entry: io_registry_entry_t, named name: String) -> Any? {
        guard entry != IO_OBJECT_NULL else {
            return nil
        }
        return IORegistryEntryCreateCFProperty(entry, name as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    /// Does this device match an identity saved in the registry?
    /// - Parameter other: Saved identity
    /// - Returns: true if the vendor ID, product ID, and serial number (when saved) match
    func matches(_ other: UTMRegistryEntry.USBDevice) -> Bool {
        guard usbVendorId == other.vendorId && usbProductId == other.productId else {
            return false
        }
        if let serial = other.serial, !serial.isEmpty {
            return usbSerial == serial
        }
        return true
    }

    static func == (lhs: UTMAppleUSBDevice, rhs: UTMAppleUSBDevice) -> Bool {
        lhs.registryID == rhs.registryID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(registryID)
    }
}

private extension Data {
    func littleEndianUInt16(at offset: Int) -> UInt16 {
        guard count >= offset + 2 else {
            return 0
        }
        return UInt16(self[startIndex + offset]) | (UInt16(self[startIndex + offset + 1]) << 8)
    }
}
