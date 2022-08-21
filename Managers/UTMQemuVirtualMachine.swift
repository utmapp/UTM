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

// MARK: - External drives
extension UTMQemuVirtualMachine {
    var qemuConfig: UTMQemuConfiguration {
        config.qemuConfig!
    }
    
    func eject(_ drive: UTMQemuConfigurationDrive, isForced: Bool = false) throws {
        guard drive.isExternal else {
            return
        }
        if let oldPath = registryEntry.externalDrives[drive.id]?.path {
            system?.stopAccessingPath(oldPath)
        }
        registryEntry.externalDrives.removeValue(forKey: drive.id)
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
        try eject(drive, isForced: true)
        let file = try UTMRegistryEntry.File(url: url, isReadOnly: drive.isReadOnly)
        registryEntry.externalDrives[drive.id] = file
        try await changeMedium(drive, with: tempBookmark, isSecurityScoped: false)
    }
    
    private func changeMedium(_ drive: UTMQemuConfigurationDrive, with bookmark: Data, isSecurityScoped: Bool) async throws {
        guard let system = system else {
            return
        }
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let path = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        if registryEntry.externalDrives[drive.id] != nil {
            registryEntry.externalDrives[drive.id]!.remoteBookmark = bookmark
        }
        if let qemu = qemu, qemu.isConnected {
            try qemu.changeMedium(forDrive: "drive\(drive.id)", path: path)
        }
    }
    
    func restoreExternalDrives() async throws {
        guard system != nil && qemu != nil && qemu!.isConnected else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        for drive in qemuConfig.drives {
            if !drive.isExternal {
                continue
            }
            let id = drive.id
            if let bookmark = registryEntry.externalDrives[id]?.remoteBookmark {
                // an image bookmark was saved while QEMU was running
                try await changeMedium(drive, with: bookmark, isSecurityScoped: true)
            } else if let localBookmark = registryEntry.externalDrives[id]?.bookmark {
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
    
    func externalImageURL(for drive: UTMQemuConfigurationDrive) -> URL? {
        registryEntry.externalDrives[drive.id]?.url
    }
}

// MARK: - Shared directory
extension UTMQemuVirtualMachine {
    var sharedDirectoryURL: URL? {
        registryEntry.sharedDirectories.first?.url
    }
    
    func clearSharedDirectory() {
        registryEntry.sharedDirectories = []
    }
    
    func changeSharedDirectory(to url: URL) async throws {
        _ = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        let file = try UTMRegistryEntry.File(url: url, isReadOnly: qemuConfig.sharing.isDirectoryShareReadOnly)
        registryEntry.sharedDirectories = [file]
        if qemuConfig.sharing.directoryShareMode == .webdav {
            if let ioService = ioService {
                ioService.changeSharedDirectory(url)
            }
        } else if qemuConfig.sharing.directoryShareMode == .virtfs {
            let tempBookmark = try url.bookmarkData()
            try await changeVirtfsSharedDirectory(with: tempBookmark, isSecurityScoped: false)
        }
    }
    
    func changeVirtfsSharedDirectory(with bookmark: Data, isSecurityScoped: Bool) async throws {
        guard let system = system else {
            return
        }
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let _ = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        if !registryEntry.sharedDirectories.isEmpty {
            registryEntry.sharedDirectories[0].remoteBookmark = bookmark
        }
    }
    
    func restoreSharedDirectory() async throws {
        guard let share = registryEntry.sharedDirectories.first else {
            return
        }
        if qemuConfig.sharing.directoryShareMode == .virtfs {
            if let bookmark = share.remoteBookmark {
                // a share bookmark was saved while QEMU was running
                try await changeVirtfsSharedDirectory(with: bookmark, isSecurityScoped: true)
            } else if let localBookmark = registryEntry.externalDrives[id]?.bookmark {
                // a share bookmark was saved while QEMU was NOT running
                let url = try URL(resolvingPersistentBookmarkData: localBookmark)
                try await changeSharedDirectory(to: url)
            }
        } else if qemuConfig.sharing.directoryShareMode == .webdav {
            if let ioService = ioService {
                ioService.changeSharedDirectory(share.url)
            }
        }
    }
}

// MARK: - Registry syncing
extension UTMQemuVirtualMachine {
    @MainActor override func updateConfigFromRegistry() {
        for i in qemuConfig.drives.indices {
            let drive = qemuConfig.drives[i]
            if drive.isExternal {
                if let file = registryEntry.externalDrives[drive.id] {
                    qemuConfig.drives[i].imageURL = file.url
                }
            }
        }
        if qemuConfig.sharing.directoryShareMode != .none {
            qemuConfig.sharing.directoryShareUrl = sharedDirectoryURL
        }
    }
    
    override func updateRegistryPostSave() async throws {
        for i in qemuConfig.drives.indices {
            let drive = qemuConfig.drives[i]
            if drive.isExternal, let url = drive.imageURL {
                try await changeMedium(drive, to: url)
                await Task { @MainActor in
                    // clear temporary URL
                    qemuConfig.drives[i].imageURL = nil
                }.value
            }
        }
        if let url = config.qemuConfig!.sharing.directoryShareUrl {
            try await changeSharedDirectory(to: url)
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
