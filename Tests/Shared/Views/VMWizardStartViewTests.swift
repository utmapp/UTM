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

/// The wizard's start page offers emulation whenever the build supports it.
@MainActor
final class VMWizardStartViewTests: XCTestCase {
    private var jitAvailable = Main.jitAvailable

    override func tearDown() {
        Main.jitAvailable = jitAvailable
    }

    private func button(_ title: String, in view: VMWizardStartView) throws -> InspectableView<ViewType.Button> {
        try view.inspect().find(ViewType.Button.self, containing: title)
    }

    /// Emulation does not depend on JIT being available at launch (87f47e24).
    func testEmulateButtonIsNotDisabledWithoutJit() throws {
        Main.jitAvailable = false
        let view = VMWizardStartView(wizardState: VMWizardState())
        XCTAssertFalse(try button("Emulate", in: view).isDisabled())
        Main.jitAvailable = true
        XCTAssertFalse(try button("Emulate", in: view).isDisabled())
    }

    func testEmulateButtonTurnsVirtualizationOff() throws {
        let state = VMWizardState()
        state.useVirtualization = true
        try button("Emulate", in: VMWizardStartView(wizardState: state)).tap()
        XCTAssertFalse(state.useVirtualization)
        XCTAssertEqual(state.currentPage, .operatingSystem)
    }
}
