//
// Copyright © 2026 osy. All rights reserved.
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

import AppKit
import Darwin
import Foundation

/// Virtual USB HID Precision Touchpad server communicating with QEMU over `usb-redir`.
///
/// Emulates a standard Microsoft Windows Precision Touchpad (HID Digitizers / Touch Pad)
/// so Windows 11 loads its built-in inbox `HID-compliant touch pad` driver with zero
/// custom guest drivers and zero extra macOS permissions.
final class UTMPrecisionTouchpadServer {
    // MARK: - usbredir protocol constants

    private enum PacketType: UInt32 {
        case hello = 0
        case deviceConnect = 1
        case reset = 3
        case interfaceInfo = 4
        case epInfo = 5
        case setConfiguration = 6
        case getConfiguration = 7
        case configurationStatus = 8
        case setAltSetting = 9
        case getAltSetting = 10
        case altSettingStatus = 11
        case startInterruptReceiving = 15
        case stopInterruptReceiving = 16
        case interruptReceivingStatus = 17
        case controlPacket = 100
        case interruptPacket = 103
    }

    private enum Status: UInt8 {
        case success = 0
        case stall = 4
    }

    private enum EndpointType: UInt8 {
        case control = 0
        case interrupt = 3
        case invalid = 255
    }

    private enum ReportID: UInt8 {
        case touchpad = 0x01
        case maxCount = 0x02
        case ptphqa = 0x03
        case inputMode = 0x04
        case functionSwitch = 0x05
    }

    private static let capBulkStreams: UInt32 = 1 << 0
    private static let capConnectDeviceVersion: UInt32 = 1 << 1
    private static let capEpInfoMaxPacketSize: UInt32 = 1 << 4
    private static let cap64BitIds: UInt32 = 1 << 5

    // MARK: - USB & HID Precision Touchpad Descriptors

    private static let fingerCollection: [UInt8] = [
        0x05, 0x0D,       // Usage Page (Digitizers)
        0x09, 0x22,       // Usage (Finger)
        0xA1, 0x02,       // Collection (Logical)
        0x09, 0x47,       //   Usage (Confidence)
        0x09, 0x42,       //   Usage (Tip Switch)
        0x15, 0x00,       //   Logical Minimum (0)
        0x25, 0x01,       //   Logical Maximum (1)
        0x75, 0x01,       //   Report Size (1)
        0x95, 0x02,       //   Report Count (2)
        0x81, 0x02,       //   Input (Data,Var,Abs)
        0x09, 0x51,       //   Usage (Contact Identifier)
        0x75, 0x04,       //   Report Size (4)
        0x95, 0x01,       //   Report Count (1)
        0x25, 0x0F,       //   Logical Maximum (15)
        0x81, 0x02,       //   Input (Data,Var,Abs)
        0x75, 0x02,       //   Report Size (2) padding
        0x95, 0x01,       //   Report Count (1)
        0x81, 0x03,       //   Input (Const,Var,Abs)
        0x05, 0x01,       //   Usage Page (Generic Desktop)
        0x15, 0x00,       //   Logical Minimum (0)
        0x26, 0xFF, 0x7F, //   Logical Maximum (32767)
        0x75, 0x10,       //   Report Size (16)
        0x55, 0x0E,       //   Unit Exponent (-2)
        0x65, 0x11,       //   Unit (SI Lin: cm)
        0x09, 0x30,       //   Usage (X)
        0x35, 0x00,       //   Physical Minimum (0)
        0x46, 0x14, 0x05, //   Physical Maximum (1300 = 13.00 cm)
        0x95, 0x01,       //   Report Count (1)
        0x81, 0x02,       //   Input (Data,Var,Abs)
        0x09, 0x31,       //   Usage (Y)
        0x46, 0x20, 0x03, //   Physical Maximum (800 = 8.00 cm)
        0x81, 0x02,       //   Input (Data,Var,Abs)
        0xC0              // End Collection
    ]

