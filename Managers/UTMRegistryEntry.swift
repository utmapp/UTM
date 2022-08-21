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

@objc class UTMRegistryEntry: NSObject, Codable, ObservableObject {
    @UTMRegistryValue var name: String
    
    @UTMRegistryValue var package: File
    
    @UTMRegistryValue var uuid: String
    
    @UTMRegistryValue var isSuspended: Bool
    
    @UTMRegistryValue var externalDrives: [String: File]
    
    @UTMRegistryValue var sharedDirectories: [File]
    
    @UTMRegistryValue var windowSettings: [Int: Window]
    
    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case package = "Package"
        case uuid = "UUID"
        case isSuspended = "Suspended"
        case externalDrives = "ExternalDrives"
        case sharedDirectories = "SharedDirectories"
        case windowSettings = "WindowSettings"
    }
    
    init?(newFrom vm: UTMVirtualMachine) {
        guard let bookmark = vm.bookmark else {
            return nil
        }
        let path = vm.path.path
        name = vm.detailsTitleLabel
        guard let package = try? File(path: path, bookmark: bookmark, isReadOnly: false) else {
            return nil
        }
        self.package = package;
        uuid = vm.config.uuid.uuidString
        isSuspended = false
        externalDrives = [:]
        sharedDirectories = []
        windowSettings = [:]
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        package = try container.decode(File.self, forKey: .package)
        uuid = try container.decode(String.self, forKey: .uuid)
        isSuspended = try container.decode(Bool.self, forKey: .isSuspended)
        externalDrives = try container.decode([String: File].self, forKey: .externalDrives)
        sharedDirectories = try container.decode([File].self, forKey: .sharedDirectories)
        windowSettings = try container.decode([Int: Window].self, forKey: .windowSettings)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(package, forKey: .package)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(isSuspended, forKey: .isSuspended)
        try container.encode(externalDrives, forKey: .externalDrives)
        try container.encode(sharedDirectories, forKey: .sharedDirectories)
        try container.encode(windowSettings, forKey: .windowSettings)
    }
}

// MARK: - Objective C bridging
@objc extension UTMRegistryEntry {
    var hasSaveState: Bool {
        get {
            isSuspended
        }
        
        set {
            isSuspended = newValue
        }
    }
    
    var packageRemoteBookmark: Data? {
        get {
            package.remoteBookmark
        }
        
        set {
            package.remoteBookmark = newValue
        }
    }
    
    var packageRemotePath: String? {
        get {
            if package.remoteBookmark != nil {
                return package.path
            } else {
                return nil
            }
        }
        
        set {
            if newValue != nil {
                package.path = newValue!
            }
        }
    }
}

extension UTMRegistryEntry {
    struct File: Codable {
        var url: URL
        
        var path: String
        
        var bookmark: Data
        
        var remoteBookmark: Data?
        
        var isReadOnly: Bool
        
        private enum CodingKeys: String, CodingKey {
            case path = "Path"
            case bookmark = "Bookmark"
            case remoteBookmark = "BookmarkRemote"
            case isReadOnly = "ReadOnly"
        }
        
        init(path: String, bookmark: Data, isReadOnly: Bool = false) throws {
            self.path = path
            self.bookmark = bookmark
            self.isReadOnly = isReadOnly
            self.url = try URL(resolvingPersistentBookmarkData: bookmark)
        }
        
        init(url: URL, isReadOnly: Bool = false) throws {
            self.path = url.path
            self.bookmark = try url.persistentBookmarkData(isReadyOnly: isReadOnly)
            self.isReadOnly = isReadOnly
            self.url = url
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            path = try container.decode(String.self, forKey: .path)
            bookmark = try container.decode(Data.self, forKey: .bookmark)
            isReadOnly = try container.decode(Bool.self, forKey: .isReadOnly)
            remoteBookmark = try container.decodeIfPresent(Data.self, forKey: .remoteBookmark)
            url = try URL(resolvingPersistentBookmarkData: bookmark)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(path, forKey: .path)
            try container.encode(bookmark, forKey: .bookmark)
            try container.encode(isReadOnly, forKey: .isReadOnly)
            try container.encodeIfPresent(remoteBookmark, forKey: .remoteBookmark)
        }
    }
    
    struct Window: Codable {
        var scale: CGFloat = 1.0
        
        var origin: CGPoint = .zero
        
        var isToolbarVisible: Bool = true
        
        var isKeyboardVisible: Bool = false
        
        var isDisplayZoomLocked: Bool = true
        
        private enum CodingKeys: String, CodingKey {
            case scale = "Scale"
            case origin = "Origin"
            case isToolbarVisible = "ToolbarVisible"
            case isKeyboardVisible = "KeyboardVisible"
            case isDisplayZoomLocked = "DisplayZoomLocked"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            scale = try container.decode(CGFloat.self, forKey: .scale)
            origin = try container.decode(CGPoint.self, forKey: .origin)
            isToolbarVisible = try container.decode(Bool.self, forKey: .isToolbarVisible)
            isKeyboardVisible = try container.decode(Bool.self, forKey: .isKeyboardVisible)
            isDisplayZoomLocked = try container.decode(Bool.self, forKey: .isDisplayZoomLocked)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(scale, forKey: .scale)
            try container.encode(origin, forKey: .origin)
            try container.encode(isToolbarVisible, forKey: .isToolbarVisible)
            try container.encode(isKeyboardVisible, forKey: .isKeyboardVisible)
            try container.encode(isDisplayZoomLocked, forKey: .isDisplayZoomLocked)
        }
    }
}

@propertyWrapper struct UTMRegistryValue<Value> {
    static subscript(
        _enclosingInstance instance: UTMRegistryEntry,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<UTMRegistryEntry, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<UTMRegistryEntry, Self>
    ) -> Value {
        get {
            instance[keyPath: storageKeyPath].storage
        }
        set {
            instance[keyPath: storageKeyPath].storage = newValue
            UTMRegistry.shared.update(entry: instance)
        }
    }

    @available(*, unavailable,
        message: "@UTMRegistryValue can only be applied to classes"
    )
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    private var storage: Value

    init(wrappedValue: Value) {
        storage = wrappedValue
    }
}
