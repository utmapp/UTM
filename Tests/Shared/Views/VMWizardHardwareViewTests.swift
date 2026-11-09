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


import SwiftUI
import ViewInspector
import XCTest
@testable import UTM

/// The wizard's hardware page. On macOS the wizard builds a new page every time it is
/// shown, so anything the page keeps for itself is lost when the user comes back to it.
@MainActor
final class VMWizardHardwareViewTests: XCTestCase {
    /// Shows the page as the wizard does when it is visited: a new view, then its
    /// `onAppear`, which sits on the page's content view.
    private func visitHardwarePage(_ state: VMWizardState) throws {
        _ = try VMWizardHardwareView(wizardState: state).inspect().find { view in
            (try? view.callOnAppear()) != nil
        }
    }

    func testFirstVisitAppliesTheDefaultMachine() throws {
        let state = VMWizardState()
        state.operatingSystem = .Linux
        try visitHardwarePage(state)
        XCTAssertEqual(state.systemTarget.rawValue, QEMUTarget_x86_64.q35.rawValue)
    }

    /// Going on to the drives and back must keep the machine, memory and storage the user chose.
    func testComingBackKeepsTheUsersChoices() throws {
        let state = VMWizardState()
        state.operatingSystem = .Linux
        try visitHardwarePage(state)
        state.applyMachine(.arm64Virt)
        state.systemMemoryMib = 3072
        state.storageSizeGib = 80
        try visitHardwarePage(state)
        XCTAssertEqual(state.systemArchitecture, .aarch64)
        XCTAssertEqual(state.systemTarget.rawValue, QEMUTarget_aarch64.virt.rawValue)
        XCTAssertEqual(state.systemMemoryMib, 3072)
        XCTAssertEqual(state.storageSizeGib, 80)
    }

    /// Another operating system has other machines: the page starts over on its default.
    func testAnotherOperatingSystemStartsOverOnItsDefault() throws {
        let state = VMWizardState()
        state.operatingSystem = .Linux
        try visitHardwarePage(state)
        state.applyMachine(.riscv64Virt)
        state.isExpertMode = true
        state.operatingSystem = .Windows
        try visitHardwarePage(state)
        XCTAssertFalse(state.isExpertMode)
        XCTAssertEqual(state.selectedMachine, .q35)
        XCTAssertEqual(state.systemTarget.rawValue, QEMUTarget_x86_64.q35.rawValue)
    }

    /// Picking the same operating system again keeps the choices.
    func testTheSameOperatingSystemKeepsTheChoices() throws {
        let state = VMWizardState()
        state.operatingSystem = .Linux
        try visitHardwarePage(state)
        state.applyMachine(.arm64Virt)
        state.operatingSystem = .Linux
        try visitHardwarePage(state)
        XCTAssertEqual(state.selectedMachine, .arm64Virt)
    }

    /// Emulating after virtualizing does not keep the expert view that virtualization forces.
    func testEmulatingAfterVirtualizingStartsOverOnTheMachines() throws {
        let state = VMWizardState()
        state.operatingSystem = .Linux
        state.useVirtualization = true
        try visitHardwarePage(state)
        XCTAssertTrue(state.isExpertMode)
        state.useVirtualization = false
        try visitHardwarePage(state)
        XCTAssertFalse(state.isExpertMode)
        XCTAssertEqual(state.selectedMachine, .q35)
    }

    /// Another architecture picked in expert mode is no longer the machine picked before,
    /// whose limits would otherwise still clamp the memory.
    func testExpertArchitectureClearsThePickedMachine() throws {
        let state = VMWizardState()
        state.operatingSystem = .ClassicMacOS
        try visitHardwarePage(state)
        XCTAssertEqual(state.selectedMachine, .powerMacG4)
        state.isExpertMode = true
        state.setSystemArchitecture(.x86_64)
        XCTAssertNil(state.selectedMachine)
    }
}
