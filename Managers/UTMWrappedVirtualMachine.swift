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
    
    override var detailsNotes: String? {
        ""
    }
    
    override var detailsSystemTargetLabel: String {
        ""
    }
    
    override var detailsSystemArchitectureLabel: String {
        ""
    }
    
    override var detailsSystemMemoryLabel: String {
        ""
    }
    
    override var hasSaveState: Bool {
        false
    }
    
    override var bookmark: Data? {
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
    init(bookmark: Data, name: String, path: URL) {
        _bookmark = bookmark
        _name = name
        _path = path
        super.init()
        self.path = path
    }
    
    /// Create a new wrapped UTM VM from an existing UTM VM
    /// - Parameter vm: Existing VM
    convenience init?(placeholderFor vm: UTMVirtualMachine) {
        guard let bookmark = vm.bookmark else {
            return nil
        }
        guard let path = vm.path else {
            return nil
        }
        self.init(bookmark: bookmark, name: vm.detailsTitleLabel, path: path)
    }
    
    /// Create a new wrapped UTM VM from a dictionary
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
    @available(iOS 14, macOS 11, *)
    public func unwrap() -> UTMVirtualMachine? {
        guard let vm = UTMVirtualMachine(bookmark: _bookmark) else {
            return nil
        }
        let defaultStorageUrl = UTMData.defaultStorageUrl.standardizedFileURL
        let parentUrl = vm.path!.deletingLastPathComponent().standardizedFileURL
        if parentUrl != defaultStorageUrl {
            vm.isShortcut = true
        }
        return vm
    }
}
