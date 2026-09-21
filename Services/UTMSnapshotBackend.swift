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

/// State of a snapshot as it is stored by a backend
struct UTMSnapshotBackendEntry: Equatable {
    /// Unique in the backend, what `UTMSnapshotManifest.Snapshot.backendIdentifier` links to
    let identifier: String

    let date: Date

    /// Bytes occupied by the snapshot
    let size: Int64

    /// Includes the running state of the VM and not just the disks
    let hasState: Bool

    /// Covers every image that takes part in a snapshot.
    ///
    /// One that does not, such as a snapshot taken before a drive was added, cannot be restored
    /// without leaving the drives holding contents from different points in time.
    var isComplete: Bool = true

    /// Snapshot this one was taken from, for backends that keep track of it
    var parentIdentifier: String? = nil
}

/// What can be done with the state of a snapshot
enum UTMSnapshotOperation {
    /// Save the current state of the VM
    case create
    /// Replace the current state of the VM
    case restore
    case delete
}

/// Where the state of snapshots is kept. There is an implementation for each kind of VM and,
/// where they differ, for a VM that is running (live) and one that is not (frozen).
///
/// A backend knows nothing about `UTMSnapshotManifest`, use `UTMSnapshotService` instead.
protocol UTMSnapshotBackend {
    /// Identifier of the state a suspended VM resumes from when the manifest does not name one
    var defaultSuspendIdentifier: String { get }

    /// Where a snapshot is saved, so without any there is nothing to save
    var imageURLs: [URL] { get }

    /// `entries()` lists the snapshots of exactly `imageURLs` and knows which are complete, which
    /// is needed to add snapshots from the backend or to find those whose state is gone
    var isInventoryExact: Bool { get }

    /// An operation is possible while the VM is in the state the backend was picked for.
    /// - Parameters:
    ///   - operation: Operation to perform
    ///   - hasState: The snapshot includes the running state of the VM, ignored for `.create`
    func supports(_ operation: UTMSnapshotOperation, hasState: Bool) -> Bool

    /// Every snapshot found in the backend, including those UTM did not create
    func entries() async throws -> [UTMSnapshotBackendEntry]

    /// Save the current state of the VM.
    /// - Parameter suspendIdentifier: State the VM is suspended to, if it is. It already holds the
    ///                                current state so a backend may return it as the snapshot.
    func create(suspendIdentifier: String?) async throws -> UTMSnapshotBackendEntry

    /// Replace the current state of the VM with a snapshot.
    /// - Returns: True if this only takes effect once the VM resumes from the snapshot when it is started
    func restore(_ entry: UTMSnapshotBackendEntry) async throws -> Bool

    func delete(identifier: String) async throws
}
