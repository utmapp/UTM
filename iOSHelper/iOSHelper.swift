//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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
import ExtensionFoundation

/// Runs a QEMU tool such as qemu-img for the app, out of the app's process.
///
/// Like the macOS `QEMUHelper`, this speaks `QEMUHelperProtocol` and reaches the app's files
/// through the bookmarks it is passed, but QEMU is loaded into the helper itself as iOS cannot
/// spawn processes. A QEMU tool can run once per process, so the helper exits when its
/// connection ends and the app launches a new one for the next tool.
@main
final class iOSHelper: AppExtension {
    required init() {
    }

    var configuration: some AppExtensionConfiguration {
        ConnectionHandler { connection in
            connection.exportedInterface = NSXPCInterface(with: QEMUHelperProtocol.self)
            connection.exportedObject = QEMUHelperService(connection: connection)
            connection.remoteObjectInterface = NSXPCInterface(with: QEMUHelperDelegate.self)
            connection.invalidationHandler = {
                _exit(0)
            }
            connection.resume()
            return true
        }
    }
}

final class QEMUHelperService: NSObject, QEMUHelperProtocol {
    typealias MainFunction = @convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

    var environment: [String: String]?
    var currentDirectoryPath: String?

    private weak var connection: NSXPCConnection?
    private var urls = [URL]()
    private var activeToken: tokenCallback_t?
    private var isStarted = false

    init(connection: NSXPCConnection) {
        self.connection = connection
    }

    func accessData(withBookmark bookmark: Data, securityScoped: Bool, completion: @escaping (Bool, Data?, String?) -> Void) {
        var isStale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
        } catch {
            NSLog("Failed to access bookmark data: \(error)")
            completion(false, nil, nil)
            return
        }
        if url.startAccessingSecurityScopedResource() {
            urls.append(url)
        } else {
            NSLog("Failed to access security scoped resource for: \(url)")
        }
        completion(true, bookmark, url.path)
    }

    func stopAccessingPath(_ path: String?) {
        guard let path = path, let index = urls.firstIndex(where: { $0.path == path }) else {
            return
        }
        urls[index].stopAccessingSecurityScopedResource()
        urls.remove(at: index)
    }

    func startQemu(_ binName: String, standardOutput: FileHandle, standardError: FileHandle, libraryBookmark libBookmark: Data, argv: [String], completion: @escaping (Bool, String?) -> Void) {
        guard !isStarted else {
            completion(false, NSLocalizedString("The helper is already in use.", comment: "iOSHelper"))
            return
        }
        isStarted = true
        var isStale = false
        guard let libraryURL = try? URL(resolvingBookmarkData: libBookmark, bookmarkDataIsStale: &isStale),
              FileManager.default.fileExists(atPath: libraryURL.path) else {
            NSLog("Cannot resolve library path")
            completion(false, NSLocalizedString("Cannot find QEMU support libraries.", comment: "iOSHelper"))
            return
        }
        // the tool writes to the app's pipes as if it were a process of its own
        dup2(standardOutput.fileDescriptor, STDOUT_FILENO)
        dup2(standardError.fileDescriptor, STDERR_FILENO)
        try? standardOutput.close()
        try? standardError.close()
        let dylibURL = libraryURL.appendingPathComponent(binName)
        let thread = Thread { [self] in
            runQemu(dylib: dylibURL, name: dylibURL.lastPathComponent, argv: argv)
        }
        thread.qualityOfService = .userInitiated
        thread.start()
        completion(true, nil)
    }

    func terminate() {
        _exit(0)
    }

    func assertActive(token: @escaping tokenCallback_t) {
        activeToken?(false)
        activeToken = token
    }

    private func runQemu(dylib: URL, name: String, argv: [String]) {
        guard let handle = dlopen(dylib.path, RTLD_LOCAL | RTLD_FIRST) else {
            processHasExited(-1, message: String(cString: dlerror()))
            return
        }
        guard let symbol = dlsym(handle, "main") else {
            processHasExited(-1, message: String(cString: dlerror()))
            return
        }
        let main = unsafeBitCast(symbol, to: MainFunction.self)
        for (key, value) in environment ?? [:] {
            setenv(key, value, 1)
        }
        setenv("TMPDIR", FileManager.default.temporaryDirectory.path, 1)
        if let currentDirectoryPath = currentDirectoryPath {
            chdir(currentDirectoryPath)
        }
        // a tool that calls exit() is reported as a failure instead of taking the helper down silently
        let qemuThread = pthread_self()
        atexit_b { [self] in
            if pthread_equal(pthread_self(), qemuThread) != 0 {
                endOutput()
                processHasExited(-1, message: nil)
                pthread_exit(nil)
            }
        }
        var cArgv = ([name] + argv).map { strdup($0) } + [nil]
        let status = main(Int32(argv.count + 1), &cArgv)
        endOutput()
        processHasExited(Int(status), message: nil)
    }

    /// Gives the app's pipes back so it sees the end of the output
    private func endOutput() {
        fflush(nil)
        let null = open("/dev/null", O_WRONLY)
        if null >= 0 {
            dup2(null, STDOUT_FILENO)
            dup2(null, STDERR_FILENO)
            close(null)
        }
    }

    private func processHasExited(_ exitCode: Int, message: String?) {
        (connection?.remoteObjectProxy as? QEMUHelperDelegate)?.processHasExited(exitCode, message: message)
        activeToken?(true)
        activeToken = nil
    }
}
