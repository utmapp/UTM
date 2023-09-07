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

public func startProcess(ptr: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    var process = ptr.load(as: UTMProcess.self)
    var processArgv = process.argv
    var environment: [String] = []
    
    for (_, item) in process.environemnt!.enumerated() {
        var combined = String(format: "%@=%@", item.key, item.value)
        environment.append(combined)
        setenv(item.key, item.value, 1)
    }
    var envc = environment.count
    var envp: [UnsafePointer<Int8>] = []
    for env in environment {
        envp.append(UnsafePointer<Int8>(env.cString(using: .utf8)!))
    }
    envp.append(UnsafePointer<Int8>([]))
    setenv("TMPDIR", FileManager.default.temporaryDirectory.path.cString(using: .utf8), 1)
    
    var currentDirectoryPath = UnsafePointer<Int8>(process.currentDirectoryUrl!.path.cString(using: .utf8))
    chdir(currentDirectoryPath)
    
    var argc: Int32 = Int32(processArgv.count + 1)
    var argv: [UnsafePointer<Int8>] = []
    if let name = process.processName {
        argv.append(UnsafePointer<Int8>(name.cString(using: .utf8)!))
    } else {
        argv.append(UnsafePointer<Int8>("process".cString(using: .utf8)!))
    }
    for arg in processArgv {
        argv.append(UnsafePointer<Int8>(arg.cString(using: .utf8)!))
    }
    
    argv.withUnsafeMutableBufferPointer({ argv in
        envp.withUnsafeMutableBufferPointer({ envp in
            process.status = Int(process.entry(process, argc, argv.baseAddress!, envp.baseAddress!))
        })
    })
    process.done.signal()
    return nil
}

class UTMProcess : NSObject {
    typealias UTMProcessThreadEntry = (UTMProcess, Int32, UnsafeMutablePointer<UnsafePointer<Int8>>, UnsafeMutablePointer<UnsafePointer<Int8>>) -> Int32

    public let libraryURL: URL = Bundle.main.bundleURL
                                    .appendingPathComponent("Contents", isDirectory: true)
                                    .appendingPathComponent("Frameworks", isDirectory: true)
    public var hasRemoteProcess: Bool {
        return connection != nil
    }
    public var arguments: String {
        var args = ""
        for arg in argv {
            if arg.contains(where: { $0 == " "} ) {
                args = args.appendingFormat(" \"%@\"", arg)
            } else {
                args = args.appendingFormat(" %@", arg)
            }
        }
        return args
    }
    
    public var argv: [String]
    public var urls: [URL]
    public var status: Int = 0
    public var fatal: Int = 0
    public var entry: UTMProcessThreadEntry
    public var standardOutput: Pipe?
    public var standardError: Pipe?
    public var currentDirectoryUrl: URL?
    public var connection: NSXPCConnection?
    public var processName: String?
    public var environemnt: Dictionary<String, String>?
    public var completionQueue: DispatchQueue
    public var done: DispatchSemaphore

    init?(arguments: [String]) {
        argv = arguments
        urls = []
        completionQueue = DispatchQueue(label: "QEMU Completion Queue", qos: .utility)
        entry = UTMProcess.defaultEntry
        done = DispatchSemaphore(value: 0)
        super.init()
        if !setupXpc() {
            return nil
        }
    }
    
    deinit {
        stopProcess()
    }
    
    public static func defaultEntry(process: UTMProcess, argc: Int32, argv: UnsafeMutablePointer<UnsafePointer<Int8>>, envp: UnsafeMutablePointer<UnsafePointer<Int8>>) -> Int32 {
        return -1
    }
    
    public func setupXpc() -> Bool {
#if TARGET_OS_IPHONE
        return true;
#else // Only supported on macOS
        var helperIdentifier = Bundle.main.infoDictionary!["HelperIdentifier"]
        if helperIdentifier == nil {
            helperIdentifier = "com.utmapp.QEMUHelper"
        }
        connection = NSXPCConnection(serviceName: helperIdentifier as! String)
        connection!.remoteObjectInterface = NSXPCInterface(with: QEMUHelperProtocol.self)
        connection!.exportedInterface = NSXPCInterface(with: QEMUHelperDelegate.self)
        connection!.exportedObject = self
        connection!.resume()
        // NSXPCConnection can never be nil in Swift
        return true
#endif
    }

    public func pushArgv(arg: String) {
        argv.append(arg)
    }

    public func clearArgv() {
        argv.removeAll()
    }
    
    public func didLoadDylib(_ handle: UnsafeMutableRawPointer) -> Bool {
        return true
    }
    
