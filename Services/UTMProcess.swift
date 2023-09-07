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

class UTMProcess {
    public let hasRemoteProcess: Bool
    public let libraryURL: URL
    public var argv: [String]
    public let arguments: String
    public var environemnt: Dictionary<String, String>?
    public var status: Int
    public var fatal: Int
    public var entry: UTMProcessThreadEntry
    public var standardOutput: Pipe?
    public var standardError: Pipe?
    public var currentDirectoryUrl: URL?
    public var urls: [URL]
    public var connection: NSXPCConnection?

    init(arguments: [String]) {
        <#statements#>
    }
    
    public static func startProcess(args) {
        
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
        status = 0
        fatal = 0
        UTMLoggingSwift.log("Loading %@", dylib)
        var dlctxPtr = dlopen(dylib, RTLD_LOCAL)
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
                if error.domain == NSCocoaErrorDomain && error.code == NSXPCConnectionInvalid {
                    self.processHasExited(exitCode: 0, message: nil)
                } else {
                    self.processHasExited(exitCode: error.code, message: error.localizedDescription)
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
    
    public func accessDataWithBookmarkThread(bookmark: Data, securityScoped: Bool, completion: @escaping (_ error: Error?) -> Void) {
        
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
