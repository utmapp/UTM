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
import Virtualization

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
struct UTMAppleConfigurationBoot: Codable {
    enum OperatingSystem: String, CaseIterable, QEMUConstant {
        case none = "None"
        case linux = "Linux"
        case macOS = "macOS"
        
        var prettyValue: String {
            switch self {
            case .none: return NSLocalizedString("None", comment: "UTMAppleConfigurationBoot")
            case .linux: return NSLocalizedString("Linux", comment: "UTMAppleConfigurationBoot")
            case .macOS: return NSLocalizedString("macOS", comment: "UTMAppleConfigurationBoot")
            }
        }
    }
    
    var operatingSystem: OperatingSystem
    var linuxKernelURL: URL?
    var linuxCommandLine: String?
    var linuxInitialRamdiskURL: URL?
    var efiVariableStorageURL: URL?
    var vmSavedStateURL: URL?
    var hasUefiBoot: Bool = false
    
    /// IPSW for installing macOS. Not saved.
    var macRecoveryIpswURL: URL?
    
    private enum CodingKeys: String, CodingKey {
        case operatingSystem = "OperatingSystem"
        case linuxKernelPath = "LinuxKernelPath"
        case linuxCommandLine = "LinuxCommandLine"
        case linuxInitialRamdiskPath = "LinuxInitialRamdiskPath"
        case efiVariableStoragePath = "EfiVariableStoragePath"
        case hasUefiBoot = "UEFIBoot"
    }
    
    init(from decoder: Decoder) throws {
        guard let dataURL = decoder.userInfo[.dataURL] as? URL else {
            throw UTMConfigurationError.invalidDataURL
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operatingSystem = try container.decode(OperatingSystem.self, forKey: .operatingSystem)
        hasUefiBoot = try container.decodeIfPresent(Bool.self, forKey: .hasUefiBoot) ?? false
        #if !arch(arm64)
        if #available(macOS 12, *) {
        } else {
            guard operatingSystem != .macOS else {
                throw UTMAppleConfigurationError.platformUnsupported
            }
        }
        #endif
        if let linuxKernelPath = try container.decodeIfPresent(String.self, forKey: .linuxKernelPath) {
            linuxKernelURL = dataURL.appendingPathComponent(linuxKernelPath)
        }
        linuxCommandLine = try container.decodeIfPresent(String.self, forKey: .linuxCommandLine)
        if let linuxInitialRamdiskPath = try container.decodeIfPresent(String.self, forKey: .linuxInitialRamdiskPath) {
            linuxInitialRamdiskURL = dataURL.appendingPathComponent(linuxInitialRamdiskPath)
        }
        if let efiVariableStoragePath = try container.decodeIfPresent(String.self, forKey: .efiVariableStoragePath) {
            efiVariableStorageURL = dataURL.appendingPathComponent(efiVariableStoragePath)
        }
        vmSavedStateURL = dataURL.appendingPathComponent(QEMUPackageFileName.vmState.rawValue)
    }
    
    init(for operatingSystem: OperatingSystem, linuxKernelURL: URL? = nil) throws {
        self.operatingSystem = operatingSystem
        self.linuxKernelURL = linuxKernelURL
        if operatingSystem == .linux && linuxKernelURL == nil {
            self.hasUefiBoot = true
        }
    }
    
    init(from linux: VZLinuxBootLoader) {
        self.operatingSystem = .linux
        self.linuxKernelURL = linux.kernelURL
        self.linuxCommandLine = linux.commandLine
        self.linuxInitialRamdiskURL = linux.initialRamdiskURL
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operatingSystem, forKey: .operatingSystem)
        try container.encode(hasUefiBoot, forKey: .hasUefiBoot)
        if operatingSystem == .linux {
            try container.encodeIfPresent(linuxKernelURL?.lastPathComponent, forKey: .linuxKernelPath)
            try container.encodeIfPresent(linuxCommandLine, forKey: .linuxCommandLine)
            try container.encodeIfPresent(linuxInitialRamdiskURL?.lastPathComponent, forKey: .linuxInitialRamdiskPath)
            try container.encodeIfPresent(efiVariableStorageURL?.lastPathComponent, forKey: .efiVariableStoragePath)
        }
    }
    
    func vzBootloader() -> VZBootLoader? {
        switch operatingSystem {
        case .none:
            return nil
        case .linux:
            if #available(macOS 13, *), let efiVariableStorageURL = efiVariableStorageURL, hasUefiBoot {
                let efi = VZEFIBootLoader()
                efi.variableStore = VZEFIVariableStore(url: efiVariableStorageURL)
                return efi
            }
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

// MARK: - Conversion of old config format

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfigurationBoot {
    init(migrating oldBoot: Bootloader) {
        switch oldBoot.operatingSystem {
        case .macOS: operatingSystem = .macOS
        case .Linux: operatingSystem = .linux
        }
        linuxKernelURL = oldBoot.linuxKernelURL
        linuxCommandLine = oldBoot.linuxCommandLine
        linuxInitialRamdiskURL = oldBoot.linuxInitialRamdiskURL
    }
}

// MARK: - Saving data

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfigurationBoot {
    @MainActor mutating func saveData(to dataURL: URL) async throws -> [URL] {
        var urls = [URL]()
        if operatingSystem == .linux && !hasUefiBoot {
            guard let linuxKernelURL = linuxKernelURL else {
                throw UTMAppleConfigurationError.kernelNotSpecified
            }
            let kernelUrl = try await UTMAppleConfiguration.copyItemIfChanged(from: linuxKernelURL, to: dataURL)
            self.linuxKernelURL = kernelUrl
            urls.append(kernelUrl)
            if let linuxInitialRamdiskURL = linuxInitialRamdiskURL {
                let ramdiskUrl = try await UTMAppleConfiguration.copyItemIfChanged(from: linuxInitialRamdiskURL, to: dataURL)
                self.linuxInitialRamdiskURL = ramdiskUrl
                urls.append(ramdiskUrl)
            }
            self.efiVariableStorageURL = nil
        }
        if hasUefiBoot {
            guard #available(macOS 13, *) else {
                throw UTMAppleConfigurationError.platformUnsupported
            }
            let fileManager = FileManager.default
            let efiVariableStorageURL = dataURL.appendingPathComponent(QEMUPackageFileName.efiVariables.rawValue)
            if !fileManager.fileExists(atPath: efiVariableStorageURL.path) {
                _ = try VZEFIVariableStore(creatingVariableStoreAt: efiVariableStorageURL)
            }
            self.linuxKernelURL = nil
            self.linuxInitialRamdiskURL = nil
            self.linuxCommandLine = nil
            self.efiVariableStorageURL = efiVariableStorageURL
            urls.append(efiVariableStorageURL)
        }
        let vmSavedStateURL = dataURL.appendingPathComponent(QEMUPackageFileName.vmState.rawValue)
        self.vmSavedStateURL = vmSavedStateURL
        urls.append(vmSavedStateURL)
        return urls
    }
}
