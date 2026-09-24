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

@objc class UTMQemuImage: UTMProcess {
    typealias ProgressCallback = (Float) -> Void

    private let output = UTMQemuImageOutput()
    private let errorOutput = UTMQemuImageOutput()
    private var processExitContinuation: CheckedContinuation<Void, any Error>?
    #if os(iOS) || os(visionOS)
    private let helper: UTMHelperProcess
    #endif

    /// qemu-img is available: on iOS it runs in a helper extension
    static var isSupported: Bool {
        #if os(iOS) || os(visionOS)
        return UTMHelperProcess.isSupported
        #else
        return true
        #endif
    }

    #if os(iOS) || os(visionOS)
    private init(helper: UTMHelperProcess) {
        self.helper = helper
        super.init(arguments: [], connection: helper.connection)
    }

    deinit {
        helper.invalidate()
    }
    #else
    private init() {
        super.init(arguments: [])
    }
    #endif

    private static func makeProcess() async throws -> UTMQemuImage {
        #if os(iOS) || os(visionOS)
        return UTMQemuImage(helper: try await UTMHelperProcess.launch())
        #else
        return UTMQemuImage()
        #endif
    }

    /// Runs an operation with a fresh qemu-img, then releases it so that the next one can start
    private static func withProcess<T>(_ body: (UTMQemuImage) async throws -> T) async throws -> T {
        let qemuImg = try await makeProcess()
        let result: T
        do {
            result = try await body(qemuImg)
        } catch {
            await qemuImg.finish()
            throw error
        }
        await qemuImg.finish()
        return result
    }

    private func finish() async {
        #if os(iOS) || os(visionOS)
        await helper.terminate()
        #endif
        stop()
    }

    override func processHasExited(_ exitCode: Int, message: String?) {
        guard let processExitContinuation = processExitContinuation else {
            return
        }
        self.processExitContinuation = nil
        var error: Error?
        if exitCode != 0 {
            if let message = message {
                error = UTMQemuImageError.qemuError(message)
            } else {
                error = UTMQemuImageError.unknown
            }
        }
        Self.resumeOffXPCQueue {
            if let error = error {
                processExitContinuation.resume(throwing: error)
            } else {
                processExitContinuation.resume()
            }
        }
    }

    /// A task resumed on the reply queue of the helper's connection would block on its next call
    /// to the helper, as NSXPC makes calls from that queue synchronous.
    private static func resumeOffXPCQueue(_ resume: @escaping () -> Void) {
        DispatchQueue.global().async(execute: resume)
    }

