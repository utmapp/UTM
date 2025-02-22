//
// Copyright © 2025 naveenrajm7. All rights reserved.
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

@objc extension UTMScriptingVirtualMachineImpl {
    @objc var registry: [URL] {
        let wrapper = UTMScriptingRegistryEntryImpl(vm.registryEntry)
        return wrapper.serializeRegistry()
    }
    
    @objc func updateRegistry(_ command: NSScriptCommand) {
        let newRegistry = command.evaluatedArguments?["newRegistry"] as? [URL]
        withScriptCommand(command) { [self] in
            guard let newRegistry = newRegistry else {
                throw ScriptingError.invalidParameter
            }
            let wrapper = UTMScriptingRegistryEntryImpl(vm.registryEntry)
            try await wrapper.updateRegistry(from: newRegistry, qemuProcess)
        }
    }
}

@MainActor
class UTMScriptingRegistryEntryImpl {
    private(set) var registry: UTMRegistryEntry
    
    init(_ registry: UTMRegistryEntry) {
        self.registry = registry
    }
    
    func serializeRegistry() -> [URL] {
        return registry.sharedDirectories.compactMap { $0.url }
    }
    
    func updateRegistry(from fileUrls: [URL], _ system: UTMQemuSystem?) async throws {
        // Clear all shared directories, we add all directories here
        registry.removeAllSharedDirectories()
        
        // Add urls to the registry
        for url in fileUrls {
            // Start scoped access
            let isScopedAccess = url.startAccessingSecurityScopedResource()
            defer {
                if isScopedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Get bookmark from UTM process
            let standardBookmark = try url.bookmarkData()
            let system = system ?? UTMProcess()
            let (success, bookmark, path) = await system.accessData(withBookmark: standardBookmark, securityScoped: false)
            guard let bookmark = bookmark, let _ = path, success else {
                throw UTMQemuVirtualMachineError.accessDriveImageFailed
            }
            
            // Store bookmark in registry
            let file = UTMRegistryEntry.File(dummyFromPath: url.path, remoteBookmark: bookmark)
            registry.appendSharedDirectory(file)
        }
        
    }
}
