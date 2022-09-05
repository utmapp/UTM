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
    private var logOutput: String = ""
    
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
            qemuImg.pushArgv("-o")
            qemuImg.pushArgv("compression_type=zstd")
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
    
    /*
     The info format looks like:
     
     $ qemu-img info foo.img --output=json
     {
         "virtual-size": 20971520,
         "filename": "foo.img",
         "cluster-size": 65536,
         "format": "qcow2",
         "actual-size": 200704,
         "format-specific": {
             "type": "qcow2",
             "data": {
                 "compat": "1.1",
                 "compression-type": "zlib",
                 "lazy-refcounts": false,
                 "refcount-bits": 16,
                 "corrupt": false,
                 "extended-l2": false
             }
         },
         "dirty-flag": false
     }
     */

    struct QemuImageInfo : Codable {
        let virtualSize : Int64
        let filename : String
        let clusterSize : Int32
        let format : String
        let actualSize : Int64
        let dirtyFlag : Bool

        private enum CodingKeys: String, CodingKey {
            case virtualSize = "virtual-size"
            case filename
            case clusterSize = "cluster-size"
            case format
            case actualSize = "actual-size"
            case dirtyFlag = "dirty-flag"
        }
    }

    static func size(image url: URL) async throws -> Int64 {
        let qemuImg = UTMQemuImage()
        let srcBookmark = try url.bookmarkData()
        qemuImg.pushArgv("info")
        qemuImg.pushArgv("--output=json")
        qemuImg.accessData(withBookmark: srcBookmark)
        qemuImg.pushArgv(url.path)
        let logging = UTMLogging()
        logging.delegate = qemuImg
        qemuImg.logging = logging
        try await Task.detached {
            let (success, message) = await qemuImg.start("qemu-img")
            if !success, let message = message {
                throw message
            }
        }.value

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let data = qemuImg.logOutput.data(using: .utf8) ?? Data()
        let image_info: QemuImageInfo = try decoder.decode(QemuImageInfo.self, from: data)

        return image_info.virtualSize
    }

    static func resize(image url: URL, size : UInt64) async throws {
        let qemuImg = UTMQemuImage()
        let srcBookmark = try url.bookmarkData()
        qemuImg.pushArgv("resize")
        qemuImg.pushArgv("-f")
        qemuImg.pushArgv("qcow2")
        qemuImg.accessData(withBookmark: srcBookmark)
        qemuImg.pushArgv(url.path)
        qemuImg.pushArgv(String(size))
        let logging = UTMLogging()
        logging.delegate = qemuImg
        qemuImg.logging = logging
        try await Task.detached {
            let (success, message) = await qemuImg.start("qemu-img")
            if !success, let message = message {
                throw message
            }
        }.value
    }
}

// MARK: - Logging delegate

extension UTMQemuImage: UTMLoggingDelegate {
    func logging(_ logging: UTMLogging, didRecieveOutputLine line: String) {
        logOutput += line
    }
    
    func logging(_ logging: UTMLogging, didRecieveErrorLine line: String) {
    }
}