    private static let hidReportDescriptor: [UInt8] = {
        var desc: [UInt8] = [
            0x05, 0x0D,                   // Usage Page (Digitizers)
            0x09, 0x05,                   // Usage (Touch Pad)
            0xA1, 0x01,                   // Collection (Application)
            0x85, ReportID.touchpad.rawValue
        ]
        for _ in 0..<5 {
            desc.append(contentsOf: fingerCollection)
        }
        desc.append(contentsOf: [
            0x05, 0x0D,                   //   Usage Page (Digitizers)
            0x55, 0x0C,                   //   Unit Exponent (-4)
            0x66, 0x01, 0x10,             //   Unit (Seconds)
            0x47, 0xFF, 0xFF, 0x00, 0x00,
            0x27, 0xFF, 0xFF, 0x00, 0x00,
            0x75, 0x10,
            0x95, 0x01,
            0x09, 0x56,                   //   Usage (Scan Time)
            0x81, 0x02,
            0x09, 0x54,                   //   Usage (Contact Count)
            0x25, 0x7F,
            0x95, 0x01,
            0x75, 0x08,
            0x81, 0x02,
            0x05, 0x09,                   //   Usage Page (Button)
            0x09, 0x01,                   //   Usage (Button 1)
            0x15, 0x00,
            0x25, 0x01,
            0x75, 0x01,
            0x95, 0x01,
            0x81, 0x02,
            0x75, 0x07,
            0x95, 0x01,
            0x81, 0x03,
            0x05, 0x0D,                   //   Usage Page (Digitizers)
            0x85, ReportID.maxCount.rawValue,
            0x09, 0x55,                   //   Usage (Contact Count Maximum)
            0x09, 0x59,                   //   Usage (Pad Type: 0 = Clickpad)
            0x75, 0x04,
            0x95, 0x02,
            0x25, 0x0F,
            0xB1, 0x02,
            0x06, 0x00, 0xFF,             //   Usage Page (Vendor 0xFF00)
            0x85, ReportID.ptphqa.rawValue,
            0x09, 0xC5,                   //   Usage (PTPHQA)
            0x15, 0x00,
            0x26, 0xFF, 0x00,
            0x75, 0x08,
            0x96, 0x00, 0x01,             //   Report Count (256)
            0xB1, 0x02,
            0xC0,

            // Configuration Top-Level Collection
            0x05, 0x0D,
            0x09, 0x0E,                   // Usage (Configuration)
            0xA1, 0x01,
            0x85, ReportID.inputMode.rawValue,
            0x09, 0x22,
            0xA1, 0x02,
            0x09, 0x52,                   //   Usage (Input Mode)
            0x15, 0x00,
            0x25, 0x0A,
            0x75, 0x08,
            0x95, 0x01,
            0xB1, 0x02,
            0xC0,
            0x09, 0x22,
            0xA1, 0x00,
            0x85, ReportID.functionSwitch.rawValue,
            0x09, 0x57,                   //   Usage (Surface Switch)
            0x09, 0x58,                   //   Usage (Button Switch)
            0x75, 0x01,
            0x95, 0x02,
            0x25, 0x01,
            0xB1, 0x02,
            0x75, 0x06,
            0x95, 0x01,
            0xB1, 0x03,
            0xC0,
            0xC0
        ])
        return desc
    }()

