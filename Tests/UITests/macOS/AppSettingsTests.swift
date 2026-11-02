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

#if UTM_UI_TESTS
/// Geometry of the app-wide settings panes in the running macOS app.
final class AppSettingsTests: UTMUITestCase {
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
    /// #7319: a pane larger than the window had its edges cut off).
    func testEveryAppSettingsPaneFitsItsWindow() throws {
        app.typeKey(",", modifierFlags: .command)
        // SwiftUI's Settings scene names its window
        let window = app.windows["com_apple_SwiftUI_Settings_window"].firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "the settings window did not open")
        let toolbar = window.toolbars.firstMatch
        XCTAssertTrue(toolbar.waitForExistence(timeout: 10), "the settings toolbar did not appear")
        let tabs = toolbar.buttons.allElementsBoundByIndex
        XCTAssertEqual(tabs.count, 7, "the settings toolbar does not contain every pane")
        for tab in tabs {
            let pane = tab.label
            tab.click()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "title == %@", pane), object: window)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed, "\(pane) did not become selected")
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
}
#else
@MainActor
final class AppSettingsTests: XCTestCase {
}
#endif
