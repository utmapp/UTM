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

import Foundation

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
final class UTMLegacyAppleConfiguration: Codable {
    private let currentVersion = 3
    
    var version: Int
    
    var isAppleVirtualization: Bool
    
    var name: String
    
    var architecture: String
    
    var iconBasePath: URL?
    
    var selectedCustomIconPath: URL?
    
    var icon: String?
    
    var iconCustom: Bool
    
    var notes: String?
    
    var consoleTheme: String?
    
    var consoleTextColor: String?
    
    var consoleBackgroundColor: String?
    
    var consoleFont: String?
    
    var consoleFontSize: NSNumber?
    
    var consoleCursorBlink: Bool
    
    var consoleResizeCommand: String?
    
    var iconUrl: URL? {
        if self.iconCustom {
            if let current = self.selectedCustomIconPath {
                return current // if we just selected a path
            }
            guard let icon = self.icon else {
                return nil
            }
            guard let base = self.iconBasePath?.appendingPathComponent("Data") else {
                return nil
            }
            return base.appendingPathComponent(icon) // from saved config
        } else {
            guard let icon = self.icon else {
                return nil
            }
            return Bundle.main.url(forResource: icon, withExtension: "png", subdirectory: "Icons")
        }
    }
    
    var cpuCount: Int
    
    var memorySize: UInt64
    
    var bootLoader: Bootloader?
    
    var macPlatform: MacPlatform?
    
    var macRecoveryIpswURL: URL?
    
    var networkDevices: [Network]
    
    var displays: [Display]
    
    var diskImages: [DiskImage] = []
    
    var sharedDirectories: [SharedDirectory] = []
    
    var isAudioEnabled: Bool
    
    var isBalloonEnabled: Bool
    
    var isEntropyEnabled: Bool
    
    var isSerialEnabled: Bool
    
    var isConsoleDisplay: Bool
    
    var isKeyboardEnabled: Bool
    
    var isPointingEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case version
        case isAppleVirtualization
        case name
        case architecture
        case icon
        case iconCustom
        case notes
        case consoleTheme
        case consoleTextColor
        case consoleBackgroundColor
        case consoleFont
        case consoleFontSize
        case consoleCursorBlink
        case consoleResizeCommand
        case cpuCount
        case memorySize
        case bootLoader
        case macPlatform
        case networkDevices
        case displays
        case diskImages
        case isAudioEnabled
        case isBalloonEnabled
        case isEntropyEnabled
        case isSerialEnabled
        case isConsoleDisplay
        case isKeyboardEnabled
        case isPointingEnabled
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        if version > currentVersion {
            throw UTMConfigurationError.versionTooHigh
        }
        isAppleVirtualization = try values.decodeIfPresent(Bool.self, forKey: .isAppleVirtualization) ?? false
        guard version > 0 && isAppleVirtualization else {
            throw UTMAppleConfigurationError.notAppleConfiguration
        }
        cpuCount = try values.decode(Int.self, forKey: .cpuCount)
        memorySize = try values.decode(UInt64.self, forKey: .memorySize)
        bootLoader = try values.decodeIfPresent(Bootloader.self, forKey: .bootLoader)
        networkDevices = try values.decode([Network].self, forKey: .networkDevices)
        macPlatform = try values.decodeIfPresent(MacPlatform.self, forKey: .macPlatform)
        displays = try values.decodeIfPresent([Display].self, forKey: .displays) ?? []
        isAudioEnabled = try values.decodeIfPresent(Bool.self, forKey: .isAudioEnabled) ?? false
        isKeyboardEnabled = try values.decodeIfPresent(Bool.self, forKey: .isKeyboardEnabled) ?? false
        isPointingEnabled = try values.decodeIfPresent(Bool.self, forKey: .isPointingEnabled) ?? false
        diskImages = try values.decode([DiskImage].self, forKey: .diskImages)
        isBalloonEnabled = try values.decode(Bool.self, forKey: .isBalloonEnabled)
        isEntropyEnabled = try values.decode(Bool.self, forKey: .isEntropyEnabled)
        isSerialEnabled = try values.decode(Bool.self, forKey: .isSerialEnabled)
        isConsoleDisplay = try values.decode(Bool.self, forKey: .isConsoleDisplay)
        name = try values.decode(String.self, forKey: .name)
        architecture = try values.decode(String.self, forKey: .architecture)
        icon = try values.decodeIfPresent(String.self, forKey: .icon)
        iconCustom = try values.decode(Bool.self, forKey: .iconCustom)
        notes = try values.decodeIfPresent(String.self, forKey: .notes)
        consoleTheme = try values.decodeIfPresent(String.self, forKey: .consoleTheme)
        consoleTextColor = try values.decodeIfPresent(String.self, forKey: .consoleTextColor)
        consoleBackgroundColor = try values.decodeIfPresent(String.self, forKey: .consoleBackgroundColor)
        consoleFont = try values.decodeIfPresent(String.self, forKey: .consoleFont)
        let fontSize = try values.decodeIfPresent(Int.self, forKey: .consoleFontSize)
        consoleFontSize = (fontSize ?? 12) as NSNumber
        consoleCursorBlink = try values.decode(Bool.self, forKey: .consoleCursorBlink)
        consoleResizeCommand = try values.decodeIfPresent(String.self, forKey: .consoleResizeCommand)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(isAppleVirtualization, forKey: .isAppleVirtualization)
        try container.encode(cpuCount, forKey: .cpuCount)
        try container.encode(memorySize, forKey: .memorySize)
        try container.encodeIfPresent(bootLoader, forKey: .bootLoader)
        try container.encode(networkDevices, forKey: .networkDevices)
        if #available(macOS 12, *) {
            #if arch(arm64)
            try container.encodeIfPresent(macPlatform, forKey: .macPlatform)
            #endif
            try container.encode(displays, forKey: .displays)
            try container.encode(isAudioEnabled, forKey: .isAudioEnabled)
            try container.encode(isKeyboardEnabled, forKey: .isKeyboardEnabled)
            try container.encode(isPointingEnabled, forKey: .isPointingEnabled)
        }
        try container.encode(diskImages.filter({ !$0.isExternal }), forKey: .diskImages)
        try container.encode(isBalloonEnabled, forKey: .isBalloonEnabled)
        try container.encode(isEntropyEnabled, forKey: .isEntropyEnabled)
        try container.encode(isSerialEnabled, forKey: .isSerialEnabled)
        try container.encode(isConsoleDisplay, forKey: .isConsoleDisplay)
        try container.encode(name, forKey: .name)
        try container.encode(architecture, forKey: .architecture)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(iconCustom, forKey: .iconCustom)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(consoleTheme, forKey: .consoleTheme)
        try container.encodeIfPresent(consoleTextColor, forKey: .consoleTextColor)
        try container.encodeIfPresent(consoleBackgroundColor, forKey: .consoleBackgroundColor)
        try container.encodeIfPresent(consoleFont, forKey: .consoleFont)
        try container.encodeIfPresent(consoleFontSize?.intValue, forKey: .consoleFontSize)
        try container.encode(consoleCursorBlink, forKey: .consoleCursorBlink)
        try container.encodeIfPresent(consoleResizeCommand, forKey: .consoleResizeCommand)
    }
}

