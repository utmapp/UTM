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
    
    func eject(_ drive: inout UTMQemuConfigurationDrive, isForced: Bool = false) throws {
        guard let oldURL = drive.imageURL else {
            return // nothing to eject
        }
        guard drive.isExternal else {
            return
        }
        drive.imageURL = nil
        registryEntry?.externalDrives.removeValue(forKey: drive.id)
        system?.stopAccessingPath(oldURL.path)
        guard let qemu = qemu, qemu.isConnected else {
            return
        }
        try qemu.ejectDrive("drive\(drive.id)", force: isForced)
    }
    
    func changeMedium(_ drive: inout UTMQemuConfigurationDrive, with url: URL) async throws {
        _ = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        let tempBookmark = try url.bookmarkData()
        try eject(&drive, isForced: true)
        try await changeMedium(&drive, with: tempBookmark, isSecurityScoped: false)
        drive.imageURL = url
    }
    
    private func changeMedium(_ drive: inout UTMQemuConfigurationDrive, with bookmark: Data, isSecurityScoped: Bool) async throws {
        guard let system = system else {
            return
        }
        let (success, bookmark, path) = await system.accessData(withBookmark: bookmark, securityScoped: isSecurityScoped)
        guard let bookmark = bookmark, let path = path, success else {
            throw UTMQemuVirtualMachineError.accessDriveImageFailed
        }
        let file = UTMRegistryEntry.File(path: path, bookmark: bookmark, isReadOnly: drive.isReadOnly)
        registryEntry?.externalDrives[drive.id] = file
        if let qemu = qemu, qemu.isConnected {
            try qemu.changeMedium(forDrive: "drive\(drive.id)", path: path)
        }
    }
    
    func restoreExternalDrives() async throws {
        guard system != nil && qemu != nil && qemu!.isConnected else {
            throw UTMQemuVirtualMachineError.invalidVmState
        }
        let qemuConfig = config.qemuConfig!
        for i in qemuConfig.drives.indices {
            if !qemuConfig.drives[i].isExternal {
                continue
            }
            let id = qemuConfig.drives[i].id
            if let url = qemuConfig.drives[i].imageURL {
                // an image was selected while the VM was stopped
                try await changeMedium(&qemuConfig.drives[i], with: url)
            } else if let bookmark = registryEntry?.externalDrives[id]?.bookmark {
                // an image bookmark was saved
                try await changeMedium(&qemuConfig.drives[i], with: bookmark, isSecurityScoped: true)
            }
        }
    }
    
    @objc func restoreExternalDrives(completion: @escaping (Error?) -> Void) {
        Task.detached {
            do {
                try await self.restoreExternalDrives()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}

enum UTMQemuVirtualMachineError: Error {
    case accessDriveImageFailed
    case invalidVmState
}

extension UTMQemuVirtualMachineError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .accessDriveImageFailed: return NSLocalizedString("Failed to access drive image path.", comment: "UTMQemuVirtualMachine")
        case .invalidVmState: return NSLocalizedString("The virtual machine is in an invalid state.", comment: "UTMQemuVirtualMachine")
        }
    }
}
