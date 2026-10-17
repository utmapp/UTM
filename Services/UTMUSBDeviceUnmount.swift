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

#if os(macOS)
import Foundation
import IOKit
import DiskArbitration
import CocoaSpice

/// Unmounts the host volumes of a USB device before it is redirected to a guest.
///
/// While any volume of a mass storage device is mounted, macOS keeps the device busy and
/// redirecting it would terminate the storage driver without flushing the volumes. Unmounting
/// first detaches the volumes cleanly so the device can be captured by the guest without
/// losing data. Devices without mounted volumes are left untouched.
enum UTMUSBDeviceUnmount {
    /// How long to wait for a volume to unmount before giving up
    private static let unmountTimeout: UInt64 = 10 * NSEC_PER_SEC

    /// Unmount every mounted volume of a host USB device
    ///
    /// Does nothing when the device has no mounted volumes or cannot be found in the IORegistry.
    /// - Parameter device: USB device about to be redirected to a guest
    /// - Throws: `UTMUSBDeviceUnmountError` when a volume cannot be unmounted
    static func unmountVolumes(for device: CSUSBDevice) async throws {
        guard let service = matchingService(for: device) else {
            logger.debug("USB device \(device) not found in the IORegistry, not unmounting")
            return
        }
        defer {
            IOObjectRelease(service)
        }
        for bsdName in bsdNames(ofMediaUnder: service) {
            try await unmount(bsdName: bsdName)
        }
    }

    /// Add a hint to the errors macOS reports when it will not release a device
    static func redirectError(_ error: any Error) -> any Error {
        let description = error.localizedDescription
        let inUseErrors = ["LIBUSB_ERROR_ACCESS", "LIBUSB_ERROR_BUSY", "in use by another application"]
        guard inUseErrors.contains(where: { description.contains($0) }) else {
            return error
        }
        return UTMUSBDeviceUnmountError.cannotClaim(description)
    }

    // MARK: - IORegistry

    /// Find the IORegistry entry of a USB device
    ///
    /// The device is matched by vendor and product ID, then narrowed down with the serial
    /// number and the bus number when they are available. An ambiguous match is treated as
    /// no match so the wrong device is never unmounted.
    private static func matchingService(for device: CSUSBDevice) -> io_service_t? {
        var candidates: [io_service_t] = []
        let matching = IOServiceMatching("IOUSBDevice") ?? IOServiceMatching("IOUSBHostDevice")
        var iterator: io_iterator_t = 0
        guard let matching = matching,
              IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer {
            IOObjectRelease(iterator)
        }
        while true {
            let service = IOIteratorNext(iterator)
            guard service != IO_OBJECT_NULL else {
                break
            }
            if (property(of: service, named: "idVendor") as? NSNumber)?.intValue == device.usbVendorId,
               (property(of: service, named: "idProduct") as? NSNumber)?.intValue == device.usbProductId {
                candidates.append(service)
            } else {
                IOObjectRelease(service)
            }
        }
        if let serial = device.usbSerial, !serial.isEmpty {
            candidates.removeAll { (property(of: $0, named: "USB Serial Number") as? String) != serial }
        }
        if candidates.count > 1 {
            let bus = device.usbBusNumber
            candidates.removeAll { ((property(of: $0, named: "locationID") as? NSNumber)?.intValue ?? 0) >> 24 != bus }
        }
        guard candidates.count == 1 else {
            candidates.forEach { IOObjectRelease($0) }
            return nil
        }
        return candidates[0]
    }

