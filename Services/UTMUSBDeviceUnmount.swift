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

import CocoaSpice
import DiskArbitration
import Foundation
import IOKit

extension CSUSBManager {
    /// Connect a host USB device to the guest after macOS has let go of its volumes
    ///
    /// Capturing a drive takes it away from macOS at once. A volume that is still mounted is
    /// lost as if the drive was unplugged, so the volumes are unmounted first and the device
    /// is left alone when macOS refuses because one is in use.
    /// - Parameter device: USB device to connect
    func connectUsbDeviceAfterUnmounting(_ device: CSUSBDevice) async throws {
        // UTM is not allowed to mount a volume again, so find out first if the connect can work
        var reason: NSString?
        guard canRedirectUsbDevice(device, errorMessage: &reason) else {
            throw UTMUSBDeviceUnmountError.cannotConnect(reason as String?)
        }
        try await device.unmountVolumes()
        try await connectUsbDevice(device)
    }
}

private extension CSUSBDevice {
    /// Unmount every volume macOS has mounted from this device
    ///
    /// Does nothing for a device that has no mounted volume.
    func unmountVolumes() async throws {
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            return
        }
        DASessionSetDispatchQueue(session, DispatchQueue.global(qos: .userInitiated))
        defer {
            DASessionSetDispatchQueue(session, nil)
        }
        for bsdName in mediaNames {
            guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName),
                  let description = DADiskCopyDescription(disk) as NSDictionary?,
                  description[kDADiskDescriptionVolumePathKey] != nil else {
                continue
            }
            let volumeName = description[kDADiskDescriptionVolumeNameKey] as? String ?? bsdName
            try await unmount(disk, named: volumeName)
        }
    }

    private func unmount(_ disk: DADisk, named volumeName: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let request = UnmountRequest(continuation: continuation, volumeName: volumeName)
            DADiskUnmount(disk, DADiskUnmountOptions(kDADiskUnmountOptionDefault), { _, dissenter, context in
                let request = Unmanaged<UnmountRequest>.fromOpaque(context!).takeRetainedValue()
                guard let dissenter = dissenter, DADissenterGetStatus(dissenter) != kDAReturnNotMounted else {
                    request.continuation.resume()
                    return
                }
                let status = DADissenterGetStatus(dissenter)
                let reason = DADissenterGetStatusString(dissenter) as String?
                logger.debug("cannot unmount '\(request.volumeName)': \(String(status, radix: 16)) \(reason ?? "")")
                if status == kDAReturnBusy || status == kDAReturnExclusiveAccess {
                    request.continuation.resume(throwing: UTMUSBDeviceUnmountError.volumeInUse(request.volumeName))
                } else {
                    request.continuation.resume(throwing: UTMUSBDeviceUnmountError.unmountFailed(request.volumeName))
                }
            }, Unmanaged.passRetained(request).toOpaque())
        }
    }

    /// BSD names of the disks and partitions macOS has created for this device
    private var mediaNames: [String] {
        guard let service = service else {
            return []
        }
        defer {
            IOObjectRelease(service)
        }
        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(service, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer {
            IOObjectRelease(iterator)
        }
        var names: [String] = []
        while case let entry = IOIteratorNext(iterator), entry != IO_OBJECT_NULL {
            if IOObjectConformsTo(entry, "IOMedia") != 0, let name = Self.property(kIOBSDNameKey, of: entry) as? String {
                names.append(name)
            }
            IOObjectRelease(entry)
        }
        return names
    }

    /// IORegistry entry of this device, which the caller releases
    ///
    /// Devices of the same model are told apart by the bus and port they are on and then by
    /// their serial number. If that still leaves more than one, none is returned.
    private var service: io_service_t? {
        let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        matching["idVendor"] = usbVendorId
        matching["idProduct"] = usbProductId
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer {
            IOObjectRelease(iterator)
        }
        var found: [io_service_t] = []
        while case let entry = IOIteratorNext(iterator), entry != IO_OBJECT_NULL {
            found.append(entry)
        }
        func keep(_ isThisDevice: (io_service_t) -> Bool) {
            guard found.count > 1 else {
                return
            }
            var kept: [io_service_t] = []
            for entry in found {
                if isThisDevice(entry) {
                    kept.append(entry)
                } else {
                    IOObjectRelease(entry)
                }
            }
            found = kept
        }
        keep { entry in
            Self.location(of: entry) >> 24 == UInt32(truncatingIfNeeded: usbBusNumber)
        }
        keep { entry in
            Self.portNumber(fromLocation: Self.location(of: entry)) == usbPortNumber
        }
        if let serial = usbSerial, !serial.isEmpty {
            keep { entry in
                (Self.property("USB Serial Number", of: entry) as? String)?.hasPrefix(serial) ?? false
            }
        }
        guard found.count == 1 else {
            found.forEach { IOObjectRelease($0) }
            return nil
        }
        return found[0]
    }

    private static func location(of entry: io_registry_entry_t) -> UInt32 {
        (property("locationID", of: entry) as? NSNumber)?.uint32Value ?? 0
    }

    /// The location ID has the bus in its top byte and then one port per hub level, 4 bits each
    private static func portNumber(fromLocation location: UInt32) -> Int {
        var ports = location & 0x00ffffff
        while ports != 0 && ports & 0xf == 0 {
            ports >>= 4
        }
        return Int(ports & 0xf)
    }

    private static func property(_ name: String, of entry: io_registry_entry_t) -> Any? {
        IORegistryEntryCreateCFProperty(entry, name as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}

/// What the DiskArbitration callback, which cannot capture anything, needs to answer
private final class UnmountRequest {
    let continuation: CheckedContinuation<Void, any Error>
    let volumeName: String

    init(continuation: CheckedContinuation<Void, any Error>, volumeName: String) {
        self.continuation = continuation
        self.volumeName = volumeName
    }
}

enum UTMUSBDeviceUnmountError: LocalizedError {
    case cannotConnect(String?)
    case volumeInUse(String)
    case unmountFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotConnect(let reason):
            return reason ?? NSLocalizedString("This USB device cannot be connected to the virtual machine.", comment: "UTMUSBDeviceUnmount")
        case .volumeInUse(let volumeName):
            let format = NSLocalizedString("'%@' could not be ejected because it is in use. Close anything that is using it and try again.", comment: "UTMUSBDeviceUnmount")
            return String.localizedStringWithFormat(format, volumeName)
        case .unmountFailed(let volumeName):
            let format = NSLocalizedString("'%@' could not be ejected. Eject it in the Finder and try again.", comment: "UTMUSBDeviceUnmount")
            return String.localizedStringWithFormat(format, volumeName)
        }
    }
}
