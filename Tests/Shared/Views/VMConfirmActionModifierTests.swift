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

/// The confirmation alerts of the swipe-safe path: cancel first, the destructive action second
/// (2d468299).
@MainActor
final class VMConfirmActionModifierTests: XCTestCase {
    private var data: UTMData!
    private var confirmed: [ConfirmAction] = []

    override func setUp() {
        data = UTMData()
        confirmed = []
    }

    override func tearDown() {
        data = nil
    }

    private func alert(for action: ConfirmAction) throws -> InspectableView<ViewType.Alert> {
        var current: ConfirmAction? = action
        let modifier = VMConfirmActionModifier(confirmAction: Binding(get: { current }, set: { current = $0 }), workaroundSwipeBug: true) { self.confirmed.append($0) }
        let view = EmptyView().modifier(modifier).environmentObject(data!)
        return try view.inspect().emptyView().modifier(VMConfirmActionModifier.self).viewModifierContent().alert()
    }

    func testDeleteAsksFirstAndIsNotThePrimaryButton() throws {
        let alert = try alert(for: .confirmDeleteVM(vm: VMData(from: .empty)))
        XCTAssertEqual(try alert.title().string(), "Do you want to delete this VM and all its data?")
        XCTAssertEqual(try alert.primaryButton().style(), .cancel)
        XCTAssertEqual(try alert.secondaryButton().style(), .destructive)
        XCTAssertEqual(try alert.secondaryButton().labelView().string(), "Delete")
    }

    func testStopAsksFirstAndIsNotThePrimaryButton() throws {
        let alert = try alert(for: .confirmStopVM(vm: VMData(from: .empty)))
        XCTAssertEqual(try alert.primaryButton().style(), .cancel)
        XCTAssertEqual(try alert.secondaryButton().style(), .destructive)
        XCTAssertEqual(try alert.secondaryButton().labelView().string(), "Stop")
    }

    func testCopyIsNotDestructive() throws {
        let vm = VMData(from: .empty)
        let alert = try alert(for: .confirmCloneVM(vm: vm))
        // a VM that only exists in the registry is a shortcut, which is copied into internal storage
        XCTAssertTrue(vm.isShortcut)
        XCTAssertEqual(try alert.title().string(), "Do you want to copy this VM and all its data to internal storage?")
        XCTAssertEqual(try alert.primaryButton().style(), .cancel)
        XCTAssertEqual(try alert.secondaryButton().style(), .default)
        XCTAssertEqual(try alert.secondaryButton().labelView().string(), "Copy")
    }

    func testMoveConfirmsWithoutTouchingAnything() throws {
        let vm = VMData(from: .empty)
        let alert = try alert(for: .confirmMoveVM(vm: vm))
        try alert.secondaryButton().tap()
        XCTAssertEqual(confirmed, [.confirmMoveVM(vm: vm)])
    }
}
