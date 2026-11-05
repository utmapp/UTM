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

/// A VM name is a single line, in the settings and in the wizard (e269ade9, #5627).
@MainActor
final class VMNameFieldTests: XCTestCase {
    private var data: UTMData!

    override func setUp() {
        data = UTMData()
    }

    override func tearDown() {
        data = nil
    }

    private func nameField(in view: InspectableView<ViewType.ClassifiedView>) throws -> InspectableView<ViewType.TextField> {
        try view.find(ViewType.TextField.self, where: { try $0.labelView().text().string() == "Name" })
    }

    func testSettingsNameFieldIsSingleLine() throws {
        var info = UTMConfigurationInfo()
        info.name = "Test"
        let view = VMConfigInfoView(config: Binding(get: { info }, set: { info = $0 }))
        XCTAssertEqual(try nameField(in: view.inspect()).lineLimit(), 1)
    }

    func testWizardNameFieldIsSingleLine() throws {
        let state = VMWizardState()
        state.name = "Test"
        let view = VMWizardSummaryView(wizardState: state).environmentObject(data!)
        XCTAssertEqual(try nameField(in: view.inspect()).lineLimit(), 1)
    }
}
