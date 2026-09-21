//
// Copyright © 2026 osy. All rights reserved.
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

/// Manages the snapshots of a VM regardless of its backend and of whether it is running.
///
/// The state of a snapshot is kept by a `UTMSnapshotBackend`. Everything else is kept in the
/// `UTMSnapshotManifest` of the bundle which links to that state. Only this service changes the
/// snapshots in a manifest so that the two stay consistent.
///
/// A snapshot never changes unless it is overwritten. Restoring one replaces the current state of
/// the VM with a copy and the snapshot it was restored from is remembered as what the current
/// state is based on, which is how snapshots get their lineage.
///
/// Suspending is closely related: the state a VM is suspended to can be kept as a snapshot and
/// restoring a snapshot makes a stopped VM resume from it. The VM itself keeps track of what it
/// resumes from through the suspend state operations of `UTMSnapshotManifest`.
@MainActor
enum UTMSnapshotService {
    fileprivate typealias Entry = UTMSnapshotManifest.Snapshot

    /// Posted with the bundle of the VM as its object whenever its snapshots change
    static let didChangeNotification = UTMSnapshotManifest.didChangeNotification

    // MARK: - Reading

    /// Snapshots can be managed for this VM, whether it is running or not
    static func isSupported(for vm: any UTMVirtualMachine) -> Bool {
        #if os(macOS)
        if vm is UTMQemuVirtualMachine {
            return true
        }
        #endif
        // qemu-img is needed for a VM that is not running and is only part of the macOS app
        return false
    }

    /// Snapshots of a VM and how the current state relates to them. The first time, those that
    /// are already in the backend are added.
    static func timeline(for vm: any UTMVirtualMachine) async throws -> UTMSnapshotTimeline {
        var manifest = try UTMSnapshotManifest.load(from: vm.pathUrl) ?? UTMSnapshotManifest()
        if !manifest.isBackendImported, let backend = try? backend(for: vm), backend.isInventoryExact {
            manifest = try await importUnlinkedSnapshots(from: backend, on: vm)
        }
        return UTMSnapshotTimeline(snapshots: manifest.snapshots.map { UTMSnapshot($0, on: vm) },
                                   currentParentID: manifest.currentParentID,
                                   isCurrentStateSaved: isCurrentStateSaved(in: manifest, on: vm))
    }

    /// An operation is possible while the VM is in its current state.
    ///
    /// Snapshots can be managed whether the VM is running or not, but not everything can be done
    /// either way. A running QEMU can only deal with snapshots that include the running state and
    /// the disks of a running Apple VM cannot be replaced.
    /// - Parameters:
    ///   - operation: Operation to perform
    ///   - snapshot: Snapshot to restore or delete
    ///   - vm: VM the snapshot belongs to
    static func isSupported(_ operation: UTMSnapshotOperation, for snapshot: UTMSnapshot? = nil, on vm: any UTMVirtualMachine) -> Bool {
        guard let backend = try? backend(for: vm) else {
            return false
        }
        if operation == .create && backend.imageURLs.isEmpty {
            return false
        }
        return backend.supports(operation, hasState: snapshot?.hasState ?? true)
    }

    /// Nothing changed since the snapshot the current state is based on, which is known when the
    /// VM is suspended to the state of that very snapshot.
    ///
    /// Saving the current state again would only duplicate that snapshot.
    private static func isCurrentStateSaved(in manifest: UTMSnapshotManifest, on vm: any UTMVirtualMachine) -> Bool {
        // a VM that is not stopped may have run since it was suspended
        guard vm.state == .stopped, let backend = try? backend(for: vm), let parentID = manifest.currentParentID else {
            return false
        }
        let suspendIdentifier = vm.registryEntry.isSuspended ? manifest.suspendIdentifier ?? backend.defaultSuspendIdentifier : nil
        return manifest[parentID]?.backendIdentifier == suspendIdentifier
    }

    fileprivate static func screenshotURL(for snapshot: Entry, on vm: any UTMVirtualMachine) -> URL? {
        snapshot.screenshotName.map { UTMSnapshotManifest.screenshotsURL(in: vm.pathUrl).appendingPathComponent($0) }
    }

