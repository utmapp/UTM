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

/// The rules behind the serial port settings, for both backends.
final class UTMConfigurationSerialTests: XCTestCase {
    // MARK: - QEMU

    func testSwitchingToTheBuiltInTerminalCreatesTerminalSettings() {
        var serial = UTMQemuConfigurationSerial()
        serial.terminal = nil
        serial.setMode(.builtin)
        XCTAssertEqual(serial.mode, .builtin)
        XCTAssertNotNil(serial.terminal)
    }

    func testSwitchingToTheBuiltInTerminalKeepsExistingTerminalSettings() {
        var serial = UTMQemuConfigurationSerial()
        serial.terminal?.fontSize = 20
        serial.setMode(.tcpServer)
        serial.setMode(.builtin)
        XCTAssertEqual(serial.terminal?.fontSize, 20)
    }

    func testOtherModesDoNotCreateTerminalSettings() {
        for mode in QEMUSerialMode.allCases where mode != .builtin {
            var serial = UTMQemuConfigurationSerial()
            serial.terminal = nil
            serial.setMode(mode)
            XCTAssertEqual(serial.mode, mode)
            XCTAssertNil(serial.terminal, "\(mode)")
        }
    }

    /// A config.plist with the built-in terminal and no terminal settings (edited by
    /// hand or by another tool) must still decode with settings: the terminal window
    /// unwraps them.
    func testBuiltInTerminalDecodedWithoutSettingsGetsDefaults() throws {
        let plist = try PropertyListSerialization.data(fromPropertyList: ["Mode": "Terminal", "Target": "Auto"], format: .xml, options: 0)
        let serial = try PropertyListDecoder().decode(UTMQemuConfigurationSerial.self, from: plist)
        XCTAssertEqual(serial.mode, .builtin)
        XCTAssertNotNil(serial.terminal)
    }

    func testOtherModesDecodedWithoutSettingsGetNoTerminal() throws {
        let plist = try PropertyListSerialization.data(fromPropertyList: ["Mode": "TcpServer", "Target": "Auto"], format: .xml, options: 0)
        let serial = try PropertyListDecoder().decode(UTMQemuConfigurationSerial.self, from: plist)
        XCTAssertNil(serial.terminal)
    }

    func testManualDeviceIsAcceptedWhenTheArchitectureHasSerialDevices() {
        var serial = UTMQemuConfigurationSerial()
        XCTAssertFalse(QEMUArchitecture.x86_64.serialDeviceType.allRawValues.isEmpty)
        XCTAssertTrue(serial.setTarget(.manualDevice, for: .x86_64))
        XCTAssertEqual(serial.target, .manualDevice)
    }

    func testManualDeviceFallsBackToAutomaticWithoutSerialDevices() {
        var serial = UTMQemuConfigurationSerial()
        serial.target = .gdb
        XCTAssertTrue(QEMUArchitecture.avr.serialDeviceType.allRawValues.isEmpty)
        XCTAssertFalse(serial.setTarget(.manualDevice, for: .avr))
        XCTAssertEqual(serial.target, .autoDevice)
    }

    func testOtherTargetsNeedNoSerialDevices() {
        for target in [QEMUSerialTarget.autoDevice, .gdb, .monitor] {
            var serial = UTMQemuConfigurationSerial()
            XCTAssertTrue(serial.setTarget(target, for: .avr), "\(target)")
            XCTAssertEqual(serial.target, target)
        }
    }

    #if os(macOS)
    // MARK: - Apple Virtualization

    func testAppleSwitchingToTheBuiltInTerminalCreatesTerminalSettings() {
        var serial = UTMAppleConfigurationSerial()
        serial.terminal = nil
        serial.setMode(.builtin)
        XCTAssertEqual(serial.mode, .builtin)
        XCTAssertNotNil(serial.terminal)
    }

    func testAppleSwitchingToTheBuiltInTerminalKeepsExistingTerminalSettings() {
        var serial = UTMAppleConfigurationSerial()
        serial.terminal?.fontSize = 20
        serial.setMode(.ptty)
        serial.setMode(.builtin)
        XCTAssertEqual(serial.terminal?.fontSize, 20)
    }

    func testAppleBuiltInTerminalDecodedWithoutSettingsGetsDefaults() throws {
        let plist = try PropertyListSerialization.data(fromPropertyList: ["Mode": "Terminal"], format: .xml, options: 0)
        let serial = try PropertyListDecoder().decode(UTMAppleConfigurationSerial.self, from: plist)
        XCTAssertEqual(serial.mode, .builtin)
        XCTAssertNotNil(serial.terminal)
    }

    func testApplePttyDoesNotCreateTerminalSettings() {
        var serial = UTMAppleConfigurationSerial()
        serial.terminal = nil
        serial.setMode(.ptty)
        XCTAssertEqual(serial.mode, .ptty)
        XCTAssertNil(serial.terminal)
    }
    #endif
}
