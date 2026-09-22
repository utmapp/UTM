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

import SwiftUI

/// A saved state of a virtual machine as shown in the snapshots list.
struct VMSnapshot: Identifiable, Equatable {
    let id: UUID

    /// User-editable display name
    var title: String

    /// Snapshot the current state was based on when this one was created, `nil` if there was none
    var parentID: UUID?

    var dateCreated: Date

    /// Last time the snapshot was renamed or overwritten
    var dateModified: Date

    /// Bytes occupied on disk
    var size: Int64

    /// Screen contents when the snapshot was taken, if one was captured
    var screenshot: PlatformImage?

    /// Includes the running state of the VM, otherwise it starts up from the saved disks
    var hasState: Bool

    /// The saved state is missing so the snapshot can only be deleted
    var isOrphaned: Bool

    /// The saved state does not cover every drive so the snapshot cannot be restored
    var isIncomplete: Bool = false

    /// Possible while the VM is in its current state, which differs between running and not
    var canRestore: Bool = true

    /// Possible while the VM is in its current state, which differs between running and not
    var canDelete: Bool = true

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.parentID == rhs.parentID
            && lhs.dateCreated == rhs.dateCreated
            && lhs.dateModified == rhs.dateModified
            && lhs.size == rhs.size
            && lhs.screenshot === rhs.screenshot
            && lhs.hasState == rhs.hasState
            && lhs.isOrphaned == rhs.isOrphaned
            && lhs.isIncomplete == rhs.isIncomplete
            && lhs.canRestore == rhs.canRestore
            && lhs.canDelete == rhs.canDelete
    }
}

/// Snapshots of a single VM along with the "current" state they are listed under.
@MainActor
final class VMSnapshotList: ObservableObject {
    /// Saved snapshots, newest first
    @Published private(set) var snapshots: [VMSnapshot] = []

    /// Snapshot the current state is based on, `nil` if there is none
    @Published private(set) var currentParentID: UUID?

    /// Nothing changed since the snapshot the current state is based on
    @Published private(set) var isCurrentStateSaved: Bool = false

    /// The current state can be saved while the VM is in its current state
    @Published private(set) var canCreate: Bool = false

    /// The snapshot the current state is based on can be replaced while the VM is in its current state
    @Published private(set) var canOverwriteBase: Bool = false

    /// Weak so that the cache does not keep a VM alive after it leaves the library
    private weak var vm: VMData?

    /// Screenshots by file
    private var screenshots: [URL: PlatformImage] = [:]

    private static var cache: [UUID: VMSnapshotList] = [:]

    private var manifestObserver: (any NSObjectProtocol)?

    /// Returns the list for a VM, keeping it alive so it is not read again every time it is shown.
    static func list(for vm: VMData) -> VMSnapshotList {
        cache = cache.filter { $0.value.vm != nil }
        if let list = cache[vm.id] {
            return list
        }
        let list = VMSnapshotList(vm: vm)
        cache[vm.id] = list
        return list
    }

    private init(vm: VMData) {
        self.vm = vm
        // snapshots also change through scripting while they are shown
        manifestObserver = NotificationCenter.default.addObserver(forName: UTMSnapshotService.didChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let bundleURL = notification.object as? URL
            Task { @MainActor [weak self] in
                guard let self = self, let bundleURL = bundleURL, bundleURL.standardizedFileURL == self.vm?.wrapped?.pathUrl.standardizedFileURL else {
                    return
                }
                try? await self.refresh()
            }
        }
    }

    private var wrapped: any UTMVirtualMachine {
        get throws {
            guard let wrapped = vm?.wrapped else {
                throw UTMSnapshotError.notSupported
            }
            return wrapped
        }
    }

    // MARK: - Lineage

    func snapshot(for id: UUID?) -> VMSnapshot? {
        guard let id = id else {
            return nil
        }
        return snapshots.first { $0.id == id }
    }

