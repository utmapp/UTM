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
import Virtualization

/// Downloads an IPSW from the web and adds it to the VM.
@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 12, *)
class UTMDownloadIPSWTask: UTMDownloadTask {
    let config: UTMAppleConfiguration
    
    private var cacheUrl: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    @MainActor init(for config: UTMAppleConfiguration) {
        self.config = config
        super.init(for: config.system.boot.macRecoveryIpswURL!, named: config.information.name)
    }
    
    override func processCompletedDownload(at location: URL) async throws -> UTMVirtualMachine {
        if !fileManager.fileExists(atPath: cacheUrl.path) {
            try fileManager.createDirectory(at: cacheUrl, withIntermediateDirectories: false)
        }
        
        let cacheIpsw = cacheUrl.appendingPathComponent(url.lastPathComponent)
        if fileManager.fileExists(atPath: cacheIpsw.path) {
            try fileManager.removeItem(at: cacheIpsw)
        }
        try fileManager.moveItem(at: location, to: cacheIpsw)
        await MainActor.run {
            config.system.boot.macRecoveryIpswURL = cacheIpsw
        }
        return UTMVirtualMachine(newConfig: config, destinationURL: UTMData.defaultStorageUrl)
    }
}
