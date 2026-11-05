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

/// Rules that both backends must follow, run against each from one table so a
/// fix landing in one backend cannot be missed in the other, as happened when the
/// wizard's boot image was lost first for QEMU (5730f984) and then for Apple (a52c0fca).
@MainActor final class BackendParityTests: XCTestCase {
    private struct Backend {
        let name: String
        let make: (String, URL) throws -> any UTMConfiguration
        let bootImageURL: (any UTMConfiguration) -> URL?
    }

    private static let qemu = Backend(name: "qemu", make: { name, image in
        var drive = UTMQemuConfigurationDrive(forArchitecture: .aarch64, target: QEMUTarget_aarch64.virt, isExternal: true)
        drive.imageURL = image
        return UTMQemuConfiguration.testFixture(named: name, drives: [drive])
    }, bootImageURL: { ($0 as? UTMQemuConfiguration)?.drives.first?.imageURL })

    #if os(macOS)
    private static let apple = Backend(name: "apple", make: { name, image in
        let config = UTMAppleConfiguration()
        config.information.name = name
        config.system.boot = try UTMAppleConfigurationBoot(for: .linux)
        config.drives = [UTMAppleConfigurationDrive(existingURL: image, isExternal: true)]
        return config
    }, bootImageURL: { ($0 as? UTMAppleConfiguration)?.drives.first?.imageURL })
    #endif

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

    /// An external boot image chosen at creation is still there after the first save and a reload.
    private func assertExternalBootImageSurvives(_ backend: Backend) async throws {
        let image = storage.url.appendingPathComponent("\(backend.name)-boot.iso")
        try Data("iso".utf8).write(to: image)
        let vm = try await data.create(config: try backend.make("Boot \(backend.name)", image))
        XCTAssertEqual(backend.bootImageURL(try XCTUnwrap(vm.config))?.path, image.path, backend.name)
        let entry = try XCTUnwrap(vm.registryEntry, backend.name)
        XCTAssertFalse(entry.externalDrives.isEmpty, "\(backend.name): the image is remembered in the registry")
        try vm.wrapped?.reload(from: nil)
        XCTAssertEqual(backend.bootImageURL(try XCTUnwrap(vm.config))?.path, image.path, "\(backend.name) after reload")
    }

    func testQemuExternalBootImageSurvivesCreateSaveAndReload() async throws {
        try await assertExternalBootImageSurvives(Self.qemu)
    }

    #if os(macOS)
    func testAppleExternalBootImageSurvivesCreateSaveAndReload() async throws {
        try await assertExternalBootImageSurvives(Self.apple)
    }
    #endif
}
