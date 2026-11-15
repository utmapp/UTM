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

/// The VM list: creating, saving, renaming, deleting and refreshing bundles in a
/// storage directory that each test owns.
@MainActor final class UTMDataListTests: XCTestCase {
    private var storage: TestStorage!
    private var data: UTMData!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storage = try TestStorage()
        data = UTMData()
    }

    override func tearDown() async throws {
        await storage.tearDown(data)
        try await super.tearDown()
    }

    private func configuration(named name: String) -> UTMQemuConfiguration {
        .testFixture(named: name)
    }

    private func bundles() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: storage.url.path).filter { $0.hasSuffix(".utm") }.sorted()
    }

    func testCreateWritesBundleAndRegistersIt() async throws {
        let vm = try await data.create(config: configuration(named: "First"))
        XCTAssertEqual(try bundles(), ["First.utm"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url.appendingPathComponent("First.utm/config.plist").path))
        XCTAssertEqual(data.virtualMachines.count, 1)
        XCTAssertEqual(vm.registryEntry?.name, "First")
        XCTAssertEqual(vm.registryEntry?.package.path, vm.pathUrl.path)
        XCTAssertNotNil(UTMRegistry.shared.entry(for: vm.id.uuidString))
    }

    func testCreateRejectsDuplicateName() async throws {
        _ = try await data.create(config: configuration(named: "Twin"))
        do {
            _ = try await data.create(config: configuration(named: "Twin"))
            XCTFail("expected a duplicate-name error")
        } catch UTMDataError.virtualMachineAlreadyExists {
            XCTAssertEqual(try bundles(), ["Twin.utm"])
        }
    }

    /// A save that fails while importing a drive image, before the configuration is
    /// written, must not leave an empty bundle that the library would then list (8a242918).
    func testFailedCreateLeavesNoEmptyBundle_8a242918() async throws {
        let config = configuration(named: "Broken")
        config.qemu.hasUefiBoot = false // no firmware variables are written ahead of the drives
        var drive = UTMQemuConfigurationDrive(forArchitecture: .aarch64, target: QEMUTarget_aarch64.virt)
        drive.imageURL = storage.url.appendingPathComponent("missing.img")
        drive.isRawImage = true // copied as-is, so the missing file fails before anything is written
        config.drives = [drive]
        do {
            _ = try await data.create(config: config)
            XCTFail("expected the missing image to fail the save")
        } catch {
            XCTAssertEqual(try bundles(), [], "\(error)")
            XCTAssertTrue(data.virtualMachines.isEmpty)
        }
    }

    /// Renaming moves the bundle and keeps the registry pointing at it (5d98afb7).
    func testRenameMovesBundleAndUpdatesRegistry_5d98afb7() async throws {
        let vm = try await data.create(config: configuration(named: "Before"))
        (vm.config as? UTMQemuConfiguration)?.information.name = "After"
        try await data.save(vm: vm)
        XCTAssertEqual(try bundles(), ["After.utm"])
        XCTAssertEqual(vm.pathUrl.lastPathComponent, "After.utm")
        XCTAssertEqual(vm.registryEntry?.name, "After")
        XCTAssertEqual(vm.registryEntry?.package.path, storage.url.appendingPathComponent("After.utm").path)
        XCTAssertEqual(data.virtualMachines.count, 1)
    }

    func testDeleteRemovesBundleAndRegistryEntry() async throws {
        let vm = try await data.create(config: configuration(named: "Gone"))
        let id = vm.id.uuidString
        try await data.delete(vm: vm)
        XCTAssertEqual(try bundles(), [])
        XCTAssertTrue(data.virtualMachines.isEmpty)
        XCTAssertNil(UTMRegistry.shared.entry(for: id))
    }

    /// A bundle written to the storage directory without going through the list is
    /// discovered by a refresh, once.
    func testRefreshPicksUpBundlesOnDiskOnce() async throws {
        let vm = try VMData(creatingFromConfig: configuration(named: "Disk"), destinationUrl: storage.url)
        try await vm.save()
        XCTAssertTrue(data.virtualMachines.isEmpty, "the list does not know the bundle yet")
        await data.listRefresh()
        XCTAssertEqual(data.virtualMachines.map(\.detailsTitleLabel), ["Disk"])
        await data.listRefresh()
        XCTAssertEqual(data.virtualMachines.count, 1, "a second refresh must not add the same bundle again")
    }

    /// The same bundle reached through another path, such as a symbolic link to the
    /// storage directory, is the same VM and must not appear twice (4879a465).
    func testRefreshRecognizesTheSameBundleThroughAnotherPath_4879a465() async throws {
        _ = try await data.create(config: configuration(named: "Linked"))
        let link = FileManager.default.temporaryDirectory.appendingPathComponent("Storage-link-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: storage.url)
        defer { try? FileManager.default.removeItem(at: link) }
        UTMData.storageUrlOverride = link
        await data.listRefresh()
        XCTAssertEqual(data.virtualMachines.count, 1, "\(data.virtualMachines.map(\.pathUrl.path))")
    }

    /// Adds a VM stored outside the storage directory, then relaunches with its saved
    /// bookmark unresolvable and the bundle out of reach, so it is listed as unavailable.
    /// Returns the bundle's original location, its ID, and where the bundle now is.
    private func makeUnavailableExternalVM(in external: URL) async throws -> (bundle: URL, id: UUID, away: URL) {
        let created = try VMData(creatingFromConfig: configuration(named: "External"), destinationUrl: external)
        try await created.save()
        let bundle = created.pathUrl
        try await data.importUTM(from: bundle)
        let entry = try XCTUnwrap(data.virtualMachines.first?.registryEntry)
        // a bookmark that cannot be resolved, which falls back to a path the sandbox denies
        entry.package = UTMRegistryEntry.File(dummyFromPath: bundle.path, remoteBookmark: Data("not a bookmark".utf8))
        let away = external.appendingPathComponent("away", isDirectory: true)
        try FileManager.default.moveItem(at: bundle, to: away)
        data = UTMData()
        XCTAssertEqual(data.virtualMachines.map(\.isLoaded), [false])
        return (bundle, entry.uuid, away)
    }

    private func assertReopened(_ id: UUID, at bundle: URL, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(data.virtualMachines.map(\.isLoaded), [true], "the same row is loaded, not a second one added", file: file, line: line)
        XCTAssertEqual(data.virtualMachines.first?.id, id, file: file, line: line)
        XCTAssertTrue(data.selectedVM === data.virtualMachines.first, file: file, line: line)
        let package = try XCTUnwrap(data.virtualMachines.first?.registryEntry?.package, file: file, line: line)
        let resolved = try URL(resolvingPersistentBookmarkData: package.bookmark)
        XCTAssertEqual(resolved.resolvingSymlinksInPath().path, bundle.resolvingSymlinksInPath().path, file: file, line: line)
        XCTAssertNil(package.remoteBookmark, "the launcher's bookmark made from the failed one is dropped", file: file, line: line)
    }

    /// Opening the `.utm` of a VM whose saved bookmark no longer resolves (shown as
    /// unavailable) loads it and saves a new bookmark, so it still loads after a relaunch
    /// instead of having to be opened again every time (#7762).
    func testReopeningUnavailableVMSavesNewBookmark_7762() async throws {
        let external = FileManager.default.temporaryDirectory.appendingPathComponent("External-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: external) }
        let (bundle, id, away) = try await makeUnavailableExternalVM(in: external)
        try FileManager.default.moveItem(at: away, to: bundle)
        try await data.importUTM(from: bundle)
        try assertReopened(id, at: bundle)
    }

    /// The same, when the bundle is opened from another path than the one saved, such as
    /// a drive that mounted under another name: the unavailable row is replaced, not kept
    /// next to a duplicate with a new ID (#7762).
    func testReopeningUnavailableVMFromAnotherPathReplacesIt_7762() async throws {
        let external = FileManager.default.temporaryDirectory.appendingPathComponent("External-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: external) }
        let (_, id, away) = try await makeUnavailableExternalVM(in: external)
        let moved = external.appendingPathComponent("Renamed.utm", isDirectory: true)
        try FileManager.default.moveItem(at: away, to: moved)
        try await data.importUTM(from: moved)
        try assertReopened(id, at: moved)
    }

    func testIsSameFileComparesFileIdentityNotPathText() throws {
        let link = FileManager.default.temporaryDirectory.appendingPathComponent("Storage-link-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: storage.url)
        defer { try? FileManager.default.removeItem(at: link) }
        try FileManager.default.createDirectory(at: storage.url.appendingPathComponent("A.utm"), withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: storage.url.appendingPathComponent("B.utm"), withIntermediateDirectories: false)
        XCTAssertTrue(data.isSameFile(storage.url.appendingPathComponent("A.utm"), as: link.appendingPathComponent("A.utm")))
        XCTAssertFalse(data.isSameFile(storage.url.appendingPathComponent("A.utm"), as: link.appendingPathComponent("B.utm")))
    }

    /// Zip a bundle the way a `utm://downloadVM` link serves it, and download it
    /// from a `file://` URL through the same call the link's prompt makes.
    private func download(_ config: UTMQemuConfiguration) async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("Download-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: source) }
        let vm = try VMData(creatingFromConfig: config, destinationUrl: source)
        try await vm.save()
        // a downloaded VM is new to this Mac, so forget the source bundle
        UTMRegistry.shared.prune(exceptFor: [])
        let name = vm.pathUrl.lastPathComponent
        var zip = ZipArchiveBuilder()
        zip.addDirectory(name)
        zip.addFile("\(name)/config.plist", contents: try String(contentsOf: vm.pathUrl.appendingPathComponent("config.plist"), encoding: .utf8))
        let zipUrl = source.appendingPathComponent("\(UUID().uuidString).zip")
        try zip.write(to: zipUrl)
        await data.downloadUTMZip(from: zipUrl).value
    }

    /// A VM downloaded through a `utm://downloadVM` link warns about custom QEMU
    /// arguments, as importing the same `.utm` does (#7733).
    func testDownloadedVMWithCustomArgumentsWarns_7733() async throws {
        let config = configuration(named: "Custom")
        config.qemu.additionalArguments = [QEMUArgument("-custom")]
        try await download(config)
        XCTAssertEqual(data.virtualMachines.map(\.detailsTitleLabel), ["Custom"])
        XCTAssertTrue(data.selectedVM === data.virtualMachines.first, "the warning must be about the selected VM")
        guard case .localizedMessage(let message) = data.alertItem else {
            return XCTFail("expected the custom arguments warning, got \(String(describing: data.alertItem))")
        }
        XCTAssertTrue(message.localizedString.contains("custom QEMU arguments"), message.localizedString)
    }

    func testDownloadedVMWithoutCustomArgumentsDoesNotWarn_7733() async throws {
        try await download(configuration(named: "Plain"))
        XCTAssertEqual(data.virtualMachines.map(\.detailsTitleLabel), ["Plain"])
        XCTAssertNil(data.alertItem)
    }
}
