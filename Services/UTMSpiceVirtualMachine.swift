//
// Copyright © 2024 osy. All rights reserved.
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

/// Common methods for all SPICE virtual machines
protocol UTMSpiceVirtualMachine: UTMVirtualMachine where Configuration == UTMQemuConfiguration {
    /// Set when VM is running with saving changes
    var isRunningAsDisposible: Bool { get }
    
    /// Get and set screenshot
    var screenshot: UTMVirtualMachineScreenshot? { get set }

    /// Handles IO
    var ioServiceDelegate: UTMSpiceIODelegate? { get set }
    
    /// SPICE interface
    var ioService: UTMSpiceIO? { get }
    
    /// Change input mode
    /// - Parameter tablet: If true, mouse events will be absolute
    func requestInputTablet(_ tablet: Bool)

    /// Eject a removable drive
    /// - Parameter drive: Removable drive
    func eject(_ drive: UTMQemuConfigurationDrive) async throws
    
    /// Change mount image of a removable drive
    /// - Parameters:
    ///   - drive: Removable drive
    ///   - url: New mount image
    func changeMedium(_ drive: UTMQemuConfigurationDrive, to url: URL) async throws
    
    /// Release resources for accessing a path
    /// - Parameter path: Path to stop accessing
    func stopAccessingPath(_ path: String) async

    /// Setup access to a VirtFS shared directory
    ///
    /// Throw an exception if this is not supported.
    /// - Parameters:
    ///   - bookmark: Bookmark to access
    ///   - isSecurityScoped: Is the bookmark security scoped?
    func changeVirtfsSharedDirectory(with bookmark: Data, isSecurityScoped: Bool) async throws
}

// MARK: - USB redirection
extension UTMSpiceVirtualMachine {
    var hasUsbRedirection: Bool {
        #if WITH_USB
        return jb_has_usb_entitlement()
        #else
        return false
        #endif
    }
}

// MARK: - Screenshot
extension UTMSpiceVirtualMachine {
    @MainActor @discardableResult
    func takeScreenshot() async -> Bool {
        if let screenshot = await ioService?.screenshot() {
            self.screenshot = UTMVirtualMachineScreenshot(wrapping: screenshot.image)
        }
        return true
    }

    func reloadScreenshotFromFile() {
        screenshot = loadScreenshot()
    }
}

// MARK: - External drives
extension UTMSpiceVirtualMachine {
    @MainActor func externalImageURL(for drive: UTMQemuConfigurationDrive) -> URL? {
        registryEntry.externalDrives[drive.id]?.url
    }
}

// MARK: - Shared directory
extension UTMSpiceVirtualMachine {
    @MainActor var sharedDirectoryURL: URL? {
        registryEntry.sharedDirectories.first?.url
    }

    func clearSharedDirectory() async {
        if let oldPath = await registryEntry.sharedDirectories.first?.path {
            await stopAccessingPath(oldPath)
        }
        await registryEntry.removeAllSharedDirectories()
    }

    func changeSharedDirectory(to url: URL) async throws {
        await clearSharedDirectory()
        let isScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if isScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let file = try await UTMRegistryEntry.File(url: url, isReadOnly: config.sharing.isDirectoryShareReadOnly)
        await registryEntry.setSingleSharedDirectory(file)
        if await config.sharing.directoryShareMode == .webdav {
            if let ioService = ioService {
                ioService.changeSharedDirectory(url)
            }
        } else if await config.sharing.directoryShareMode == .virtfs {
            let tempBookmark = try url.bookmarkData()
            try await changeVirtfsSharedDirectory(with: tempBookmark, isSecurityScoped: false)
        }
    }

    func restoreSharedDirectory(for ioService: UTMSpiceIO) async throws {
        guard let share = await registryEntry.sharedDirectories.first else {
            return
        }
        if await config.sharing.directoryShareMode == .virtfs {
            if let bookmark = share.remoteBookmark {
                // a share bookmark was saved while QEMU was running
                try await changeVirtfsSharedDirectory(with: bookmark, isSecurityScoped: true)
            } else {
                // a share bookmark was saved while QEMU was NOT running
                let url = try URL(resolvingPersistentBookmarkData: share.bookmark)
                try await changeSharedDirectory(to: url)
            }
        } else if await config.sharing.directoryShareMode == .webdav {
            ioService.changeSharedDirectory(share.url)
        }
    }
}

// MARK: - Registry syncing
extension UTMSpiceVirtualMachine {
    @MainActor func updateRegistryFromConfig() async throws {
        // save a copy to not collide with updateConfigFromRegistry()
        let configShare = config.sharing.directoryShareUrl
        let configDrives = config.drives
        try await updateRegistryBasics()
        for drive in configDrives {
            if drive.isExternal, let url = drive.imageURL {
                try await changeMedium(drive, to: url)
            } else if drive.isExternal {
                try await eject(drive)
            }
        }
        if let url = configShare {
            try await changeSharedDirectory(to: url)
        } else {
            await clearSharedDirectory()
        }
        // remove any unreferenced drives
        registryEntry.externalDrives = registryEntry.externalDrives.filter({ element in
            configDrives.contains(where: { $0.id == element.key && $0.isExternal })
        })
    }

    @MainActor func updateConfigFromRegistry() {
        config.sharing.directoryShareUrl = sharedDirectoryURL
        for i in config.drives.indices {
            let id = config.drives[i].id
            if config.drives[i].isExternal {
                config.drives[i].imageURL = registryEntry.externalDrives[id]?.url
            }
        }
    }
}
