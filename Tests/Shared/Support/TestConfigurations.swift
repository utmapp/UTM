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
@testable import UTM

extension UTMQemuConfiguration {
    /// A minimal aarch64 virt configuration with the given name and drives.
    @MainActor static func testFixture(named name: String, drives: [UTMQemuConfigurationDrive] = []) -> UTMQemuConfiguration {
        let config = UTMQemuConfiguration()
        config.information.name = name
        config.system.architecture = .aarch64
        config.system.target = QEMUTarget_aarch64.virt
        config.reset(forArchitecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.drives = drives
        return config
    }
}

/// A storage directory for VM bundles that a test owns, with the data layer's
/// persisted list reset so each test starts from an empty library.
@MainActor struct TestStorage {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("Storage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        UTMData.storageUrlOverride = url
        UserDefaults.standard.removeObject(forKey: "VMEntryList")
        UTMRegistry.shared.prune(exceptFor: [])
    }

    func tearDown(_ data: UTMData?) async {
        if let data = data {
            for vm in data.virtualMachines {
                try? await data.delete(vm: vm)
            }
        }
        UTMData.storageUrlOverride = nil
        UserDefaults.standard.removeObject(forKey: "VMEntryList")
        UTMRegistry.shared.prune(exceptFor: [])
        try? FileManager.default.removeItem(at: url)
    }
}
