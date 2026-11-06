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

import XCTest
@testable import UTM

/// The snapshot manifest kept in a VM bundle: ordering, re-parenting on delete,
/// stale backend identifiers, and its plist form.
final class UTMSnapshotManifestTests: XCTestCase {
    private func snapshot(_ title: String, parent: UUID? = nil, daysAgo: Double = 0, backend: String? = nil) -> UTMSnapshotManifest.Snapshot {
        UTMSnapshotManifest.Snapshot(title: title, parentID: parent, date: Date(timeIntervalSinceNow: -daysAgo * 86400), size: 1024, hasState: false, backendIdentifier: backend ?? title.lowercased())
    }

    func testInsertKeepsNewestFirst() {
        var manifest = UTMSnapshotManifest()
        manifest.insert(snapshot("Old", daysAgo: 2))
        manifest.insert(snapshot("New"))
        manifest.insert(snapshot("Middle", daysAgo: 1))
        XCTAssertEqual(manifest.snapshots.map(\.title), ["New", "Middle", "Old"])
    }

    func testRemoveReparentsChildrenAndCurrentParent() {
        var manifest = UTMSnapshotManifest()
        let root = snapshot("Root", daysAgo: 3)
        let middle = snapshot("Middle", parent: root.id, daysAgo: 2)
        let leaf = snapshot("Leaf", parent: middle.id, daysAgo: 1)
        manifest.insert(root)
        manifest.insert(middle)
        manifest.insert(leaf)
        manifest.currentParentID = middle.id

        manifest.remove(middle.id)

        XCTAssertNil(manifest[middle.id])
        XCTAssertEqual(manifest[leaf.id]?.parentID, root.id)
        XCTAssertEqual(manifest.currentParentID, root.id)
        XCTAssertEqual(manifest.snapshots.count, 2)
    }

    func testRemoveUnknownIdIsIgnored() {
        var manifest = UTMSnapshotManifest()
        manifest.insert(snapshot("Only"))
        manifest.remove(UUID())
        XCTAssertEqual(manifest.snapshots.count, 1)
    }

    func testSubscriptReplacesInsertsAndRemoves() {
        var manifest = UTMSnapshotManifest()
        var first = snapshot("First")
        manifest[first.id] = first
        XCTAssertEqual(manifest.snapshots.count, 1)
        first.title = "Renamed"
        manifest[first.id] = first
        XCTAssertEqual(manifest[first.id]?.title, "Renamed")
        manifest[first.id] = nil
        XCTAssertTrue(manifest.snapshots.isEmpty)
    }

    func testStaleIdentifiersTrackUnreferencedBackends() {
        var manifest = UTMSnapshotManifest()
        manifest.insert(snapshot("Kept", backend: "kept"))
        manifest.markStale("kept")
        XCTAssertTrue(manifest.staleIdentifiers.isEmpty, "a referenced backend is not stale")
        manifest.markStale("gone")
        manifest.markStale("gone")
        XCTAssertEqual(manifest.staleIdentifiers, ["gone"])
    }

    func testReplacingSuspendStateMarksPreviousOneStale() {
        var manifest = UTMSnapshotManifest()
        manifest.setSuspendState("suspend-1")
        XCTAssertTrue(manifest.staleIdentifiers.isEmpty)
        manifest.setSuspendState("suspend-2")
        XCTAssertEqual(manifest.suspendIdentifier, "suspend-2")
        XCTAssertEqual(manifest.staleIdentifiers, ["suspend-1"])
        XCTAssertTrue(manifest.isReferenced(backendIdentifier: "suspend-2"))
        XCTAssertFalse(manifest.isReferenced(backendIdentifier: "suspend-1"))
    }

    func testPlistRoundTripKeepsEveryField() throws {
        var manifest = UTMSnapshotManifest()
        let root = snapshot("Root", daysAgo: 1)
        var leaf = snapshot("Leaf", parent: root.id)
        leaf.screenshotName = "leaf.png"
        leaf.isOrphaned = true
        leaf.isIncomplete = true
        manifest.insert(root)
        manifest.insert(leaf)
        manifest.currentParentID = leaf.id
        manifest.setSuspendState("suspend")
        manifest.markStale("old")
        manifest.isBackendImported = true

        let data = try PropertyListEncoder().encode(manifest)
        let decoded = try PropertyListDecoder().decode(UTMSnapshotManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
        let dict = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(Set(dict.keys), ["Version", "Snapshots", "CurrentParent", "SuspendIdentifier", "BackendImported", "Stale"])
    }

    func testEmptyStaleListIsNotWritten() throws {
        let data = try PropertyListEncoder().encode(UTMSnapshotManifest())
        let dict = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertNil(dict["Stale"])
        XCTAssertEqual(dict["Version"] as? Int, 1)
    }

    func testUpdateCreatesLoadsAndSavesTheBundleManifest() throws {
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent("Manifest-\(UUID().uuidString).utm", isDirectory: true)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundle) }

        XCTAssertNil(try UTMSnapshotManifest.load(from: bundle))
        let count: Int = try UTMSnapshotManifest.update(in: bundle) { manifest in
            manifest.insert(self.snapshot("Saved"))
            return manifest.snapshots.count
        }
        XCTAssertEqual(count, 1)
        let loaded = try XCTUnwrap(try UTMSnapshotManifest.load(from: bundle))
        XCTAssertEqual(loaded.snapshots.map(\.title), ["Saved"])
        XCTAssertEqual(UTMSnapshotManifest.suspendState(in: bundle), nil)
        let stale = try UTMSnapshotManifest.replaceSuspendState(in: bundle, with: "s1")
        XCTAssertTrue(stale.isEmpty)
        XCTAssertEqual(UTMSnapshotManifest.suspendState(in: bundle), "s1")
    }
}