    /// Collect the BSD names of all media below an IORegistry entry
    private static func bsdNames(ofMediaUnder service: io_service_t) -> [String] {
        var bsdNames: [String] = []
        // The loop below releases every entry it pops, so hold a reference on the root
        IOObjectRetain(service)
        var queue: [(entry: io_service_t, depth: Int)] = [(service, 0)]
        while let (entry, depth) = queue.popLast() {
            defer {
                IOObjectRelease(entry)
            }
            if depth > 0,
               IOObjectConformsTo(entry, "IOMedia") != 0,
               let bsdName = property(of: entry, named: "BSD Name") as? String {
                bsdNames.append(bsdName)
            }
            guard depth < 16 else {
                continue
            }
            var iterator: io_iterator_t = 0
            guard IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator) == KERN_SUCCESS else {
                continue
            }
            while true {
                let child = IOIteratorNext(iterator)
                guard child != IO_OBJECT_NULL else {
                    break
                }
                queue.append((child, depth + 1))
            }
            IOObjectRelease(iterator)
        }
        return bsdNames
    }

    private static func property(of service: io_service_t, named name: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, name as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    // MARK: - DiskArbitration

    /// Unmount a volume, treating an already unmounted volume as success
    private static func unmount(bsdName: String) async throws {
        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName) else {
            return
        }
        guard let description = DADiskCopyDescription(disk) else {
            return
        }
        guard (description as NSDictionary)[kDADiskDescriptionVolumePathKey] != nil else {
            return // the disk is not a mounted volume
        }
        let queue = DispatchQueue(label: "com.utmapp.UTM.USBUnmount")
        DASessionSetDispatchQueue(session, queue)
        let continuation = UnmountContinuation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (checkedContinuation: CheckedContinuation<Void, any Error>) in
                continuation.set(checkedContinuation)
                let context = UnmountContext(continuation: continuation, bsdName: bsdName)
                DADiskUnmount(disk, DADiskUnmountOptions(kDADiskUnmountOptionDefault), { _, dissenter, pointer in
                    guard let pointer = pointer else {
                        return
                    }
                    let context = Unmanaged<UnmountContext>.fromOpaque(pointer).takeRetainedValue()
                    if let dissenter = dissenter, DADissenterGetStatus(dissenter) != kDAReturnNotMounted {
                        let message = DADissenterGetStatusString(dissenter) as String?
                        context.continuation.resume(throwing: UTMUSBDeviceUnmountError.volumeInUse(context.bsdName, message))
                    } else {
                        context.continuation.resume()
                    }
                }, Unmanaged.passRetained(context).toOpaque())
                Task {
                    try? await Task.sleep(nanoseconds: unmountTimeout)
                    continuation.resume(throwing: UTMUSBDeviceUnmountError.timeout(bsdName))
                }
            }
        } onCancel: {
            continuation.resume(throwing: CancellationError())
        }
    }
}

// MARK: - Errors

enum UTMUSBDeviceUnmountError: LocalizedError {
    /// The volume is still in use by the host
    case volumeInUse(String, String?)
    /// The volume did not unmount in time
    case timeout(String)
    /// The device could not be claimed even after unmounting
    case cannotClaim(String)

    var errorDescription: String? {
        switch self {
        case .volumeInUse(let bsdName, let message):
            let format = NSLocalizedString("The volume '%@' is in use by macOS and could not be ejected. Eject it in the Finder and try again.", comment: "UTMUSBDeviceUnmount")
            return String.localizedStringWithFormat(format, bsdName) + (message.map { " (\($0))" } ?? "")
        case .timeout(let bsdName):
            let format = NSLocalizedString("The volume '%@' did not finish ejecting from macOS.", comment: "UTMUSBDeviceUnmount")
            return String.localizedStringWithFormat(format, bsdName)
        case .cannotClaim(let message):
            let format = NSLocalizedString("The device is still in use by macOS and cannot be connected to the virtual machine. Eject any of its volumes in the Finder, allow USB access when macOS asks, and try again.\n\n%@", comment: "UTMUSBDeviceUnmount")
            return String.localizedStringWithFormat(format, message)
        }
    }
}

/// Resumes a continuation exactly once from a DiskArbitration callback or a timeout
private final class UnmountContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, any Error>?

    func set(_ continuation: CheckedContinuation<Void, any Error>) {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let error = pendingError {
            pendingError = nil
            continuation.resume(throwing: error)
        } else {
            self.continuation = continuation
        }
    }

    func resume() {
        resume(with: .success(()))
    }

    func resume(throwing error: any Error) {
        resume(with: .failure(error))
    }

    private func resume(with result: Result<Void, any Error>) {
        lock.lock()
        defer {
            lock.unlock()
        }
        guard let continuation = continuation else {
            if case .failure(let error) = result {
                pendingError = error
            }
            return
        }
        self.continuation = nil
        continuation.resume(with: result)
    }

    /// Error that arrived before the continuation was set, such as a cancellation
    private var pendingError: (any Error)?
}

/// State passed to a DiskArbitration callback
///
/// The callback cannot capture context, so everything it needs is passed through the
/// callback's context pointer instead.
private final class UnmountContext: @unchecked Sendable {
    let continuation: UnmountContinuation
    let bsdName: String

    init(continuation: UnmountContinuation, bsdName: String) {
        self.continuation = continuation
        self.bsdName = bsdName
    }
}

// MARK: - CSUSBManager

extension CSUSBManager {
    /// Eject the host volumes of a USB device and then redirect it to the guest
    ///
    /// Unmounting the volumes first lets the guest capture a mass storage device without
    /// the host terminating its storage driver while the volumes are still in use.
    /// - Parameter device: USB device to redirect
    func prepareAndConnectUsbDevice(_ device: CSUSBDevice) async throws {
        try await UTMUSBDeviceUnmount.unmountVolumes(for: device)
        do {
            try await connectUsbDevice(device)
        } catch {
            throw UTMUSBDeviceUnmount.redirectError(error)
        }
    }
}
#endif