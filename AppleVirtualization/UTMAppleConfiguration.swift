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
import Virtualization

@available(macOS 11, *)
final class UTMAppleConfiguration: UTMConfigurable, Codable, ObservableObject {
    let apple: VZVirtualMachineConfiguration
    
    let baseURL: URL
    
    @Published var name: String
    
    @Published var existingPath: URL?
    
    @Published var selectedCustomIconPath: URL?
    
    @Published var icon: String?
    
    @Published var iconCustom: Bool
    
    @Published var notes: String?
    
    @Published var consoleTheme: String?
    
    @Published var consoleFont: String?
    
    @Published var consoleFontSize: NSNumber?
    
    @Published var consoleCursorBlink: Bool
    
    @Published var consoleResizeCommand: String?
    
    var cpuCount: Int {
        get {
            apple.cpuCount
        }
        
        set {
            objectWillChange.send()
            apple.cpuCount = newValue
        }
    }
    
    var memorySize: UInt64 {
        get {
            apple.memorySize
        }
        
        set {
            objectWillChange.send()
            apple.memorySize = newValue
        }
    }
    
    var bootLoader: Bootloader? {
        get {
            if let linux = apple.bootLoader as? VZLinuxBootLoader {
                return Bootloader(from: linux)
            } else {
                #if arch(arm64)
                if #available(macOS 12, *), let _ = apple.bootLoader as? VZMacOSBootLoader {
                    return try? Bootloader(for: .macOS)
                }
                #endif
                return nil
            }
        }
        
