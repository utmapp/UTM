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

/// The AppleScript `configuration` record: what `get configuration` returns
/// and how `update configuration` applies a record to a configuration.
@MainActor final class UTMScriptingConfigImplTests: XCTestCase {
    /// An aarch64 virt configuration with one 4 GiB virtio disk.
    private func configuration() -> UTMQemuConfiguration {
        let config = UTMQemuConfiguration()
        config.information.name = "Scripted"
        config.system.architecture = .aarch64
        config.system.target = QEMUTarget_aarch64.virt
        config.reset(forArchitecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.system.cpuCount = 2
        var disk = UTMQemuConfigurationDrive(forArchitecture: .aarch64, target: QEMUTarget_aarch64.virt)
        disk.sizeMib = 4096
        config.drives = [disk]
        return config
    }

    private func plist(_ config: UTMQemuConfiguration) throws -> NSDictionary {
        let data = try PropertyListEncoder().encode(config)
        return try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? NSDictionary)
    }

    func testSerializedRecordDescribesTheConfiguration() throws {
        let config = configuration()
        config.qemu.hasTPMDevice = true
        let record = UTMScriptingConfigImpl(config).serializeConfiguration()
        XCTAssertEqual(record["name"] as? String, "Scripted")
        XCTAssertEqual(record["architecture"] as? String, "aarch64")
        XCTAssertEqual(record["machine"] as? String, "virt")
        XCTAssertEqual(record["cpuCores"] as? Int, 2)
        XCTAssertEqual(record["tpm"] as? Bool, true)
        let drives = try XCTUnwrap(record["drives"] as? [[AnyHashable: Any]])
        XCTAssertEqual(drives.count, 1)
        XCTAssertEqual(drives[0]["id"] as? String, config.drives[0].id)
        XCTAssertEqual((record["networkInterfaces"] as? [[AnyHashable: Any]])?.count, 1)
        XCTAssertEqual((record["displays"] as? [[AnyHashable: Any]])?.count, 1)
    }

    /// Applying a configuration's own record must change nothing.
    func testApplyingOwnRecordIsIdentity() throws {
        let config = configuration()
        config.sharing.directoryShareMode = .virtfs
        config.qemu.additionalArguments = [QEMUArgument("-custom")]
        let before = try plist(config)
        let wrapper = UTMScriptingConfigImpl(config)
        try wrapper.updateConfiguration(from: wrapper.serializeConfiguration())
        XCTAssertEqual(try plist(config), before)
    }

    /// A record that names the architecture and machine the configuration already
    /// has, as every record from `get configuration` does, must not reset it (9db50536).
    func testSameMachineDoesNotResetConfiguration_9db50536() throws {
        let config = configuration()
        config.qemu.hasRNGDevice = false
        config.displays = []
        try UTMScriptingConfigImpl(config).updateConfiguration(from: ["architecture": "aarch64", "machine": "virt", "memory": 1024])
        XCTAssertFalse(config.qemu.hasRNGDevice, "settings survive an update that keeps the machine")
        XCTAssertTrue(config.displays.isEmpty)
        XCTAssertEqual(config.system.memorySize, 1024)
    }

    func testNewArchitectureResetsToItsDefaults() throws {
        let config = configuration()
        config.qemu.hasRNGDevice = false
        try UTMScriptingConfigImpl(config).updateConfiguration(from: ["architecture": "x86_64"])
        XCTAssertEqual(config.system.architecture, .x86_64)
        XCTAssertEqual(config.system.target.rawValue, QEMUTarget_x86_64.default.rawValue)
        XCTAssertTrue(config.qemu.hasRNGDevice, "reset to the x86_64 default")
        XCTAssertEqual(config.drives.count, 1, "drives are kept across a reset")
    }

    func testEmptyNameAndZeroMemoryAreIgnored() throws {
        let config = configuration()
        try UTMScriptingConfigImpl(config).updateConfiguration(from: ["name": "", "memory": 0, "notes": ""])
        XCTAssertEqual(config.information.name, "Scripted")
        XCTAssertEqual(config.system.memorySize, 512)
        XCTAssertNil(config.information.notes)
    }

    func testUnknownIconIsAnError() {
        let config = configuration()
        XCTAssertThrowsError(try UTMScriptingConfigImpl(config).updateConfiguration(from: ["icon": "no-such-icon"])) { error in
            guard case UTMScriptingConfigImpl.ConfigurationError.iconNotFound(let icon) = error else {
                return XCTFail("\(error)")
            }
            XCTAssertEqual(icon, "no-such-icon")
        }
    }

    /// Turning the TPM on brings the Secure Boot keys with it, like the settings toggle.
    func testTpmToggleCarriesSecureBootKeys() throws {
        let config = configuration()
        let wrapper = UTMScriptingConfigImpl(config)
        try wrapper.updateConfiguration(from: ["tpm": true])
        XCTAssertTrue(config.qemu.hasTPMDevice)
        XCTAssertTrue(config.qemu.hasPreloadedSecureBootKeys)
        XCTAssertTrue(config.qemu.isUefiVariableResetRequested)
        try wrapper.updateConfiguration(from: ["tpm": false])
        XCTAssertFalse(config.qemu.hasTPMDevice)
        XCTAssertFalse(config.qemu.hasPreloadedSecureBootKeys)
    }

    // MARK: Drives

