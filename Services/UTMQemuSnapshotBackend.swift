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
import QEMUKitInternal

/// Snapshot tag that a VM was always suspended to before suspend states could be kept as snapshots
let kUTMQemuDefaultSuspendSnapshotName = "suspend"

extension UTMQemuVirtualMachine {
    /// Images that take part in a snapshot
    @MainActor var snapshotImageURLs: [URL] {
        var imageURLs = config.drives.compactMap { drive -> URL? in
            guard drive.imageType == .disk && !drive.isExternal && !drive.isReadOnly else {
                return nil
            }
            return drive.imageURL
        }
        // the same condition under which QEMU is given the variable store
        if config.qemu.hasUefiBoot, !config.hasCustomBios, let efiVarsURL = config.qemu.efiVarsURL, FileManager.default.fileExists(atPath: efiVarsURL.path) {
            imageURLs.insert(efiVarsURL, at: 0)
        }
        return imageURLs
    }
}

// MARK: - Live

/// Internal snapshots of a running QEMU, managed through the monitor.
///
/// QEMU has the images open so nothing else may touch them, least of all qemu-img. It saves and
/// loads the running state along with the disks. A snapshot of just the disks cannot be loaded
/// into a running guest and is left alone until the VM is off.
struct UTMQemuLiveSnapshotBackend: UTMSnapshotBackend {
    let vm: UTMQemuVirtualMachine

    let imageURLs: [URL]

    /// QEMU lists the snapshots of every drive together, removable ones included
    let isInventoryExact = false

    let defaultSuspendIdentifier = kUTMQemuDefaultSuspendSnapshotName

    func supports(_ operation: UTMSnapshotOperation, hasState: Bool) -> Bool {
        operation == .create || hasState
    }

    func entries() async throws -> [UTMSnapshotBackendEntry] {
        guard let monitor = await vm.monitor else {
            throw UTMSnapshotError.invalidVmState
        }
        return try monitor.snapshots().map { snapshot in
            UTMSnapshotBackendEntry(identifier: snapshot.name,
                                    date: snapshot.date,
                                    size: snapshot.vmStateSize,
                                    hasState: snapshot.vmStateSize > 0)
        }
    }

    func create(suspendIdentifier: String?) async throws -> UTMSnapshotBackendEntry {
        // the state is saved anew because a VM can keep running after it was suspended
        let identifier = UUID().uuidString
        try await vm.saveSnapshot(name: identifier)
        guard let entry = try await entries().first(where: { $0.identifier == identifier }) else {
            throw UTMSnapshotError.notFound(identifier)
        }
        return entry
    }

    func restore(_ entry: UTMSnapshotBackendEntry) async throws -> Bool {
        try await vm.restoreSnapshot(name: entry.identifier)
        return false
    }

    func delete(identifier: String) async throws {
        try await vm.deleteSnapshot(name: identifier)
    }
}

// MARK: - Frozen

/// Internal snapshots in the images of a QEMU that is not running, managed through qemu-img.
///
/// A snapshot spans every image, including the one for the UEFI variables. QEMU saves and loads
/// all of them together and refuses to load a snapshot that any of them is missing.
struct UTMQemuFrozenSnapshotBackend: UTMSnapshotBackend {
    let imageURLs: [URL]

    /// Kept from starting while the images change, unless the caller already sees to that
    var vm: UTMQemuVirtualMachine? = nil

    let isInventoryExact = true

    let defaultSuspendIdentifier = kUTMQemuDefaultSuspendSnapshotName

    func supports(_ operation: UTMSnapshotOperation, hasState: Bool) -> Bool {
        true
    }

    func entries() async throws -> [UTMSnapshotBackendEntry] {
        var entries = [String: UTMSnapshotBackendEntry]()
        var imageCounts = [String: Int]()
        for imageURL in imageURLs {
            for snapshot in try await UTMQemuImage.snapshots(image: imageURL) {
                // the VM state is only in one of the images
                let previous = entries[snapshot.name]
                entries[snapshot.name] = UTMSnapshotBackendEntry(identifier: snapshot.name,
                                                                 date: max(snapshot.date, previous?.date ?? .distantPast),
                                                                 size: snapshot.vmStateSize + (previous?.size ?? 0),
                                                                 hasState: snapshot.vmStateSize > 0 || previous?.hasState == true)
                imageCounts[snapshot.name, default: 0] += 1
            }
        }
        return entries.values.map { entry in
            var entry = entry
            entry.isComplete = imageCounts[entry.identifier] == imageURLs.count
            return entry
        }
    }

    func create(suspendIdentifier: String?) async throws -> UTMSnapshotBackendEntry {
        if let suspendIdentifier = suspendIdentifier {
            // nothing changed since the VM was suspended
            guard let entry = try await entries().first(where: { $0.identifier == suspendIdentifier }), entry.isComplete else {
                throw UTMSnapshotError.notFound(suspendIdentifier)
            }
            return entry
        }
        for imageURL in imageURLs {
            guard try await UTMQemuImage.info(image: imageURL).format == "qcow2" else {
                throw UTMSnapshotError.notSupported
            }
        }
        let identifier = UUID().uuidString
        try await changingImages(as: .saving) {
            do {
                for imageURL in imageURLs {
                    try await UTMQemuImage.createSnapshot(image: imageURL, name: identifier)
                }
            } catch {
                try? await deleteFromImages(identifier: identifier)
                throw error
            }
        }
        guard let entry = try await entries().first(where: { $0.identifier == identifier }) else {
            throw UTMSnapshotError.notFound(identifier)
        }
        return entry
    }

    func restore(_ entry: UTMSnapshotBackendEntry) async throws -> Bool {
        guard entry.isComplete else {
            throw UTMSnapshotError.incomplete(entry.identifier)
        }
        // the disks are reverted now even when QEMU loads the running state on the next start,
        // so they hold the snapshot should that state be discarded instead
        try await changingImages(as: .restoring) {
            for imageURL in imageURLs {
                try await UTMQemuImage.applySnapshot(image: imageURL, name: entry.identifier)
            }
        }
        return entry.hasState
    }

    func delete(identifier: String) async throws {
        try await changingImages(as: .saving) {
            try await deleteFromImages(identifier: identifier)
        }
    }

    private func deleteFromImages(identifier: String) async throws {
        for imageURL in try await imageURLs(containing: identifier) {
            try await UTMQemuImage.deleteSnapshot(image: imageURL, name: identifier)
        }
    }

    private func changingImages(as state: UTMVirtualMachineState, _ body: () async throws -> Void) async throws {
        if let vm = vm {
            try await vm.changingImages(as: state, body)
        } else {
            try await body()
        }
    }

    private func imageURLs(containing identifier: String) async throws -> [URL] {
        var found = [URL]()
        for imageURL in imageURLs {
            if try await UTMQemuImage.snapshots(image: imageURL).contains(where: { $0.name == identifier }) {
                found.append(imageURL)
            }
        }
        guard !found.isEmpty else {
            throw UTMSnapshotError.notFound(identifier)
        }
        return found
    }
}