        set {
            objectWillChange.send()
            apple.bootLoader = newValue?.vzBootloader()
        }
    }
    
    var linuxCommandLine: String {
        get {
            if let linux = apple.bootLoader as? VZLinuxBootLoader {
                return linux.commandLine
            } else {
                return ""
            }
        }
        
        set {
            if let linux = apple.bootLoader as? VZLinuxBootLoader {
                objectWillChange.send()
                linux.commandLine = newValue
            }
        }
    }
    
    #if arch(arm64)
    @available(macOS 12, *)
    var macPlatform: MacPlatform? {
        get {
            guard let config = apple.platform as? VZMacPlatformConfiguration else {
                return nil
            }
            return MacPlatform(from: config)
        }
        
        set {
            objectWillChange.send()
            if let macPlatform = newValue, let platform = macPlatform.vzMacPlatform(atBase: baseURL) {
                apple.platform = platform
            } else {
                apple.platform = VZGenericPlatformConfiguration()
            }
        }
    }
    #endif
    
    @available(macOS 12, *)
    @Published var macRecoveryIpswURL: URL?
    
    var networkDevices: [Network] {
        get {
            apple.networkDevices.compactMap { config in
                Network(from: config)
            }
        }
        
        set {
            objectWillChange.send()
            apple.networkDevices = newValue.map { network in
                network.vzNetworking()
            }
        }
    }
    
    @available(macOS 12, *)
    var displays: [Display] {
        get {
            guard let graphics = apple.graphicsDevices.first as? VZMacGraphicsDeviceConfiguration else {
                return []
            }
            return graphics.displays.map { display in
                Display(from: display)
            }
        }
        
        set {
            objectWillChange.send()
            guard !newValue.isEmpty else {
                apple.graphicsDevices = []
                return
            }
            let graphics = VZMacGraphicsDeviceConfiguration()
            graphics.displays = newValue.map({ display in
                display.vzDisplay()
            })
            apple.graphicsDevices = [graphics]
        }
    }
    
    @Published var storageAttachments: [DiskImage] = []
    
    var storageAttachmentsToDelete: Set<DiskImage> = Set()
    
    @Published var numberOfDirectoryShares: Int = 0
    
    @available(macOS 12, *)
    var isAudioEnabled: Bool {
        get {
            !apple.audioDevices.isEmpty
        }
        
        set {
            objectWillChange.send()
            if newValue {
                let audioConfiguration = VZVirtioSoundDeviceConfiguration()
                let audioInput = VZVirtioSoundDeviceInputStreamConfiguration()
                audioInput.source = VZHostAudioInputStreamSource()
                let audioOutput = VZVirtioSoundDeviceOutputStreamConfiguration()
                audioOutput.sink = VZHostAudioOutputStreamSink()
                audioConfiguration.streams = [audioInput, audioOutput]
                apple.audioDevices = [audioConfiguration]
            } else {
                apple.audioDevices = []
            }
        }
    }
    
    var isBalloonEnabled: Bool {
        get {
            !apple.memoryBalloonDevices.isEmpty
        }
        
        set {
            objectWillChange.send()
            if newValue {
                apple.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
            } else {
                apple.memoryBalloonDevices = []
            }
        }
    }
    
    var isEntropyEnabled: Bool {
        get {
            !apple.entropyDevices.isEmpty
        }
        
        set {
            objectWillChange.send()
            if newValue {
                apple.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
            } else {
                apple.entropyDevices = []
            }
        }
    }
    
    var isSerialEnabled: Bool {
        get {
            !apple.serialPorts.isEmpty
        }
        
        set {
            objectWillChange.send()
            if newValue {
                apple.serialPorts = [VZVirtioConsoleDeviceSerialPortConfiguration()]
            } else {
                apple.serialPorts = []
            }
        }
    }
    
    @available(macOS 12, *)
    var isKeyboardEnabled: Bool {
        get {
            !apple.keyboards.isEmpty
        }
        
        set {
            objectWillChange.send()
            if newValue {
                apple.keyboards = [VZUSBKeyboardConfiguration()]
            } else {
                apple.keyboards = []
            }
        }
    }
    
    @available(macOS 12, *)
    var isPointingEnabled: Bool {
        get {
            !apple.pointingDevices.isEmpty
        }
        
        set {
            objectWillChange.send()
            if newValue {
                apple.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
            } else {
                apple.pointingDevices = []
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case icon
        case iconCustom
        case notes
        case consoleTheme
        case consoleFont
        case consoleFontSize
        case consoleCursorBlink
        case consoleResizeCommand
        case cpuCount
        case memorySize
        case bootLoader
        case macPlatform
        case macRecoveryIpswBookmark
        case networkDevices
        case displays
        case numberOfDirectoryShares
        case isAudioEnabled
        case isBalloonEnabled
        case isEntropyEnabled
        case isSerialEnabled
        case isKeyboardEnabled
        case isPointingEnabled
    }
    
    init(at base: URL) {
        apple = VZVirtualMachineConfiguration()
        baseURL = base
        name = ""
        iconCustom = false
        consoleCursorBlink = true
    }
    
    convenience init() {
        self.init(at: URL(fileURLWithPath: "/"))
    }
    
    required convenience init(from decoder: Decoder) throws {
        let baseURL = decoder.userInfo[.baseURL] as? URL
        guard let baseURL = baseURL else {
            throw ConfigError.invalidBaseURL
        }
        self.init(at: baseURL)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cpuCount = try values.decode(Int.self, forKey: .cpuCount)
        memorySize = try values.decode(UInt64.self, forKey: .memorySize)
        bootLoader = try values.decodeIfPresent(Bootloader.self, forKey: .bootLoader)
        networkDevices = try values.decode([Network].self, forKey: .networkDevices)
        if #available(macOS 12, *) {
            #if arch(arm64)
            macPlatform = try values.decodeIfPresent(MacPlatform.self, forKey: .macPlatform)
            #endif
            if let recoveryIpswBookmark = try values.decodeIfPresent(Data.self, forKey: .macRecoveryIpswBookmark) {
                var stale: Bool = false
                macRecoveryIpswURL = try URL(resolvingBookmarkData: recoveryIpswBookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
            }
            displays = try values.decode([Display].self, forKey: .displays)
            isAudioEnabled = try values.decode(Bool.self, forKey: .isAudioEnabled)
            isKeyboardEnabled = try values.decode(Bool.self, forKey: .isKeyboardEnabled)
            isPointingEnabled = try values.decode(Bool.self, forKey: .isPointingEnabled)
        }
        numberOfDirectoryShares = try values.decode(Int.self, forKey: .numberOfDirectoryShares)
        isBalloonEnabled = try values.decode(Bool.self, forKey: .isBalloonEnabled)
        isEntropyEnabled = try values.decode(Bool.self, forKey: .isEntropyEnabled)
        isSerialEnabled = try values.decode(Bool.self, forKey: .isSerialEnabled)
        name = try values.decode(String.self, forKey: .name)
        icon = try values.decodeIfPresent(String.self, forKey: .icon)
        iconCustom = try values.decode(Bool.self, forKey: .iconCustom)
        notes = try values.decodeIfPresent(String.self, forKey: .notes)
        consoleTheme = try values.decodeIfPresent(String.self, forKey: .consoleTheme)
        consoleFont = try values.decodeIfPresent(String.self, forKey: .consoleFont)
        let fontSize = try values.decodeIfPresent(Int.self, forKey: .consoleFontSize)
        if let fontSize = fontSize {
            consoleFontSize = NSNumber(value: fontSize)
        } else {
            consoleFontSize = nil
        }
        consoleCursorBlink = try values.decode(Bool.self, forKey: .consoleCursorBlink)
        consoleResizeCommand = try values.decodeIfPresent(String.self, forKey: .consoleResizeCommand)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cpuCount, forKey: .cpuCount)
        try container.encode(memorySize, forKey: .memorySize)
        try container.encodeIfPresent(bootLoader, forKey: .bootLoader)
        try container.encode(networkDevices, forKey: .networkDevices)
        if #available(macOS 12, *) {
            #if arch(arm64)
            try container.encodeIfPresent(macPlatform, forKey: .macPlatform)
            #endif
            let recoveryIpswBookmark = try macRecoveryIpswURL?.bookmarkData(options: .withSecurityScope)
            try container.encodeIfPresent(recoveryIpswBookmark, forKey: .macRecoveryIpswBookmark)
            try container.encode(displays, forKey: .displays)
            try container.encode(isAudioEnabled, forKey: .isAudioEnabled)
            try container.encode(isKeyboardEnabled, forKey: .isKeyboardEnabled)
            try container.encode(isPointingEnabled, forKey: .isPointingEnabled)
        }
        try container.encode(numberOfDirectoryShares, forKey: .numberOfDirectoryShares)
        try container.encode(isBalloonEnabled, forKey: .isBalloonEnabled)
        try container.encode(isEntropyEnabled, forKey: .isEntropyEnabled)
        try container.encode(isSerialEnabled, forKey: .isSerialEnabled)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(iconCustom, forKey: .iconCustom)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(consoleTheme, forKey: .consoleTheme)
        try container.encodeIfPresent(consoleFont, forKey: .consoleFont)
        try container.encodeIfPresent(consoleFontSize?.intValue, forKey: .consoleFontSize)
        try container.encode(consoleCursorBlink, forKey: .consoleCursorBlink)
        try container.encodeIfPresent(consoleResizeCommand, forKey: .consoleResizeCommand)
    }
    
    func resetDefaults() {
        memorySize = 4 * 1024 * 1024 * 1024
        cpuCount = 4
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
        guard let baseURL = decoder.userInfo[.baseURL] as? URL else {
            throw ConfigError.invalidBaseURL
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operatingSystem = try container.decode(OperatingSystem.self, forKey: .operatingSystem)
        if let linuxKernelPath = try container.decodeIfPresent(String.self, forKey: .linuxKernelPath) {
            linuxKernelURL = baseURL.appendingPathComponent(linuxKernelPath)
        }
        linuxCommandLine = try container.decodeIfPresent(String.self, forKey: .linuxCommandLine)
        if let linuxInitialRamdiskPath = try container.decodeIfPresent(String.self, forKey: .linuxInitialRamdiskPath) {
            linuxInitialRamdiskURL = baseURL.appendingPathComponent(linuxInitialRamdiskPath)
        }
    }
    
    init(for operatingSystem: OperatingSystem, linuxKernelURL: URL? = nil) throws {
        self.operatingSystem = operatingSystem
        self.linuxKernelURL = linuxKernelURL
        if operatingSystem == .Linux && linuxKernelURL == nil {
            throw ConfigError.kernelNotSpecified
        }
    }
    
    init(from linux: VZLinuxBootLoader) {
        self.operatingSystem = .Linux
        self.linuxKernelURL = linux.kernelURL
        self.linuxCommandLine = linux.commandLine
        self.linuxInitialRamdiskURL = linux.initialRamdiskURL
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operatingSystem, forKey: .operatingSystem)
        try container.encodeIfPresent(linuxKernelURL?.lastPathComponent, forKey: .linuxKernelPath)
        try container.encodeIfPresent(linuxCommandLine, forKey: .linuxCommandLine)
        try container.encodeIfPresent(linuxInitialRamdiskURL?.lastPathComponent, forKey: .linuxInitialRamdiskPath)
    }
    
    func vzBootloader() -> VZBootLoader? {
        switch operatingSystem {
        case .Linux:
            guard let linuxKernelURL = linuxKernelURL else {
                return nil
            }
            let linux = VZLinuxBootLoader(kernelURL: linuxKernelURL)
            linux.initialRamdiskURL = linuxInitialRamdiskURL
            if let linuxCommandLine = linuxCommandLine {
                linux.commandLine = linuxCommandLine
            }
            return linux
        case .macOS:
            #if arch(arm64)
            if #available(macOS 12, *) {
                return VZMacOSBootLoader()
            }
            #endif
            return nil
        }
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
    var macAddress: String?
    
    init?(from config: VZNetworkDeviceConfiguration) {
        guard let virtioConfig = config as? VZVirtioNetworkDeviceConfiguration else {
            return nil
        }
        self.macAddress = virtioConfig.macAddress.string
        if let attachment = virtioConfig.attachment as? VZBridgedNetworkDeviceAttachment {
            self.networkMode = .Bridged
            self.bridgeInterfaceIdentifier = attachment.interface.identifier
        } else if let _ = virtioConfig.attachment as? VZNATNetworkDeviceAttachment {
            self.networkMode = .Shared
        } else {
            return nil
        }
    }
    
    func vzNetworking() -> VZNetworkDeviceConfiguration {
        let config = VZVirtioNetworkDeviceConfiguration()
        if let macAddress = macAddress {
            config.macAddress = VZMACAddress(string: macAddress) ?? .randomLocallyAdministered()
        } else {
            config.macAddress = .randomLocallyAdministered()
        }
        switch networkMode {
        case .Shared:
            let attachment = VZNATNetworkDeviceAttachment()
            config.attachment = attachment
        case .Bridged:
            var found: VZBridgedNetworkInterface?
            for interface in VZBridgedNetworkInterface.networkInterfaces {
                if interface.identifier == bridgeInterfaceIdentifier {
                    found = interface
                    break
                }
            }
            if let found = found {
                let attachment = VZBridgedNetworkDeviceAttachment(interface: found)
                config.attachment = attachment
            }
        }
        return config
    }
}

