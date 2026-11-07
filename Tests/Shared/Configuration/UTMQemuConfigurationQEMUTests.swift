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
    func testAddingATPMResetsUefiVariablesAndPreloadsSecureBootKeys() {
        var qemu = UTMQemuConfigurationQEMU()
        qemu.setTPMDevice(true)
        XCTAssertTrue(qemu.hasTPMDevice)
        XCTAssertTrue(qemu.isUefiVariableResetRequested)
        XCTAssertTrue(qemu.hasPreloadedSecureBootKeys)
    }

    func testRemovingTheTPMDropsTheKeyPreloadButKeepsTheResetRequest() {
        var qemu = UTMQemuConfigurationQEMU()
        qemu.setTPMDevice(true)
        qemu.setTPMDevice(false)
        XCTAssertFalse(qemu.hasTPMDevice)
        XCTAssertTrue(qemu.isUefiVariableResetRequested)
        XCTAssertFalse(qemu.hasPreloadedSecureBootKeys)
    }

    func testCancellingTheVariableResetDropsTheKeyPreload() {
        var qemu = UTMQemuConfigurationQEMU()
        qemu.setTPMDevice(true)
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
            XCTAssertEqual(qemu.canPreloadSecureBootKeys, isReset && hasTPM, "reset \(isReset), TPM \(hasTPM)")
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
