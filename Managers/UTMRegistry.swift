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

import Combine
import Foundation

class UTMRegistry: NSObject {
    @objc static let shared = UTMRegistry()
    
    private var lastUpdateTasks: [UTMRegistryEntry: Task<Void, Error>] = [:]
    
    private var serializedEntries: [String: Any] {
        get {
            UserDefaults.standard.dictionary(forKey: "Registry") ?? [:]
        }
        
        set {
            UserDefaults.standard.setValue(newValue, forKey: "Registry")
        }
    }
    
    private var changeListeners: [String: AnyCancellable] = [:]
    
    private var entries: [String: UTMRegistryEntry] {
        didSet {
            let toAdd = entries.keys.filter({ !changeListeners.keys.contains($0) })
            for key in toAdd {
                let entry = entries[key]!
                changeListeners[key] = entry.objectWillChange.sink { [weak self, weak entry] in
                    if let entry = entry {
                        self?.update(entry: entry)
                    }
                }
            }
            let toRemove = changeListeners.keys.filter({ !entries.keys.contains($0) })
            for key in toRemove {
                changeListeners.removeValue(forKey: key)
            }
        }
    }
    
    private override init() {
        entries = [:]
        super.init()
        if let newEntries = try? serializedEntries.mapValues({ value in
            let dict = value as! [String: Any]
            return try UTMRegistryEntry(from: dict)
        }) {
            entries = newEntries
        }
    }
    
    /// Gets an existing registry entry or create a new entry
    /// - Parameter vm: UTM virtual machine to locate in the registry
    /// - Returns: Either an existing registry entry or a new entry
    @objc func entry(for vm: UTMVirtualMachine) -> UTMRegistryEntry {
        if let entry = entries[vm.id] {
            return entry
        }
        return UTMRegistryEntry(newFrom: vm)!
    }
    
    /// Coalesce multiple updates in quick succession into one
    /// - Parameter entry: Entry to update
    private func update(entry: UTMRegistryEntry) {
        lastUpdateTasks[entry]?.cancel()
        lastUpdateTasks[entry] = Task(priority: .background) {
            let uuid = await entry.uuid
            let dict = try await entry.asDictionary()
            serializedEntries[uuid] = dict
            lastUpdateTasks.removeValue(forKey: entry)
        }
    }
}