    private static let ptphqaBlob: [UInt8] = [
        0xFC, 0x28, 0xFE, 0x84, 0x40, 0xCB, 0x9A, 0x87, 0x0D, 0xBE, 0x57, 0x3C, 0xB6, 0x70, 0x09, 0x88,
        0x07, 0x97, 0x2D, 0x2B, 0xE3, 0x38, 0x34, 0xB6, 0x6C, 0xED, 0xB0, 0xF7, 0xE5, 0x9C, 0xF6, 0xC2,
        0x2E, 0x84, 0x1B, 0xE8, 0xB4, 0x51, 0x78, 0x43, 0x1F, 0x28, 0x4B, 0x7C, 0x2D, 0x53, 0xAF, 0xFC,
        0x47, 0x70, 0x1B, 0x59, 0x6F, 0x74, 0x43, 0xC4, 0xF3, 0x47, 0x18, 0x53, 0x1A, 0xA2, 0xA1, 0x71,
        0xC7, 0x95, 0x0E, 0x31, 0x55, 0x21, 0xD3, 0xB5, 0x1E, 0xE9, 0x0C, 0xBA, 0xEC, 0xB8, 0x89, 0x19,
        0x3E, 0xB3, 0xAF, 0x75, 0x81, 0x9D, 0x53, 0xB9, 0x41, 0x57, 0xF4, 0x6D, 0x39, 0x25, 0x29, 0x7C,
        0x87, 0xD9, 0xB4, 0x98, 0x45, 0x7D, 0xA7, 0x26, 0x9C, 0x65, 0x3B, 0x85, 0x68, 0x89, 0xD7, 0x3B,
        0xBD, 0xFF, 0x14, 0x67, 0xF2, 0x2B, 0xF0, 0x2A, 0x41, 0x54, 0xF0, 0xFD, 0x2C, 0x66, 0x7C, 0xF8,
        0xC0, 0x8F, 0x33, 0x13, 0x03, 0xF1, 0xD3, 0xC1, 0x0B, 0x89, 0xD9, 0x1B, 0x62, 0xCD, 0x51, 0xB7,
        0x80, 0xB8, 0xAF, 0x3A, 0x10, 0xC1, 0x8A, 0x5B, 0xE8, 0x8A, 0x56, 0xF0, 0x8C, 0xAA, 0xFA, 0x35,
        0xE9, 0x42, 0xC4, 0xD8, 0x55, 0xC3, 0x38, 0xCC, 0x2B, 0x53, 0x5C, 0x69, 0x52, 0xD5, 0xC8, 0x73,
        0x02, 0x38, 0x7C, 0x73, 0xB6, 0x41, 0xE7, 0xFF, 0x05, 0xD8, 0x2B, 0x79, 0x9A, 0xE2, 0x34, 0x60,
        0x8F, 0xA3, 0x32, 0x1F, 0x09, 0x78, 0x62, 0xBC, 0x80, 0xE3, 0x0F, 0xBD, 0x65, 0x20, 0x08, 0x13,
        0xC1, 0xE2, 0xEE, 0x53, 0x2D, 0x86, 0x7E, 0xA7, 0x5A, 0xC5, 0xD3, 0x7D, 0x98, 0xBE, 0x31, 0x48,
        0x1F, 0xFB, 0xDA, 0xAF, 0xA2, 0xA8, 0x6A, 0x89, 0xD6, 0xBF, 0xF2, 0xD3, 0x32, 0x2A, 0x9A, 0xE4,
        0xCF, 0x17, 0xB7, 0xB8, 0xF4, 0xE1, 0x33, 0x08, 0x24, 0x8B, 0xC4, 0x43, 0xA5, 0xE5, 0x24, 0xC2
    ]

    private static let deviceDescriptor: [UInt8] = [
        18, 0x01,             // bLength, bDescriptorType (Device)
        0x00, 0x02,           // bcdUSB 2.00
        0x00, 0x00, 0x00,     // Class/SubClass/Protocol (defined at interface)
        64,                   // bMaxPacketSize0
        0x09, 0x12,           // idVendor = 0x1209
        0x54, 0x50,           // idProduct = 0x5054
        0x00, 0x01,           // bcdDevice 1.00
        1, 2, 3,              // iManufacturer, iProduct, iSerialNumber
        1                     // bNumConfigurations
    ]

    private static let configDescriptor: [UInt8] = {
        let rlen = UInt16(hidReportDescriptor.count)
        return [
            // Configuration Descriptor (9)
            9, 0x02, 34, 0, 1, 1, 0, 0xA0, 50,
            // Interface Descriptor (9): HID
            9, 0x04, 0, 0, 1, 0x03, 0x00, 0x00, 0,
            // HID Descriptor (9)
            9, 0x21, 0x11, 0x01, 0x00, 1, 0x22, UInt8(rlen & 0xFF), UInt8(rlen >> 8),
            // Endpoint Descriptor (7): EP 0x81 Interrupt IN, 64B, 1ms interval
            7, 0x05, 0x81, 0x03, 64, 0, 1
        ]
    }()

    // MARK: - State

    private struct TouchSlot {
        var active = false
        var identity: (NSObjectProtocol & NSCopying)?
        var sx: Double = 0
        var sy: Double = 0
    }

    private let serverQueue = DispatchQueue(label: "com.utmapp.UTM.PrecisionTouchpad", qos: .userInteractive)
    private let stateLock = NSLock()

    private var listenFD: Int32 = -1
    private var clientFD: Int32 = -1
    private var isStopped = false
    private var use64BitIds = false
    private var helloCompleted = false
    private var guestBooted = false
    private var deviceAttached = false
    private var interruptActive = false
    private var inputMode: UInt8 = 0x03
    private var surfaceSwitch: UInt8 = 0x03

