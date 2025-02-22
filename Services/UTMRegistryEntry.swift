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
import Combine

@objc class UTMRegistryEntry: NSObject, Codable, ObservableObject {
    /// Empty registry entry used only as a workaround for object initialization
    static let empty = UTMRegistryEntry(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, name: "", path: "")
    
    @Published private var _name: String
    
    @Published private var _package: File
    
    private(set) var uuid: UUID
    
    @Published private var _isSuspended: Bool
    
    @Published private var _externalDrives: [String: File]
    
    @Published private var _sharedDirectories: [File]
    
    @Published private var _windowSettings: [Int: Window]
    
    @Published private var _terminalSettings: [Int: Terminal]

    @Published private var _resolutionSettings: [Int: Resolution]

    @Published private var _hasMigratedConfig: Bool
    
    @Published private var _macRecoveryIpsw: File?
    
    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case package = "Package"
        case uuid = "UUID"
        case isSuspended = "Suspended"
        case externalDrives = "ExternalDrives"
        case sharedDirectories = "SharedDirectories"
        case windowSettings = "WindowSettings"
        case terminalSettings = "TerminalSettings"
        case resolutionSettings = "ResolutionSettings"
        case hasMigratedConfig = "MigratedConfig"
        case macRecoveryIpsw = "MacRecoveryIpsw"
    }
    
    init(uuid: UUID, name: String, path: String, bookmark: Data? = nil) {
        _name = name
        let package: File?
        if let bookmark = bookmark {
            package = try? File(path: path, bookmark: bookmark)
        } else {
            package = nil
        }
        _package = package ?? File(dummyFromPath: path)
        self.uuid = uuid
        _isSuspended = false
        _externalDrives = [:]
        _sharedDirectories = []
        _windowSettings = [:]
        _terminalSettings = [:]
        _resolutionSettings = [:]
        _hasMigratedConfig = false
    }
    
    convenience init(newFrom vm: any UTMVirtualMachine) {
        self.init(uuid: vm.id, name: vm.name, path: vm.pathUrl.path)
        if let package = try? File(url: vm.pathUrl) {
            _package = package
        }
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _name = try container.decode(String.self, forKey: .name)
        _package = try container.decode(File.self, forKey: .package)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        _isSuspended = try container.decode(Bool.self, forKey: .isSuspended)
        _externalDrives = (try container.decode([String: File].self, forKey: .externalDrives)).filter({ $0.value.isValid })
        _sharedDirectories = try container.decode([File].self, forKey: .sharedDirectories).filter({ $0.isValid })
        _windowSettings = try container.decode([Int: Window].self, forKey: .windowSettings)
        _terminalSettings = try container.decodeIfPresent([Int: Terminal].self, forKey: .terminalSettings) ?? [:]
        _resolutionSettings = try container.decodeIfPresent([Int: Resolution].self, forKey: .resolutionSettings) ?? [:]
        _hasMigratedConfig = try container.decodeIfPresent(Bool.self, forKey: .hasMigratedConfig) ?? false
        _macRecoveryIpsw = try container.decodeIfPresent(File.self, forKey: .macRecoveryIpsw)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_name, forKey: .name)
        try container.encode(_package, forKey: .package)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(_isSuspended, forKey: .isSuspended)
        try container.encode(_externalDrives, forKey: .externalDrives)
        try container.encode(_sharedDirectories, forKey: .sharedDirectories)
        try container.encode(_windowSettings, forKey: .windowSettings)
        try container.encode(_terminalSettings, forKey: .terminalSettings)
        try container.encode(_resolutionSettings, forKey: .resolutionSettings)
        if _hasMigratedConfig {
            try container.encode(_hasMigratedConfig, forKey: .hasMigratedConfig)
        }
        try container.encodeIfPresent(_macRecoveryIpsw, forKey: .macRecoveryIpsw)
    }
    
    func asDictionary() throws -> [String: Any] {
        return try propertyList() as! [String: Any]
    }
    
    /// Update the UUID
    ///
    /// Should only be called from `UTMRegistry`!
    /// - Parameter uuid: UUID to change to
    func _updateUuid(_ uuid: UUID) {
        self.objectWillChange.send()
        self.uuid = uuid
    }
}

protocol UTMRegistryEntryDecodable: Decodable {}
extension UTMRegistryEntry: UTMRegistryEntryDecodable {}

// MARK: - Accessors
@MainActor extension UTMRegistryEntry {
    var name: String {
        get {
            _name
        }
        
        set {
            _name = newValue
        }
    }
    
