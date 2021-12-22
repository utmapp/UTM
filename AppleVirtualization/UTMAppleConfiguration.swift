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

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
final class UTMAppleConfiguration: UTMConfigurable, Codable, ObservableObject {
    private let currentVersion = 3
    let apple: VZVirtualMachineConfiguration
    
    @Published var version: Int
    
    @Published var isAppleVirtualization: Bool
    
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
            if let macPlatform = newValue, let platform = macPlatform.vzMacPlatform() {
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
            apple.networkDevices = newValue.compactMap { network in
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
    
    @Published var diskImages: [DiskImage] = [] {
        didSet {
            apple.storageDevices = diskImages.compactMap({ diskImage in
                guard let attachment = try? diskImage.vzDiskImage() else {
                    return nil
                }
                return VZVirtioBlockDeviceConfiguration(attachment: attachment)
            })
        }
    }
    
    @available(macOS 12, *)
    var sharedDirectories: [SharedDirectory] {
        get {
            let fsConfig = apple.directorySharingDevices.first as? VZVirtioFileSystemDeviceConfiguration
            if let single = fsConfig?.share as? VZSingleDirectoryShare {
                return [SharedDirectory(from: single.directory)]
            } else if let multi = fsConfig?.share as? VZMultipleDirectoryShare {
                return multi.directories.values.map { directory in
                    SharedDirectory(from: directory)
                }
            } else {
                return []
            }
        }
        
        set {
            objectWillChange.send()
            let fsConfig = VZVirtioFileSystemDeviceConfiguration(tag: "Share")
            let vzSharedDirectories = newValue.compactMap { sharedDirectory in
                sharedDirectory.vzSharedDirectory()
            }
            if vzSharedDirectories.count == 1 {
                let single = VZSingleDirectoryShare(directory: vzSharedDirectories[0])
                fsConfig.share = single
                apple.directorySharingDevices = [fsConfig]
            } else if vzSharedDirectories.count > 1 {
                let directories = vzSharedDirectories.reduce(into: [String: VZSharedDirectory]()) { (dict, share) in
                    let lastPathComponent = share.url.lastPathComponent
                    var name = lastPathComponent
                    var i = 2
                    while dict.keys.contains(name) {
                        name = "\(lastPathComponent) (\(i))"
                        i += 1
                    }
                    dict[name] = share
                }
                let multi = VZMultipleDirectoryShare(directories: directories)
                fsConfig.share = multi
                apple.directorySharingDevices = [fsConfig]
            } else {
                apple.directorySharingDevices = []
            }
        }
    }
    
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
        case version
        case isAppleVirtualization
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
        case diskImages
        case sharedDirectories
        case isAudioEnabled
        case isBalloonEnabled
        case isEntropyEnabled
        case isSerialEnabled
        case isKeyboardEnabled
        case isPointingEnabled
    }
    
    init() {
        apple = VZVirtualMachineConfiguration()
        name = ""
        iconCustom = false
        consoleCursorBlink = true
        version = currentVersion
        isAppleVirtualization = true
        memorySize = 4 * 1024 * 1024 * 1024
        cpuCount = 4
    }
    
    required convenience init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        isAppleVirtualization = try values.decode(Bool.self, forKey: .isAppleVirtualization)
        guard isAppleVirtualization else {
            throw ConfigError.notAppleConfiguration
        }
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
                macRecoveryIpswURL = try? URL(resolvingBookmarkData: recoveryIpswBookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
            }
            displays = try values.decode([Display].self, forKey: .displays)
            sharedDirectories = try values.decode([SharedDirectory].self, forKey: .sharedDirectories)
            isAudioEnabled = try values.decode(Bool.self, forKey: .isAudioEnabled)
            isKeyboardEnabled = try values.decode(Bool.self, forKey: .isKeyboardEnabled)
            isPointingEnabled = try values.decode(Bool.self, forKey: .isPointingEnabled)
        }
        diskImages = try values.decode([DiskImage].self, forKey: .diskImages)
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
            _ = macRecoveryIpswURL?.startAccessingSecurityScopedResource()
            defer {
                macRecoveryIpswURL?.stopAccessingSecurityScopedResource()
            }
            let recoveryIpswBookmark = try macRecoveryIpswURL?.bookmarkData(options: .withSecurityScope)
            try container.encodeIfPresent(recoveryIpswBookmark, forKey: .macRecoveryIpswBookmark)
            try container.encode(displays, forKey: .displays)
            try container.encode(sharedDirectories, forKey: .sharedDirectories)
            try container.encode(isAudioEnabled, forKey: .isAudioEnabled)
            try container.encode(isKeyboardEnabled, forKey: .isKeyboardEnabled)
            try container.encode(isPointingEnabled, forKey: .isPointingEnabled)
        }
        try container.encode(diskImages, forKey: .diskImages)
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
    
    static func load(from packageURL: URL) throws -> UTMAppleConfiguration {
        let dataURL = packageURL.appendingPathComponent("Data")
        let configURL = packageURL.appendingPathComponent(kUTMBundleConfigFilename)
        let configData = try Data(contentsOf: configURL)
        let decoder = PropertyListDecoder()
        decoder.userInfo = [.dataURL: dataURL]
        return try decoder.decode(UTMAppleConfiguration.self, from: configData)
    }
    
    func save(to packageURL: URL) throws {
        let fileManager = FileManager.default
        // create package directory
        if !fileManager.fileExists(atPath: packageURL.path) {
            try fileManager.createDirectory(at: packageURL, withIntermediateDirectories: false)
        }
        // create data directory
        let dataURL = packageURL.appendingPathComponent("Data")
        if !fileManager.fileExists(atPath: dataURL.path) {
            try fileManager.createDirectory(at: dataURL, withIntermediateDirectories: false)
        }
        var existingDataURLs = [URL]()
        existingDataURLs += try saveIcon(to: dataURL)
        existingDataURLs += try saveBootloader(to: dataURL)
        existingDataURLs += try saveImportedDrives(to: dataURL)
        // cleanup any files before creating new drives
        try cleanupAllFiles(at: dataURL, notIncluding: existingDataURLs)
        // create new drives
        existingDataURLs += try createNewDrives(at: dataURL)
        // create config.plist
        let encoder = PropertyListEncoder()
        let settingsData = try encoder.encode(self)
        try settingsData.write(to: packageURL.appendingPathComponent(kUTMBundleConfigFilename))
    }
    
    private func copyItemIfChanged(from sourceURL: URL, to destFolderURL: URL) throws -> URL {
        _ = sourceURL.startAccessingSecurityScopedResource()
        defer {
            sourceURL.stopAccessingSecurityScopedResource()
        }
        let fileManager = FileManager.default
        let destURL = destFolderURL.appendingPathComponent(sourceURL.lastPathComponent)
        // check if both are same file
        if fileManager.fileExists(atPath: destURL.path) {
            let sourceRef = try sourceURL.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
            let destRef = try destURL.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
            if sourceRef?.isEqual(destRef) ?? false {
                return destURL
            }
            if fileManager.contentsEqual(atPath: sourceURL.path, andPath: destURL.path) {
                return destURL
            }
        }
        try fileManager.copyItem(at: sourceURL, to: destURL)
        return destURL
    }
    
    private func saveIcon(to dataURL: URL) throws -> [URL] {
        // save new icon
        if iconCustom {
            if let iconURL = selectedCustomIconPath {
                icon = iconURL.lastPathComponent
                return [try copyItemIfChanged(from: iconURL, to: dataURL)]
            } else if let existingName = icon {
                return [dataURL.appendingPathComponent(existingName)]
            } else {
                throw ConfigError.customIconInvalid
            }
        }
        return []
    }
    
    private func saveBootloader(to dataURL: URL) throws -> [URL] {
        let fileManager = FileManager.default
        var urls = [URL]()
        if bootLoader != nil && bootLoader!.operatingSystem == .Linux {
            guard let linuxKernelURL = bootLoader!.linuxKernelURL else {
                throw ConfigError.kernelNotSpecified
            }
            bootLoader!.linuxKernelURL = try copyItemIfChanged(from: linuxKernelURL, to: dataURL)
            urls.append(bootLoader!.linuxKernelURL!)
            if let linuxInitialRamdiskURL = bootLoader!.linuxInitialRamdiskURL {
                bootLoader!.linuxInitialRamdiskURL = try copyItemIfChanged(from: linuxInitialRamdiskURL, to: dataURL)
                urls.append(bootLoader!.linuxInitialRamdiskURL!)
            }
        }
        #if arch(arm64)
        if #available(macOS 12, *), macPlatform != nil {
            let auxStorageURL = dataURL.appendingPathComponent("AuxiliaryStorage")
            if !fileManager.fileExists(atPath: auxStorageURL.path) {
                guard let hwModel = VZMacHardwareModel(dataRepresentation: macPlatform!.hardwareModel) else {
                    throw ConfigError.hardwareModelInvalid
                }
                _ = try VZMacAuxiliaryStorage(creatingStorageAt: auxStorageURL, hardwareModel: hwModel, options: [])
                macPlatform!.auxiliaryStorageURL = auxStorageURL
            }
            urls.append(auxStorageURL)
        }
        #endif
        return urls
    }
    
    private func saveImportedDrives(to dataURL: URL) throws -> [URL] {
        var urls = [URL]()
        for i in diskImages.indices {
            if !diskImages[i].isExternal, let imageURL = diskImages[i].imageURL {
                let newUrl = try copyItemIfChanged(from: imageURL, to: dataURL)
                diskImages[i].imageURL = newUrl
                urls.append(newUrl)
            }
        }
        return urls
    }
    
    private func cleanupAllFiles(at dataURL: URL, notIncluding urls: [URL]) throws {
        let fileManager = FileManager.default
        let existingNames = urls.map { url in
            url.lastPathComponent
        }
        let dataFileURLs = try fileManager.contentsOfDirectory(at: dataURL, includingPropertiesForKeys: nil)
        for dataFileURL in dataFileURLs {
            if !existingNames.contains(dataFileURL.lastPathComponent) {
                try fileManager.removeItem(at: dataFileURL)
            }
        }
    }
    
    private func createNewDrives(at dataURL: URL) throws -> [URL] {
        var urls = [URL]()
        for i in diskImages.indices {
            if diskImages[i].imageURL == nil {
                // TODO: implement new drive creation
            }
        }
        return urls
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
            throw ConfigError.invalidDataURL
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
    var macAddress: String
    
    init(newInterfaceForMode networkMode: NetworkMode) {
        self.networkMode = networkMode
        self.macAddress = VZMACAddress.randomLocallyAdministered().string
    }
    
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
    
    func vzNetworking() -> VZNetworkDeviceConfiguration? {
        let config = VZVirtioNetworkDeviceConfiguration()
        guard let macAddress = VZMACAddress(string: macAddress) else {
            return nil
        }
        config.macAddress = macAddress
        switch networkMode {
        case .Shared:
            let attachment = VZNATNetworkDeviceAttachment()
            config.attachment = attachment
        case .Bridged:
            var found: VZBridgedNetworkInterface?
            for interface in VZBridgedNetworkInterface.networkInterfaces.reversed() {
                // this defaults to first interface if not found
                found = interface
                if interface.identifier == bridgeInterfaceIdentifier {
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
        guard let dataURL = decoder.userInfo[.dataURL] as? URL else {
            throw ConfigError.invalidDataURL
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hardwareModel = try container.decode(Data.self, forKey: .hardwareModel)
        machineIdentifier = try container.decode(Data.self, forKey: .machineIdentifier)
        if let auxiliaryStoragePath = try container.decodeIfPresent(String.self, forKey: .auxiliaryStoragePath) {
            auxiliaryStorageURL = dataURL.appendingPathComponent(auxiliaryStoragePath)
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
    
    func vzMacPlatform() -> VZMacPlatformConfiguration? {
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
    
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeMib) * Int64(bytesInMib), countStyle: .file)
    }
    
    init(newSize: Int) {
        sizeMib = newSize
        isReadOnly = false
        isExternal = false
    }
    
    init(importImage url: URL, isReadOnly: Bool = false, isExternal: Bool = false) {
        self.imageURL = url
        self.isReadOnly = isReadOnly
        self.isExternal = isExternal
        if let attributes = try? url.resourceValues(forKeys: [.fileSizeKey]), let fileSize = attributes.fileSize {
            sizeMib = fileSize / bytesInMib
        } else {
            sizeMib = 0
        }
    }
    
    init(from decoder: Decoder) throws {
        guard let dataURL = decoder.userInfo[.dataURL] as? URL else {
            throw ConfigError.invalidDataURL
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
    
    func vzDiskImage() throws -> VZDiskImageStorageDeviceAttachment? {
        if let imageURL = imageURL {
            return try VZDiskImageStorageDeviceAttachment(url: imageURL, readOnly: isReadOnly)
        } else {
            return nil
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

@available(macOS 12, *)
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
    
    init(directoryURL: URL, isReadOnly: Bool = false) {
        self.directoryURL = directoryURL
        self.isReadOnly = isReadOnly
    }
    
    init(from config: VZSharedDirectory) {
        self.isReadOnly = config.isReadOnly
        self.directoryURL = config.url
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
    
    func vzSharedDirectory() -> VZSharedDirectory? {
        if let directoryURL = directoryURL {
            return VZSharedDirectory(url: directoryURL, readOnly: isReadOnly)
        } else {
            return nil
        }
    }
}

fileprivate enum ConfigError: Error {
    case notAppleConfiguration
    case invalidDataURL
    case kernelNotSpecified
    case customIconInvalid
    case hardwareModelInvalid
}

fileprivate extension CodingUserInfoKey {
    static var dataURL: CodingUserInfoKey {
        return CodingUserInfoKey(rawValue: "dataURL")!
    }
}