    // Main-thread touch tracking state
    private var slots: [TouchSlot] = Array(repeating: TouchSlot(), count: 5)
    private var inGesture = false
    private var lastScanTime: UInt16 = 0
    private var lastContactSignature: [UInt64] = []

    private(set) var port: UInt16 = 0

    /// Returns `true` when QEMU is connected and the guest OS has activated Precision Touchpad reporting.
    var isActive: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return clientFD >= 0 && interruptActive && (surfaceSwitch & 0x01) != 0
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Starts listening on an ephemeral loopback TCP port (`127.0.0.1:0`) and returns the assigned port.
    func start() throws -> UInt16 {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr = in_addr(s_addr: UInt32(INADDR_LOOPBACK).bigEndian)

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            let err = errno
            Darwin.close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: err) ?? .EADDRINUSE)
        }

        var boundAddr = sockaddr_in()
        var boundLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.getsockname(fd, sa, &boundLen)
            }
        }
        guard nameResult == 0 else {
            let err = errno
            Darwin.close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: err) ?? .EIO)
        }

        guard Darwin.listen(fd, 4) == 0 else {
            let err = errno
            Darwin.close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: err) ?? .EIO)
        }

        let assignedPort = UInt16(bigEndian: boundAddr.sin_port)
        stateLock.lock()
        self.listenFD = fd
        self.port = assignedPort
        self.isStopped = false
        stateLock.unlock()

        logger.debug("Precision Touchpad server listening on 127.0.0.1:\(assignedPort)")

        serverQueue.async { [weak self] in
            self?.acceptLoop(listenFD: fd)
        }
        return assignedPort
    }

    func stop() {
        stateLock.lock()
        isStopped = true
        interruptActive = false
        let lfd = listenFD
        listenFD = -1
        let cfd = clientFD
        clientFD = -1
        stateLock.unlock()

        if cfd >= 0 {
            Darwin.shutdown(cfd, SHUT_RDWR)
            Darwin.close(cfd)
        }
        if lfd >= 0 {
            Darwin.shutdown(lfd, SHUT_RDWR)
            Darwin.close(lfd)
        }
    }

    /// Signals that QEMU has exited its initial paused (`-S`) state and begun booting the guest.
    func notifyGuestBooted() {
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.stateLock.lock()
            self.guestBooted = true
            let shouldAttach = self.helloCompleted && !self.deviceAttached && self.clientFD >= 0
            if shouldAttach {
                self.deviceAttached = true
            }
            self.stateLock.unlock()
            if shouldAttach {
                self.sendDeviceConnect()
            }
        }
    }

    // MARK: - AppKit NSTouch Input Handling (Main Thread)

    @MainActor
    func handleTouches(event: NSEvent, in view: NSView) {
        guard isActive else {
            if inGesture {
                cancelActiveGesture(timestamp: event.timestamp)
            }
            return
        }

        let touching = event.touches(matching: .touching, in: nil).filter { $0.type == .indirect }
        var scanTime = UInt16(truncatingIfNeeded: UInt64(max(0, event.timestamp) * 10000.0))

        let touchingCount = touching.count
        guard touchingCount >= 2 || inGesture else {
            return
        }

        let wasInGesture = inGesture
        var seen = [Bool](repeating: false, count: 5)

        if touchingCount >= 2 {
            inGesture = true
            for touch in touching {
                guard let slot = findOrAllocateSlot(for: touch.identity) else { continue }
                let nx = Double(touch.normalizedPosition.x)
                let ny = 1.0 - Double(touch.normalizedPosition.y)
                if !slots[slot].active {
                    slots[slot].active = true
                    slots[slot].identity = touch.identity
                }
                // Use raw Apple-filtered coordinates so Windows' own PTP velocity/inertia filter has zero phase lag
                slots[slot].sx = nx
                slots[slot].sy = ny
                seen[slot] = true
            }
        }

        var report = Data(capacity: 30)
        report.append(ReportID.touchpad.rawValue)

        var contactCount: UInt8 = 0
        var anyStillDown = false
        var signature: [UInt64] = []
        signature.reserveCapacity(5)

        for i in 0..<5 {
            guard slots[i].active else { continue }
            let isDown = (touchingCount >= 2) && seen[i]
            let flags = UInt8((i << 2) | (isDown ? 0x03 : 0x01)) // Confidence=1, Tip=isDown
            let qx = Self.clampCoord(slots[i].sx)
            let qy = Self.clampCoord(slots[i].sy)
            report.append(flags)
            report.appendLE16(qx)
            report.appendLE16(qy)
            signature.append((UInt64(flags) << 32) | (UInt64(qx) << 16) | UInt64(qy))
            contactCount += 1

            if !isDown {
                slots[i].active = false
                slots[i].identity = nil
            } else {
                anyStillDown = true
            }
        }

        guard contactCount > 0 else {
            if !anyStillDown {
                inGesture = false
                lastContactSignature.removeAll(keepingCapacity: true)
            }
            return
        }

        // Skip duplicate frames with identical quantized contacts to prevent zero-velocity dips in Windows inertia
        if wasInGesture && anyStillDown && signature == lastContactSignature {
            return
        }
        lastContactSignature = signature

        // Ensure strictly monotonic scanTime within a gesture so Windows never divides by Δt = 0
        if wasInGesture && scanTime == lastScanTime {
            scanTime &+= 1
        }
        lastScanTime = scanTime

        // Pad remaining finger slots (5 total * 5 bytes = 25 bytes)
        for _ in Int(contactCount)..<5 {
            report.append(contentsOf: [0, 0, 0, 0, 0])
        }
        report.appendLE16(scanTime)
        report.append(contactCount)
        report.append(0) // buttons

        sendInterruptReport(report)

        if !anyStillDown {
            inGesture = false
            lastContactSignature.removeAll(keepingCapacity: true)
        }
    }

    @MainActor
    func cancelActiveGesture(timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard inGesture else { return }
        let scanTime = UInt16(truncatingIfNeeded: UInt64(max(0, timestamp) * 10000.0))

        var report = Data(capacity: 30)
        report.append(ReportID.touchpad.rawValue)

        var contactCount: UInt8 = 0
        for i in 0..<5 {
            guard slots[i].active else { continue }
            report.append(UInt8((i << 2) | 0x01)) // Confidence=1, Tip=0
            report.appendLE16(Self.clampCoord(slots[i].sx))
            report.appendLE16(Self.clampCoord(slots[i].sy))
            slots[i].active = false
            slots[i].identity = nil
            contactCount += 1
        }

        if contactCount > 0 {
            for _ in Int(contactCount)..<5 {
                report.append(contentsOf: [0, 0, 0, 0, 0])
            }
            report.appendLE16(scanTime)
            report.append(contactCount)
            report.append(0)
            sendInterruptReport(report)
        }
        inGesture = false
        lastContactSignature.removeAll(keepingCapacity: true)
    }

    private func findOrAllocateSlot(for identity: NSObjectProtocol & NSCopying) -> Int? {
        for i in 0..<5 {
            if slots[i].active, let existing = slots[i].identity, existing.isEqual(identity) {
                return i
            }
        }
        for i in 0..<5 {
            if !slots[i].active {
                return i
            }
        }
        return nil
    }

    private static func clampCoord(_ value: Double) -> UInt16 {
        let clamped = min(max(value, 0.0), 1.0)
        return UInt16(clamped * 32767.0 + 0.5)
    }

    // MARK: - usbredir Socket Server

    private func acceptLoop(listenFD: Int32) {
        while true {
            stateLock.lock()
            let stopped = isStopped
            stateLock.unlock()
            if stopped { break }

            let cfd = Darwin.accept(listenFD, nil, nil)
            if cfd < 0 {
                if errno == EINTR { continue }
                break
            }

            var yes: Int32 = 1
            setsockopt(cfd, IPPROTO_TCP, TCP_NODELAY, &yes, socklen_t(MemoryLayout<Int32>.size))
            setsockopt(cfd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

            stateLock.lock()
            if isStopped {
                stateLock.unlock()
                Darwin.close(cfd)
                break
            }
            clientFD = cfd
            use64BitIds = false
            helloCompleted = false
            deviceAttached = false
            interruptActive = false
            stateLock.unlock()

            logger.debug("Precision Touchpad: QEMU usbredir connected")
            sendHello()
            handleClient(fd: cfd)

            stateLock.lock()
            interruptActive = false
            if clientFD == cfd {
                clientFD = -1
            }
            stateLock.unlock()
            Darwin.close(cfd)
            logger.debug("Precision Touchpad: QEMU usbredir disconnected")
        }
    }

    private func handleClient(fd: Int32) {
        var headerBuf = [UInt8](repeating: 0, count: 16)
        var payloadBuf = [UInt8](repeating: 0, count: 4096)

        while true {
            stateLock.lock()
            let is64 = use64BitIds
            stateLock.unlock()

            let hdrSize = is64 ? 16 : 12
            guard Self.readAll(fd: fd, into: &headerBuf, count: hdrSize) else {
                break
            }

            let pktType = Self.readLE32(headerBuf, offset: 0)
            let pktLen = Int(Self.readLE32(headerBuf, offset: 4))
            let pktId: UInt64 = is64
                ? Self.readLE64(headerBuf, offset: 8)
                : UInt64(Self.readLE32(headerBuf, offset: 8))

            guard pktLen <= payloadBuf.count else {
                break
            }
            if pktLen > 0 && !Self.readAll(fd: fd, into: &payloadBuf, count: pktLen) {
                break
            }

            guard let type = PacketType(rawValue: pktType) else {
                continue
            }

            switch type {
            case .hello:
                var qcaps: UInt32 = 0
                if pktLen >= 68 {
                    qcaps = Self.readLE32(payloadBuf, offset: 64)
                }
                let use64 = (qcaps & Self.cap64BitIds) != 0
                stateLock.lock()
                use64BitIds = use64
                helloCompleted = true
                let shouldAttach = guestBooted && !deviceAttached
                if shouldAttach {
                    deviceAttached = true
                }
                stateLock.unlock()
                logger.debug("Precision Touchpad: QEMU hello received (64bit_ids=\(use64), shouldAttach=\(shouldAttach))")
                if shouldAttach {
                    sendDeviceConnect()
                }

            case .reset:
                stateLock.lock()
                interruptActive = false
                stateLock.unlock()

            case .setConfiguration:
                let cfg = pktLen >= 1 ? payloadBuf[0] : 1
                sendPacket(type: .configurationStatus, id: pktId, payload: Data([Status.success.rawValue, cfg]))

            case .getConfiguration:
                sendPacket(type: .configurationStatus, id: pktId, payload: Data([Status.success.rawValue, 1]))

            case .setAltSetting:
                let iface = pktLen >= 1 ? payloadBuf[0] : 0
                let alt = pktLen >= 2 ? payloadBuf[1] : 0
                sendPacket(type: .altSettingStatus, id: pktId, payload: Data([Status.success.rawValue, iface, alt]))

            case .getAltSetting:
                let iface = pktLen >= 1 ? payloadBuf[0] : 0
                sendPacket(type: .altSettingStatus, id: pktId, payload: Data([Status.success.rawValue, iface, 0]))

            case .startInterruptReceiving:
                let ep = pktLen >= 1 ? payloadBuf[0] : 0x81
                stateLock.lock()
                interruptActive = true
                stateLock.unlock()
                sendPacket(type: .interruptReceivingStatus, id: pktId, payload: Data([Status.success.rawValue, ep]))
                logger.debug("Precision Touchpad: guest started interrupt stream (EP 0x\(String(ep, radix: 16)))")

            case .stopInterruptReceiving:
                let ep = pktLen >= 1 ? payloadBuf[0] : 0x81
                stateLock.lock()
                interruptActive = false
                stateLock.unlock()
                sendPacket(type: .interruptReceivingStatus, id: pktId, payload: Data([Status.success.rawValue, ep]))

            case .controlPacket:
                if pktLen >= 10 {
                    let outData = pktLen > 10 ? Array(payloadBuf[10..<pktLen]) : []
                    handleControlPacket(id: pktId, header: Array(payloadBuf[0..<10]), outData: outData)
                }

            default:
                break
            }
        }
    }

    private func sendHello() {
        var payload = Data(count: 64)
        let version = Array("UTM Precision Touchpad 1.0".utf8)
        payload.replaceSubrange(0..<min(version.count, 63), with: version)
        let caps = Self.capBulkStreams | Self.capConnectDeviceVersion | Self.capEpInfoMaxPacketSize | Self.cap64BitIds
        payload.appendLE32(caps)
        sendPacket(type: .hello, id: 0, payload: payload)
    }

    private func sendDeviceConnect() {
        // 1. Interface info (4 + 32*4 = 132 bytes)
        var ii = Data(count: 132)
        ii[0] = 1 // interface_count = 1 (LE32)
        ii[4] = 0 // interface[0] = 0
        ii[36] = 0x03 // interface_class[0] = HID
        sendPacket(type: .interfaceInfo, id: 0, payload: ii)

        // 2. Endpoint info (32 + 32 + 32 + 64 + 128 = 288 bytes)
        var ei = Data(count: 288)
        for i in 0..<32 {
            ei[i] = EndpointType.invalid.rawValue
        }
        // EP0 OUT (index 0) and EP0 IN (index 16)
        ei[0] = EndpointType.control.rawValue
        ei[16] = EndpointType.control.rawValue
        // EP 0x81 IN (index 17)
        ei[17] = EndpointType.interrupt.rawValue
        ei[32 + 17] = 1 // interval = 1 ms
        ei[64 + 17] = 0 // interface = 0
        // max_packet_size[32] starts at offset 96 (uint16 LE)
        ei[96 + 0 * 2] = 64
        ei[96 + 16 * 2] = 64
        ei[96 + 17 * 2] = 64
        sendPacket(type: .epInfo, id: 0, payload: ei)

        // 3. Device connect (10 bytes)
        var dc = Data(capacity: 10)
        dc.append(1) // usb_redir_speed_full
        dc.append(0) // device_class
        dc.append(0) // device_subclass
        dc.append(0) // device_protocol
        dc.appendLE16(0x1209) // vendor_id
        dc.appendLE16(0x5054) // product_id
        dc.appendLE16(0x0100) // device_version_bcd
        sendPacket(type: .deviceConnect, id: 0, payload: dc)
    }

    private func handleControlPacket(id: UInt64, header: [UInt8], outData: [UInt8]) {
        let endpoint = header[0]
        let request = header[1]
        let requestType = header[2]
        let value = Self.readLE16(header, offset: 4)
        let index = Self.readLE16(header, offset: 6)
        let reqLength = Int(Self.readLE16(header, offset: 8))
        let isIn = (requestType & 0x80) != 0

        var status: Status = .success
        var body = Data()

        if isIn && (requestType & 0x60) == 0x00 && request == 0x06 {
            // GET_DESCRIPTOR
            let descType = UInt8(value >> 8)
            let descIdx = UInt8(value & 0xFF)
            switch descType {
            case 0x01:
                body = Data(Self.deviceDescriptor)
            case 0x02:
                body = Data(Self.configDescriptor)
            case 0x03:
                switch descIdx {
                case 0:
                    body = Data([4, 0x03, 0x09, 0x04]) // en-US
                case 1:
                    body = Self.makeUSBString("UTM")
                case 2:
                    body = Self.makeUSBString("UTM Precision Touchpad")
                default:
                    body = Self.makeUSBString("0001")
                }
            case 0x21:
                body = Data(Self.configDescriptor[18..<27])
            case 0x22:
                body = Data(Self.hidReportDescriptor)
            default:
                status = .stall
            }
        } else if isIn && (requestType & 0x60) == 0x00 && request == 0x00 {
            // GET_STATUS
            body = Data([0, 0])
        } else if (requestType & 0x60) == 0x20 {
            // HID Class requests
            if isIn && request == 0x01 {
                // GET_REPORT
                let reportType = UInt8(value >> 8)
                let reportId = UInt8(value & 0xFF)
                if reportType == 0x03 {
                    switch ReportID(rawValue: reportId) {
                    case .maxCount:
                        body = Data([ReportID.maxCount.rawValue, 5])
                    case .ptphqa:
                        var blob = Data([ReportID.ptphqa.rawValue])
                        blob.append(contentsOf: Self.ptphqaBlob)
                        body = blob
                    case .inputMode:
                        stateLock.lock()
                        let mode = inputMode
                        stateLock.unlock()
                        body = Data([ReportID.inputMode.rawValue, mode])
                    case .functionSwitch:
                        stateLock.lock()
                        let sw = surfaceSwitch
                        stateLock.unlock()
                        body = Data([ReportID.functionSwitch.rawValue, sw])
                    default:
                        status = .stall
                    }
                } else {
                    status = .stall
                }
            } else if !isIn && request == 0x09 {
                // SET_REPORT
                let reportId = UInt8(value & 0xFF)
                if reportId == ReportID.inputMode.rawValue && outData.count >= 2 {
                    stateLock.lock()
                    inputMode = outData[1]
                    stateLock.unlock()
                    logger.debug("Precision Touchpad: guest set InputMode = 0x\(String(outData[1], radix: 16))")
                } else if reportId == ReportID.functionSwitch.rawValue && outData.count >= 2 {
                    stateLock.lock()
                    surfaceSwitch = outData[1]
                    stateLock.unlock()
                    logger.debug("Precision Touchpad: guest set SurfaceSwitch = 0x\(String(outData[1], radix: 16))")
                }
            } else if !isIn && (request == 0x0A || request == 0x0B) {
                // SET_IDLE / SET_PROTOCOL
            } else {
                status = .stall
            }
        } else if !isIn && (requestType & 0x60) == 0x00 && (request == 0x01 || request == 0x03) {
            // CLEAR_FEATURE / SET_FEATURE
        } else {
            status = .stall
        }

        let respData: Data
        if isIn && status == .success {
            respData = body.count > reqLength ? body.prefix(reqLength) : body
        } else {
            respData = Data()
        }

        var respPayload = Data(capacity: 10 + respData.count)
        respPayload.append(endpoint)
        respPayload.append(request)
        respPayload.append(requestType)
        respPayload.append(status.rawValue)
        respPayload.appendLE16(value)
        respPayload.appendLE16(index)
        respPayload.appendLE16(UInt16(respData.count))
        respPayload.append(respData)
        sendPacket(type: .controlPacket, id: id, payload: respPayload)
    }

    private func sendInterruptReport(_ report: Data) {
        var payload = Data(capacity: 4 + report.count)
        payload.append(0x81) // endpoint
        payload.append(Status.success.rawValue)
        payload.appendLE16(UInt16(report.count))
        payload.append(report)
        sendPacket(type: .interruptPacket, id: 0, payload: payload)
    }

    @discardableResult
    private func sendPacket(type: PacketType, id: UInt64, payload: Data) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        let fd = clientFD
        guard fd >= 0 else { return false }

        let use64 = (type != .hello) && use64BitIds
        var packet = Data(capacity: (use64 ? 16 : 12) + payload.count)
        packet.appendLE32(type.rawValue)
        packet.appendLE32(UInt32(payload.count))
        if use64 {
            packet.appendLE64(id)
        } else {
            packet.appendLE32(UInt32(truncatingIfNeeded: id))
        }
        packet.append(payload)

        return packet.withUnsafeBytes { rawBuf -> Bool in
            guard let base = rawBuf.baseAddress else { return true }
            var sent = 0
            while sent < rawBuf.count {
                let n = Darwin.send(fd, base.advanced(by: sent), rawBuf.count - sent, 0)
                if n <= 0 {
                    if n < 0 && errno == EINTR { continue }
                    return false
                }
                sent += n
            }
            return true
        }
    }

    // MARK: - Byte Helpers

    private static func makeUSBString(_ text: String) -> Data {
        let utf16 = Array(text.utf16)
        var data = Data(capacity: 2 + utf16.count * 2)
        data.append(UInt8(2 + utf16.count * 2))
        data.append(0x03)
        for unit in utf16 {
            data.appendLE16(unit)
        }
        return data
    }

    private static func readAll(fd: Int32, into buffer: inout [UInt8], count: Int) -> Bool {
        var total = 0
        while total < count {
            let n = buffer.withUnsafeMutableBytes { rawBuf in
                Darwin.recv(fd, rawBuf.baseAddress!.advanced(by: total), count - total, 0)
            }
            if n <= 0 {
                if n < 0 && errno == EINTR { continue }
                return false
            }
            total += n
        }
        return true
    }

    private static func readLE16(_ buf: [UInt8], offset: Int) -> UInt16 {
        UInt16(buf[offset]) | (UInt16(buf[offset + 1]) << 8)
    }

    private static func readLE32(_ buf: [UInt8], offset: Int) -> UInt32 {
        UInt32(buf[offset])
            | (UInt32(buf[offset + 1]) << 8)
            | (UInt32(buf[offset + 2]) << 16)
            | (UInt32(buf[offset + 3]) << 24)
    }

    private static func readLE64(_ buf: [UInt8], offset: Int) -> UInt64 {
        UInt64(readLE32(buf, offset: offset)) | (UInt64(readLE32(buf, offset: offset + 4)) << 32)
    }
}

private extension Data {
    mutating func appendLE16(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendLE32(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }

    mutating func appendLE64(_ value: UInt64) {
        appendLE32(UInt32(value & 0xFFFF_FFFF))
        appendLE32(UInt32((value >> 32) & 0xFFFF_FFFF))
    }
}