    var package: File {
        get {
            _package
        }
        
        set {
            _package = newValue
        }
    }
    
    var isSuspended: Bool {
        get {
            _isSuspended
        }
        
        set {
            _isSuspended = newValue
        }
    }
    
    var externalDrives: [String: File] {
        get {
            _externalDrives
        }
        
        set {
            _externalDrives = newValue
        }
    }

    var externalDrivePublisher: Published<[String: File]>.Publisher {
        $_externalDrives
    }

    var sharedDirectories: [File] {
        get {
            _sharedDirectories
        }
        
        set {
            _sharedDirectories = newValue
        }
    }
    
    var windowSettings: [Int: Window] {
        get {
            _windowSettings
        }
        
        set {
            _windowSettings = newValue
        }
    }
    
    var terminalSettings: [Int: Terminal] {
        get {
            _terminalSettings
        }
        
        set {
            _terminalSettings = newValue
        }
    }

    var resolutionSettings: [Int: Resolution] {
        get {
            _resolutionSettings
        }

        set {
            _resolutionSettings = newValue
        }
    }

    var hasMigratedConfig: Bool {
        get {
            _hasMigratedConfig
        }
        
        set {
            _hasMigratedConfig = newValue
        }
    }
    
    var macRecoveryIpsw: File? {
        get {
            _macRecoveryIpsw
        }
        
        set {
            _macRecoveryIpsw = newValue
        }
    }
    
    func setExternalDrive(_ file: File, forId id: String) {
        externalDrives[id] = file
    }
    
    func updateExternalDriveRemoteBookmark(_ bookmark: Data, forId id: String) {
        externalDrives[id]?.remoteBookmark = bookmark
    }
    
    func removeExternalDrive(forId id: String) {
        externalDrives.removeValue(forKey: id)
    }
    
    func setSingleSharedDirectory(_ file: File) {
        sharedDirectories = [file]
    }
    
    func updateSingleSharedDirectoryRemoteBookmark(_ bookmark: Data) {
        if !sharedDirectories.isEmpty {
            sharedDirectories[0].remoteBookmark = bookmark
        }
    }
    
    func appendSharedDirectory(_ file: File) {
        sharedDirectories.append(file)
    }
    
    func removeAllSharedDirectories() {
        sharedDirectories = []
    }
    
    func update(copying other: UTMRegistryEntry) {
        isSuspended = other.isSuspended
        externalDrives = other.externalDrives
        sharedDirectories = other.sharedDirectories
        windowSettings = other.windowSettings
        terminalSettings = other.terminalSettings
        resolutionSettings = other.resolutionSettings
        hasMigratedConfig = other.hasMigratedConfig
    }
    
    func setIsSuspended(_ isSuspended: Bool) {
        self.isSuspended = isSuspended
    }
    
    func setPackageRemoteBookmark(_ remoteBookmark: Data?, path: String? = nil) {
        package.remoteBookmark = remoteBookmark
        if let path = path {
            package.path = path
        }
    }
}

// MARK: - Migration from UTMViewState

extension UTMRegistryEntry {
    /// Migrate from a view state
    /// - Parameter viewState: View state to migrate
    private func migrate(viewState: UTMLegacyViewState) {
        var primaryWindow = Window()
        if viewState.displayScale != .zero {
            primaryWindow.scale = viewState.displayScale
        }
        if viewState.displayOriginX != .zero || viewState.displayOriginY != .zero {
            primaryWindow.origin = CGPoint(x: viewState.displayOriginX,
                                           y: viewState.displayOriginY)
        }
        primaryWindow.isKeyboardVisible = viewState.isKeyboardShown
        primaryWindow.isToolbarVisible = viewState.isToolbarShown
        if primaryWindow != Window() {
            _windowSettings[0] = primaryWindow
        }
        _isSuspended = viewState.hasSaveState
        if let sharedDirectoryBookmark = viewState.sharedDirectory, let sharedDirectoryPath = viewState.sharedDirectoryPath {
            if let file = try? File(path: sharedDirectoryPath,
                                    bookmark: sharedDirectoryBookmark) {
                _sharedDirectories = [file]
            } else {
                logger.error("Failed to migrate shared directory \(sharedDirectoryPath) because bookmark is invalid.")
            }
        }
        if let shortcutBookmark = viewState.shortcutBookmark {
            _package.remoteBookmark = shortcutBookmark
        }
        for drive in viewState.allDrives() {
            if let bookmark = viewState.bookmark(forRemovableDrive: drive), let path = viewState.path(forRemovableDrive: drive) {
                let file = File(dummyFromPath: path, remoteBookmark: bookmark)
                _externalDrives[drive] = file
            }
        }
    }
    