@available(macOS 12, *)
struct Display: Codable {
    struct Resolution: Hashable {
        var width: Int
        var height: Int
        func hash(into hasher: inout Hasher) {
            hasher.combine(width)
            hasher.combine(height)
        }
    }
    
    var widthInPixels: Int
    var heightInPixels: Int
    var pixelsPerInch: Int
    
    init(for resolution: Resolution, isHidpi: Bool) {
        self.widthInPixels = resolution.width
        self.heightInPixels = resolution.height
        self.pixelsPerInch = isHidpi ? 226 : 80
    }
    
    init(from config: VZMacGraphicsDisplayConfiguration) {
        self.widthInPixels = config.widthInPixels
        self.heightInPixels = config.heightInPixels
        self.pixelsPerInch = config.pixelsPerInch
    }
    
    func vzDisplay() -> VZMacGraphicsDisplayConfiguration {
        VZMacGraphicsDisplayConfiguration(widthInPixels: widthInPixels,
                                          heightInPixels: heightInPixels,
                                          pixelsPerInch: pixelsPerInch)
    }
}

#if arch(arm64)
@available(macOS 12, *)
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
        guard let baseURL = decoder.userInfo[.baseURL] as? URL else {
            throw ConfigError.invalidBaseURL
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hardwareModel = try container.decode(Data.self, forKey: .hardwareModel)
        machineIdentifier = try container.decode(Data.self, forKey: .machineIdentifier)
        if let auxiliaryStoragePath = try container.decodeIfPresent(String.self, forKey: .auxiliaryStoragePath) {
            auxiliaryStorageURL = baseURL.appendingPathComponent(auxiliaryStoragePath)
        }
    }
    
    init(newHardware: VZMacHardwareModel) {
        hardwareModel = newHardware.dataRepresentation
        machineIdentifier = VZMacMachineIdentifier().dataRepresentation
    }
    
    init(from config: VZMacPlatformConfiguration) {
        hardwareModel = config.hardwareModel.dataRepresentation
        machineIdentifier = config.machineIdentifier.dataRepresentation
        auxiliaryStorageURL = config.auxiliaryStorage?.url
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hardwareModel, forKey: .hardwareModel)
        try container.encode(machineIdentifier, forKey: .machineIdentifier)
        try container.encodeIfPresent(auxiliaryStorageURL?.lastPathComponent, forKey: .auxiliaryStoragePath)
    }
    
    func vzMacPlatform(atBase baseURL: URL) -> VZMacPlatformConfiguration? {
        guard let vzHardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModel) else {
            return nil
        }
        guard let vzMachineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifier) else {
            return nil
        }
        var vzAuxiliaryStorage: VZMacAuxiliaryStorage?
        if let auxiliaryStorageURL = auxiliaryStorageURL {
            vzAuxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: auxiliaryStorageURL)
        }
        let config = VZMacPlatformConfiguration()
        config.hardwareModel = vzHardwareModel
        config.machineIdentifier = vzMachineIdentifier
        config.auxiliaryStorage = vzAuxiliaryStorage
        return config
    }
}
#endif

struct DiskImage: Codable, Hashable, Identifiable {
    var size: UInt64
    var isReadOnly: Bool
    var imagePath: String
    
    var id: Int {
        hashValue
    }
    
    init(newSize: UInt64) {
        size = newSize
        isReadOnly = false
        imagePath = UUID().uuidString + ".dmg"
    }
    
    func vzDiskImage(atBase baseURL: URL) throws -> VZDiskImageStorageDeviceAttachment? {
        let url = baseURL.appendingPathComponent(imagePath)
        return try VZDiskImageStorageDeviceAttachment(url: url, readOnly: isReadOnly)
    }
    
    func hash(into hasher: inout Hasher) {
        imagePath.hash(into: &hasher)
        size.hash(into: &hasher)
        isReadOnly.hash(into: &hasher)
    }
}

fileprivate enum ConfigError: Error {
    case invalidBaseURL
    case kernelNotSpecified
}

fileprivate extension CodingUserInfoKey {
    static var baseURL: CodingUserInfoKey {
        return CodingUserInfoKey(rawValue: "baseURL")!
    }
}
