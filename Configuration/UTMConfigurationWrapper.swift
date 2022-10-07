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
/// Note: We cannot enforce @MainActor here so it is up to the caller to ensure main thread access.
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
        #if os(iOS)
        false
        #else
        wrappedValue is UTMAppleConfiguration
        #endif
    }
    
    @objc var name: String {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._information.name
        } else if wrappedValue is UTMAppleConfiguration {
            return appleConfig!._information.name
        } else if let placeholderName = placeholderName {
            return placeholderName
        } else {
            fatalError()
        }
    }
    
    @objc var uuid: UUID {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._information.uuid
        } else if wrappedValue is UTMAppleConfiguration {
            return appleConfig!._information.uuid
        } else if let placeholderUuid = placeholderUuid {
            return placeholderUuid
        } else {
            fatalError()
        }
    }
    
    @objc var iconURL: URL? {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._information.iconURL
        } else if wrappedValue is UTMAppleConfiguration {
            return appleConfig!._information.iconURL
        } else {
            return placeholderIconURL
        }
    }
    
    @objc var qemuHasDebugLog: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._qemu.hasDebugLog
        } else if wrappedValue is UTMAppleConfiguration {
            return false
        } else {
            fatalError()
        }
    }
    
    @objc var qemuDebugLogURL: URL? {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._qemu.debugLogURL
        } else {
            fatalError()
        }
    }
    
    @objc var qemuArchitecture: String {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._system.architecture.rawValue
        } else {
            fatalError()
        }
    }
    
    // FIXME: @MainActor here is a HACK and does nothing in Obj-C!
    @MainActor @objc var qemuArguments: [String] {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.allArguments.map({ $0.string })
        } else {
            fatalError()
        }
    }
    
    // FIXME: @MainActor here is a HACK and does nothing in Obj-C!
    @MainActor @objc var qemuResources: [URL] {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.allArguments.compactMap({ $0.fileUrls }).flatMap({ $0 })
        } else {
            fatalError()
        }
    }
    
    @objc var qemuIsDisposable: Bool {
        get {
            if wrappedValue is UTMQemuConfiguration {
                return qemuConfig!._qemu.isDisposable
            } else {
                fatalError()
            }
        }
        
        set {
            if wrappedValue is UTMQemuConfiguration {
                qemuConfig!._qemu.isDisposable = newValue
            } else {
                fatalError()
            }
        }
    }
    
    @objc var qemuSnapshotName: String? {
        get {
            if wrappedValue is UTMQemuConfiguration {
                return qemuConfig!._qemu.snapshotName
            } else {
                fatalError()
            }
        }
        
        set {
            if wrappedValue is UTMQemuConfiguration {
                qemuConfig!._qemu.snapshotName = newValue
            } else {
                fatalError()
            }
        }
    }
    
    // FIXME: @MainActor here is a HACK and does nothing in Obj-C!
    @MainActor @objc var qemuSpiceSocketURL: URL {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!.spiceSocketURL
        } else {
            fatalError()
        }
    }
    
    @objc var qemuHasAudio: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return !qemuConfig!._sound.isEmpty
        } else {
            fatalError()
        }
    }
    
    @objc var qemuHasDisplay: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return !qemuConfig!._displays.isEmpty
        } else {
            fatalError()
        }
    }
    
    @objc var qemuHasTerminal: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return !(qemuConfig!._serials.filter { $0.mode == .builtin }).isEmpty
        } else {
            fatalError()
        }
    }
    
    @objc var qemuHasClipboardSharing: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._sharing.hasClipboardSharing
        } else {
            fatalError()
        }
    }
    
    @objc var qemuHasWebdavSharing: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._sharing.directoryShareMode == .webdav
        } else {
            fatalError()
        }
    }
    
    @objc var qemuIsDirectoryShareReadOnly: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._sharing.isDirectoryShareReadOnly
        } else {
            fatalError()
        }
    }
    
    @objc var qemuConsoleBackgroundColor: String {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._serials.first!.terminal!.backgroundColor ?? "#000000"
        } else {
            fatalError()
        }
    }
    
    @objc var qemuConsoleForegroundColor: String {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._serials.first!.terminal!.foregroundColor ?? "#ffffff"
        } else {
            fatalError()
        }
    }
    
    @objc var qemuConsoleFont: String {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._serials.first!.terminal!.font.rawValue
        } else {
            fatalError()
        }
    }
    
    @objc var qemuConsoleFontSize: Int {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._serials.first!.terminal!.fontSize
        } else {
            fatalError()
        }
    }
    
    @objc var qemuConsoleResizeCommand: String? {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._serials.first!.terminal!.resizeCommand
        } else {
            fatalError()
        }
    }
    
    @objc var qemuShouldWaitForeverForConnect: Bool {
        if wrappedValue is UTMQemuConfiguration {
            return qemuConfig!._serials.contains { serial in
                (serial.mode == .tcpServer || serial.mode == .tcpServer) &&
                serial.isWaitForConnection == true
            }
        } else {
            fatalError()
        }
    }
    
    init<Config: UTMConfiguration>(wrapping config: Config) {
        self.wrappedValue = config
    }
    
    @objc init?(from packageURL: URL) {
        do {
            let config = try UTMQemuConfiguration.load(from: packageURL)
            self.wrappedValue = config
        } catch {
            logger.error("Error loading config from \(packageURL.path): \(error)")
            return nil
        }
    }
    
    @objc init(placeholderFor name: String, uuid: UUID? = nil) {
        self.placeholderName = name
        self.placeholderUuid = uuid ?? UUID()
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
        guard let qemuConfig = qemuConfig, let efiVarsURL = qemuConfig._qemu.efiVarsURL else {
            completion(nil)
            return
        }
        guard qemuConfig.isLegacy else {
            completion(nil)
            return
        }
        Task {
            do {
                _ = try await qemuConfig._qemu.saveData(to: efiVarsURL.deletingLastPathComponent(), for: qemuConfig._system)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    @objc func qemuSetPttyDevicePath(_ pttyDevicePath: String, for index: Int) {
        guard let qemuConfig = qemuConfig else {
            fatalError()
        }
        Task { @MainActor in
            guard index >= 0 && index < qemuConfig.serials.count else {
                logger.error("Serial device '\(pttyDevicePath)' out of bounds for index \(index)")
                return
            }
            qemuConfig.serials[index].pttyDevice = URL(fileURLWithPath: pttyDevicePath)
        }
    }
    
    @objc func qemuClearPttyPaths() {
        guard let qemuConfig = qemuConfig else {
            fatalError()
        }
        Task { @MainActor in
            for index in qemuConfig.serials.indices {
                if qemuConfig.serials[index].pttyDevice != nil {
                    qemuConfig.serials[index].pttyDevice = nil
                }
            }
        }
    }
}
