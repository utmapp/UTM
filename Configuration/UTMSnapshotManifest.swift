//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

/// Everything UTM knows about the snapshots of a VM, stored as `snapshots.plist` in the bundle.
///
/// The backend (QEMU image, Apple disk image) only stores the state of a snapshot. Each entry
/// here links to that state through `backendIdentifier` and adds what the backend cannot hold.
struct UTMSnapshotManifest: Codable, Equatable {
    static let fileName = "snapshots.plist"

    /// Directory in the bundle holding the screenshots referenced by the entries
    static let screenshotsDirectoryName = "Snapshots"

    struct Snapshot: Codable, Identifiable, Equatable {
        var id: UUID = UUID()

        /// User-editable display name
        var title: String

        /// Snapshot the current state was based on when this one was created, `nil` if there was none
        var parentID: UUID?

        var dateCreated: Date

        var dateModified: Date

        /// Bytes occupied in the backend
        var size: Int64

        /// Includes the running state of the VM and not just the disks
        var hasState: Bool

        /// Identifies the state in the backend
        var backendIdentifier: String

        /// File in the screenshots directory
        var screenshotName: String?

        /// The backend no longer has the state this entry links to
        var isOrphaned: Bool = false

        /// The state does not cover every drive, such as after one was added, so it cannot be restored
        var isIncomplete: Bool = false

        private enum CodingKeys: String, CodingKey {
            case id = "Identifier"
            case title = "Title"
            case parentID = "Parent"
            case dateCreated = "Created"
            case dateModified = "Modified"
            case size = "Size"
            case hasState = "HasState"
            case backendIdentifier = "BackendIdentifier"
            case screenshotName = "Screenshot"
            case isOrphaned = "Orphaned"
            case isIncomplete = "Incomplete"
        }

        init(title: String, parentID: UUID?, date: Date, size: Int64, hasState: Bool, backendIdentifier: String, screenshotName: String? = nil) {
            self.title = title
            self.parentID = parentID
            self.dateCreated = date
            self.dateModified = date
            self.size = size
            self.hasState = hasState
            self.backendIdentifier = backendIdentifier
            self.screenshotName = screenshotName
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(UUID.self, forKey: .id)
            title = try values.decode(String.self, forKey: .title)
            parentID = try values.decodeIfPresent(UUID.self, forKey: .parentID)
            dateCreated = try values.decode(Date.self, forKey: .dateCreated)
            dateModified = try values.decode(Date.self, forKey: .dateModified)
            size = try values.decode(Int64.self, forKey: .size)
            hasState = try values.decode(Bool.self, forKey: .hasState)
            backendIdentifier = try values.decode(String.self, forKey: .backendIdentifier)
            screenshotName = try values.decodeIfPresent(String.self, forKey: .screenshotName)
            isOrphaned = try values.decodeIfPresent(Bool.self, forKey: .isOrphaned) ?? false
            isIncomplete = try values.decodeIfPresent(Bool.self, forKey: .isIncomplete) ?? false
        }

        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(id, forKey: .id)
            try values.encode(title, forKey: .title)
            try values.encodeIfPresent(parentID, forKey: .parentID)
            try values.encode(dateCreated, forKey: .dateCreated)
            try values.encode(dateModified, forKey: .dateModified)
            try values.encode(size, forKey: .size)
            try values.encode(hasState, forKey: .hasState)
            try values.encode(backendIdentifier, forKey: .backendIdentifier)
            try values.encodeIfPresent(screenshotName, forKey: .screenshotName)
            if isOrphaned {
                try values.encode(isOrphaned, forKey: .isOrphaned)
            }
            if isIncomplete {
                try values.encode(isIncomplete, forKey: .isIncomplete)
            }
        }
    }

    private(set) var version: Int = 1

    /// Newest first
    var snapshots: [Snapshot] = []

    /// Snapshot the current state descends from, `nil` if there is none
    var currentParentID: UUID?

    /// Backend state the VM resumes from the next time it starts while it is marked as suspended
    ///
    /// This may be the state of a snapshot. Otherwise it is only used for suspending.
    var suspendIdentifier: String?

    /// Snapshots already in the backend were added, which is done once for the benefit of those
    /// made by other tools. The manifest can exist before this because suspending creates it.
    var isBackendImported: Bool = false

    /// States in the backend that nothing needs anymore but that could not be deleted yet
    var staleIdentifiers: [String] = []

    private enum CodingKeys: String, CodingKey {
        case version = "Version"
        case snapshots = "Snapshots"
        case currentParentID = "CurrentParent"
        case suspendIdentifier = "SuspendIdentifier"
        case isBackendImported = "BackendImported"
        case staleIdentifiers = "Stale"
    }

    init() {
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        snapshots = try values.decode([Snapshot].self, forKey: .snapshots)
        currentParentID = try values.decodeIfPresent(UUID.self, forKey: .currentParentID)
        suspendIdentifier = try values.decodeIfPresent(String.self, forKey: .suspendIdentifier)
        isBackendImported = try values.decodeIfPresent(Bool.self, forKey: .isBackendImported) ?? false
        staleIdentifiers = try values.decodeIfPresent([String].self, forKey: .staleIdentifiers) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version)
        try values.encode(snapshots, forKey: .snapshots)
        try values.encodeIfPresent(currentParentID, forKey: .currentParentID)
        try values.encodeIfPresent(suspendIdentifier, forKey: .suspendIdentifier)
        try values.encode(isBackendImported, forKey: .isBackendImported)
        if !staleIdentifiers.isEmpty {
            try values.encode(staleIdentifiers, forKey: .staleIdentifiers)
        }
    }
}

