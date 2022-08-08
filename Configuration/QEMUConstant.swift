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

import Foundation
import Metal

// MARK: QEMUConstant protocol

/// A QEMU constant is a enum that can be generated externally
protocol QEMUConstant: Codable, RawRepresentable, CaseIterable where RawValue == String, AllCases == [Self] {
    static var allRawValues: [String] { get }
    static var allPrettyValues: [String] { get }
    var prettyValue: String { get }
    var rawValue: String { get }
    
    init?(rawValue: String)
}

extension QEMUConstant where Self: CaseIterable, AllCases == [Self] {
    static var allRawValues: [String] {
        allCases.map { value in value.rawValue }
    }
    
    static var allPrettyValues: [String] {
        allCases.map { value in value.prettyValue }
    }
}

extension QEMUConstant where Self: RawRepresentable, RawValue == String {
    init(from decoder: Decoder) throws {
        let rawValue = try String(from: decoder)
        guard let representedValue = Self.init(rawValue: rawValue) else {
            throw UTMConfigurationError.invalidConfigurationValue(rawValue)
        }
        self = representedValue
    }
    
    func encode(to encoder: Encoder) throws {
        try rawValue.encode(to: encoder)
    }
}

protocol QEMUDefaultConstant: QEMUConstant {
    static var `default`: Self { get }
}

extension Optional where Wrapped: QEMUDefaultConstant {
    var _bound: Wrapped? {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    
    var bound: Wrapped {
        get {
            return _bound ?? Wrapped.default
        }
        set {
            _bound = newValue
        }
    }
}

/// Type erasure for a QEMU constant useful for serialization/deserialization
struct AnyQEMUConstant: QEMUConstant, RawRepresentable {
    static var allRawValues: [String] { [] }
    
    static var allPrettyValues: [String] { [] }
    
    static var allCases: [AnyQEMUConstant] { [] }
    
    var prettyValue: String { rawValue }
    
    let rawValue: String
    
    init<C>(_ base: C) where C : QEMUConstant {
        self.rawValue = base.rawValue
    }
    
    init?(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension QEMUConstant {
    func asAnyQEMUConstant() -> AnyQEMUConstant {
        return AnyQEMUConstant(self)
    }
}

extension AnyQEMUConstant: QEMUDefaultConstant {
    static var `default`: AnyQEMUConstant {
        AnyQEMUConstant(rawValue: "default")!
    }
}

// MARK: Enhanced type checking for generated constants

protocol QEMUTarget: QEMUDefaultConstant {}

extension AnyQEMUConstant: QEMUTarget {}

protocol QEMUCPU: QEMUDefaultConstant {}

extension AnyQEMUConstant: QEMUCPU {}

protocol QEMUCPUFlag: QEMUConstant {}

extension AnyQEMUConstant: QEMUCPUFlag {}

protocol QEMUDisplayDevice: QEMUConstant {}

extension AnyQEMUConstant: QEMUDisplayDevice {}

protocol QEMUNetworkDevice: QEMUConstant {}

extension AnyQEMUConstant: QEMUNetworkDevice {}

protocol QEMUSoundDevice: QEMUConstant {}

extension AnyQEMUConstant: QEMUSoundDevice {}

protocol QEMUSerialDevice: QEMUConstant {}

extension AnyQEMUConstant: QEMUSerialDevice {}

// MARK: Display constants

enum QEMUScaler: String, CaseIterable, QEMUConstant {
    case linear = "Linear"
    case nearest = "Nearest"
    
    var prettyValue: String {
        switch self {
        case .linear: return NSLocalizedString("Linear", comment: "UTMQemuConstants")
        case .nearest: return NSLocalizedString("Nearest Neighbor", comment: "UTMQemuConstants")
        }
    }
    
    var metalSamplerMinMagFilter: MTLSamplerMinMagFilter {
        switch self {
        case .linear: return .linear
        case .nearest: return .nearest
        }
    }
}

// MARK: USB constants

enum QEMUUSBBus: String, CaseIterable, QEMUConstant {
    case disabled = "Disabled"
    case usb2_0 = "2.0"
    case usb3_0 = "3.0"
    
    var prettyValue: String {
        switch self {
        case .disabled: return NSLocalizedString("Disabled", comment: "UTMQemuConstants")
        case .usb2_0: return NSLocalizedString("USB 2.0", comment: "UTMQemuConstants")
        case .usb3_0: return NSLocalizedString("USB 3.0 (XHCI)", comment: "UTMQemuConstants")
        }
    }
}

// MARK: Network constants

enum QEMUNetworkMode: String, CaseIterable, QEMUConstant {
    case emulated = "Emulated"
    #if os(macOS)
    case shared = "Shared"
    case host = "Host"
    case bridged = "Bridged"
    #endif
    
    var prettyValue: String {
        switch self {
        case .emulated: return NSLocalizedString("Emulated VLAN", comment: "UTMQemuConstants")
        #if os(macOS)
        case .shared: return NSLocalizedString("Shared Network", comment: "UTMQemuConstants")
        case .host: return NSLocalizedString("Host Only", comment: "UTMQemuConstants")
        case .bridged: return NSLocalizedString("Bridged (Advanced)", comment: "UTMQemuConstants")
        #endif
        }
    }
}

enum QEMUNetworkProtocol: String, CaseIterable, QEMUConstant {
    case tcp = "TCP"
    case udp = "UDP"
    
    var prettyValue: String {
        switch self {
        case .tcp: return NSLocalizedString("TCP", comment: "UTMQemuConstants")
        case .udp: return NSLocalizedString("UDP", comment: "UTMQemuConstants")
        }
    }
}

// MARK: Serial constants

enum QEMUTerminalTheme: String, CaseIterable, QEMUDefaultConstant {
    case `default` = "Default"
    
    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "UTMQemuConstants")
        }
    }
}

