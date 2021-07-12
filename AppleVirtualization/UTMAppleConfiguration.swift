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
                return nil
            }
        }
        
        set {
            objectWillChange.send()
            apple.bootLoader = newValue?.vzBootloader(atBase: baseURL)
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
    
    var networkDevices: [Network] {
        get {
            apple.networkDevices.map { config in
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
        case cpuCount
        case memorySize
        case bootLoader
        case macPlatform
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
    
    enum DecodeError: Error {
        case invalidBaseURL
    }
    
    static var baseURL: CodingUserInfoKey {
        return CodingUserInfoKey(rawValue: "baseURL")!
    }
    
    init(at base: URL) {
        apple = VZVirtualMachineConfiguration()
        baseURL = base
        name = ""
        iconCustom = false
    }
    
    convenience init() {
        self.init(at: URL(fileURLWithPath: "/"))
    }
    
    required convenience init(from decoder: Decoder) throws {
        let baseURL = decoder.userInfo[Self.baseURL] as? URL
        guard let baseURL = baseURL else {
            throw DecodeError.invalidBaseURL
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
    }
    
    func resetDefaults() {
        memorySize = 4 * 1024 * 1024 * 1024
        cpuCount = 4
    }
}

struct Bootloader: Codable {
    enum OperatingSystem: String, Codable {
        case Linux
        case macOS
    }
    
    var operatingSystem: OperatingSystem
    var linuxKernelPath: String?
    var linuxCommandLine: String?
    var linuxInitialRamdiskPath: String?
    
    init(from linux: VZLinuxBootLoader) {
        self.operatingSystem = .Linux
        self.linuxKernelPath = linux.kernelURL.lastPathComponent
        self.linuxCommandLine = linux.commandLine
        self.linuxInitialRamdiskPath = linux.initialRamdiskURL?.lastPathComponent
    }
    
    func vzBootloader(atBase baseURL: URL) -> VZBootLoader? {
        switch operatingSystem {
        case .Linux:
            guard let linuxKernelPath = linuxKernelPath else {
                return nil
            }
            let kernelURL = baseURL.appendingPathComponent(linuxKernelPath)
            let linux = VZLinuxBootLoader(kernelURL: kernelURL)
            if let linuxInitialRamdiskPath = linuxInitialRamdiskPath {
                linux.initialRamdiskURL = baseURL.appendingPathComponent(linuxInitialRamdiskPath)
            }
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
    enum NetworkMode: String, Codable {
        case None
        case Shared
        case Bridged
    }
    
    var networkMode: NetworkMode
    var bridgeInterfaceIdentifier: String?
    var macAddress: String?
    
    init(from config: VZNetworkDeviceConfiguration) {
        guard let virtioConfig = config as? VZVirtioNetworkDeviceConfiguration else {
            self.networkMode = .None
            return
        }
        self.macAddress = virtioConfig.macAddress.string
        if let attachment = virtioConfig.attachment as? VZBridgedNetworkDeviceAttachment {
            self.networkMode = .Bridged
            self.bridgeInterfaceIdentifier = attachment.interface.identifier
        } else if let _ = virtioConfig.attachment as? VZNATNetworkDeviceAttachment {
            self.networkMode = .Shared
        } else {
            self.networkMode = .None
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
        case .None: break
        }
        return config
    }
}

@available(macOS 12, *)
struct Display: Codable {
    var widthInPixels: Int
    var heightInPixels: Int
    var pixelsPerInch: Int
    
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
    var auxiliaryStoragePath: String?
    
    init(newHardware: VZMacHardwareModel) {
        hardwareModel = newHardware.dataRepresentation
        machineIdentifier = VZMacMachineIdentifier().dataRepresentation
        auxiliaryStoragePath = "MacPlatformData"
    }
    
    init(from config: VZMacPlatformConfiguration) {
        hardwareModel = config.hardwareModel.dataRepresentation
        machineIdentifier = config.machineIdentifier.dataRepresentation
        auxiliaryStoragePath = config.auxiliaryStorage?.url.lastPathComponent
    }
    
    func vzMacPlatform(atBase baseURL: URL) -> VZMacPlatformConfiguration? {
        guard let vzHardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModel) else {
            return nil
        }
        guard let vzMachineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifier) else {
            return nil
        }
        var vzAuxiliaryStorage: VZMacAuxiliaryStorage?
        if let auxiliaryStoragePath = auxiliaryStoragePath {
            let auxiliaryStorageURL = baseURL.appendingPathComponent(auxiliaryStoragePath)
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

struct DiskImage: Codable, Hashable {
    var size: UInt64
    var isReadOnly: Bool
    var imagePath: String
    
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
    }
}