// MARK: - Links

extension UTMSnapshotManifest {
    subscript(id: UUID) -> Snapshot? {
        get {
            snapshots.first { $0.id == id }
        }

        set {
            if let index = snapshots.firstIndex(where: { $0.id == id }) {
                if let newValue = newValue {
                    snapshots[index] = newValue
                } else {
                    snapshots.remove(at: index)
                }
            } else if let newValue = newValue {
                insert(newValue)
            }
        }
    }

    mutating func insert(_ snapshot: Snapshot) {
        snapshots.append(snapshot)
        snapshots.sort { $0.dateCreated > $1.dateCreated }
    }

    /// Removes an entry and hands its children to its parent so the remaining lineage stays linked.
    mutating func remove(_ id: UUID) {
        guard let snapshot = self[id] else {
            return
        }
        for index in snapshots.indices where snapshots[index].parentID == id {
            snapshots[index].parentID = snapshot.parentID
        }
        if currentParentID == id {
            currentParentID = snapshot.parentID
        }
        self[id] = nil
    }

    /// The state in the backend is still needed by an entry or for resuming
    func isReferenced(backendIdentifier: String) -> Bool {
        suspendIdentifier == backendIdentifier || snapshots.contains { $0.backendIdentifier == backendIdentifier }
    }

    /// Remember to delete a state from the backend unless something still needs it
    mutating func markStale(_ backendIdentifier: String) {
        if !isReferenced(backendIdentifier: backendIdentifier) && !staleIdentifiers.contains(backendIdentifier) {
            staleIdentifiers.append(backendIdentifier)
        }
    }

    /// Resume from `backendIdentifier` from now on, or from nothing
    mutating func setSuspendState(_ backendIdentifier: String?) {
        let previous = suspendIdentifier
        suspendIdentifier = backendIdentifier
        if let previous = previous, previous != backendIdentifier {
            markStale(previous)
        }
    }
}

// MARK: - Suspend state

/// How a VM keeps track of the state it resumes from, the only part of the manifest that a VM
/// changes itself. Everything else goes through `UTMSnapshotService`.
///
/// A state that is let go of stays listed as stale until it has been deleted, so that one that
/// cannot be deleted right away is tried again the next time.
extension UTMSnapshotManifest {
    /// State the VM in a bundle resumes from, if the manifest names one
    static func suspendState(in bundleURL: URL) -> String? {
        ((try? load(from: bundleURL)) ?? nil)?.suspendIdentifier
    }

    /// Resume from `backendIdentifier` from now on.
    /// - Returns: States to delete, which are forgotten with `forgetState(_:in:)` once they are gone
    static func replaceSuspendState(in bundleURL: URL, with backendIdentifier: String) throws -> [String] {
        try update(in: bundleURL) { manifest in
            manifest.setSuspendState(backendIdentifier)
            return manifest.staleIdentifiers
        }
    }

    /// Stop resuming from any state.
    /// - Parameter defaultIdentifier: State of a VM that was suspended before the manifest named it
    /// - Returns: States to delete, which are forgotten with `forgetState(_:in:)` once they are gone
    static func releaseSuspendState(in bundleURL: URL, default defaultIdentifier: String?) throws -> [String] {
        try update(in: bundleURL) { manifest in
            if manifest.suspendIdentifier == nil, let defaultIdentifier = defaultIdentifier {
                manifest.suspendIdentifier = defaultIdentifier
            }
            manifest.setSuspendState(nil)
            return manifest.staleIdentifiers
        }
    }

    /// A state that was to be deleted is gone
    static func forgetState(_ backendIdentifier: String, in bundleURL: URL) throws {
        try update(in: bundleURL) { manifest in
            manifest.staleIdentifiers.removeAll { $0 == backendIdentifier }
        }
    }
}

// MARK: - Storage

extension UTMSnapshotManifest {
    /// Serializes every read-modify-write of a manifest
    private static let lock = NSLock()

    private static func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try body()
    }

    private static func fileURL(in bundleURL: URL) -> URL {
        bundleURL.appendingPathComponent(fileName)
    }

    static func screenshotsURL(in bundleURL: URL) -> URL {
        bundleURL.appendingPathComponent(screenshotsDirectoryName, isDirectory: true)
    }

    /// - Returns: `nil` if the bundle has no manifest yet
    static func load(from bundleURL: URL) throws -> UTMSnapshotManifest? {
        let fileURL = fileURL(in: bundleURL)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try PropertyListDecoder().decode(UTMSnapshotManifest.self, from: data)
    }

    func save(to bundleURL: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        try encoder.encode(self).write(to: Self.fileURL(in: bundleURL), options: .atomic)
    }

    /// Posted with the bundle as its object whenever a manifest is saved
    static let didChangeNotification = Notification.Name("UTMSnapshotManifestDidChange")

    /// Modify the manifest of a bundle, creating it if needed.
    /// - Parameters:
    ///   - bundleURL: Bundle of the VM
    ///   - body: Changes to make, nothing is written if this throws
    /// - Returns: Result of `body`
    @discardableResult
    static func update<T>(in bundleURL: URL, _ body: (inout UTMSnapshotManifest) throws -> T) throws -> T {
        let (result, isChanged) = try withLock { () -> (T, Bool) in
            var manifest = try load(from: bundleURL) ?? UTMSnapshotManifest()
            let original = manifest
            let result = try body(&manifest)
            if manifest != original {
                try manifest.save(to: bundleURL)
            }
            return (result, manifest != original)
        }
        // observers may take the lock themselves
        if isChanged {
            NotificationCenter.default.post(name: didChangeNotification, object: bundleURL)
        }
        return result
    }
}