struct Bootloader: Codable {
    enum OperatingSystem: String, CaseIterable, Identifiable, Codable {
        var id: String {
            rawValue
        }
        case Linux
        case macOS
    }
    
    var operatingSystem: OperatingSystem
    var linuxKernelURL: URL?
    var linuxCommandLine: String?
    var linuxInitialRamdiskURL: URL?
    
    private enum CodingKeys: String, CodingKey {
        case operatingSystem
        case linuxKernelPath
        case linuxCommandLine
        case linuxInitialRamdiskPath
    }
    
    init(from decoder: Decoder) throws {
        guard let dataURL = decoder.userInfo[.dataURL] as? URL else {
            throw UTMConfigurationError.invalidDataURL
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operatingSystem = try container.decode(OperatingSystem.self, forKey: .operatingSystem)
        if let linuxKernelPath = try container.decodeIfPresent(String.self, forKey: .linuxKernelPath) {
            linuxKernelURL = dataURL.appendingPathComponent(linuxKernelPath)
        }
        linuxCommandLine = try container.decodeIfPresent(String.self, forKey: .linuxCommandLine)
        if let linuxInitialRamdiskPath = try container.decodeIfPresent(String.self, forKey: .linuxInitialRamdiskPath) {
            linuxInitialRamdiskURL = dataURL.appendingPathComponent(linuxInitialRamdiskPath)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operatingSystem, forKey: .operatingSystem)
        try container.encodeIfPresent(linuxKernelURL?.lastPathComponent, forKey: .linuxKernelPath)
        try container.encodeIfPresent(linuxCommandLine, forKey: .linuxCommandLine)
        try container.encodeIfPresent(linuxInitialRamdiskURL?.lastPathComponent, forKey: .linuxInitialRamdiskPath)
    }
}

struct Network: Codable {
    enum NetworkMode: String, CaseIterable, Identifiable, Codable {
        var id: String {
            rawValue
        }
        case Shared
        case Bridged
    }
    