    // MARK: - Operations

    /// Save the current state of a VM as a new snapshot.
    /// - Parameters:
    ///   - title: Display name, a default is used if nil
    ///   - vm: VM that is either running or not
    @discardableResult
    static func createSnapshot(title: String? = nil, on vm: any UTMVirtualMachine) async throws -> UTMSnapshot {
        let backend = try backend(for: vm)
        guard !backend.imageURLs.isEmpty else {
            throw UTMSnapshotError.noDrives
        }
        guard backend.supports(.create, hasState: true) else {
            throw UTMSnapshotError.requiresStoppedVm
        }
        let suspendIdentifier = try suspendIdentifier(of: vm, in: backend)
        let entry = try await backend.create(suspendIdentifier: suspendIdentifier)
        logger.debug("Created snapshot '\(entry.identifier)'")
        let screenshotName = saveScreenshot(of: vm)
        let isSuspendStateKept = suspendIdentifier != nil && entry.hasState && vm.state != .started
        let title = title.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        let (snapshot, staleIdentifiers) = try UTMSnapshotManifest.update(in: vm.pathUrl) { manifest -> (Entry, [String]) in
            if isSuspendStateKept {
                // the VM still resumes from the state which is now the one of the snapshot
                manifest.replaceSuspendState(suspendIdentifier, with: entry.identifier)
            }
            let snapshot = Entry(title: title ?? manifest.defaultTitle,
                                    parentID: manifest.currentParentID,
                                    date: entry.date,
                                    size: entry.size,
                                    hasState: entry.hasState,
                                    backendIdentifier: entry.identifier,
                                    screenshotName: screenshotName)
            manifest.insert(snapshot)
            manifest.currentParentID = snapshot.id
            return (snapshot, manifest.staleIdentifiers)
        }
        await deleteStaleStates(staleIdentifiers, from: backend, on: vm)
        return UTMSnapshot(snapshot, on: vm)
    }

    /// Replace what a snapshot holds with the current state of a VM.
    ///
    /// Everything else about the snapshot stays, including the snapshots based on it.
    static func overwriteSnapshot(_ id: UUID, on vm: any UTMVirtualMachine) async throws {
        let backend = try backend(for: vm)
        guard let original = try UTMSnapshotManifest.load(from: vm.pathUrl)?[id] else {
            throw UTMSnapshotError.notFound(id.uuidString)
        }
        guard !backend.imageURLs.isEmpty else {
            throw UTMSnapshotError.noDrives
        }
        guard backend.supports(.create, hasState: true) && backend.supports(.delete, hasState: original.hasState) else {
            throw UTMSnapshotError.requiresStoppedVm
        }
        let suspendIdentifier = try suspendIdentifier(of: vm, in: backend)
        let entry = try await backend.create(suspendIdentifier: suspendIdentifier)
        logger.debug("Overwriting snapshot '\(original.backendIdentifier)' with '\(entry.identifier)'")
        let screenshotName = saveScreenshot(of: vm)
        let isSuspendStateKept = suspendIdentifier != nil && entry.hasState && vm.state != .started
        let staleIdentifiers = try UTMSnapshotManifest.update(in: vm.pathUrl) { manifest -> [String] in
            if isSuspendStateKept {
                manifest.replaceSuspendState(suspendIdentifier, with: entry.identifier)
            }
            if var snapshot = manifest[id] {
                snapshot.backendIdentifier = entry.identifier
                snapshot.size = entry.size
                snapshot.hasState = entry.hasState
                snapshot.screenshotName = screenshotName
                snapshot.dateModified = Date()
                snapshot.isOrphaned = false
                snapshot.isIncomplete = false
                manifest[id] = snapshot
            }
            manifest.currentParentID = id
            manifest.markStale(original.backendIdentifier)
            return manifest.staleIdentifiers
        }
        await deleteStaleStates(staleIdentifiers, from: backend, on: vm)
        if let screenshotName = original.screenshotName {
            try? FileManager.default.removeItem(at: UTMSnapshotManifest.screenshotsURL(in: vm.pathUrl).appendingPathComponent(screenshotName))
        }
    }

