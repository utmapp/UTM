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

/// Represents a UTM Virtual Machine that is a placeholder and cannot be started
@objc class UTMWrappedVirtualMachine: UTMVirtualMachine {
    override var detailsTitleLabel: String {
        _name
    }
    
    override var detailsSubtitleLabel: String {
        NSLocalizedString("Unavailable", comment: "UTMUnavailableVirtualMachine")
    }
    
    var bookmark: Data {
        _bookmark
    }
    
    /// Represent a serialized dictionary for saving the VM to a list
    public var serialized: [String: Any] {
        return ["Name": _name,
                "Path": _path.path,
                "Bookmark": _bookmark];
    }
    
    private var _bookmark: Data
    
    private var _name: String
    
    private var _path: URL {
        didSet {
            self.path = _path
        }
    }
    
    /// Create a new wrapped UTM VM
    /// - Parameters:
    ///   - bookmark: Bookmark data for this VM
    ///   - name: Name of this VM
    ///   - path: Path where the VM is located
    ///   - uuid: UUID of the VM
    init(bookmark: Data, name: String, path: URL, uuid: UUID? = nil) {
        _bookmark = bookmark
        _name = name
        _path = path
        let config = UTMConfigurationWrapper(placeholderFor: name, uuid: uuid)
        super.init(configuration: config, packageURL: path)
    }
    
    /// Create a new wrapped UTM VM from a registry entry
    /// - Parameter registryEntry: Registry entry
    @MainActor convenience init(from registryEntry: UTMRegistryEntry) {
        let file = registryEntry.package
        self.init(bookmark: file.bookmark, name: registryEntry.name, path: file.url, uuid: registryEntry.uuid)
    }
    
    /// Create a new wrapped UTM VM from a dictionary (legacy support)
    /// - Parameter info: Dictionary info
    convenience init?(from info: [String: Any]) {
        guard let bookmark = info["Bookmark"] as? Data,
              let name = info["Name"] as? String,
              let pathString = info["Path"] as? String else {
            return nil
        }
        self.init(bookmark: bookmark, name: name, path: URL(fileURLWithPath: pathString))
    }
    
    /// Create a new wrapped UTM VM from only the bookmark data (legacy support)
    /// - Parameter bookmark: Bookmark data
    convenience init(bookmark: Data) {
        self.init(bookmark: bookmark,
                  name: NSLocalizedString("(Unavailable)", comment: "UTMWrappedVirtualMachine"),
                  path: URL(fileURLWithPath: "/\(UUID().uuidString)"))
    }
    
    /// Unwrap to a fully formed UTM VM
    /// - Returns: New UTM VM if it is valid and can be accessed
    @MainActor func unwrap() -> UTMVirtualMachine? {
        guard let vm = UTMVirtualMachine(url: registryEntry.package.url) else {
            return nil
        }
        let defaultStorageUrl = UTMData.defaultStorageUrl.standardizedFileURL
        let parentUrl = vm.path.deletingLastPathComponent().standardizedFileURL
        if parentUrl != defaultStorageUrl {
            vm.isShortcut = true
        }
        return vm
    }
}