    var networkMode: NetworkMode
    var bridgeInterfaceIdentifier: String?
    var macAddress: String
}

struct Display: Codable {
    var widthInPixels: Int
    var heightInPixels: Int
    var pixelsPerInch: Int
}

struct MacPlatform: Codable {
    var hardwareModel: Data
    var machineIdentifier: Data
    var auxiliaryStorageURL: URL?
    
    private enum CodingKeys: String, CodingKey {
        case hardwareModel
        case machineIdentifier
        case auxiliaryStoragePath
    }
    
    init(from decoder: Decoder) throws {
        guard let dataURL = decoder.userInfo[.dataURL] as? URL else {
            throw UTMConfigurationError.invalidDataURL
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hardwareModel = try container.decode(Data.self, forKey: .hardwareModel)
        machineIdentifier = try container.decode(Data.self, forKey: .machineIdentifier)
        if let auxiliaryStoragePath = try container.decodeIfPresent(String.self, forKey: .auxiliaryStoragePath) {
            auxiliaryStorageURL = dataURL.appendingPathComponent(auxiliaryStoragePath)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hardwareModel, forKey: .hardwareModel)
        try container.encode(machineIdentifier, forKey: .machineIdentifier)
        try container.encodeIfPresent(auxiliaryStorageURL?.lastPathComponent, forKey: .auxiliaryStoragePath)
    }
}

struct DiskImage: Codable, Hashable, Identifiable {
    private let bytesInMib = 1048576
    
    var sizeMib: Int
    var isReadOnly: Bool
    var isExternal: Bool
    var imageURL: URL?
    private var uuid = UUID() // for identifiable
    
    private enum CodingKeys: String, CodingKey {
        case sizeMib
        case isReadOnly
        case isExternal
        case imagePath
        case imageBookmark
    }
    
    var id: Int {
        hashValue
    }
    
    var sizeBytes: Int64 {
        Int64(sizeMib) * Int64(bytesInMib)
    }
    
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    init(from decoder: Decoder) throws {
        guard let dataURL = decoder.userInfo[.dataURL] as? URL else {
            throw UTMConfigurationError.invalidDataURL
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sizeMib = try container.decode(Int.self, forKey: .sizeMib)
        isReadOnly = try container.decode(Bool.self, forKey: .isReadOnly)
        isExternal = try container.decode(Bool.self, forKey: .isExternal)
        if !isExternal, let imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath) {
            imageURL = dataURL.appendingPathComponent(imagePath)
        } else if let bookmark = try container.decodeIfPresent(Data.self, forKey: .imageBookmark) {
            var stale: Bool = false
            imageURL = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sizeMib, forKey: .sizeMib)
        try container.encode(isReadOnly, forKey: .isReadOnly)
        try container.encode(isExternal, forKey: .isExternal)
        if !isExternal {
            try container.encodeIfPresent(imageURL?.lastPathComponent, forKey: .imagePath)
        } else {
            var options = NSURL.BookmarkCreationOptions.withSecurityScope
            if isReadOnly {
                options.insert(.securityScopeAllowOnlyReadAccess)
            }
            _ = imageURL?.startAccessingSecurityScopedResource()
            defer {
                imageURL?.stopAccessingSecurityScopedResource()
            }
            let bookmark = try imageURL?.bookmarkData(options: options)
            try container.encodeIfPresent(bookmark, forKey: .imageBookmark)
        }
    }
    
    func hash(into hasher: inout Hasher) {
        if let imageURL = imageURL {
            imageURL.lastPathComponent.hash(into: &hasher)
        } else {
            uuid.hash(into: &hasher)
        }
    }
}

struct SharedDirectory: Codable, Hashable, Identifiable {
    var directoryURL: URL?
    var isReadOnly: Bool
    
    var id: SharedDirectory {
        self
    }
    
    private enum CodingKeys: String, CodingKey {
        case directoryBookmark
        case isReadOnly
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isReadOnly = try container.decode(Bool.self, forKey: .isReadOnly)
        let bookmark = try container.decode(Data.self, forKey: .directoryBookmark)
        var stale: Bool = false
        directoryURL = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isReadOnly, forKey: .isReadOnly)
        var options = NSURL.BookmarkCreationOptions.withSecurityScope
        if isReadOnly {
            options.insert(.securityScopeAllowOnlyReadAccess)
        }
        _ = directoryURL?.startAccessingSecurityScopedResource()
        defer {
            directoryURL?.stopAccessingSecurityScopedResource()
        }
        let bookmark = try directoryURL?.bookmarkData(options: options)
        try container.encodeIfPresent(bookmark, forKey: .directoryBookmark)
    }
    
    func hash(into hasher: inout Hasher) {
        directoryURL.hash(into: &hasher)
    }
}