    /// - Returns: The snapshot with the title it ended up with
    @discardableResult
    static func renameSnapshot(_ id: UUID, to title: String, on vm: any UTMVirtualMachine) throws -> UTMSnapshot {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshot = try UTMSnapshotManifest.update(in: vm.pathUrl) { manifest -> Entry in
            guard var snapshot = manifest[id] else {
                throw UTMSnapshotError.notFound(id.uuidString)
            }
            guard !title.isEmpty && snapshot.title != title else {
                return snapshot
            }
            snapshot.title = title
            snapshot.dateModified = Date()
            manifest[id] = snapshot
            return snapshot
        }
        return UTMSnapshot(snapshot, on: vm)
    }

    /// Delete a snapshot, along with its state once nothing else links to it.
    static func deleteSnapshot(_ id: UUID, on vm: any UTMVirtualMachine) async throws {
        let backend = try backend(for: vm)
        guard let manifest = try UTMSnapshotManifest.load(from: vm.pathUrl), let snapshot = manifest[id] else {
            throw UTMSnapshotError.notFound(id.uuidString)
        }
        guard backend.supports(.delete, hasState: snapshot.hasState) else {
            throw UTMSnapshotError.requiresStoppedVm
        }
        var remaining = manifest
        remaining.remove(id)
        if !remaining.isReferenced(backendIdentifier: snapshot.backendIdentifier) {
            do {
                try await backend.delete(identifier: snapshot.backendIdentifier)
                logger.debug("Deleted snapshot '\(snapshot.backendIdentifier)'")
            } catch UTMSnapshotError.notFound(_) {
                // orphaned
            } catch {
                // some drives may have lost the state already, so it must not look restorable
                _ = try? await identifyOrphanedSnapshots(on: vm)
                throw error
            }
        }
        try UTMSnapshotManifest.update(in: vm.pathUrl) { manifest in
            manifest.remove(id)
        }
        if let screenshotName = snapshot.screenshotName {
            try? FileManager.default.removeItem(at: UTMSnapshotManifest.screenshotsURL(in: vm.pathUrl).appendingPathComponent(screenshotName))
        }
    }

    /// Replace the current state of a VM with a snapshot.
    ///
    /// A running VM continues from the snapshot right away. Otherwise it resumes from it, or boots
    /// from its disks if the snapshot has no running state, the next time it is started.
    static func restoreSnapshot(_ id: UUID, on vm: any UTMVirtualMachine) async throws {
        let backend = try backend(for: vm)
        guard let snapshot = try UTMSnapshotManifest.load(from: vm.pathUrl)?[id] else {
            throw UTMSnapshotError.notFound(id.uuidString)
        }
        guard backend.supports(.restore, hasState: snapshot.hasState) else {
            throw UTMSnapshotError.requiresStoppedVm
        }
        guard let entry = try await backend.entries().first(where: { $0.identifier == snapshot.backendIdentifier }) else {
            try? await identifyOrphanedSnapshots(on: vm)
            throw UTMSnapshotError.orphaned(snapshot.title)
        }
        guard entry.isComplete else {
            try? await identifyOrphanedSnapshots(on: vm)
            throw UTMSnapshotError.incomplete(snapshot.title)
        }
        // a state left named after a start that failed is replaced as well
        let previousSuspendIdentifier = try suspendIdentifier(of: vm, in: backend)
        let isResumedOnStart = try await backend.restore(entry)
        logger.debug("Restored snapshot '\(entry.identifier)'")
        let staleIdentifiers = try UTMSnapshotManifest.update(in: vm.pathUrl) { manifest -> [String] in
            manifest.replaceSuspendState(previousSuspendIdentifier, with: isResumedOnStart ? entry.identifier : nil)
            manifest.currentParentID = id
            return manifest.staleIdentifiers
        }
        vm.registryEntry.isSuspended = isResumedOnStart
        // the state that was suspended to is replaced
        await deleteStaleStates(staleIdentifiers, from: backend, on: vm)
        // the current state is a copy of the snapshot now, so show what the snapshot shows
        restoreScreenshot(of: snapshot, on: vm)
    }

