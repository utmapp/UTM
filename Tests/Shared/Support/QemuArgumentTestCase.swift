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

/// A test case that generates QEMU command lines from configurations built in code.
///
/// It pins the host state the generator reads (the capabilities, the defaults, the
/// resource directory) for the duration of each test and puts it back afterwards, and
/// offers the configuration, drive and firmware helpers the argument tests share.
@MainActor class QemuArgumentTestCase: XCTestCase {
    private var savedCapabilities: UTMCapabilities!
    private var savedArguments: [String: Any]!

    /// An empty directory standing in for the app's QEMU resources; stage firmware here.
    private(set) var resources: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedCapabilities = UTMCapabilities.current
        savedArguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        resources = FileManager.default.temporaryDirectory.appendingPathComponent("qemu-resources-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        UTMQemuConfiguration.resourceURLOverride = resources
    }

    override func tearDownWithError() throws {
        UTMQemuConfiguration.resourceURLOverride = nil
        UTMCapabilities.current = savedCapabilities
        UserDefaults.standard.setVolatileDomain(savedArguments, forName: UserDefaults.argumentDomain)
        try? FileManager.default.removeItem(at: resources)
        try super.tearDownWithError()
    }

    /// Settings the generator reads from `UserDefaults.standard`, applied through the
    /// argument domain so nothing is written to disk and the host's own launch
    /// arguments stay in place.
    func setDefaults(_ values: [String: Any]) {
        var domain = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        domain.merge(values) { _, new in new }
        UserDefaults.standard.setVolatileDomain(domain, forName: UserDefaults.argumentDomain)
    }

    /// The defaults for the architecture and target, with two cores and a name.
    func configuration(architecture: QEMUArchitecture, target: any QEMUTarget) -> UTMQemuConfiguration {
        let config = UTMQemuConfiguration()
        config.system.architecture = architecture
        config.system.target = target
        config.reset(forArchitecture: architecture, target: target)
        config.system.cpuCount = 2
        config.information.name = "Test"
        return config
    }

    func drive(_ config: UTMQemuConfiguration, interface: QEMUDriveInterface, type: QEMUDriveImageType = .disk, imageURL: URL? = URL(fileURLWithPath: "/tmp/image.qcow2"), interfaceVersion: Int = UTMQemuConfigurationDrive.latestInterfaceVersion) -> UTMQemuConfigurationDrive {
        var drive = UTMQemuConfigurationDrive(forArchitecture: config.system.architecture, target: config.system.target)
        drive.imageType = type
        drive.interface = interface
        drive.imageURL = imageURL
        drive.interfaceVersion = interfaceVersion
        return drive
    }

    /// Creates an empty firmware image of this name in the resources, so the generator
    /// emits the pflash drives for it.
    func stageFirmware(_ name: String) {
        FileManager.default.createFile(atPath: resources.appendingPathComponent(name).path, contents: Data())
    }

    func arguments(_ config: UTMQemuConfiguration) -> QEMUArgumentList {
        QEMUArgumentList(config.allArguments)
    }
}
