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

extension UTMAppleVirtualMachine {
    /// Images that take part in a snapshot
    @MainActor var snapshotImageURLs: [URL] {
        config.drives.compactMap { drive in
            drive.isReadOnly || drive.isExternal ? nil : drive.imageURL
        }
    }

    /// Small files the guest writes to that are not disks, such as the variables of the firmware
    @MainActor var snapshotAuxiliaryURLs: [URL] {
        [config.system.boot.efiVariableStorageURL, config.system.macPlatform?.auxiliaryStorageURL].compactMap { url in
            url.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        }
    }
}

/// Which files a bundle has to keep for the snapshots of an Apple VM.
///
/// A bundle only keeps the files its configuration names, and what a snapshot holds is named
/// after the file it belongs to rather than being named by the configuration.
enum UTMAppleSnapshotFiles {
    /// Files beside `baseURLs` that the snapshots recorded in the bundle still need.
    ///
    /// Everything else beside them is left over — from a snapshot that was deleted, or from a
    /// tool that is no longer around — and is left out so that it is cleaned up with the rest.
    /// - Parameters:
    ///   - baseURLs: Files the configuration keeps
    ///   - bundleURL: Bundle of the VM
    static func preservedDataURLs(for baseURLs: [URL], in bundleURL: URL) -> [URL] {
        // without the manifest nothing can be ruled out, and snapshots it does not list yet are
        // adopted from these files the next time the snapshots are read
        guard let manifest = (try? UTMSnapshotManifest.load(from: bundleURL)) ?? nil else {
            return baseURLs.flatMap { namedAfter($0) }
        }
        var identifiers = Set(manifest.snapshots.map { $0.backendIdentifier })
        if let suspendIdentifier = manifest.suspendIdentifier {
            identifiers.insert(suspendIdentifier)
        }
        let fileManager = FileManager.default
        var preserved = [URL]()
        for baseURL in baseURLs {
            // the saved state and the firmware of a snapshot are copies named after the original
            for identifier in identifiers {
                let url = baseURL.appendingPathExtension(identifier)
                if fileManager.fileExists(atPath: url.path) {
                    preserved.append(url)
                }
            }
            if #available(macOS 27, *), let layerURLs = try? UTMAppleDiskImage.preservedLayerURLs(of: baseURL, for: identifiers) {
                preserved += layerURLs
            } else {
                // the layers cannot be read, so keep all of them rather than lose one
                preserved += namedAfter(baseURL).filter { $0.pathExtension == "asif" }
            }
        }
        return preserved
    }

    /// Files beside `baseURL` whose names start with its own, which is how snapshots name theirs
    private static func namedAfter(_ baseURL: URL) -> [URL] {
        let prefix = baseURL.lastPathComponent + "."
        let siblings = (try? FileManager.default.contentsOfDirectory(at: baseURL.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
        return siblings.filter { $0.lastPathComponent.hasPrefix(prefix) }
    }
}

/// Snapshots of a VM using Apple Virtualization.
///
/// A snapshot spans every drive. The disks are kept as a layer of each image (see
/// `UTMAppleDiskImage`), while the running state and the files in `auxiliaryURLs` are small
/// enough to be kept as copies named after the snapshot. Virtualization cannot change the layers of a
/// disk that is attached, so the current state can only be saved or replaced while the VM is
/// not running. Everything else works either way.
@available(macOS 27, *)
struct UTMAppleSnapshotBackend: UTMSnapshotBackend {
    let imageURLs: [URL]

    let isInventoryExact = true

    /// Files that are not disks but still part of the state of the guest
    let auxiliaryURLs: [URL]

    /// File the VM is suspended to
    let savedStateURL: URL?

    let isRunning: Bool

    /// Kept from starting while its files change
    var vm: UTMAppleVirtualMachine? = nil

    /// There is only one file to suspend to which is never a snapshot by itself
    let defaultSuspendIdentifier = "suspend"

    func supports(_ operation: UTMSnapshotOperation, hasState: Bool) -> Bool {
        // the layers below a disk that is attached have to stay the same
        !isRunning || operation == .delete
    }

    private var fileManager: FileManager {
        FileManager.default
    }

    private func snapshotStateURL(for identifier: String) -> URL? {
        savedStateURL?.appendingPathExtension(identifier)
    }

    /// Copy beside `url` for `replaceItemAt`, which consumes what it puts in place
    private func copyToTemporary(_ url: URL) throws -> URL {
        let temporaryURL = url.appendingPathExtension(UUID().uuidString)
        try fileManager.copyItem(at: url, to: temporaryURL)
        return temporaryURL
    }

    private func size(of url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
        return Int64(values?.totalFileAllocatedSize ?? 0)
    }

    func entries() async throws -> [UTMSnapshotBackendEntry] {
        var entries = [String: UTMSnapshotBackendEntry]()
        var imageCounts = [String: Int]()
        for imageURL in imageURLs {
            let layers = try UTMAppleDiskImage.layers(of: imageURL)
            for layer in layers where !layer.isCurrent && !layer.isUnlinked {
                // skip the layers of deleted snapshots to find the one this was taken from
                var parent = layers.first { $0.uuid == layer.parentUUID }
                while let unlinked = parent, unlinked.isUnlinked {
                    parent = layers.first { $0.uuid == unlinked.parentUUID }
                }
                let date = (try? layer.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                let previous = entries[layer.name]
                entries[layer.name] = UTMSnapshotBackendEntry(identifier: layer.name,
                                                              date: max(date, previous?.date ?? .distantPast),
                                                              size: size(of: layer.url) + (previous?.size ?? 0),
                                                              hasState: false,
                                                              parentIdentifier: previous?.parentIdentifier ?? parent?.name)
                imageCounts[layer.name, default: 0] += 1
            }
        }
        return entries.values.map { entry in
            var entry = entry
            entry.isComplete = imageCounts[entry.identifier] == imageURLs.count
            guard let stateURL = snapshotStateURL(for: entry.identifier), fileManager.fileExists(atPath: stateURL.path) else {
                return entry
            }
            return UTMSnapshotBackendEntry(identifier: entry.identifier,
                                           date: entry.date,
                                           size: entry.size + size(of: stateURL),
                                           hasState: true,
                                           isComplete: entry.isComplete,
                                           parentIdentifier: entry.parentIdentifier)
        }
    }

    func create(suspendIdentifier: String?) async throws -> UTMSnapshotBackendEntry {
        let identifier = UUID().uuidString
        try await changingFiles(as: .saving) {
            do {
                for imageURL in imageURLs {
                    try UTMAppleDiskImage.createSnapshot(of: imageURL, name: identifier)
                }
                for auxiliaryURL in auxiliaryURLs {
                    try fileManager.copyItem(at: auxiliaryURL, to: auxiliaryURL.appendingPathExtension(identifier))
                }
                if suspendIdentifier != nil, let savedStateURL = savedStateURL, let stateURL = snapshotStateURL(for: identifier) {
                    // the VM still resumes from its own copy
                    try fileManager.copyItem(at: savedStateURL, to: stateURL)
                }
            } catch {
                try? await delete(identifier: identifier)
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
        try await changingFiles(as: .restoring) {
            // every drive is restored or none is
            for imageURL in imageURLs {
                try UTMAppleDiskImage.validateSnapshot(of: imageURL, name: entry.identifier)
            }
            for imageURL in imageURLs {
                try UTMAppleDiskImage.restoreSnapshot(of: imageURL, name: entry.identifier)
                // what the VM was suspended to stops matching the drives once one is restored
                if let savedStateURL = savedStateURL, fileManager.fileExists(atPath: savedStateURL.path) {
                    try? fileManager.removeItem(at: savedStateURL)
                }
            }
            for auxiliaryURL in auxiliaryURLs {
                let snapshotURL = auxiliaryURL.appendingPathExtension(entry.identifier)
                if fileManager.fileExists(atPath: snapshotURL.path) {
                    // the original stays until the copy is in place so a failure cannot lose it
                    _ = try fileManager.replaceItemAt(auxiliaryURL, withItemAt: try copyToTemporary(snapshotURL))
                }
            }
            if let savedStateURL = savedStateURL, entry.hasState, let stateURL = snapshotStateURL(for: entry.identifier) {
                try fileManager.copyItem(at: stateURL, to: savedStateURL)
            }
        }
        return savedStateURL != nil && entry.hasState
    }

    private func changingFiles(as state: UTMVirtualMachineState, _ body: () async throws -> Void) async throws {
        if let vm = vm {
            try await vm.changingFiles(as: state, body)
        } else {
            try await body()
        }
    }

    func delete(identifier: String) async throws {
        var isFound = false
        for imageURL in imageURLs {
            do {
                try UTMAppleDiskImage.deleteSnapshot(of: imageURL, name: identifier)
                isFound = true
            } catch UTMAppleDiskImageError.snapshotNotFound(_) {
                // a drive added after the snapshot was created
            }
        }
        for auxiliaryURL in auxiliaryURLs {
            try? fileManager.removeItem(at: auxiliaryURL.appendingPathExtension(identifier))
        }
        if let stateURL = snapshotStateURL(for: identifier) {
            try? fileManager.removeItem(at: stateURL)
        }
        guard isFound else {
            throw UTMSnapshotError.notFound(identifier)
        }
    }
}
