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

/// Bridge from Swift configuration backend to Objective-C
/// This should be temporary and be removed after the Objective-C backend is fully migrated.
@objc class UTMConfigurationWrapper: NSObject {
    #if !os(macOS)
    typealias UTMAppleConfiguration = UTMQemuConfiguration
    #endif
    
    private(set) var wrappedValue: Any?
    private var placeholderName: String?
    private var placeholderUuid: UUID?
    private var placeholderIconURL: URL?
    
    var qemuConfig: UTMQemuConfiguration? {
        wrappedValue as? UTMQemuConfiguration
    }
    
    var appleConfig: UTMAppleConfiguration? {
        wrappedValue as? UTMAppleConfiguration
    }
    
    @objc var isAppleVirtualization: Bool {
        wrappedValue is UTMAppleConfiguration
    }
    
    @objc var name: String {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.information.name
        } else if wrappedValue is UTMAppleConfiguration {
            return appleConfig!.information.name
        } else if let placeholderName = placeholderName {
            return placeholderName
        } else {
            fatalError()
        }
    }
    
    @objc var uuid: UUID {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.information.uuid
        } else if wrappedValue is UTMAppleConfiguration {
            return appleConfig!.information.uuid
        } else if let placeholderUuid = placeholderUuid {
            return placeholderUuid
        } else {
            fatalError()
        }
    }
    
    @objc var iconURL: URL? {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.information.iconURL
        } else if wrappedValue is UTMAppleConfiguration {
            return appleConfig!.information.iconURL
        } else {
            return placeholderIconURL
        }
    }
    
    @objc var qemuHasDebugLog: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.qemu.hasDebugLog
        } else if wrappedValue is UTMAppleConfiguration {
            return false
        } else {
            fatalError()
        }
    }
    
    @objc var qemuDebugLogURL: URL? {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.qemu.debugLogURL
        } else {
            fatalError()
        }
    }
    
    @objc var qemuArchitecture: String {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.system.architecture.rawValue
        } else {
            fatalError()
        }
    }
    
    @objc var qemuArguments: [String] {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.allArguments.map({ $0.string })
        } else {
            fatalError()
        }
    }
    
    @objc var qemuResources: [URL] {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.allArguments.compactMap({ $0.fileUrls }).flatMap({ $0 })
        } else {
            fatalError()
        }
    }
    
    @objc var qemuIsDisposable: Bool {
        get {
            if wrappedValue is UTMQemuConfiguration {
                return qemuConfig!.qemu.isDisposable
            } else {
                fatalError()
            }
        }
        
        set {
            if wrappedValue is UTMQemuConfiguration {
                qemuConfig!.qemu.isDisposable = newValue
            } else {
                fatalError()
            }
        }
    }
    
    @objc var qemuSnapshotName: String? {
        get {
            if wrappedValue is UTMQemuConfiguration {
                return qemuConfig!.qemu.snapshotName
            } else {
                fatalError()
            }
        }
        
        set {
            if wrappedValue is UTMQemuConfiguration {
                qemuConfig!.qemu.snapshotName = newValue
            } else {
                fatalError()
            }
        }
    }
    
    @objc var qemuSpiceSocketURL: URL {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.spiceSocketURL
        } else {
            fatalError()
        }
    }
    
    @objc var qemuInputLegacy: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.input.usbBusSupport == .disabled || qemuConfig!.qemu.hasPS2Controller
        } else {
            fatalError()
        }
    }
    
    //FIXME: support multiple sound cards
    @objc var qemuHasAudio: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return !qemuConfig!.sound.isEmpty
        } else {
            fatalError()
        }
    }
    
    //FIXME: support multiple displays
    @objc var qemuHasDisplay: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return !qemuConfig!.displays.isEmpty
        } else {
            fatalError()
        }
    }
    
    @objc var qemuDisplayUpscaler: MTLSamplerMinMagFilter {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.displays.first!.upscalingFilter.metalSamplerMinMagFilter
        } else {
            fatalError()
        }
    }
    
    @objc var qemuDisplayDownscaler: MTLSamplerMinMagFilter {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.displays.first!.downscalingFilter.metalSamplerMinMagFilter
        } else {
            fatalError()
        }
    }
    
    @objc var qemuDisplayIsDynamicResolution: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.displays.first!.isDynamicResolution
        } else {
            fatalError()
        }
    }
    
    @objc var qemuDisplayIsNativeResolution: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.displays.first!.isNativeResolution
        } else {
            fatalError()
        }
    }
    
    @objc var qemuHasClipboardSharing: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.sharing.hasClipboardSharing
        } else {
            fatalError()
        }
    }
    
    @objc var qemuHasWebdavSharing: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.sharing.directoryShareMode == .webdav
        } else {
            fatalError()
        }
    }
    
    @objc var qemuIsDirectoryShareReadOnly: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.sharing.isDirectoryShareReadOnly
        } else {
            fatalError()
        }
    }
    
    @objc var qemuConsoleBackgroundColor: String {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.serials.first!.terminal!.backgroundColor ?? "#000000"
        } else {
            fatalError()
        }
    }
    
    @objc var qemuConsoleForegroundColor: String {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.serials.first!.terminal!.foregroundColor ?? "#ffffff"
        } else {
            fatalError()
        }
    }
    
    @objc var qemuConsoleFont: String {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.serials.first!.terminal!.font.rawValue
        } else {
            fatalError()
        }
    }
    
    @objc var qemuConsoleFontSize: Int {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.serials.first!.terminal!.fontSize
        } else {
            fatalError()
        }
    }
    
    @objc var qemuConsoleResizeCommand: String? {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.serials.first!.terminal!.resizeCommand
        } else {
            fatalError()
        }
    }
    
    init<Config: UTMConfiguration>(wrapping config: Config) {
        self.wrappedValue = config
    }
    
    @objc init?(from packageURL: URL) {
        if let config = try? UTMQemuConfiguration.load(from: packageURL) {
            self.wrappedValue = config
        } else {
            return nil
        }
    }
    
    @objc init(placeholderFor name: String) {
        self.placeholderName = name
        self.placeholderUuid = UUID()
        self.placeholderIconURL = nil
    }
    
    @objc func reload(from packageURL: URL) throws {
        self.wrappedValue = try UTMQemuConfiguration.load(from: packageURL)
    }
    
    @objc func save(to packageURL: URL) async throws {
        if wrappedValue is UTMQemuConfiguration {
            try await qemuConfig!.save(to: packageURL)
        } else if wrappedValue is UTMAppleConfiguration {
            try await appleConfig!.save(to: packageURL)
        } else {
            fatalError()
        }
    }
    
    @objc func qemuEnsureEfiVarsAvailable(completion: @escaping (Error?) -> Void) {
        guard let qemuConfig = qemuConfig, let efiVarsURL = qemuConfig.qemu.efiVarsURL else {
            completion(nil)
            return
        }
        guard qemuConfig.isLegacy else {
            completion(nil)
            return
        }
        Task {
            do {
                _ = try await qemuConfig.qemu.saveData(to: efiVarsURL.deletingLastPathComponent(), for: qemuConfig.system)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
