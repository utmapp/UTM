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

// MARK: - Display details
public extension UTMQemuVirtualMachine {
    internal var qemuConfig: UTMQemuConfiguration {
        config.qemuConfig!
    }
    
    @MainActor override var detailsTitleLabel: String {
        qemuConfig.information.name
    }
    
    @MainActor override var detailsSubtitleLabel: String {
        detailsSystemTargetLabel
    }
    
    @MainActor override var detailsNotes: String? {
        qemuConfig.information.notes
    }
    
    @MainActor override var detailsSystemTargetLabel: String {
        qemuConfig.system.target.prettyValue
    }
    
    @MainActor override var detailsSystemArchitectureLabel: String {
        qemuConfig.system.architecture.prettyValue
    }
    
    @MainActor override var detailsSystemMemoryLabel: String {
        let bytesInMib = Int64(1048576)
        return ByteCountFormatter.string(fromByteCount: Int64(qemuConfig.system.memorySize) * bytesInMib, countStyle: .binary)
    }
    
    /// Check if a QEMU target is supported
    /// - Parameter systemArchitecture: QEMU architecture
    /// - Returns: true if UTM is compiled with the supporting binaries
    internal static func isSupported(systemArchitecture: QEMUArchitecture) -> Bool {
        let arch = systemArchitecture.rawValue
        let bundleURL = Bundle.main.bundleURL
        #if os(macOS)
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let base = "Versions/A/"
        #else
        let contentsURL = bundleURL
        let base = ""
        #endif
        let frameworksURL = contentsURL.appendingPathComponent("Frameworks", isDirectory: true)
        let framework = frameworksURL.appendingPathComponent("qemu-" + arch + "-softmmu.framework/" + base + "qemu-" + arch + "-softmmu", isDirectory: false)
        logger.error("\(framework.path)")
        return FileManager.default.fileExists(atPath: framework.path)
    }
    
    /// Check if the current VM target is supported by the host
    @objc var isSupported: Bool {
        return UTMQemuVirtualMachine.isSupported(systemArchitecture: qemuConfig._system.architecture)
    }
}

// MARK: - External drives
extension UTMQemuVirtualMachine {
    func eject(_ drive: UTMQemuConfigurationDrive, isForced: Bool = false) async throws {
        guard drive.isExternal else {
            return
        }
        if let oldPath = await registryEntry.externalDrives[drive.id]?.path {
            system?.stopAccessingPath(oldPath)
        }
        await registryEntry.removeExternalDrive(forId: drive.id)
        guard let qemu = qemu, qemu.isConnected else {
            return
        }
        try qemu.ejectDrive("drive\(drive.id)", force: isForced)
    }
    
    func changeMedium(_ drive: UTMQemuConfigurationDrive, to url: URL) async throws {
        _ = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        let tempBookmark = try url.bookmarkData()
        try await eject(drive, isForced: true)
        let file = try UTMRegistryEntry.File(url: url, isReadOnly: drive.isReadOnly)
        await registryEntry.setExternalDrive(file, forId: drive.id)
        try await changeMedium(drive, with: tempBookmark, url: url, isSecurityScoped: false)
    }
    
    private func changeMedium(_ drive: UTMQemuConfigurationDrive, with bookmark: Data, url: URL?, isSecurityScoped: Bool) async throws {
        let system = system ?? UTMQemu()
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let path = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        await registryEntry.updateExternalDriveRemoteBookmark(bookmark, forId: drive.id)
        let newUrl = url ?? URL(fileURLWithPath: path)
        if let qemu = qemu, qemu.isConnected {
            try qemu.changeMedium(forDrive: "drive\(drive.id)", path: path)
        }
    }
    
    func restoreExternalDrives() async throws {
        guard system != nil else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        for drive in await qemuConfig.drives {
            if !drive.isExternal {
                continue
            }
            let id = drive.id
            if let bookmark = await registryEntry.externalDrives[id]?.remoteBookmark {
                // an image bookmark was saved while QEMU was running
                try await changeMedium(drive, with: bookmark, url: nil, isSecurityScoped: true)
            } else if let localBookmark = await registryEntry.externalDrives[id]?.bookmark {
                // an image bookmark was saved while QEMU was NOT running
                let url = try URL(resolvingPersistentBookmarkData: localBookmark)
                try await changeMedium(drive, to: url)
            }
        }
    }
    