    /// Runs qemu-img with the arguments and waits for it to exit and for its output to end
    private func start(onProgress: ProgressCallback? = nil) async throws {
        standardOutput = output.pipe
        standardError = errorOutput.pipe
        if let onProgress = onProgress {
            output.onLine = { line in
                if let progress = Self.parseProgress(line) {
                    onProgress(progress)
                }
            }
        }
        var exitError: Error?
        do {
            try await withCheckedThrowingContinuation { continuation in
                processExitContinuation = continuation
                start("qemu-img") { error in
                    // the write ends belong to the tool now, so the output ends when it exits
                    self.output.closeWriter()
                    self.errorOutput.closeWriter()
                    if let error = error {
                        self.processExitContinuation = nil
                        Self.resumeOffXPCQueue {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        } catch {
            exitError = error
        }
        await output.waitForEnd()
        await errorOutput.waitForEnd()
        if let exitError = exitError {
            if case UTMQemuImageError.unknown = exitError, let message = errorOutput.lines.last(where: { !$0.isEmpty }) {
                throw UTMQemuImageError.qemuError(message)
            }
            throw exitError
        }
    }

    /// Grants qemu-img access to a file and adds it to the arguments
    private func pushArgv(accessing url: URL) async throws {
        // a file that does not exist yet is reached through its directory
        let accessURL = FileManager.default.fileExists(atPath: url.path) ? url : url.deletingLastPathComponent()
        let bookmark = try accessURL.bookmarkData()
        let success: Bool = await withCheckedContinuation { continuation in
            accessData(withBookmark: bookmark, securityScoped: false) { success, _, _ in
                Self.resumeOffXPCQueue {
                    continuation.resume(returning: success)
                }
            }
        }
        guard success else {
            #if os(iOS) || os(visionOS)
            if helper.isLost {
                throw UTMHelperProcessError.lost
            }
            #endif
            throw UTMQemuImageError.accessFailed(url)
        }
        pushArgv(url.path)
    }

    static func convert(from url: URL, toQcow2 dest: URL, withCompression compressed: Bool = false, onProgress: ProgressCallback? = nil) async throws {
        try await withProcess { qemuImg in
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
            try await qemuImg.pushArgv(accessing: url)
            try await qemuImg.pushArgv(accessing: dest)
            try await qemuImg.start(onProgress: onProgress)
        }
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

    struct QemuSnapshotInfo: Codable, Sendable, Equatable {
        let id: String
        let name: String
        let vmStateSize: Int64
        let dateSec: Int64
        let dateNsec: Int64
        let vmClockSec: Int64
        let vmClockNsec: Int64

        var date: Date {
            Date(timeIntervalSince1970: TimeInterval(dateSec) + TimeInterval(dateNsec) / 1_000_000_000)
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case vmStateSize = "vm-state-size"
            case dateSec = "date-sec"
            case dateNsec = "date-nsec"
            case vmClockSec = "vm-clock-sec"
            case vmClockNsec = "vm-clock-nsec"
        }
    }

    struct QemuImageInfo: Codable {
        let virtualSize : Int64
        let filename : String
        let clusterSize : Int32?
        let format : String
        let actualSize : Int64
        let dirtyFlag : Bool?
        let snapshots: [QemuSnapshotInfo]?

        private enum CodingKeys: String, CodingKey {
            case virtualSize = "virtual-size"
            case filename
            case clusterSize = "cluster-size"
            case format
            case actualSize = "actual-size"
            case dirtyFlag = "dirty-flag"
            case snapshots
        }
    }

    static func info(image url: URL) async throws -> QemuImageInfo {
        try await withProcess { qemuImg in
            qemuImg.pushArgv("info")
            qemuImg.pushArgv("--output=json")
            try await qemuImg.pushArgv(accessing: url)
            try await qemuImg.start()

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let data = qemuImg.output.lines.joined(separator: "\n").data(using: .utf8) ?? Data()
            return try decoder.decode(QemuImageInfo.self, from: data)
        }
    }

    /// Internal snapshots stored in an image
    static func snapshots(image url: URL) async throws -> [QemuSnapshotInfo] {
        try await info(image: url).snapshots ?? []
    }

    private enum SnapshotOperation: String {
        case create = "-c"
        case apply = "-a"
        case delete = "-d"
    }

    private static func snapshot(_ operation: SnapshotOperation, name: String, image url: URL) async throws {
        try await withProcess { qemuImg in
            qemuImg.pushArgv("snapshot")
            qemuImg.pushArgv(operation.rawValue)
            qemuImg.pushArgv(name)
            try await qemuImg.pushArgv(accessing: url)
            try await qemuImg.start()
        }
    }

    /// Save the contents of the image as an internal snapshot without any VM state
    static func createSnapshot(image url: URL, name: String) async throws {
        try await snapshot(.create, name: name, image: url)
    }

    /// Revert the contents of the image to an internal snapshot
    static func applySnapshot(image url: URL, name: String) async throws {
        try await snapshot(.apply, name: name, image: url)
    }

    static func deleteSnapshot(image url: URL, name: String) async throws {
        try await snapshot(.delete, name: name, image: url)
    }

    static func size(image url: URL) async throws -> Int64 {
        try await info(image: url).virtualSize
    }

    static func resize(image url: URL, size : UInt64) async throws {
        try await withProcess { qemuImg in
            qemuImg.pushArgv("resize")
            qemuImg.pushArgv("-f")
            qemuImg.pushArgv("qcow2")
            try await qemuImg.pushArgv(accessing: url)
            qemuImg.pushArgv(String(size))
            try await qemuImg.start()
        }
    }
}

private enum UTMQemuImageError: Error {
    case qemuError(String)
    case accessFailed(URL)
    case unknown
}

extension UTMQemuImageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .qemuError(let message): return message
        case .accessFailed(let url): return String.localizedStringWithFormat(NSLocalizedString("Cannot access '%@'.", comment: "UTMQemuImage"), url.lastPathComponent)
        case .unknown: return NSLocalizedString("An unknown QEMU error has occurred.", comment: "UTMQemuImage")
        }
    }
}

// MARK: - Output

/// Collects the lines a tool writes to a pipe until the tool closes it
private final class UTMQemuImageOutput: @unchecked Sendable {
    /// Waited for at most this long after the tool exited
    private static let endTimeout: TimeInterval = 5

    let pipe = Pipe()
    /// Called for each line as it arrives, such as the progress of a conversion
    var onLine: ((String) -> Void)?

    private let lock = NSLock()
    private var buffer = Data()
    private var isEnded = false
    private var endContinuation: CheckedContinuation<Void, Never>?
    private var _lines = [String]()

    /// Complete once the output has ended
    var lines: [String] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return _lines
    }

    init() {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.read(from: handle)
        }
    }

    /// Give up the write end so the reader sees the end of the output when the tool exits
    func closeWriter() {
        try? pipe.fileHandleForWriting.close()
    }

    func waitForEnd() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            guard !isEnded else {
                lock.unlock()
                continuation.resume()
                return
            }
            endContinuation = continuation
            lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.endTimeout) {
                self.end()
            }
        }
    }

    private func read(from handle: FileHandle) {
        let data = handle.availableData
        guard !data.isEmpty else {
            handle.readabilityHandler = nil
            end()
            return
        }
        lock.lock()
        buffer.append(data)
        var lines = [String]()
        while let separator = buffer.firstIndex(where: { $0 == UInt8(ascii: "\n") || $0 == UInt8(ascii: "\r") }) {
            lines.append(String(decoding: buffer[buffer.startIndex..<separator], as: UTF8.self))
            buffer.removeSubrange(buffer.startIndex...separator)
        }
        _lines.append(contentsOf: lines)
        lock.unlock()
        for line in lines {
            onLine?(line)
        }
    }

    private func end() {
        lock.lock()
        if !buffer.isEmpty {
            _lines.append(String(decoding: buffer, as: UTF8.self))
            buffer.removeAll()
        }
        isEnded = true
        let continuation = endContinuation
        endContinuation = nil
        lock.unlock()
        continuation?.resume()
    }
}

// MARK: - Progress

extension UTMQemuImage {
    private static func parseProgress(_ line: String) -> Float? {
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
