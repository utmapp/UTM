//
// Copyright © 2024 naveenrajm7. All rights reserved.
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

@MainActor
@objc(UTMScriptingImportCommand)
class UTMScriptingImportCommand: NSCreateCommand, UTMScriptable {
    
    private var data: UTMData? {
        (NSApp.scriptingDelegate as? AppDelegate)?.data
    }
    
    @objc override func performDefaultImplementation() -> Any? {
        if createClassDescription.implementationClassName == "UTMScriptingVirtualMachineImpl" {
            withScriptCommand(self) { [self] in
                // Retrieve the import file URL from the evaluated arguments
                guard let fileUrl = evaluatedArguments?["file"] as? URL else {
                    throw ScriptingError.fileNotSpecified
                }
                
                // Validate the file (UTM is a directory) path
                guard FileManager.default.fileExists(atPath: fileUrl.path) else {
                    throw ScriptingError.fileNotFound
                }
                return try await importVirtualMachine(from: fileUrl).objectSpecifier
            }
            return nil
        } else {
            return super.performDefaultImplementation()
        }
    }
    
    private func importVirtualMachine(from url: URL) async throws -> UTMScriptingVirtualMachineImpl {
        guard let data = data else {
            throw ScriptingError.notReady
        }
        
        // import the VM
        let vm = try await data.importNewUTM(from: url)
        
        // return VM scripting object
        return UTMScriptingVirtualMachineImpl(for: vm, data: data)
    }
    
    enum ScriptingError: Error, LocalizedError {
        case notReady
        case fileNotFound
        case fileNotSpecified
        
        var errorDescription: String? {
            switch self {
            case .notReady: return NSLocalizedString("UTM is not ready to accept commands.", comment: "UTMScriptingAppDelegate")
            case .fileNotFound: return NSLocalizedString("A valid UTM file must be specified.", comment: "UTMScriptingAppDelegate")
            case .fileNotSpecified: return NSLocalizedString("No file specified in the command.", comment: "UTMScriptingAppDelegate")
            }
        }
    }
}
