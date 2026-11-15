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

#if os(macOS)
import Virtualization
import XCTest
@testable import UTM

/// Cloning an Apple Virtualization VM through the data layer.
@MainActor final class AppleVMCloneTests: XCTestCase {
    private static let regenerateMACKey = "IsRegenerateMACOnClone"
    private var storage: TestStorage!
    private var data: UTMData!
    private var savedRegenerateMAC: Any?

    override func setUpWithError() throws {
        try super.setUpWithError()
        // saving validates the configuration with Virtualization, which a VM guest may not offer
        try XCTSkipUnless(VZVirtualMachine.isSupported, "Virtualization is not available on this Mac")
        savedRegenerateMAC = UserDefaults.standard.object(forKey: Self.regenerateMACKey)
        storage = try TestStorage()
        data = UTMData()
    }

    override func tearDown() async throws {
        // storage is set only after setUp captured the setting, so a skipped test changes nothing
        if let storage = storage {
            await storage.tearDown(data)
            UserDefaults.standard.set(savedRegenerateMAC, forKey: Self.regenerateMACKey)
        }
        try await super.tearDown()
    }

    private func createVM(named name: String) async throws -> VMData {
        let config = UTMAppleConfiguration()
        config.information.name = name
        config.system.boot = try UTMAppleConfigurationBoot(for: .linux)
        // two cards, so a fix that only changes the first one fails
        config.networks = [UTMAppleConfigurationNetwork(), UTMAppleConfigurationNetwork()]
        return try await data.create(config: config)
    }

    private func macAddresses(of vm: VMData) throws -> [String] {
        let config = try XCTUnwrap(vm.config as? UTMAppleConfiguration)
        return config.networks.map { $0.macAddress }
    }

    /// With "Regenerate MAC addresses on clone" on, the clone of an Apple VM gets new MAC
    /// addresses on every network, as a QEMU clone does (#7895: the clone kept the original's).
    func testCloneRegeneratesMACAddressesWhenEnabled_7895() async throws {
        UserDefaults.standard.set(true, forKey: Self.regenerateMACKey)
        let original = try await createVM(named: "Original")
        let originalMACs = try macAddresses(of: original)
        let clone = try await data.clone(vm: original)
        let cloneMACs = try macAddresses(of: clone)
        XCTAssertEqual(cloneMACs.count, originalMACs.count)
        for (cloneMAC, originalMAC) in zip(cloneMACs, originalMACs) {
            XCTAssertNotEqual(cloneMAC, originalMAC, "the clone kept the original's MAC address")
            XCTAssertNotNil(VZMACAddress(string: cloneMAC), "\(cloneMAC) is not a valid MAC address")
        }
        // the new addresses are saved, not only changed in memory
        let reloaded = try VMData(url: clone.pathUrl)
        XCTAssertEqual(try macAddresses(of: reloaded), cloneMACs)
    }

    /// With the setting off, the clone keeps the original's MAC addresses.
    func testCloneKeepsMACAddressesWhenDisabled() async throws {
        UserDefaults.standard.set(false, forKey: Self.regenerateMACKey)
        let original = try await createVM(named: "Original")
        let clone = try await data.clone(vm: original)
        XCTAssertEqual(try macAddresses(of: clone), try macAddresses(of: original))
    }
}
#endif
