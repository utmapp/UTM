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

import XCTest
@testable import UTM

/// Loads a UTM 3 era `config.plist` (no `Backend` key) through the same path the
/// app uses and checks the migrated result.
@MainActor final class UTMQemuConfigurationLegacyMigrationTests: XCTestCase {
    private var bundleURL: URL?

    override func setUpWithError() throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "v2-qemu-ac97", withExtension: "plist"))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Legacy-\(UUID().uuidString)")
            .appendingPathComponent("Legacy.utm")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        bundleURL = url
        try FileManager.default.copyItem(at: fixture, to: url.appendingPathComponent("config.plist"))
    }

    override func tearDownWithError() throws {
        if let bundleURL = bundleURL {
            try FileManager.default.removeItem(at: bundleURL.deletingLastPathComponent())
        }
    }

    private func loadQemuConfiguration() throws -> UTMQemuConfiguration {
        try XCTUnwrap(try UTMQemuConfiguration.load(from: XCTUnwrap(bundleURL)) as? UTMQemuConfiguration)
    }

    func testLegacyPlistIsRecognizedAndMigrated() throws {
        let config = try loadQemuConfiguration()
        XCTAssertTrue(config.isLegacy)
        XCTAssertEqual(config.information.name, "Legacy")
        XCTAssertEqual(config.system.architecture, .x86_64)
        XCTAssertEqual(config.system.target.rawValue, "pc")
        XCTAssertEqual(config.system.memorySize, 512)
        XCTAssertEqual(config.drives.count, 1)
        XCTAssertEqual(config.drives[0].imageName, "disk.qcow2")
        XCTAssertEqual(config.networks.count, 1)
    }

    /// QEMU's device is spelled "AC97" but UTM 3 saved it as "ac97" (65dbdded).
    func testAc97SoundCardIsRenamedOnMigration_65dbdded() throws {
        let config = try loadQemuConfiguration()
        XCTAssertEqual(config.sound.count, 1)
        XCTAssertEqual(config.sound.first?.hardware.rawValue, "AC97")
    }

    /// A UTM 3 forward from host port 2222 to guest port 22 keeps both ports; the
    /// migration once copied the guest port into the host port (b2215bc1). The
    /// second forward keeps its protocol and its place.
    func testPortForwardKeepsHostAndGuestPorts_b2215bc1() throws {
        let config = try loadQemuConfiguration()
        let forwards = try XCTUnwrap(config.networks.first?.portForward)
        XCTAssertEqual(forwards.count, 2)
        XCTAssertEqual(forwards[0].protocol, .tcp)
        XCTAssertEqual(forwards[0].hostAddress, "127.0.0.1")
        XCTAssertEqual(forwards[0].hostPort, 2222)
        XCTAssertEqual(forwards[0].guestAddress, "10.0.2.15")
        XCTAssertEqual(forwards[0].guestPort, 22)
        XCTAssertEqual(forwards[1].protocol, .udp)
        XCTAssertEqual(forwards[1].hostAddress, "0.0.0.0")
        XCTAssertEqual(forwards[1].hostPort, 5353)
        XCTAssertEqual(forwards[1].guestPort, 53)
    }

    func testMigratedConfigurationEncodesAsCurrentVersion() throws {
        let config = try loadQemuConfiguration()
        let data = try PropertyListEncoder().encode(config)
        let dict = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(dict["Backend"] as? String, "QEMU")
        XCTAssertEqual(dict["ConfigurationVersion"] as? Int, UTMQemuConfiguration.currentVersion)
        let decoder = PropertyListDecoder()
        decoder.userInfo = [.dataURL: try XCTUnwrap(bundleURL).appendingPathComponent("Data")]
        let again = try decoder.decode(UTMQemuConfiguration.self, from: data)
        XCTAssertFalse(again.isLegacy)
        XCTAssertEqual(again.sound.first?.hardware.rawValue, "AC97")
        XCTAssertEqual(again.networks.first?.portForward.map(\.hostPort), [2222, 5353])
    }
}
