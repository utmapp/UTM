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
import XCTest
@testable import UTM

/// What an Apple Virtualization VM writes to its registry entry when its configuration is saved.
@MainActor
final class AppleVMRegistryTests: XCTestCase {
    private var packageDirectory: URL!
    private var vm: UTMAppleVirtualMachine?

    override func setUpWithError() throws {
        try super.setUpWithError()
        packageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AppleVMRegistryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let vm = vm {
            UTMRegistry.shared.remove(entry: vm.registryEntry)
            UTMRegistry.shared.sync()
        }
        vm = nil
        if let packageDirectory = packageDirectory {
            try? FileManager.default.removeItem(at: packageDirectory)
        }
        try super.tearDownWithError()
    }

    /// Clearing the restore image in the configuration clears it in the registry as well, so
    /// that a reload does not bring it back (7339e5ff: the registry kept the old path and the
    /// VM still asked to install from it).
    func testClearedRestoreImageIsClearedInTheRegistry() async throws {
        let ipsw = packageDirectory.appendingPathComponent("restore.ipsw")
        try Data("not really an ipsw".utf8).write(to: ipsw)
        let config = UTMAppleConfiguration()
        config.information.name = "registry"
        config.system.boot.macRecoveryIpswURL = ipsw
        let package = packageDirectory.appendingPathComponent("registry.utm", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let vm = try UTMAppleVirtualMachine(packageUrl: package, configuration: config)
        self.vm = vm
        try await vm.updateRegistryFromConfig()
        XCTAssertEqual(vm.registryEntry.macRecoveryIpsw?.url, ipsw, "the restore image was not recorded")
        config.system.boot.macRecoveryIpswURL = nil
        try await vm.updateRegistryFromConfig()
        XCTAssertNil(vm.registryEntry.macRecoveryIpsw, "the registry still names the cleared restore image")
        vm.updateConfigFromRegistry()
        XCTAssertNil(config.system.boot.macRecoveryIpswURL, "the cleared restore image came back from the registry")
    }
}
#endif
