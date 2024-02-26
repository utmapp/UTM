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
    
    private var serializedEntries: [String: Any] {
        get {
            UserDefaults.standard.dictionary(forKey: "Registry") ?? [:]
        }
        
        set {
            UserDefaults.standard.setValue(newValue, forKey: "Registry")
        }
    }
    
    private var registryListener: AnyCancellable?
    
    private var changeListeners: [String: AnyCancellable] = [:]
    
    @Published private var entries: [String: UTMRegistryEntry] {
        didSet {
            let toAdd = entries.keys.filter({ !changeListeners.keys.contains($0) })
            for key in toAdd {
                let entry = entries[key]!
                changeListeners[key] = entry.objectWillChange
                    .debounce(for: .seconds(1), scheduler: DispatchQueue.global(qos: .utility))
                    .sink { [weak self, weak entry] in
                    if let self = self, let entry = entry {
                        self.commit(entry: entry, to: &self.serializedEntries)
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
            return try UTMRegistryEntry(fromPropertyList: dict)
        }) {
            entries = newEntries
        }
        registryListener = $entries
            .debounce(for: .seconds(1), scheduler: DispatchQueue.global(qos: .utility))
            .sink { [weak self] newEntries in
                self?.commitAll(entries: newEntries)
            }
    }
    
    /// Gets an existing registry entry or create a new entry
    /// - Parameter vm: UTM virtual machine to locate in the registry
    /// - Returns: Either an existing registry entry or a new entry
    func entry(for vm: any UTMVirtualMachine) -> UTMRegistryEntry {
        if let entry = entries[vm.id.uuidString] {
            return entry
        }
        let newEntry = UTMRegistryEntry(newFrom: vm)
        entries[newEntry.uuid.uuidString] = newEntry
        return newEntry
    }
    
    /// Gets an existing registry entry or create a new entry for a legacy bookmark
    /// - Parameters:
    ///   - uuid: UUID
    ///   - name: VM name
    ///   - path: VM path string
    ///   - bookmark: VM bookmark
    /// - Returns: Either an existing registry entry or a new entry
    func entry(uuid: UUID, name: String, path: String, bookmark: Data? = nil) -> UTMRegistryEntry {
        if let entry = entries[uuid.uuidString] {
            return entry
        }
        let newEntry = UTMRegistryEntry(uuid: uuid, name: name, path: path, bookmark: bookmark)
        entries[uuid.uuidString] = newEntry
        return newEntry
    }
    
    /// Get an existing registry entry for a UUID
    /// - Parameter uuidString: UUID
    /// - Returns: An existing registry entry or nil if it does not exist
    func entry(for uuidString: String) -> UTMRegistryEntry? {
        return entries[uuidString]
    }
    
    /// Commit the entry to persistent storage
    /// This runs in a background queue.
    /// - Parameter entry: Entry to commit
    private func commit(entry: UTMRegistryEntry, to entries: inout [String: Any]) {
        let uuid = entry.uuid
        if let dict = try? entry.asDictionary() {
            entries[uuid.uuidString] = dict
        } else {
            logger.error("Failed to commit entry for \(uuid)")
        }
    }
    
    /// Commit all entries to persistent storage
    /// This runs in a background queue.
    /// - Parameter entries: All entries to commit
    private func commitAll(entries: [String: UTMRegistryEntry]) {
        var newSerializedEntries: [String: Any] = [:]
        for key in entries.keys {
            let entry = entries[key]!
            commit(entry: entry, to: &newSerializedEntries)
        }
        serializedEntries = newSerializedEntries
    }
    
    /// Remove an entry from the registry
    /// - Parameter entry: Entry to remove
    func remove(entry: UTMRegistryEntry) {
        entries.removeValue(forKey: entry.uuid.uuidString)
    }
    
    /// Remove all entries from the registry except for the specified set
    /// - Parameter uuidStrings: Keys to NOT remove
    func prune(exceptFor uuidStrings: Set<String>) {
        for key in entries.keys {
            if !uuidStrings.contains(key) {
                entries.removeValue(forKey: key)
            }
        }
    }
    
    /// Make sure the registry is synchronized when UTM terminates
    func sync() {
        commitAll(entries: entries)
    }
}
