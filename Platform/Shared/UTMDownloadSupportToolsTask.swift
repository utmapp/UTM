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

/// Downloads support tools ISO
class UTMDownloadSupportToolsTask: UTMDownloadTask {
    private let vm: UTMQemuVirtualMachine
    
    // TODO: make this dynamic
    private static let supportToolsDownloadUrl = URL(string: "https://github.com/utmapp/qemu/releases/download/v7.0.0-utm/spice-guest-tools-0.164.4.iso")!
    
    private var supportUrl: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("GuestSupportTools")
    }
    
    private var supportToolsLocalUrl: URL {
        supportUrl.appendingPathComponent(Self.supportToolsDownloadUrl.lastPathComponent)
    }
    
    var hasExistingSupportTools: Bool {
        fileManager.fileExists(atPath: supportToolsLocalUrl.path)
    }
    
    init(for vm: UTMQemuVirtualMachine) {
        self.vm = vm
        let name = NSLocalizedString("Windows Guest Support Tools", comment: "UTMDownloadSupportToolsTask")
        super.init(for: Self.supportToolsDownloadUrl, named: name)
    }
    
    override func processCompletedDownload(at location: URL) async throws -> UTMVirtualMachine {
        if !fileManager.fileExists(atPath: supportUrl.path) {
            try fileManager.createDirectory(at: supportUrl, withIntermediateDirectories: true)
        }
        if fileManager.fileExists(atPath: supportToolsLocalUrl.path) {
            try fileManager.removeItem(at: supportToolsLocalUrl)
        }
        try fileManager.moveItem(at: location, to: supportToolsLocalUrl)
        return try await mountTools()
    }
    
    func mountTools() async throws -> UTMVirtualMachine {
        for file in await vm.registryEntry.externalDrives.values {
            if file.path == supportToolsLocalUrl.path {
                throw UTMDownloadSupportToolsTaskError.alreadyMounted
            }
        }
        guard let drive = await vm.qemuConfig.drives.last(where: { $0.isExternal && $0.imageURL == nil }) else {
            throw UTMDownloadSupportToolsTaskError.driveUnavailable
        }
        try await vm.changeMedium(drive, to: supportToolsLocalUrl)
        return vm
    }
}

enum UTMDownloadSupportToolsTaskError: Error {
    case driveUnavailable
    case alreadyMounted
}

extension UTMDownloadSupportToolsTaskError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .driveUnavailable: return NSLocalizedString("No empty removable drive found. Make sure you have at least one removable drive that is not in use.", comment: "UTMDownloadSupportToolsTaskError")
        case .alreadyMounted: return NSLocalizedString("The guest support tools have already been mounted.", comment: "UTMDownloadSupportToolsTaskError")
        }
    }
}