struct QEMUTerminalFont: QEMUConstant {
    #if os(macOS)
    static var allRawValues: [String] = {
        NSFontManager.shared.availableFontNames(with: .fixedPitchFontMask) ?? []
    }()
    
    static var allPrettyValues: [String] = {
        allRawValues.map { name in
            NSFont(name: name, size: 1)?.displayName ?? name
        }
    }()
    #else
    static var allRawValues: [String] = {
        UIFont.familyNames.flatMap { family -> [String] in
            guard let font = UIFont(name: family, size: 1) else {
                return []
            }
            if font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
                return UIFont.fontNames(forFamilyName: family)
            } else {
                return []
            }
        }
    }()
    
    static var allPrettyValues: [String] = {
        allRawValues.map { name in
            guard let font = UIFont(name: name, size: 1) else {
                return name
            }
            let traits = font.fontDescriptor.symbolicTraits
            let description: String
            if traits.isSuperset(of: [.traitItalic, .traitBold]) {
                description = NSLocalizedString("Italic, Bold", comment: "UTMQemuConstants")
            } else if traits.contains(.traitItalic) {
                description = NSLocalizedString("Italic", comment: "UTMQemuConstants")
            } else if traits.contains(.traitBold) {
                description = NSLocalizedString("Bold", comment: "UTMQemuConstants")
            } else {
                description = NSLocalizedString("Regular", comment: "UTMQemuConstants")
            }
            return String.localizedStringWithFormat(NSLocalizedString("%@ (%@)", comment: "QEMUConstant"), font.familyName, description)
        }
    }()
    #endif
    
    static var allCases: [QEMUTerminalFont] {
        Self.allRawValues.map { Self(rawValue: $0) }
    }
    
    var prettyValue: String {
        guard let index = Self.allRawValues.firstIndex(of: rawValue) else {
            return rawValue
        }
        return Self.allPrettyValues[index]
    }
    
    let rawValue: String
}

enum QEMUSerialMode: String, CaseIterable, QEMUConstant {
    case builtin = "Terminal"
    case tcpClient = "TcpClient"
    case tcpServer = "TcpServer"
    #if os(macOS)
    case ptty = "Ptty"
    #endif
    
    var prettyValue: String {
        switch self {
        case .builtin: return NSLocalizedString("Built-in Terminal", comment: "UTMQemuConstants")
        case .tcpClient: return NSLocalizedString("TCP Client Connection", comment: "UTMQemuConstants")
        case .tcpServer: return NSLocalizedString("TCP Server Connection", comment: "UTMQemuConstants")
        #if os(macOS)
        case .ptty: return NSLocalizedString("Pseudo-TTY Device", comment: "UTMQemuConstants")
        #endif
        }
    }
}