    // MARK: - Consistency with the backend

    /// Find snapshots whose state is no longer in the backend, such as after another tool
    /// modified it, and mark them in the manifest.
    ///
    /// Call this when something that depends on the state of a snapshot fails.
    static func identifyOrphanedSnapshots(on vm: any UTMVirtualMachine) async throws {
        let backend = try backend(for: vm)
        guard backend.isInventoryExact else {
            return
        }
        let entries = try await backend.entries()
        try UTMSnapshotManifest.update(in: vm.pathUrl) { manifest in
            for index in manifest.snapshots.indices {
                let entry = entries.first { $0.identifier == manifest.snapshots[index].backendIdentifier }
                manifest.snapshots[index].isOrphaned = entry == nil
                // the state is there but does not cover every drive, which is not the same as gone
                manifest.snapshots[index].isIncomplete = entry.map { !$0.isComplete } ?? false
            }
            manifest.forgetStaleStates(notIn: entries)
        }
    }

    /// Add a snapshot for every state in the backend that none links to, such as those made by
    /// another tool, and refresh what the backend knows about the others.
    ///
    /// Anything the backend does not store is generated.
    @discardableResult
    private static func importUnlinkedSnapshots(from backend: any UTMSnapshotBackend, on vm: any UTMVirtualMachine) async throws -> UTMSnapshotManifest {
        let entries = try await backend.entries().sorted { $0.date < $1.date }
        return try UTMSnapshotManifest.update(in: vm.pathUrl) { manifest in
            for index in manifest.snapshots.indices {
                if let entry = entries.first(where: { $0.identifier == manifest.snapshots[index].backendIdentifier }) {
                    manifest.snapshots[index].size = entry.size
                    manifest.snapshots[index].hasState = entry.hasState
                    manifest.snapshots[index].isOrphaned = false
                    manifest.snapshots[index].isIncomplete = !entry.isComplete
                }
            }
            manifest.forgetStaleStates(notIn: entries)
            for entry in entries where !manifest.isReferenced(backendIdentifier: entry.identifier) {
                guard entry.identifier != backend.defaultSuspendIdentifier && !manifest.staleIdentifiers.contains(entry.identifier) else {
                    // only ever used for suspending, or waiting to be deleted
                    continue
                }
                logger.debug("Importing snapshot '\(entry.identifier)'")
                // an identifier that is not generated was chosen by someone
                let title = UUID(uuidString: entry.identifier) == nil ? manifest.uniqueTitle(entry.identifier) : manifest.defaultTitle
                let parent = manifest.snapshots.first { $0.backendIdentifier == entry.parentIdentifier }
                var snapshot = Entry(title: title,
                                        parentID: parent?.id,
                                        date: entry.date,
                                        size: entry.size,
                                        hasState: entry.hasState,
                                        backendIdentifier: entry.identifier)
                snapshot.isIncomplete = !entry.isComplete
                manifest.insert(snapshot)
            }
            manifest.isBackendImported = true
            return manifest
        }
    }

    // MARK: - Snapshots by name

    /// Create a snapshot or overwrite the one with the same title.
    static func createSnapshot(name: String, on vm: any UTMVirtualMachine) async throws {
        if let snapshot = try await timeline(for: vm).snapshots.first(where: { $0.title == name }) {
            try await overwriteSnapshot(snapshot.id, on: vm)
        } else {
            try await createSnapshot(title: name, on: vm)
        }
    }

    /// Titles of all snapshots, newest first
    static func listSnapshots(on vm: any UTMVirtualMachine) async throws -> [String] {
        _ = try backend(for: vm)
        return try await timeline(for: vm).snapshots.map { $0.title }
    }

    static func restoreSnapshot(name: String, on vm: any UTMVirtualMachine) async throws {
        try await restoreSnapshot(try await snapshot(named: name, on: vm).id, on: vm)
    }

    static func deleteSnapshot(name: String, on vm: any UTMVirtualMachine) async throws {
        try await deleteSnapshot(try await snapshot(named: name, on: vm).id, on: vm)
    }

