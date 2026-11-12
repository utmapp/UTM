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

/// Geometry of the virtual machine creation wizard.
final class WizardLayoutTests: UTMUITestCase {
    private static let inset: CGFloat = 8

    /// The wizard summary's name field is inset from the edges of the scroll view that clips
    /// it, so that its focus ring is not cut off (a19d921c).
    func testWizardSummaryNameFieldIsInsetFromTheScrollEdges() {
        walkWizardToSummary()
        let name = app.textFields.matching(identifier: UTMAccessibilityID.Wizard.name).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "the name field did not appear")
        let scroll = app.scrollViews.containing(.textField, identifier: UTMAccessibilityID.Wizard.name).firstMatch
        XCTAssertTrue(scroll.exists, "the summary is not in a scroll view")
        XCTAssertGreaterThanOrEqual(scroll.frame.maxX - name.frame.maxX, Self.inset, "the name field \(name.frame) touches the trailing edge of \(scroll.frame)")
        XCTAssertGreaterThanOrEqual(name.frame.minY - scroll.frame.minY, Self.inset, "the name field \(name.frame) touches the top edge of \(scroll.frame)")
        element(UTMAccessibilityID.Wizard.cancel).click()
    }
}
