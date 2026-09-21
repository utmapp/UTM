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
///
/// FIXME: all operations are placeholders that only modify the in-memory list.
@MainActor
final class VMSnapshotList: ObservableObject {
    /// Saved snapshots, newest first
    @Published private(set) var snapshots: [VMSnapshot] = []

    /// Snapshot the current state is based on, `nil` if there is none
    @Published private(set) var currentParentID: UUID?

    /// Nothing changed since the snapshot the current state is based on
    @Published private(set) var isCurrentStateSaved: Bool = false

    /// The current state can be saved while the VM is in its current state
    @Published private(set) var canCreate: Bool = true

    /// The snapshot the current state is based on can be replaced while the VM is in its current state
    var canOverwriteBase: Bool {
        canCreate && snapshot(for: currentParentID)?.canDelete == true
    }

    private let vm: VMData

    private static var cache: [UUID: VMSnapshotList] = [:]

    /// Returns the list for a VM, keeping it alive so placeholder edits survive navigation.
    static func list(for vm: VMData) -> VMSnapshotList {
        if let list = cache[vm.id] {
            return list
        }
        let list = VMSnapshotList(vm: vm)
        cache[vm.id] = list
        return list
    }

    private init(vm: VMData) {
        self.vm = vm
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

    /// FIXME: read the snapshots from the VM
    func refresh() async throws {
    }

    func rename(_ snapshot: VMSnapshot, to title: String) async throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) else {
            return
        }
        snapshots[index].title = title
        snapshots[index].dateModified = Date()
    }

    /// Saves the current state as a new snapshot based on the one the current state was based on.
    /// - Returns: Identifier of the new snapshot
    @discardableResult
    func createSnapshot() async throws -> UUID {
        logger.debug("FIXME: saving the current state as a snapshot is not implemented")
        let now = Date()
        let snapshot = VMSnapshot(id: UUID(),
                                  title: defaultTitle,
                                  parentID: currentParentID,
                                  dateCreated: now,
                                  dateModified: now,
                                  size: 0,
                                  screenshot: vm.screenshotImage,
                                  hasState: vm.hasSuspendState,
                                  isOrphaned: false)
        snapshots.insert(snapshot, at: 0)
        currentParentID = snapshot.id
        return snapshot.id
    }

    /// Replaces what the snapshot the current state is based on holds with the current state.
    func overwriteBase() async throws {
        logger.debug("FIXME: overwriting a snapshot is not implemented")
        guard let index = snapshots.firstIndex(where: { $0.id == currentParentID }) else {
            return
        }
        snapshots[index].dateModified = Date()
        snapshots[index].screenshot = vm.screenshotImage
        snapshots[index].hasState = vm.hasSuspendState
    }

    /// Snapshots based on a deleted snapshot are handed to what it was based on so the remaining lineage stays linked.
    func delete(_ snapshot: VMSnapshot) async throws {
        logger.debug("FIXME: deleting a snapshot is not implemented")
        for index in snapshots.indices where snapshots[index].parentID == snapshot.id {
            snapshots[index].parentID = snapshot.parentID
        }
        if currentParentID == snapshot.id {
            currentParentID = snapshot.parentID
        }
        snapshots.removeAll { $0.id == snapshot.id }
    }

    /// Replaces the current state with `snapshot`. If the VM is not running, it resumes from it when started.
    func restore(_ snapshot: VMSnapshot) async throws {
        logger.debug("FIXME: restoring a snapshot is not implemented")
        currentParentID = snapshot.id
    }

    /// Discards the state the VM is suspended to so that it starts up normally.
    func deleteSuspendState() async throws {
        logger.debug("FIXME: deleting the suspended state is not implemented")
    }

    private var defaultTitle: String {
        var number = snapshots.count + 1
        var title: String
        repeat {
            title = String.localizedStringWithFormat(NSLocalizedString("Snapshot %lld", comment: "VMSnapshotData"), number)
            number += 1
        } while snapshots.contains { $0.title == title }
        return title
    }
}
