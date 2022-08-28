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
    
    func eject(_ drive: UTMQemuConfigurationDrive, isForced: Bool = false) async throws {
        guard drive.isExternal else {
            return
        }
        if let oldPath = await registryEntry.externalDrives[drive.id]?.path {
            system?.stopAccessingPath(oldPath)
        }
        await MainActor.run {
            for i in qemuConfig.drives.indices {
                if qemuConfig.drives[i].id == drive.id {
                    qemuConfig.drives[i].imageURL = nil
                }
            }
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
        guard let system = system else {
            return
        }
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let path = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        await registryEntry.updateExternalDriveRemoteBookmark(bookmark, forId: drive.id)
        let newUrl = url ?? URL(fileURLWithPath: path)
        await MainActor.run {
            for i in qemuConfig.drives.indices {
                if qemuConfig.drives[i].id == drive.id {
                    qemuConfig.drives[i].imageURL = newUrl
                }
            }
        }
        if let qemu = qemu, qemu.isConnected {
            try qemu.changeMedium(forDrive: "drive\(drive.id)", path: path)
        }
    }
    
    func restoreExternalDrives() async throws {
        guard system != nil && qemu != nil && qemu!.isConnected else {
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
    
    @MainActor func clearSharedDirectory() {
        qemuConfig.sharing.directoryShareUrl = nil
        registryEntry.removeAllSharedDirectories()
    }
    
    func changeSharedDirectory(to url: URL) async throws {
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
            await MainActor.run {
                qemuConfig.sharing.directoryShareUrl = url
            }
        } else if await qemuConfig.sharing.directoryShareMode == .virtfs {
            let tempBookmark = try url.bookmarkData()
            try await changeVirtfsSharedDirectory(with: tempBookmark, isSecurityScoped: false)
        }
    }
    
    func changeVirtfsSharedDirectory(with bookmark: Data, isSecurityScoped: Bool) async throws {
        guard let system = system else {
            return
        }
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let path = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        await registryEntry.updateSingleSharedDirectoryRemoteBookmark(bookmark)
        await MainActor.run {
            qemuConfig.sharing.directoryShareUrl = URL(fileURLWithPath: path)
        }
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
    @MainActor override func updateRegistryPostSave() async throws {
        for i in qemuConfig.drives.indices {
            let drive = qemuConfig.drives[i]
            if drive.isExternal, let url = drive.imageURL {
                try await changeMedium(drive, to: url)
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