    private static func snapshot(named name: String, on vm: any UTMVirtualMachine) async throws -> UTMSnapshot {
        guard let snapshot = try await timeline(for: vm).snapshots.first(where: { $0.title == name }) else {
            throw UTMSnapshotError.notFound(name)
        }
        return snapshot
    }

    // MARK: - Helpers

    /// Pick the backend for the kind of VM and for whether it is running
    private static func backend(for vm: any UTMVirtualMachine) throws -> any UTMSnapshotBackend {
        guard !vm.isRunningAsDisposible else {
            throw UTMSnapshotError.notSupported
        }
        guard isSupported(for: vm) else {
            throw UTMSnapshotError.notSupported
        }
        if let qemu = vm as? UTMQemuVirtualMachine {
            switch vm.state {
            case .started, .paused: return UTMQemuLiveSnapshotBackend(vm: qemu, imageURLs: qemu.snapshotImageURLs)
            case .stopped: return UTMQemuFrozenSnapshotBackend(imageURLs: qemu.snapshotImageURLs, vm: qemu)
            default: throw UTMSnapshotError.invalidVmState
            }
        }
        throw UTMSnapshotError.notSupported
    }

    /// State the VM is suspended to, if it is
    private static func suspendIdentifier(of vm: any UTMVirtualMachine, in backend: any UTMSnapshotBackend) throws -> String? {
        guard vm.registryEntry.isSuspended else {
            return nil
        }
        return try UTMSnapshotManifest.load(from: vm.pathUrl)?.suspendIdentifier ?? backend.defaultSuspendIdentifier
    }

    /// Delete states that nothing needs anymore. Each stays listed in the manifest until it is
    /// gone so that one that fails, such as one a running VM cannot delete, is tried again the
    /// next time instead of staying in the backend for good.
    private static func deleteStaleStates(_ identifiers: [String], from backend: any UTMSnapshotBackend, on vm: any UTMVirtualMachine) async {
        for identifier in identifiers {
            do {
                try await backend.delete(identifier: identifier)
                logger.debug("Deleted stale state '\(identifier)'")
            } catch UTMSnapshotError.notFound(_) {
                // already gone
            } catch {
                logger.debug("Keeping stale state '\(identifier)': \(error)")
                continue
            }
            try? UTMSnapshotManifest.forgetState(identifier, in: vm.pathUrl)
        }
    }

