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

/// The details page must render for a VM that only exists in the registry, such as one whose
/// files are missing or still loading (the class of crash fixed by f7c38dc5).
@MainActor
final class VMDetailsViewTests: XCTestCase {
    private var data: UTMData!

    override func setUp() {
        data = UTMData()
    }

    override func tearDown() {
        data = nil
    }

    /// Reaching the labels inside `Details` evaluates the whole page, including the
    /// accessors that read the configuration, for a VM that has none.
    func testDetailsRenderForARegistryOnlyVM() throws {
        let vm = VMData(from: .empty)
        let view = VMDetailsView(vm: vm).environmentObject(data!)
        XCTAssertNoThrow(try view.inspect().find(ViewType.View<Screenshot>.self))
        XCTAssertNoThrow(try view.inspect().find(text: "Architecture"))
        XCTAssertNoThrow(try view.inspect().find(text: "Machine"))
        XCTAssertNoThrow(try view.inspect().find(text: vm.stateLabel))
    }

    func testRemovedVMShowsAPlaceholder() throws {
        let vm = VMData(from: .empty)
        vm.isDeleted = true
        let view = VMDetailsView(vm: vm).environmentObject(data!)
        XCTAssertNoThrow(try view.inspect().find(text: "This virtual machine has been removed."))
        XCTAssertThrowsError(try view.inspect().find(text: "Architecture"))
    }
}
