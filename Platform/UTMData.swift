//
// Copyright © 2020 osy. All rights reserved.
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

class UTMData: ObservableObject {
    
    @Published var currentVM: UTMVirtualMachine? = nil
    
    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    var virtualMachines: [UTMVirtualMachine] {
        let fileManager = FileManager.default
        var list = [UTMVirtualMachine]()
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            for file in files {
                guard try file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false else {
                    continue
                }
                guard UTMVirtualMachine.isVirtualMachine(url: file) else {
                    continue
                }
                let vm = UTMVirtualMachine(url: file)
                if vm != nil {
                    list.append(vm!)
                } else {
                    logger.error("Failed to create object for \(file)")
                }
            }
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        return list
    }
    
    func newDefaultName() -> String {
        let nameForId = { (i: Int) in "Virtual Machine \(i)" }
        for i in 1..<1000 {
            let name = nameForId(i)
            let file = UTMVirtualMachine.virtualMachinePath(name, inParentURL: documentsURL)
            if !FileManager.default.fileExists(atPath: file.path) {
                return name
            }
        }
        return ProcessInfo.processInfo.globallyUniqueString
    }
    
    func saveConfiguration(config: UTMConfiguration) throws {
        let vm = UTMVirtualMachine(configuration: config, withDestinationURL: documentsURL)
        do {
            try vm.saveUTM()
        } catch {
            DispatchQueue.main.async {
                self.objectWillChange.send() // reload old Configuration in Views
            }
            throw error
        }
    }
}