enum QEMUSerialTarget: String, CaseIterable, QEMUConstant {
    case autoDevice = "Auto"
    case manualDevice = "Manual"
    case gdb = "GDB"
    case monitor = "Monitor"
    
    var prettyValue: String {
        switch self {
        case .autoDevice: return NSLocalizedString("Automatic Serial Device (max 4)", comment: "UTMQemuConstants")
        case .manualDevice: return NSLocalizedString("Manual Serial Device (advanced)", comment: "UTMQemuConstants")
        case .gdb: return NSLocalizedString("GDB Debug Stub", comment: "UTMQemuConstants")
        case .monitor: return NSLocalizedString("QEMU Monitor (HMP)", comment: "UTMQemuConstants")
        }
    }
}

// MARK: Drive constants

enum QEMUDriveImageType: String, CaseIterable, QEMUConstant {
    case none = "None"
    case disk = "Disk"
    case cd = "CD"
    case bios = "BIOS"
    case linuxKernel = "LinuxKernel"
    case linuxInitrd = "LinuxInitrd"
    case linuxDtb = "LinuxDTB"
    
    var prettyValue: String {
        switch self {
        case .none: return NSLocalizedString("None", comment: "UTMQemuConstants")
        case .disk: return NSLocalizedString("Disk Image", comment: "UTMQemuConstants")
        case .cd: return NSLocalizedString("CD/DVD (ISO) Image", comment: "UTMQemuConstants")
        case .bios: return NSLocalizedString("BIOS", comment: "UTMQemuConstants")
        case .linuxKernel: return NSLocalizedString("Linux Kernel", comment: "UTMQemuConstants")
        case .linuxInitrd: return NSLocalizedString("Linux RAM Disk", comment: "UTMQemuConstants")
        case .linuxDtb: return NSLocalizedString("Linux Device Tree Binary", comment: "UTMQemuConstants")
        }
    }
}

enum QEMUDriveInterface: String, CaseIterable, QEMUConstant {
    case none = "None"
    case ide = "IDE"
    case scsi = "SCSI"
    case sd = "SD"
    case mtd = "MTD"
    case floppy = "Floppy"
    case pflash = "PFlash"
    case virtio = "VirtIO"
    case nvme = "NVMe"
    case usb = "USB"
    
    var prettyValue: String {
        switch self {
        case .none: return NSLocalizedString("None (Advanced)", comment: "UTMQemuConstants")
        case .ide: return NSLocalizedString("IDE", comment: "UTMQemuConstants")
        case .scsi: return NSLocalizedString("SCSI", comment: "UTMQemuConstants")
        case .sd: return NSLocalizedString("SD Card", comment: "UTMQemuConstants")
        case .mtd: return NSLocalizedString("MTD (NAND/NOR)", comment: "UTMQemuConstants")
        case .floppy: return NSLocalizedString("Floppy", comment: "UTMQemuConstants")
        case .pflash: return NSLocalizedString("PC System Flash", comment: "UTMQemuConstants")
        case .virtio: return NSLocalizedString("VirtIO", comment: "UTMQemuConstants")
        case .nvme: return NSLocalizedString("NVMe", comment: "UTMQemuConstants")
        case .usb: return NSLocalizedString("USB", comment: "UTMQemuConstants")
        }
    }
}

// MARK: Sharing constants

enum QEMUFileShareMode: String, CaseIterable, QEMUConstant {
    case none = "None"
    case webdav = "WebDAV"
    case virtfs = "VirtFS"
    
    var prettyValue: String {
        switch self {
        case .none: return NSLocalizedString("None", comment: "UTMQemuConstants")
        case .webdav: return NSLocalizedString("SPICE WebDAV (Legacy)", comment: "UTMQemuConstants")
        case .virtfs: return NSLocalizedString("VirtFS (Recommended)", comment: "UTMQemuConstants")
        }
    }
}

// MARK: File names

enum QEMUPackageFileName: String {
    case images = "Images"
    case debugLog = "debug.log"
    case efiVariables = "efi_vars.fd"
}