    public func startDylibThread(dylib: String, completion: @escaping (_ error: Error?) -> Void) {
        var qemu_thread: pthread_t?
        var qosAttribute: pthread_attr_t = pthread_attr_t()
        status = 0
        fatal = 0
        UTMLoggingSwift.log("Loading %@", dylib)
        if let dlctxPtr = dlopen(dylib, RTLD_LOCAL) {
            if !didLoadDylib(dlctxPtr) {
                var error = String(utf8String: dlerror())!
                completion(errorWithMessage(message: error))
                return
            }
            
            if (atexit_b {
                if pthread_self() == qemu_thread {
                    self.fatal = 1
                    self.done.signal()
                }
                pthread_exit(nil)
            } != 0) {
                completion(errorWithMessage(message: NSLocalizedString("Internal error has occured", comment: "UTMProcess")))
                return
            }
            var pSelf = UnsafeMutablePointer<UTMProcess>.allocate(capacity: 1)
            pSelf.pointee = self
            pthread_attr_init(&qosAttribute)
            pthread_attr_set_qos_class_np(&qosAttribute, QOS_CLASS_USER_INTERACTIVE, 0)
            // There is likely a Swift-ier way to do this with modern concurrency
            pthread_create(&qemu_thread, &qosAttribute, startProcess(ptr:), pSelf)
            completionQueue.async(qos: .userInteractive) {
                if self.done.wait(timeout: .distantFuture) == .timedOut {
                    dlclose(dlctxPtr)
                    self.processHasExited(exitCode: -1, message: NSLocalizedString("Internal error has occured.", comment: "UTMProcess"))
                } else {
                    if dlclose(dlctxPtr) < 0 {
                        var error = String(utf8String: dlerror())!
                        self.processHasExited(exitCode: -1, message: error)
                    } else if (self.fatal != 0) || (self.status != 0) {
                        self.processHasExited(exitCode: -1, message: "")
                    } else {
                        self.processHasExited(exitCode: 0, message: "")
                    }
                }
            }
            completion(nil)
        } else {
            var error = String(utf8String: dlerror())!
            completion(errorWithMessage(message: error))
            return
        }
    }
    
    public func startQemuRemote(name: String, completion: @escaping (_ error: Error?) -> Void) {
        do {
            var libBookmark = try self.libraryURL.bookmarkData()
            var standardOutput = self.standardOutput!.fileHandleForWriting
            var standardError = self.standardError!.fileHandleForWriting
            var proxy = connection!.remoteObjectProxy as! any QEMUHelperProtocol
            proxy.environment = self.environemnt
            proxy.currentDirectoryPath = self.currentDirectoryUrl!.path
            proxy.assertActive(token: { _ in })
            
            proxy = connection!.remoteObjectProxyWithErrorHandler({ error in
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain && nsError.code == NSXPCConnectionInvalid {
                    self.processHasExited(exitCode: 0, message: "")
                } else {
                    self.processHasExited(exitCode: nsError.code, message: error.localizedDescription)
                }
            }) as! any QEMUHelperProtocol
            
            proxy.startQemu(name, standardOutput: standardOutput, standardError: standardError, libraryBookmark: libBookmark, argv: argv, completion: { success, message in
                if !success {
                    completion(self.errorWithMessage(message: message))
                } else {
                    completion(nil)
                }
            })
        } catch {
            completion(error)
            return
        }
    }
    
    public func startProcess(name: String, completion: @escaping (_ error: Error?) -> Void) {
#if TARGET_OS_IPHONE
        var base = ""
#else
        var base = "Versions/A/"
#endif
        var dylib = String(format: "%@.framework/%@%@", name, base, name)
        self.processName = name
        if let connection = connection {
            startQemuRemote(name: dylib, completion: completion)
        } else {
            startDylibThread(dylib: dylib, completion: completion)
        }
    }
    
    public func stopProcess() {
        if let connection = connection {
            let proxy = connection.remoteObjectProxy as! any QEMUHelperProtocol
            proxy.terminate()
            connection.invalidate()
        }
        connection = nil
        for url in urls {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    public func accessDataWithBookmarkThread(bookmark: Data, securityScoped: Bool, completion: @escaping (_ bool: Bool, _ data: Data?, _ path: String?) -> Void) {
        var stale = false
        var url: URL = URL(string: "")!

        do {
            var url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
        } catch {
            UTMLoggingSwift.log("Failed to access bookmark data.")
            completion(false, nil, nil)
            return
        }

        do {
            if stale || !securityScoped {
                var bookmark = try url.bookmarkData(options: .minimalBookmark)
                
            }
        } catch {
            UTMLoggingSwift.log("Failed to create new bookmark!")
            completion(false, bookmark, url.path)
            return
        }

        if url.startAccessingSecurityScopedResource() {
            urls.append(url)
        } else {
            UTMLoggingSwift.log("Failed to access security scoped resource for: %@", url)
        }
        completion(true, bookmark, url.path)
    }

    public func accessDataWithBookmark(bookmark: Data) {
        self.accessDataWithBookmark(bookmark: bookmark, securityScoped: false, completion: { success, bookmark, path  in
            if !success {
                UTMLoggingSwift.log("Access bookmark failed for %@", path!)
            }
        })
    }
    
    public func accessDataWithBookmark(bookmark: Data, securityScoped: Bool, completion: @escaping (_ bool: Bool, _ data: Data?, _ string: String?) -> Void) {
        if let connection = connection {
            let proxy = connection.remoteObjectProxy as! any QEMUHelperProtocol
            proxy.accessData(withBookmark: bookmark, securityScoped: securityScoped, completion: completion)
        } else {
            self.accessDataWithBookmark(bookmark: bookmark, securityScoped: securityScoped, completion: completion)
        }
    }
    
    public func stopAccessingPathThread(path: String) {
        for url in urls {
            if url.path == path {
                url.stopAccessingSecurityScopedResource()
                urls.removeAll(where: { $0 == url} )
                return
            }
        }
        
        UTMLoggingSwift.log("Cannot find '%@' in existing scoped access.", path)
    }
    
    public func stopAccessingPath(path: String) {
        if let connection = connection {
            let proxy = connection.remoteObjectProxy as! any QEMUHelperProtocol
            proxy.stopAccessingPath(path)
        } else {
            self.stopAccessingPathThread(path: path)
        }
    }
    
    public func errorWithMessage(message: String) -> NSError {
        return NSError(domain: kUTMErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    
    public func processHasExited(exitCode: Int, message: String) {
        UTMLoggingSwift.log("QEMU has exited with code %ld and message %@", exitCode, message)
    }
}
