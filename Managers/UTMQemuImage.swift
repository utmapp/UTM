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

@objc class UTMQemuImage: UTMQemu {
    private init() {
        super.init(arguments: [])
    }
    
    static func convert(from url: URL, toQcow2 dest: URL, withCompression compressed: Bool = false) async throws {
        let qemuImg = UTMQemuImage()
        let srcBookmark = try url.bookmarkData()
        let dstBookmark = try dest.deletingLastPathComponent().bookmarkData()
        qemuImg.pushArgv("convert")
        if compressed {
            qemuImg.pushArgv("-c")
        }
        qemuImg.pushArgv("-O")
        qemuImg.pushArgv("qcow2")
        qemuImg.accessData(withBookmark: srcBookmark)
        qemuImg.pushArgv(url.path)
        qemuImg.accessData(withBookmark: dstBookmark)
        qemuImg.pushArgv(dest.path)
        let logging = UTMLogging()
        qemuImg.logging = logging
        try await Task.detached {
            let (success, message) = await qemuImg.start("qemu-img")
            if !success, let message = message {
                throw message
            }
        }.value
    }
}