    func testDriveRecordsReplaceTheDriveList() throws {
        let config = configuration()
        let existing = config.drives[0].id
        XCTAssertEqual(config.drives[0].interface, .virtio, "the default, so the update below is observable")
        let records: [[AnyHashable: Any]] = [
            ["id": existing, "interface": UTMScriptingQemuDriveInterface.scsi.rawValue],
            ["guestSize": 2048, "interface": UTMScriptingQemuDriveInterface.nvMe.rawValue, "raw": true],
            ["removable": true, "source": URL(fileURLWithPath: "/tmp/install.iso")],
        ]
        try UTMScriptingConfigImpl(config).updateConfiguration(from: ["drives": records])
        XCTAssertEqual(config.drives.count, 3)
        XCTAssertEqual(config.drives[0].id, existing)
        XCTAssertEqual(config.drives[0].interface, .scsi)
        XCTAssertEqual(config.drives[1].sizeMib, 2048)
        XCTAssertEqual(config.drives[1].interface, .nvme)
        XCTAssertTrue(config.drives[1].isRawImage)
        XCTAssertTrue(config.drives[2].isExternal)
        XCTAssertEqual(config.drives[2].imageURL?.path, "/tmp/install.iso")
    }

    func testOmittedDriveIsRemoved() throws {
        let config = configuration()
        try UTMScriptingConfigImpl(config).updateConfiguration(from: ["drives": [[AnyHashable: Any]]()])
        XCTAssertTrue(config.drives.isEmpty)
    }

    func testUnknownDriveIdIsAnError() {
        let config = configuration()
        XCTAssertThrowsError(try UTMScriptingConfigImpl(config).updateConfiguration(from: ["drives": [["id": "missing"]]])) { error in
            guard case UTMScriptingConfigImpl.ConfigurationError.identifierNotFound = error else {
                return XCTFail("\(error)")
            }
        }
    }

    /// Only a qcow2 image inside the bundle can be grown (7c01ae38).
    func testGuestSizeIsRejectedForRawAndRemovableDrives() throws {
        for (label, prepare) in [("raw", { (drive: inout UTMQemuConfigurationDrive) in drive.isRawImage = true }),
                                 ("removable", { (drive: inout UTMQemuConfigurationDrive) in drive.isExternal = true })] {
            let config = configuration()
            prepare(&config.drives[0])
            let record: [AnyHashable: Any] = ["drives": [["id": config.drives[0].id, "guestSize": 8192]]]
            XCTAssertThrowsError(try UTMScriptingConfigImpl(config).updateConfiguration(from: record), label) { error in
                guard case UTMScriptingConfigImpl.ConfigurationError.driveNotResizable = error else {
                    return XCTFail("\(label): \(error)")
                }
            }
        }
    }

    // MARK: Networks and port forwards

    /// `protocol:TCP` compiles to the serial-interface constant of the same name,
    /// which must be accepted alongside the network-protocol ones (99e32936).
    func testPortForwardProtocolAcceptsBothTcpConstants() throws {
        let config = configuration()
        let forwards: [[AnyHashable: Any]] = [
            ["protocol": UTMScriptingNetworkProtocol.udp.rawValue, "hostPort": 5353, "guestPort": 53],
            ["protocol": UTMScriptingSerialInterface.tcp.rawValue, "hostAddress": "127.0.0.1", "hostPort": 2222, "guestAddress": "10.0.2.15", "guestPort": 22],
        ]
        try UTMScriptingConfigImpl(config).updateConfiguration(from: ["networkInterfaces": [["index": 0, "portForwards": forwards]]])
        let result = config.networks[0].portForward
        XCTAssertEqual(result.map(\.protocol), [.udp, .tcp])
        XCTAssertEqual(result[1].hostAddress, "127.0.0.1")
        XCTAssertEqual(result[1].hostPort, 2222)
        XCTAssertEqual(result[1].guestAddress, "10.0.2.15")
        XCTAssertEqual(result[1].guestPort, 22)
    }

    /// Before 99e32936 an unparseable protocol was silently dropped.
    func testOtherSerialConstantIsNotAProtocol_99e32936() {
        let config = configuration()
        let record: [AnyHashable: Any] = ["networkInterfaces": [["index": 0, "portForwards": [["protocol": UTMScriptingSerialInterface.ptty.rawValue, "hostPort": 1, "guestPort": 1]]]]]
        XCTAssertThrowsError(try UTMScriptingConfigImpl(config).updateConfiguration(from: record)) { error in
            guard case UTMScriptingConfigImpl.ConfigurationError.invalidNetworkProtocol = error else {
                return XCTFail("\(error)")
            }
        }
    }

    func testNetworkRecordsAddUpdateAndRemoveByIndex() throws {
        let config = configuration()
        XCTAssertEqual(config.networks[0].mode, .shared, "the macOS default, so the update below is observable")
        let records: [[AnyHashable: Any]] = [
            ["index": 0, "mode": UTMScriptingQemuNetworkMode.emulated.rawValue, "address": "52:54:00:aa:bb:cc"],
            ["mode": UTMScriptingQemuNetworkMode.host.rawValue],
        ]
        try UTMScriptingConfigImpl(config).updateConfiguration(from: ["networkInterfaces": records])
        XCTAssertEqual(config.networks.count, 2)
        XCTAssertEqual(config.networks[0].mode, .emulated)
        XCTAssertEqual(config.networks[0].macAddress, "52:54:00:aa:bb:cc")
        XCTAssertEqual(config.networks[1].mode, .host)
        try UTMScriptingConfigImpl(config).updateConfiguration(from: ["networkInterfaces": [["index": 1]]])
        XCTAssertEqual(config.networks.count, 1)
        XCTAssertEqual(config.networks[0].mode, .host)
    }

    func testUnknownNetworkIndexIsAnError() {
        let config = configuration()
        XCTAssertThrowsError(try UTMScriptingConfigImpl(config).updateConfiguration(from: ["networkInterfaces": [["index": 5]]])) { error in
            guard case UTMScriptingConfigImpl.ConfigurationError.indexNotFound(let index) = error else {
                return XCTFail("\(error)")
            }
            XCTAssertEqual(index, 5)
        }
    }
}