    /// Try to migrate from a view.plist or does nothing if it does not exist.
    /// - Parameter viewStateURL: URL to view.plist
    @objc func migrateUnsafe(viewStateURL: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: viewStateURL.path) else {
            return
        }
        guard let dict = try? NSDictionary(contentsOf: viewStateURL, error: ()) as? [AnyHashable : Any] else {
            logger.error("Failed to parse legacy \(viewStateURL)")
            return
        }
        let viewState = UTMLegacyViewState(dictionary: dict)
        migrate(viewState: viewState)
        try? fileManager.removeItem(at: viewStateURL) // delete view.plist
    }
    
    #if os(macOS)
    /// Try to migrate bookmarks from an Apple VM config.
    /// - Parameter config: Apple config to migrate
    @MainActor func migrate(fromAppleConfig config: UTMAppleConfiguration) {
        for sharedDirectory in config.sharedDirectories {
            if let url = sharedDirectory.directoryURL,
               let file = try? File(url: url, isReadOnly: sharedDirectory.isReadOnly) {
                sharedDirectories.append(file)
            } else {
                logger.error("Failed to migrate a shared directory from config.")
            }
        }
        for drive in config.drives {
            if drive.isExternal, let url = drive.imageURL,
               let file = try? File(url: url, isReadOnly: drive.isReadOnly) {
                externalDrives[drive.id] = file
            } else {
                logger.error("Failed to migrate drive \(drive.id) from config.")
            }
        }
    }
    #endif
}

extension UTMRegistryEntry {
    struct File: Codable, Identifiable {
        var url: URL
        
        var path: String
        
        var bookmark: Data
        
        var remoteBookmark: Data?
        
        var isReadOnly: Bool
        
        let id: UUID = UUID()
        
        fileprivate var isValid: Bool
        
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
            self.isValid = true
        }
        
        init(url: URL, isReadOnly: Bool = false) throws {
            self.path = url.path
            self.bookmark = try url.persistentBookmarkData(isReadyOnly: isReadOnly)
            self.isReadOnly = isReadOnly
            self.url = url
            self.isValid = true
        }
        
        init(dummyFromPath path: String, remoteBookmark: Data = Data()) {
            self.path = path
            self.bookmark = Data()
            self.isReadOnly = false
            self.url = URL(fileURLWithPath: path)
            self.remoteBookmark = remoteBookmark
            self.isValid = true
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            path = try container.decode(String.self, forKey: .path)
            bookmark = try container.decode(Data.self, forKey: .bookmark)
            isReadOnly = try container.decode(Bool.self, forKey: .isReadOnly)
            remoteBookmark = try container.decodeIfPresent(Data.self, forKey: .remoteBookmark)
            url = URL(fileURLWithPath: path)
            if bookmark.isEmpty {
                isValid = true
            } else {
                // we cannot throw because that stops the decode process so we record the error and continue
                do {
                    url = try URL(resolvingPersistentBookmarkData: bookmark)
                    isValid = true
                } catch {
                    isValid = false
                }
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(path, forKey: .path)
            try container.encode(bookmark, forKey: .bookmark)
            try container.encode(isReadOnly, forKey: .isReadOnly)
            try container.encodeIfPresent(remoteBookmark, forKey: .remoteBookmark)
        }
    }
    
    struct Window: Codable, Equatable {
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
        
        init() {
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
    
    struct Terminal: Codable, Equatable {
        var columns: Int
        
        var rows: Int
        
        private enum CodingKeys: String, CodingKey {
            case columns = "Columns"
            case rows = "Rows"
        }
        
        init(columns: Int = 80, rows: Int = 24) {
            self.columns = columns
            self.rows = rows
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            columns = try container.decode(Int.self, forKey: .columns)
            rows = try container.decode(Int.self, forKey: .rows)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(columns, forKey: .columns)
            try container.encode(rows, forKey: .rows)
        }
    }

    struct Resolution: Codable, Equatable {
        var size: CGSize = .zero

        var isFullscreen: Bool = false

        private enum CodingKeys: String, CodingKey {
            case size = "Size"
            case isFullscreen = "Fullscreen"
        }

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            size = try container.decode(CGSize.self, forKey: .size)
            isFullscreen = try container.decode(Bool.self, forKey: .isFullscreen)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(size, forKey: .size)
            try container.encode(isFullscreen, forKey: .isFullscreen)
        }
    }
}
