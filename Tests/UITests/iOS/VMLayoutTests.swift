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

import UIKit
import XCTest

/// Where things sit on the iOS this runs on; the sheet tests need an iPad, where a
/// regular-width sheet lays out differently from an iPhone's.
final class VMLayoutTests: UTMUITestCase {
    /// The settings sheet is a single column: its rows span the sheet instead of sitting in
    /// a sidebar next to an empty detail column (11d5fdfc, on an iPad or an open iPhone Duo).
    func testSettingsSheetIsASingleColumn() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "a compact-width sheet is always a single column")
        element(UTMAccessibilityID.Library.settings).tap()
        // the sheet's navigation bar is the last one; its rows are the cells below it
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10), "the settings sheet has no rows")
        let bar = app.navigationBars.element(boundBy: app.navigationBars.count - 1)
        let row = app.cells.allElementsBoundByIndex.first { $0.frame.minY >= bar.frame.maxY && abs($0.frame.midX - bar.frame.midX) < bar.frame.width / 2 }
        guard let row = row else {
            return XCTFail("no row below the sheet's navigation bar \(bar.frame)")
        }
        let width = app.windows.firstMatch.frame.width
        // a sidebar column takes about a third of its container; a single column, nearly all of it
        XCTAssertGreaterThan(row.frame.width, min(width, 540) * 0.75, "the settings row \(row.frame) is narrower than a single column in a \(width) wide window")
    }
}
