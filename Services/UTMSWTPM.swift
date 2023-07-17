//
// Copyright © 2023 osy. All rights reserved.
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

private typealias SwtpmMainFunction = @convention(c) (_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafePointer<CChar>>, _ prgname: UnsafePointer<CChar>, _ iface: UnsafePointer<CChar>) -> Int32

private let kMaxAttempts = 15
private let kRetryDelay = 1*NSEC_PER_SEC

class UTMSWTPM: UTMProcess {
    private var swtpmMain: SwtpmMainFunction!
    private var hasProcessExited: Bool = false
    private var lastErrorLine: String?
    
    var ctrlSocketUrl: URL?
    var dataUrl: URL?
    
    private override init(arguments: [String]) {
        super.init(arguments: arguments)
        entry = { process, argc, argv, envp in
            let _self = process as! UTMSWTPM
            return _self.swtpmMain(argc, argv, "swtpm", "socket")
        }
        standardError = Pipe()
        standardError!.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let string = String(data: handle.availableData, encoding: .utf8) ?? ""
            logger.debug("\(string)")
            self?.lastErrorLine = string
        }
        standardOutput = Pipe()
        standardOutput!.fileHandleForReading.readabilityHandler = { handle in
            let string = String(data: handle.availableData, encoding: .utf8) ?? ""
            logger.debug("\(string)")
        }
    }
    
    convenience init() {
        self.init(arguments: [])
    }
    
    override func didLoadDylib(_ handle: UnsafeMutableRawPointer) -> Bool {
        let sym = dlsym(handle, "swtpm_main")
        swtpmMain = unsafeBitCast(sym, to: SwtpmMainFunction.self)
        return swtpmMain != nil
    }
    
    override func processHasExited(_ exitCode: Int, message: String?) {
        hasProcessExited = true
        if let message = message {
            logger.error("SWTPM exited: \(message)")
        }
    }
    
    func start() async throws {
        guard let ctrlSocketUrl = ctrlSocketUrl else {
            throw UTMSWTPMError.socketNotSpecified
        }
        guard let dataUrl = dataUrl else {
            throw UTMSWTPMError.dataNotSpecified
        }
        let fm = FileManager.default
        if !fm.fileExists(atPath: dataUrl.path) {
            fm.createFile(atPath: dataUrl.path, contents: nil)
        }
        let dataBookmark = try dataUrl.bookmarkData()
        let (success, _, _) = await accessData(withBookmark: dataBookmark, securityScoped: false)
        guard success else {
            throw UTMSWTPMError.cannotAccessTpmData
        }
        clearArgv()
        pushArgv("--ctrl")
        pushArgv("type=unixio,path=\(ctrlSocketUrl.lastPathComponent),terminate")
        pushArgv("--tpmstate")
        pushArgv("backend-uri=file://\(dataUrl.path)")
        pushArgv("--tpm2")
        hasProcessExited = false
        try? fm.removeItem(at: ctrlSocketUrl)
        try await start("swtpm.0")
        // monitor for socket to be created
        try await Task {
            let fm = FileManager.default
            for _ in 0...kMaxAttempts {
                if hasProcessExited {
                    throw UTMSWTPMError.swtpmStartupFailed(lastErrorLine)
                }
                if fm.fileExists(atPath: ctrlSocketUrl.path) {
                    return
                }
                try await Task.sleep(nanoseconds: kRetryDelay)
            }
        }.value
    }
}

enum UTMSWTPMError: Error {
    case socketNotSpecified
    case dataNotSpecified
    case cannotAccessTpmData
    case swtpmStartupFailed(String?)
}

extension UTMSWTPMError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .socketNotSpecified: return NSLocalizedString("Socket not specified.", comment: "UTMSWTPM")
        case .dataNotSpecified: return NSLocalizedString("Data not specified.", comment: "UTMSWTPM")
        case .cannotAccessTpmData: return NSLocalizedString("Cannot access TPM data.", comment: "UTMSWTPM")
        case .swtpmStartupFailed(let message): return String.localizedStringWithFormat(NSLocalizedString("SW TPM failed to start. %@", comment: "UTMSWTPM"), message ?? "")
        }
    }
}