    /// Keep the most recent screenshot of the VM for a snapshot.
    /// - Returns: Name of the file in the screenshots directory
    private static func saveScreenshot(of vm: any UTMVirtualMachine) -> String? {
        let fileManager = FileManager.default
        let screenshotsURL = UTMSnapshotManifest.screenshotsURL(in: vm.pathUrl)
        let name = UUID().uuidString + ".png"
        if vm.state != .stopped {
            try? vm.saveScreenshot()
        }
        do {
            try fileManager.createDirectory(at: screenshotsURL, withIntermediateDirectories: true)
            try fileManager.copyItem(at: vm.pathUrl.appendingPathComponent(kUTMBundleScreenshotFilename), to: screenshotsURL.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    /// Show what a snapshot shows for the current state of a VM.
    ///
    /// A snapshot taken while the screen was not being kept has no picture of its own, and then
    /// the one on show belongs to a state the VM is no longer in, so it goes.
    private static func restoreScreenshot(of snapshot: Entry, on vm: any UTMVirtualMachine) {
        let fileManager = FileManager.default
        let currentURL = vm.pathUrl.appendingPathComponent(kUTMBundleScreenshotFilename)
        try? fileManager.removeItem(at: currentURL)
        if let screenshotURL = screenshotURL(for: snapshot, on: vm), fileManager.fileExists(atPath: screenshotURL.path) {
            try? fileManager.copyItem(at: screenshotURL, to: currentURL)
        }
        try? vm.reloadScreenshotFromFile()
    }
}

// MARK: - Read model

/// A snapshot of a VM as it is shown and scripted
struct UTMSnapshot: Identifiable, Equatable {
    let id: UUID

    /// User-editable display name
    var title: String

    /// Snapshot the current state was based on when this one was created, `nil` if there was none
    var parentID: UUID?

    var dateCreated: Date

    /// Last time the snapshot was renamed or overwritten
    var dateModified: Date

    /// Bytes occupied in the backend
    var size: Int64

    /// Includes the running state of the VM, otherwise it starts up from the saved disks
    var hasState: Bool

    /// The saved state is missing so the snapshot can only be deleted
    var isOrphaned: Bool

    /// The saved state does not cover every drive so the snapshot cannot be restored
    var isIncomplete: Bool

    /// Screen contents when the snapshot was taken, if one was captured
    var screenshotURL: URL?

    @MainActor
    fileprivate init(_ entry: UTMSnapshotManifest.Snapshot, on vm: any UTMVirtualMachine) {
        id = entry.id
        title = entry.title
        parentID = entry.parentID
        dateCreated = entry.dateCreated
        dateModified = entry.dateModified
        size = entry.size
        hasState = entry.hasState
        isOrphaned = entry.isOrphaned
        isIncomplete = entry.isIncomplete
        screenshotURL = UTMSnapshotService.screenshotURL(for: entry, on: vm)
    }
}

/// The snapshots of a VM along with the current state they are listed under
struct UTMSnapshotTimeline: Equatable {
    /// Newest first
    var snapshots: [UTMSnapshot]

    /// Snapshot the current state descends from, `nil` if there is none
    var currentParentID: UUID?

    /// Nothing changed since the snapshot the current state is based on
    var isCurrentStateSaved: Bool
}

private extension UTMSnapshotManifest {
    /// Stop resuming from `previous`, the state the VM was found suspended to, which the manifest
    /// may not name when it was suspended by an older version
    mutating func replaceSuspendState(_ previous: String?, with backendIdentifier: String?) {
        if suspendIdentifier == nil {
            suspendIdentifier = previous
        }
        setSuspendState(backendIdentifier)
    }

    /// States that were to be deleted and are gone from an exact inventory need no deleting
    mutating func forgetStaleStates(notIn entries: [UTMSnapshotBackendEntry]) {
        staleIdentifiers.removeAll { identifier in !entries.contains { $0.identifier == identifier } }
    }

    var defaultTitle: String {
        var number = snapshots.count + 1
        var title: String
        repeat {
            title = String.localizedStringWithFormat(NSLocalizedString("Snapshot %lld", comment: "UTMSnapshotService"), number)
            number += 1
        } while snapshots.contains { $0.title == title }
        return title
    }

    func uniqueTitle(_ base: String) -> String {
        var title = base
        var number = 2
        while snapshots.contains(where: { $0.title == title }) {
            title = "\(base) \(number)"
            number += 1
        }
        return title
    }
}

enum UTMSnapshotError: Error {
    case notFound(String)
    case orphaned(String)
    case incomplete(String)
    case noDrives
    case notSupported
    case invalidVmState
    case requiresStoppedVm
}

extension UTMSnapshotError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound(let name):
            return String.localizedStringWithFormat(NSLocalizedString("The snapshot '%@' does not exist.", comment: "UTMSnapshotService"), name)
        case .orphaned(let name):
            return String.localizedStringWithFormat(NSLocalizedString("The data of the snapshot '%@' is missing. It may have been removed by another application.", comment: "UTMSnapshotService"), name)
        case .incomplete(let name):
            return String.localizedStringWithFormat(NSLocalizedString("The snapshot '%@' cannot be restored because it does not cover every drive of the virtual machine, such as a drive added after it was taken.", comment: "UTMSnapshotService"), name)
        case .noDrives:
            return NSLocalizedString("A snapshot needs a drive that the virtual machine can write to.", comment: "UTMSnapshotService")
        case .notSupported:
            return NSLocalizedString("Snapshots are not supported for this virtual machine.", comment: "UTMSnapshotService")
        case .invalidVmState:
            return NSLocalizedString("The virtual machine is in an invalid state for this snapshot operation.", comment: "UTMSnapshotService")
        case .requiresStoppedVm:
            return NSLocalizedString("The virtual machine must be stopped for this snapshot operation.", comment: "UTMSnapshotService")
        }
    }
}
