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
import Logging

private let snapshotLogger = Logger(label: "com.utmapp.UTM.snapshot") { label in
    UTMLoggingSwift(label: label)
}

/// Coordinates named full-VM snapshots for the QEMU backend.
///
/// This is distinct from the internal suspend/resume feature which uses the reserved name
/// `"suspend"` and `registryEntry.isSuspended`; named snapshots never mark a VM as suspended.
@MainActor
enum UTMSnapshotService {
    /// Snapshot name reserved for the internal suspend/resume feature.
    private static let reservedSuspendName = "suspend"

    /// Create a named snapshot capturing the full VM state (RAM + devices + disk).
    ///
    /// QEMU replaces an existing snapshot with the same name.
    static func createSnapshot(name: String, on vm: any UTMVirtualMachine) async throws {
        _ = try requireQemuBackend(vm)
        try validate(name: name)
        if let error = vm.snapshotUnsupportedError {
            throw error
        }
        // capturing RAM through the QEMU monitor requires the VM to be running or paused
        guard vm.state == .started || vm.state == .paused else {
            throw UTMSnapshotError.invalidVmState
        }
        snapshotLogger.debug("Creating snapshot '\(name)' on QEMU VM")
        try await vm.saveSnapshot(name: name)
    }

    /// List full-VM snapshots stored in the VM's bundled writable disk images, newest first.
    static func listSnapshots(on vm: any UTMVirtualMachine) async throws -> [UTMQemuImage.QemuSnapshotInfo] {
        let qemu = try requireQemuBackend(vm)
        guard vm.state == .stopped else {
            throw UTMSnapshotError.listRequiresStoppedVm
        }
        var snapshotsByName = [String: UTMQemuImage.QemuSnapshotInfo]()
        var imageURLs = qemu.config.drives.compactMap { drive -> URL? in
            guard drive.imageType == .disk && !drive.isExternal && !drive.isReadOnly else {
                return nil
            }
            return drive.imageURL
        }
        if qemu.config.qemu.hasUefiBoot,
           let efiVarsURL = qemu.config.qemu.efiVarsURL,
           FileManager.default.fileExists(atPath: efiVarsURL.path) {
            imageURLs.insert(efiVarsURL, at: 0)
        }
        for imageURL in imageURLs {
            let imageInfo = try await UTMQemuImage.info(image: imageURL)
            for snapshot in imageInfo.snapshots ?? [] where snapshot.vmStateSize > 0 && snapshot.name != reservedSuspendName {
                snapshotsByName[snapshot.name] = snapshot
            }
        }
        return snapshotsByName.values.sorted { $0.date > $1.date }
    }

    /// Restore the VM to a previously captured named snapshot.
    static func restoreSnapshot(name: String, on vm: any UTMVirtualMachine) async throws {
        _ = try requireQemuBackend(vm)
        try validate(name: name)
        guard vm.state == .stopped else {
            throw UTMSnapshotError.restoreRequiresStoppedVm
        }
        guard try await listSnapshots(on: vm).contains(where: { $0.name == name }) else {
            throw UTMSnapshotError.notFound(name)
        }
        snapshotLogger.debug("Restoring snapshot '\(name)' on QEMU VM")
        try await vm.restoreSnapshot(name: name)
    }

    /// Delete a named snapshot and its backend state.
    static func deleteSnapshot(name: String, on vm: any UTMVirtualMachine) async throws {
        _ = try requireQemuBackend(vm)
        try validate(name: name)
        // QEMU deletes the tag from the running qcow2 via the monitor, so it must be running.
        if vm.state != .started && vm.state != .paused {
            throw UTMSnapshotError.invalidVmState
        }
        snapshotLogger.debug("Deleting snapshot '\(name)' on QEMU VM")
        try await vm.deleteSnapshot(name: name)
    }

    // MARK: - Helpers

    private static func requireQemuBackend(_ vm: any UTMVirtualMachine) throws -> UTMQemuVirtualMachine {
        guard let qemu = vm as? UTMQemuVirtualMachine else {
            throw UTMSnapshotError.notSupported
        }
        return qemu
    }

    private static func validate(name: String) throws {
        if name.caseInsensitiveCompare(reservedSuspendName) == .orderedSame {
            throw UTMSnapshotError.reservedName(name)
        }
        let pattern = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$"
        guard name.range(of: pattern, options: .regularExpression) != nil else {
            throw UTMSnapshotError.invalidName(name)
        }
    }
}

enum UTMSnapshotError: Error {
    case reservedName(String)
    case invalidName(String)
    case notFound(String)
    case notSupported
    case invalidVmState
    case listRequiresStoppedVm
    case restoreRequiresStoppedVm
}

extension UTMSnapshotError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .reservedName(let name):
            return String.localizedStringWithFormat(NSLocalizedString("The name '%@' is reserved and cannot be used for a snapshot.", comment: "UTMSnapshotService"), name)
        case .invalidName(let name):
            return String.localizedStringWithFormat(NSLocalizedString("The name '%@' is not a valid snapshot name. Use letters, numbers, and the characters _.- (up to 64 characters).", comment: "UTMSnapshotService"), name)
        case .notFound(let name):
            return String.localizedStringWithFormat(NSLocalizedString("The snapshot '%@' does not exist.", comment: "UTMSnapshotService"), name)
        case .notSupported:
            return NSLocalizedString("Snapshots are not supported for this virtual machine.", comment: "UTMSnapshotService")
        case .invalidVmState:
            return NSLocalizedString("The virtual machine is in an invalid state for this snapshot operation.", comment: "UTMSnapshotService")
        case .listRequiresStoppedVm:
            return NSLocalizedString("The virtual machine must be stopped before listing snapshots.", comment: "UTMSnapshotService")
        case .restoreRequiresStoppedVm:
            return NSLocalizedString("The virtual machine must be stopped before restoring a snapshot.", comment: "UTMSnapshotService")
        }
    }
}
