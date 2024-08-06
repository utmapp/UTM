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
import QEMUKitInternal

@objc class UTMQemuImage: UTMProcess {
    typealias ProgressCallback = (Float) -> Void

    private var logOutput: String = ""
    private var processExitContinuation: CheckedContinuation<Void, any Error>?
    private var onProgress: ProgressCallback?

    private init() {
        super.init(arguments: [])
    }
    
    override func processHasExited(_ exitCode: Int, message: String?) {
        if let processExitContinuation = processExitContinuation {
            self.processExitContinuation = nil
            if exitCode != 0 {
                if let message = message {
                    processExitContinuation.resume(throwing: UTMQemuImageError.qemuError(message))
                } else {
                    processExitContinuation.resume(throwing: UTMQemuImageError.unknown)
                }
            } else {
                processExitContinuation.resume()
            }
        }
    }
    
    private func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            processExitContinuation = continuation
            start("qemu-img") { error in
                if let error = error {
                    self.processExitContinuation = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    static func convert(from url: URL, toQcow2 dest: URL, withCompression compressed: Bool = false, onProgress: ProgressCallback? = nil) async throws {
        let qemuImg = UTMQemuImage()
        let srcBookmark = try url.bookmarkData()
        let dstBookmark = try dest.deletingLastPathComponent().bookmarkData()
        qemuImg.pushArgv("convert")
        if onProgress != nil {
            qemuImg.pushArgv("-p")
        }
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
        let logging = QEMULogging()
        logging.delegate = qemuImg
        qemuImg.standardOutput = logging.standardOutput
        qemuImg.standardError = logging.standardError
        qemuImg.onProgress = onProgress
        try await qemuImg.start()
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
        let logging = QEMULogging()
        logging.delegate = qemuImg
        qemuImg.standardOutput = logging.standardOutput
        qemuImg.standardError = logging.standardError
        try await qemuImg.start()

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
        let logging = QEMULogging()
        logging.delegate = qemuImg
        qemuImg.standardOutput = logging.standardOutput
        qemuImg.standardError = logging.standardError
        try await qemuImg.start()
    }
}

private enum UTMQemuImageError: Error {
    case qemuError(String)
    case unknown
}

extension UTMQemuImageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .qemuError(let message): return message
        case .unknown: return NSLocalizedString("An unknown QEMU error has occurred.", comment: "UTMQemuImage")
        }
    }
}

// MARK: - Logging

extension UTMQemuImage: QEMULoggingDelegate {
    func logging(_ logging: QEMULogging, didRecieveOutputLine line: String) {
        logOutput += line
        if let onProgress = onProgress, line.contains("100%") {
            if let progress = parseProgress(line) {
                onProgress(progress)
            }
        }
    }
    
    func logging(_ logging: QEMULogging, didRecieveErrorLine line: String) {
    }
}

extension UTMQemuImage {
    private func parseProgress(_ line: String) -> Float? {
        let pattern = "\\(([0-9]+\\.[0-9]+)/100\\%\\)"
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: line) {
                    let floatValueString = line[swiftRange]
                    if let floatValue = Float(floatValueString) {
                        return floatValue
                    }
                }
            }
        } catch {

        }
        return nil
    }
}
