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

/// The registry keeps what is not part of a VM's configuration (its location, window
/// state, external drives) in the app's defaults, keyed by the VM's UUID.
///
/// Each test gets its own registry on a defaults suite of its own, which is removed
/// afterwards, so the app's registry (`UTMRegistry.shared`) is never touched; the
/// registry's debounced background writes go to the suite, or nowhere once the registry
/// is gone. The entry's properties are main-actor isolated.
@MainActor
final class UTMRegistryTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var registry: UTMRegistry!

    override func setUpWithError() throws {
        suiteName = "UTMRegistryTests." + UUID().uuidString
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        registry = UTMRegistry(defaults: defaults)
    }

    override func tearDownWithError() throws {
        registry = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    private func makeEntry(name: String = "VM") -> UTMRegistryEntry {
        registry.entry(uuid: UUID(), name: name, path: "/tmp/\(name).utm")
    }

    // MARK: - The registry

    func testEntryIsCreatedOnceAndFoundByUuid() {
        let uuid = UUID()
        let entry = registry.entry(uuid: uuid, name: "VM", path: "/tmp/VM.utm")
        XCTAssertEqual(entry.uuid, uuid)
        XCTAssertEqual(entry.name, "VM")
        XCTAssertEqual(entry.package.path, "/tmp/VM.utm")
        // asking again with other details returns the existing entry unchanged
        let again = registry.entry(uuid: uuid, name: "Other", path: "/tmp/Other.utm")
        XCTAssertTrue(again === entry)
        XCTAssertEqual(again.name, "VM")
        XCTAssertTrue(registry.entry(for: uuid.uuidString) === entry)
        XCTAssertNil(registry.entry(for: UUID().uuidString))
    }

    func testRemoveForgetsTheEntry() {
        let entry = makeEntry()
        registry.remove(entry: entry)
        XCTAssertNil(registry.entry(for: entry.uuid.uuidString))
    }

    func testPruneKeepsOnlyTheGivenEntries() {
        let kept = makeEntry(name: "Kept")
        let dropped = makeEntry(name: "Dropped")
        registry.prune(exceptFor: [kept.uuid.uuidString])
        XCTAssertTrue(registry.entry(for: kept.uuid.uuidString) === kept)
        XCTAssertNil(registry.entry(for: dropped.uuid.uuidString))
    }

    /// `sync()` writes every entry to the defaults under its UUID, and a registry
    /// created on the same defaults (as at the next launch) reads them back.
    func testSyncWritesEveryEntryToTheDefaults() throws {
        let first = makeEntry(name: "First")
        let second = makeEntry(name: "Second")
        second.setIsSuspended(true)
        registry.sync()
        let stored = try XCTUnwrap(defaults.dictionary(forKey: "Registry"))
        XCTAssertEqual(Set(stored.keys), [first.uuid.uuidString, second.uuid.uuidString])
        let relaunched = UTMRegistry(defaults: defaults)
        let reloaded = try XCTUnwrap(relaunched.entry(for: second.uuid.uuidString))
        XCTAssertEqual(reloaded.name, "Second")
        XCTAssertEqual(reloaded.package.path, "/tmp/Second.utm")
        XCTAssertTrue(reloaded.isSuspended)
        // a removed entry is gone from the defaults after the next sync
        registry.remove(entry: first)
        registry.sync()
        XCTAssertEqual(defaults.dictionary(forKey: "Registry")?.keys.sorted(), [second.uuid.uuidString])
    }

    // MARK: - The entry's property list

    func testOptionalKeysAreWrittenOnlyWhenSet() throws {
        let entry = UTMRegistryEntry(uuid: UUID(), name: "VM", path: "/tmp/VM.utm")
        var dict = try entry.asDictionary()
        XCTAssertEqual(Set(dict.keys), ["Name", "Package", "UUID", "Suspended", "ExternalDrives", "SharedDirectories", "WindowSettings", "TerminalSettings", "ResolutionSettings"])
        entry.hasMigratedConfig = true
        entry.setConnectedUsbDevices([.init(vendorId: 0x1234, productId: 0x5678, serial: "S1", uuid: nil)])
        dict = try entry.asDictionary()
        XCTAssertEqual(dict["MigratedConfig"] as? Bool, true)
        XCTAssertEqual((dict["ConnectedUsbDevices"] as? [Any])?.count, 1)
    }

    /// An entry written by an older UTM has none of the keys added since.
    func testEntryWithoutTheNewerKeysDecodes() throws {
        let uuid = UUID()
        let plist: [String: Any] = [
            "Name": "Old",
            "Package": ["Path": "/tmp/Old.utm", "Bookmark": Data(), "ReadOnly": false],
            "UUID": uuid.uuidString,
            "Suspended": false,
            "ExternalDrives": [:],
            "SharedDirectories": [],
            "WindowSettings": [:],
        ]
        let entry = try UTMRegistryEntry(fromPropertyList: plist)
        XCTAssertEqual(entry.uuid, uuid)
        XCTAssertEqual(entry.name, "Old")
        XCTAssertEqual(entry.package.path, "/tmp/Old.utm")
        XCTAssertTrue(entry.terminalSettings.isEmpty)
        XCTAssertTrue(entry.resolutionSettings.isEmpty)
        XCTAssertFalse(entry.hasMigratedConfig)
        XCTAssertNil(entry.macRecoveryIpsw)
        XCTAssertTrue(entry.connectedUsbDevices.isEmpty)
    }

    /// A drive or shared directory whose bookmark no longer resolves (its file was
    /// deleted) is dropped on load rather than failing the whole entry; the others stay.
    func testUnresolvableFilesAreDroppedOnDecode() throws {
        let deleted = FileManager.default.temporaryDirectory.appendingPathComponent("UTMRegistryTests-" + UUID().uuidString + ".img")
        try Data().write(to: deleted)
        let staleBookmark = try deleted.persistentBookmarkData()
        try FileManager.default.removeItem(at: deleted)
        let stale: [String: Any] = ["Path": deleted.path, "Bookmark": staleBookmark, "ReadOnly": false]
        let kept: [String: Any] = ["Path": "/tmp/kept.img", "Bookmark": Data(), "ReadOnly": true]
        let plist: [String: Any] = [
            "Name": "VM",
            "Package": ["Path": "/tmp/VM.utm", "Bookmark": Data(), "ReadOnly": false],
            "UUID": UUID().uuidString,
            "Suspended": false,
            "ExternalDrives": ["drive0": stale, "drive1": kept],
            "SharedDirectories": [stale, kept],
            "WindowSettings": [:],
        ]
        let entry = try UTMRegistryEntry(fromPropertyList: plist)
        XCTAssertEqual(entry.externalDrives.keys.sorted(), ["drive1"])
        XCTAssertEqual(entry.externalDrives["drive1"]?.path, "/tmp/kept.img")
        XCTAssertEqual(entry.sharedDirectories.map(\.path), ["/tmp/kept.img"])
    }

    func testSettingsSurviveARoundTrip() throws {
        let entry = UTMRegistryEntry(uuid: UUID(), name: "VM", path: "/tmp/VM.utm")
        var window = UTMRegistryEntry.Window()
        window.scale = 2
        window.origin = CGPoint(x: 10, y: 20)
        window.isToolbarVisible = false
        entry.windowSettings = [0: window]
        entry.terminalSettings = [1: .init(columns: 132, rows: 43)]
        var resolution = UTMRegistryEntry.Resolution()
        resolution.size = CGSize(width: 1920, height: 1080)
        resolution.isFullscreen = true
        entry.resolutionSettings = [0: resolution]
        entry.setIsSuspended(true)
        entry.hasMigratedConfig = true
        let device = UTMRegistryEntry.USBDevice(vendorId: 1, productId: 2, serial: nil, uuid: UUID())
        entry.setConnectedUsbDevices([device])

        let again = try UTMRegistryEntry(fromPropertyList: try entry.asDictionary())
        XCTAssertEqual(again.uuid, entry.uuid)
        XCTAssertEqual(again.windowSettings, [0: window])
        XCTAssertEqual(again.terminalSettings, [1: .init(columns: 132, rows: 43)])
        XCTAssertEqual(again.resolutionSettings, [0: resolution])
        XCTAssertTrue(again.isSuspended)
        XCTAssertTrue(again.hasMigratedConfig)
        XCTAssertEqual(again.connectedUsbDevices, [device])
    }

    /// Copying another entry's state (as a clone or a move does) keeps the identity.
    func testUpdateCopyingKeepsTheIdentity() {
        let source = UTMRegistryEntry(uuid: UUID(), name: "Source", path: "/tmp/Source.utm")
        source.setIsSuspended(true)
        source.terminalSettings = [0: .init(columns: 100, rows: 50)]
        source.hasMigratedConfig = true
        let target = UTMRegistryEntry(uuid: UUID(), name: "Target", path: "/tmp/Target.utm")
        target.update(copying: source)
        XCTAssertNotEqual(target.uuid, source.uuid)
        XCTAssertEqual(target.name, "Target")
        XCTAssertEqual(target.package.path, "/tmp/Target.utm")
        XCTAssertTrue(target.isSuspended)
        XCTAssertEqual(target.terminalSettings, [0: .init(columns: 100, rows: 50)])
        XCTAssertTrue(target.hasMigratedConfig)
    }
}