    @objc func restoreExternalDrivesAndShares(completion: @escaping (Error?) -> Void) {
        Task.detached {
            do {
                try await self.restoreExternalDrives()
                try await self.restoreSharedDirectory()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    @MainActor func externalImageURL(for drive: UTMQemuConfigurationDrive) -> URL? {
        registryEntry.externalDrives[drive.id]?.url
    }
}

// MARK: - Shared directory
extension UTMQemuVirtualMachine {
    @MainActor var sharedDirectoryURL: URL? {
        registryEntry.sharedDirectories.first?.url
    }
    
    func clearSharedDirectory() async {
        if let oldPath = await registryEntry.sharedDirectories.first?.path {
            system?.stopAccessingPath(oldPath)
        }
        await registryEntry.removeAllSharedDirectories()
    }
    
    func changeSharedDirectory(to url: URL) async throws {
        await clearSharedDirectory()
        _ = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        let file = try await UTMRegistryEntry.File(url: url, isReadOnly: qemuConfig.sharing.isDirectoryShareReadOnly)
        await registryEntry.setSingleSharedDirectory(file)
        if await qemuConfig.sharing.directoryShareMode == .webdav {
            if let ioService = ioService {
                ioService.changeSharedDirectory(url)
            }
        } else if await qemuConfig.sharing.directoryShareMode == .virtfs {
            let tempBookmark = try url.bookmarkData()
            try await changeVirtfsSharedDirectory(with: tempBookmark, isSecurityScoped: false)
        }
    }
    
    func changeVirtfsSharedDirectory(with bookmark: Data, isSecurityScoped: Bool) async throws {
        let system = system ?? UTMQemu()
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let path = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        await registryEntry.updateSingleSharedDirectoryRemoteBookmark(bookmark)
    }
    
    func restoreSharedDirectory() async throws {
        guard let share = await registryEntry.sharedDirectories.first else {
            return
        }
        if await qemuConfig.sharing.directoryShareMode == .virtfs {
            if let bookmark = share.remoteBookmark {
                // a share bookmark was saved while QEMU was running
                try await changeVirtfsSharedDirectory(with: bookmark, isSecurityScoped: true)
            } else {
                // a share bookmark was saved while QEMU was NOT running
                let url = try URL(resolvingPersistentBookmarkData: share.bookmark)
                try await changeSharedDirectory(to: url)
            }
        } else if await qemuConfig.sharing.directoryShareMode == .webdav {
            if let ioService = ioService {
                ioService.changeSharedDirectory(share.url)
            }
        }
    }
}

// MARK: - Registry syncing
extension UTMQemuVirtualMachine {
    @MainActor override func updateRegistryFromConfig() async throws {
        // save a copy to not collide with updateConfigFromRegistry()
        let configShare = qemuConfig.sharing.directoryShareUrl
        let configDrives = qemuConfig.drives
        try await super.updateRegistryFromConfig()
        for drive in configDrives {
            if drive.isExternal, let url = drive.imageURL {
                try await changeMedium(drive, to: url)
            }
        }
        if let url = configShare {
            try await changeSharedDirectory(to: url)
        }
        // remove any unreferenced drives
        registryEntry.externalDrives = registryEntry.externalDrives.filter({ element in
            configDrives.contains(where: { $0.id == element.key && $0.isExternal })
        })
    }
    
    @MainActor override func updateConfigFromRegistry() {
        super.updateConfigFromRegistry()
        qemuConfig.sharing.directoryShareUrl = sharedDirectoryURL
        for i in qemuConfig.drives.indices {
            let id = qemuConfig.drives[i].id
            if qemuConfig.drives[i].isExternal {
                qemuConfig.drives[i].imageURL = registryEntry.externalDrives[id]?.url
            }
        }
    }
}

enum UTMQemuVirtualMachineError: Error {
    case accessDriveImageFailed
    case accessShareFailed
    case invalidVmState
}

extension UTMQemuVirtualMachineError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .accessDriveImageFailed: return NSLocalizedString("Failed to access drive image path.", comment: "UTMQemuVirtualMachine")
        case .accessShareFailed: return NSLocalizedString("Failed to access shared directory.", comment: "UTMQemuVirtualMachine")
        case .invalidVmState: return NSLocalizedString("The virtual machine is in an invalid state.", comment: "UTMQemuVirtualMachine")
        }
    }
}
