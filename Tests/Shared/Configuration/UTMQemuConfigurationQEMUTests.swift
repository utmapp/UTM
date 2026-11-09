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

/// The rules behind the QEMU tweaks and maintenance settings.
final class UTMQemuConfigurationQEMUTests: XCTestCase {
    /// The default machine, which supports Secure Boot.
    private let system = UTMQemuConfigurationSystem()

    func testAddingATPMResetsUefiVariablesAndPreloadsSecureBootKeys() {
        var qemu = UTMQemuConfigurationQEMU()
        qemu.setTPMDevice(true, for: system)
        XCTAssertTrue(qemu.hasTPMDevice)
        XCTAssertTrue(qemu.isUefiVariableResetRequested)
        XCTAssertTrue(qemu.hasPreloadedSecureBootKeys)
    }

    func testRemovingTheTPMDropsTheKeyPreloadButKeepsTheResetRequest() {
        var qemu = UTMQemuConfigurationQEMU()
        qemu.setTPMDevice(true, for: system)
        qemu.setTPMDevice(false, for: system)
        XCTAssertFalse(qemu.hasTPMDevice)
        XCTAssertTrue(qemu.isUefiVariableResetRequested)
        XCTAssertFalse(qemu.hasPreloadedSecureBootKeys)
    }

    func testCancellingTheVariableResetDropsTheKeyPreload() {
        var qemu = UTMQemuConfigurationQEMU()
        qemu.setTPMDevice(true, for: system)
        qemu.setUefiVariableResetRequested(false)
        XCTAssertFalse(qemu.isUefiVariableResetRequested)
        XCTAssertFalse(qemu.hasPreloadedSecureBootKeys)
        XCTAssertTrue(qemu.hasTPMDevice)
    }

    func testRequestingTheVariableResetDoesNotPreloadKeysByItself() {
        var qemu = UTMQemuConfigurationQEMU()
        qemu.setUefiVariableResetRequested(true)
        XCTAssertTrue(qemu.isUefiVariableResetRequested)
        XCTAssertFalse(qemu.hasPreloadedSecureBootKeys)
    }

    func testSecureBootKeysNeedAResetAndATPM() {
        for (isReset, hasTPM) in [(false, false), (true, false), (false, true), (true, true)] {
            var qemu = UTMQemuConfigurationQEMU()
            qemu.isUefiVariableResetRequested = isReset
            qemu.hasTPMDevice = hasTPM
            XCTAssertEqual(qemu.canPreloadSecureBootKeys(for: system), isReset && hasTPM, "reset \(isReset), TPM \(hasTPM)")
        }
    }

    func testUefiIsSupportedOnlyWhereFirmwareShips() {
        let supported: Set<QEMUArchitecture> = [.arm, .aarch64, .i386, .x86_64, .loongarch64, .riscv64]
        for architecture in QEMUArchitecture.allCases {
            XCTAssertEqual(architecture.hasUefiSupport, supported.contains(architecture), "\(architecture)")
        }
    }

    func testPcAndQ35MachinesShareTheirDefaults() {
        XCTAssertTrue(QEMUTarget_x86_64.pc.isPcOrQ35Machine)
        XCTAssertTrue(QEMUTarget_x86_64.q35.isPcOrQ35Machine)
        XCTAssertTrue(QEMUTarget_i386.pc.isPcOrQ35Machine)
        XCTAssertFalse(QEMUTarget_x86_64.isapc.isPcOrQ35Machine)
        XCTAssertFalse(QEMUTarget_x86_64.microvm.isPcOrQ35Machine)
    }

    func testPS2ControllerIsOnlyForPcAndQ35Machines() {
        XCTAssertTrue(QEMUTarget_x86_64.pc.hasPS2ControllerSupport)
        XCTAssertTrue(QEMUTarget_x86_64.q35.hasPS2ControllerSupport)
        XCTAssertTrue(QEMUTarget_x86_64.pc_q35_2_10.hasPS2ControllerSupport)
        XCTAssertFalse(QEMUTarget_x86_64.isapc.hasPS2ControllerSupport)
        XCTAssertFalse(QEMUTarget_x86_64.microvm.hasPS2ControllerSupport)
        XCTAssertFalse(QEMUTarget_aarch64.virt.hasPS2ControllerSupport)
    }
}

// MARK: - Secure Boot support

extension UTMQemuConfigurationQEMUTests {
    /// riscv64 ships no Secure Boot variables image: adding a TPM there must not ask for
    /// one, or saving the VM fails copying a file that does not exist.
    @MainActor func testTPMOnAMachineWithoutSecureBootStillSaves() async throws {
        var system = UTMQemuConfigurationSystem()
        system.architecture = .riscv64
        system.target = QEMUTarget_riscv64.default
        var qemu = UTMQemuConfigurationQEMU(forArchitecture: system.architecture, target: system.target)
        XCTAssertTrue(qemu.hasUefiBoot)
        qemu.setTPMDevice(true, for: system)
        XCTAssertFalse(qemu.hasPreloadedSecureBootKeys)
        XCTAssertFalse(qemu.canPreloadSecureBootKeys(for: system))
        let dataURL = FileManager.default.temporaryDirectory.appendingPathComponent("QEMUTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: dataURL)
        }
        _ = try await qemu.saveData(to: dataURL, for: system)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dataURL.appendingPathComponent(QEMUPackageFileName.efiVariables.rawValue).path))
    }

    /// The wizard and a VM start that recreates missing variables set the key preload from
    /// the TPM directly; saving must still use the plain variables where Secure Boot is unsupported.
    @MainActor func testKeyPreloadIsIgnoredOnAMachineWithoutSecureBoot() async throws {
        var system = UTMQemuConfigurationSystem()
        system.architecture = .riscv64
        system.target = QEMUTarget_riscv64.default
        var qemu = UTMQemuConfigurationQEMU(forArchitecture: system.architecture, target: system.target)
        qemu.hasTPMDevice = true
        qemu.hasPreloadedSecureBootKeys = true
        let dataURL = FileManager.default.temporaryDirectory.appendingPathComponent("QEMUTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: dataURL)
        }
        _ = try await qemu.saveData(to: dataURL, for: system)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dataURL.appendingPathComponent(QEMUPackageFileName.efiVariables.rawValue).path))
    }
}
