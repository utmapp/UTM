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
    private let vm: any UTMSpiceVirtualMachine

    private static let supportToolsDownloadUrl = URL(string: "https://getutm.app/downloads/utm-guest-tools-latest.iso")!
    
    private var toolsUrl: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("GuestSupportTools")
    }
    
    private var supportToolsLocalUrl: URL {
        toolsUrl.appendingPathComponent(Self.supportToolsDownloadUrl.lastPathComponent)
    }

    @Setting("LastDownloadedGuestTools")
    private var lastDownloadGuestTools: Int = 0

    var hasExistingSupportTools: Bool {
        get async {
            guard fileManager.fileExists(atPath: supportToolsLocalUrl.path) else {
                return false
            }
            return await lastModifiedTimestamp <= lastDownloadGuestTools
        }
    }
    
    init(for vm: any UTMSpiceVirtualMachine) {
        self.vm = vm
        let name = NSLocalizedString("Windows Guest Support Tools", comment: "UTMDownloadSupportToolsTask")
        super.init(for: Self.supportToolsDownloadUrl, named: name)
    }
    
    override func processCompletedDownload(at location: URL, response: URLResponse?) async throws -> any UTMVirtualMachine {
        if !fileManager.fileExists(atPath: toolsUrl.path) {
            try fileManager.createDirectory(at: toolsUrl, withIntermediateDirectories: true)
        }
        if fileManager.fileExists(atPath: supportToolsLocalUrl.path) {
            try fileManager.removeItem(at: supportToolsLocalUrl)
        }
        try fileManager.moveItem(at: location, to: supportToolsLocalUrl)
        lastDownloadGuestTools = lastModifiedTimestamp(for: response) ?? 0
        return try await mountTools()
    }
    
    func mountTools() async throws -> any UTMVirtualMachine {
        for file in await vm.registryEntry.externalDrives.values {
            if file.path == supportToolsLocalUrl.path {
                throw UTMDownloadSupportToolsTaskError.alreadyMounted
            }
        }
        guard let drive = await vm.config.drives.last(where: { $0.isExternal && $0.imageURL == nil }) else {
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
