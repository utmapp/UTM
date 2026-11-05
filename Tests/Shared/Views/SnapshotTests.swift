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
import SwiftUI
import XCTest
@testable import UTM

/// Pure content panels rendered offscreen and compared with the reference images under
/// `Tests/Fixtures/snapshots/` (see `SnapshotSupport`). Nothing here depends on a window,
/// a toolbar or an animation; a busy card, for example, is not snapshotted because its
/// spinner never looks the same twice.
@MainActor
final class SnapshotTests: XCTestCase {
    private var data: UTMData!

    override func setUp() {
        data = UTMData()
    }

    override func tearDown() {
        data = nil
    }

    private func wizard(_ os: VMWizardOS, name: String) -> VMWizardState {
        let state = VMWizardState()
        state.operatingSystem = os
        state.name = name
        state.storageSizeGib = 64
        state.systemMemoryMib = 4096
        state.systemCpuCount = 0
        // a machine whose name does not carry the QEMU version, so a dependency bump
        // does not change the picture
        state.systemArchitecture = .aarch64
        state.systemTarget = QEMUTarget_aarch64.virt_9_0
        return state
    }

    func testWizardSummaryForLinux() throws {
        let state = wizard(.Linux, name: "Linux VM")
        try assertSnapshot(of: VMWizardSummaryView(wizardState: state).environmentObject(data!), named: "wizard-summary-linux", size: CGSize(width: 600, height: 700))
    }

    func testWizardSummaryForWindows() throws {
        let state = wizard(.Windows, name: "Windows VM")
        state.isGuestToolsInstallRequested = true
        try assertSnapshot(of: VMWizardSummaryView(wizardState: state).environmentObject(data!), named: "wizard-summary-windows", size: CGSize(width: 600, height: 700))
    }

    func testWizardSummaryForAppleVirtualization() throws {
        let state = wizard(.Linux, name: "Apple VM")
        state.useVirtualization = true
        state.useAppleVirtualization = true
        try assertSnapshot(of: VMWizardSummaryView(wizardState: state).environmentObject(data!), named: "wizard-summary-apple", size: CGSize(width: 600, height: 700))
    }

    func testStoppedCard() throws {
        let vm = VMData(from: UTMRegistryEntry(uuid: UUID(), name: "Snapshot VM", path: "/tmp/Snapshot VM.utm"))
        try assertSnapshot(of: VMCardView(vm: vm).environmentObject(data!).padding(), named: "card-stopped", size: CGSize(width: 320, height: 70))
    }

    func testDetailsOfARegistryOnlyVM() throws {
        let vm = VMData(from: UTMRegistryEntry(uuid: UUID(), name: "Snapshot VM", path: "/tmp/Snapshot VM.utm"))
        try assertSnapshot(of: VMDetailsView(vm: vm).environmentObject(data!), named: "details-registry-only", size: CGSize(width: 700, height: 900))
    }
}
#endif
