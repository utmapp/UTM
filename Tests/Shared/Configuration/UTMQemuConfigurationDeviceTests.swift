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

/// Which devices the settings can add to a configuration.
@MainActor
final class UTMQemuConfigurationDeviceTests: XCTestCase {
    private func configuration(for architecture: QEMUArchitecture) -> UTMQemuConfiguration {
        let config = UTMQemuConfiguration()
        config.system.architecture = architecture
        config.system.target = architecture.targetType.default
        config.reset(forArchitecture: architecture, target: architecture.targetType.default)
        return config
    }

    private func addDisplay(to config: UTMQemuConfiguration) throws {
        let display = UTMQemuConfigurationDisplay(forArchitecture: config.system.architecture, target: config.system.target)
        config.displays.append(try XCTUnwrap(display))
    }

    func testAPcTakesAnyNumberOfDisplaysNetworksAndSoundCards() throws {
        let config = configuration(for: .x86_64)
        XCTAssertTrue(config.canAddDisplay)
        try addDisplay(to: config)
        try addDisplay(to: config)
        XCTAssertTrue(config.canAddDisplay)
        XCTAssertTrue(config.canAddNetwork)
        XCTAssertTrue(config.canAddSound)
    }

    func testFixedFramebufferArchitecturesTakeOneDisplay() throws {
        for architecture in [QEMUArchitecture.sparc, .sparc64, .m68k] {
            let config = configuration(for: architecture)
            config.displays.removeAll()
            XCTAssertTrue(config.canAddDisplay, "\(architecture)")
            try addDisplay(to: config)
            XCTAssertFalse(config.canAddDisplay, "\(architecture)")
        }
    }

    func testArchitecturesWithoutDevicesCannotAddThem() {
        for architecture in [QEMUArchitecture.avr, .rx, .tricore] {
            let config = configuration(for: architecture)
            XCTAssertFalse(config.canAddDisplay, "\(architecture)")
            XCTAssertFalse(config.canAddNetwork, "\(architecture)")
            XCTAssertFalse(config.canAddSound, "\(architecture)")
        }
    }

    func testSparcHasNoSoundCardButHasANetworkDevice() {
        let config = configuration(for: .sparc)
        XCTAssertFalse(config.canAddSound)
        XCTAssertTrue(config.canAddNetwork)
    }
}
