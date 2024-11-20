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

/// Downloads support tools for macOS
@available(macOS 15, *)
class UTMDownloadMacSupportToolsTask: UTMDownloadTask {
    private let vm: UTMAppleVirtualMachine

    private static let supportToolsDownloadUrl = URL(string: "https://getutm.app/downloads/utm-guest-tools-macos-latest.img")!

    private var toolsUrl: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("GuestSupportTools")
    }
    
    private var supportToolsLocalUrl: URL {
        toolsUrl.appendingPathComponent(Self.supportToolsDownloadUrl.lastPathComponent)
    }

    @Setting("LastDownloadedMacGuestTools")
    private var lastDownloadMacGuestTools: Int = 0

    var hasExistingSupportTools: Bool {
        get async {
            guard fileManager.fileExists(atPath: supportToolsLocalUrl.path) else {
                return false
            }
            return await lastModifiedTimestamp <= lastDownloadMacGuestTools
        }
    }
    
    init(for vm: UTMAppleVirtualMachine) {
        self.vm = vm
        let name = NSLocalizedString("macOS Guest Support Tools", comment: "UTMDownloadMacSupportToolsTask")
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
        lastDownloadMacGuestTools = lastModifiedTimestamp(for: response) ?? 0
        return try await mountTools()
    }
    
    func mountTools() async throws -> any UTMVirtualMachine {
        try await vm.attachGuestTools(supportToolsLocalUrl)
        return vm
    }
}
