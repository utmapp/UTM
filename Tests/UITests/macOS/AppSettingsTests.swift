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

/// Where things sit in the app settings window and the wizard on the macOS this runs on.
///
/// The flows elsewhere check that controls exist and work; these check their geometry, which
/// is where the layout regressions of past releases showed up.
final class VMLayoutTests: UTMUITestCase {
    private static let inset: CGFloat = 8

    /// Waits until the window's frame has been the same for three samples in a row, as it is
    /// once a pane has been swapped in and the window resized to it.
    private func waitForSettledFrame(of window: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        var frame = window.frame
        var same = 0
        for _ in 0..<40 {
            Thread.sleep(forTimeInterval: 0.25)
            let next = window.frame
            same = next == frame ? same + 1 : 0
            frame = next
            if same >= 2 {
                return
            }
        }
        XCTFail("the settings window kept changing its frame", file: file, line: line)
    }

    /// Every element of the snapshot, depth first.
    private func elements(of snapshot: XCUIElementSnapshot) -> [XCUIElementSnapshot] {
        [snapshot] + snapshot.children.flatMap { elements(of: $0) }
    }

    /// Every element of every pane of the app settings window lies within the window (#7117,
    /// #7319: a pane larger than the window had its edges cut off). The window is the
    /// sidebar one of macOS 26 and later; older releases show a tab view instead.
    func testEveryAppSettingsPaneFitsItsWindow() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)), "the settings window has a sidebar on macOS 26 and later only")
        app.typeKey(",", modifierFlags: .command)
        // SwiftUI's Settings scene names its window
        let window = app.windows["com_apple_SwiftUI_Settings_window"].firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "the settings window did not open")
        let rows = window.outlineRows.allElementsBoundByIndex
        XCTAssertGreaterThan(rows.count, 1, "the settings window has no sidebar rows")
        for row in rows {
            // the row itself is not hittable; its title is
            let title = row.staticTexts.firstMatch
            let pane = title.value as? String ?? row.label
            title.click()
            waitForSettledFrame(of: window)
            // kept with a failure, so that the cut-off pane can be seen
            let shot = XCTAttachment(screenshot: window.screenshot())
            shot.name = "settings-\(pane)"
            add(shot)
            let bounds = window.frame.insetBy(dx: -1, dy: -1)
            for element in elements(of: try window.snapshot()) where !element.frame.isEmpty {
                XCTAssertTrue(bounds.contains(element.frame), "\(pane): \(element.elementType.rawValue) '\(element.label)' at \(element.frame) lies outside the window \(window.frame)")
            }
        }
        window.buttons[XCUIIdentifierCloseWindow].click()
    }

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