    /// Identifiers of every ancestor starting at `id` (inclusive) and walking up the parents.
    func lineage(from id: UUID?) -> Set<UUID> {
        var lineage = Set<UUID>()
        var next = snapshot(for: id)
        while let snapshot = next, !lineage.contains(snapshot.id) {
            lineage.insert(snapshot.id)
            next = self.snapshot(for: snapshot.parentID)
        }
        return lineage
    }

    // MARK: - Operations

    /// Read the snapshots of the VM. The first time this adds those made by other tools.
    func refresh() async throws {
        let wrapped = try wrapped
        let timeline = try await UTMSnapshotService.timeline(for: wrapped)
        snapshots = timeline.snapshots.map { snapshot in
            VMSnapshot(id: snapshot.id,
                       title: snapshot.title,
                       parentID: snapshot.parentID,
                       dateCreated: snapshot.dateCreated,
                       dateModified: snapshot.dateModified,
                       size: snapshot.size,
                       screenshot: screenshot(at: snapshot.screenshotURL),
                       hasState: snapshot.hasState,
                       isOrphaned: snapshot.isOrphaned,
                       isIncomplete: snapshot.isIncomplete,
                       canRestore: !snapshot.isOrphaned && !snapshot.isIncomplete && UTMSnapshotService.isSupported(.restore, for: snapshot, on: wrapped),
                       canDelete: UTMSnapshotService.isSupported(.delete, for: snapshot, on: wrapped))
        }
        // pictures of snapshots that are gone are not needed anymore
        let screenshotURLs = Set(timeline.snapshots.compactMap { $0.screenshotURL })
        screenshots = screenshots.filter { screenshotURLs.contains($0.key) }
        currentParentID = timeline.currentParentID
        isCurrentStateSaved = timeline.isCurrentStateSaved
        canCreate = UTMSnapshotService.isSupported(.create, on: wrapped)
        // overwriting saves the current state and deletes what the snapshot held
        canOverwriteBase = canCreate && snapshot(for: currentParentID)?.canDelete == true
    }

    private func screenshot(at url: URL?) -> PlatformImage? {
        guard let url = url else {
            return nil
        }
        if screenshots[url] == nil {
            screenshots[url] = PlatformImage(contentsOfURL: url)
        }
        return screenshots[url]
    }

    func rename(_ snapshot: VMSnapshot, to title: String) async throws {
        try UTMSnapshotService.renameSnapshot(snapshot.id, to: title, on: try wrapped)
        try await refresh()
    }

    /// Saves the current state as a new snapshot based on the one the current state was based on.
    /// - Returns: Identifier of the new snapshot
    @discardableResult
    func createSnapshot() async throws -> UUID {
        let snapshot = try await UTMSnapshotService.createSnapshot(on: try wrapped)
        try await refresh()
        return snapshot.id
    }

    /// Replaces what the snapshot the current state is based on holds with the current state.
    func overwriteBase() async throws {
        guard let currentParentID = currentParentID else {
            return
        }
        try await UTMSnapshotService.overwriteSnapshot(currentParentID, on: try wrapped)
        try await refresh()
    }

    func delete(_ snapshot: VMSnapshot) async throws {
        try await UTMSnapshotService.deleteSnapshot(snapshot.id, on: try wrapped)
        try await refresh()
    }

    /// Replaces the current state with `snapshot`. If the VM is not running, it resumes from it when started.
    func restore(_ snapshot: VMSnapshot) async throws {
        do {
            try await UTMSnapshotService.restoreSnapshot(snapshot.id, on: try wrapped)
        } catch {
            // show snapshots found to be orphaned
            try? await refresh()
            throw error
        }
        try await refresh()
    }

    /// Discards the state the VM is suspended to so that it starts up normally.
    func deleteSuspendState() async throws {
        try await wrapped.deleteSnapshot(name: nil)
        try await refresh()
    }
}
