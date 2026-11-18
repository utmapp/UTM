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
    private let vmName = "Layout Test VM"

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

    /// The FPS Limit stepper and field of the Display settings pane line up with the Renderer
    /// Backend picker above them (#7702: the form lined up neither the stepper nor the field of
    /// that row with its columns). The row lines up through `LabeledContent`, new in macOS 13.
    func testAppSettingsNumberStepperLinesUpWithTheForm() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)), "number steppers line up with the form on macOS 13 and later only")
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows["com_apple_SwiftUI_Settings_window"].firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "the settings window did not open")
        // a sidebar row on macOS 26 and later, a toolbar tab before
        let row = window.outlineRows.allElementsBoundByIndex.first { ($0.staticTexts.firstMatch.value as? String) == "Display" }
        if let row = row {
            row.staticTexts.firstMatch.click()
        } else {
            window.toolbars.buttons["Display"].click()
        }
        let renderer = element(UTMAccessibilityID.AppSettings.rendererBackend)
        let stepper = element(UTMAccessibilityID.AppSettings.fpsLimit + ".stepper")
        let field = element(UTMAccessibilityID.AppSettings.fpsLimit)
        waitForSettledFrame(of: window)
        let shot = XCTAttachment(screenshot: window.screenshot())
        shot.name = "settings-display"
        add(shot)
        // controls start at the control column of a columns form, and end at the trailing edge of a grouped one
        let leading = abs(stepper.frame.minX - renderer.frame.minX) <= 1
        let trailing = abs(field.frame.maxX - renderer.frame.maxX) <= 1
        XCTAssertTrue(leading || trailing, "the FPS Limit stepper \(stepper.frame) and field \(field.frame) are not lined up with the Renderer Backend picker \(renderer.frame)")
        window.buttons[XCUIIdentifierCloseWindow].click()
    }

    /// Every element of every pane of a QEMU VM's settings lies between the sidebar and the
    /// trailing edge of the settings sheet when UTM runs in Russian, whose labels are among the
    /// longest (#7782: a long label made the Display and Input panes wider than the sheet, which
    /// cut off both of their sides). The VM has a drive, a network, a serial port and a sound
    /// card, so that each kind of pane is checked.
    func testEveryVmSettingsPaneFitsTheSheetWithLongLabels() throws {
        // creating the VM, relaunching in Russian and visiting every pane takes up to 105
        // seconds on a busy Mac, too close to the default allowance of two minutes
        executionTimeAllowance = 300
        // the wizard and the menu are driven by English labels; the panes are checked in Russian
        createVM(named: vmName)
        element(UTMAccessibilityID.Library.card(named: vmName), timeout: 30).click()
        element(UTMAccessibilityID.Details.edit).click()
        element(UTMAccessibilityID.Settings.addDevice).click()
        let serial = app.menuItems["Serial"].firstMatch
        XCTAssertTrue(serial.waitForExistence(timeout: 10), "the add device menu has no Serial item")
        serial.click()
        element(UTMAccessibilityID.Settings.save).click()
        XCTAssertTrue(app.sheets.firstMatch.waitForNonExistence(timeout: 30), "the settings sheet did not close")
        app.terminate()
        launch(language: "ru", locale: "ru_RU", reset: false)
        element(UTMAccessibilityID.Library.card(named: vmName), timeout: 30).click()
        element(UTMAccessibilityID.Details.edit).click()
        // the settings are a sheet on the main window, which has scroll views of its own
        let settings = app.sheets.firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "the settings sheet did not open")
        let rows = settings.outlineRows.allElementsBoundByIndex
        XCTAssertGreaterThan(rows.count, 8, "the settings sheet does not list every pane")
        var checked = 0
        var misplaced: [String] = []
        for row in rows {
            // a pane's row is a button; section headers have none, and the buttons that add a
            // device or a drive open a menu or a sheet instead of a pane
            let link = row.buttons.firstMatch
            guard link.exists && ![UTMAccessibilityID.Settings.addDevice, UTMAccessibilityID.Settings.newDrive, UTMAccessibilityID.Settings.importDrive].contains(link.identifier) else {
                continue
            }
            let name = link.label
            link.click()
            // the pane is swapped in once its row is selected; the sheet keeps its size
            let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: row)
            wait(for: [selected], timeout: 10)
            waitForSettledFrame(of: settings)
            // every pane of this VM goes through the shared scroll view (port forwarding, which
            // does not, is only listed for an emulated network)
            let pane = settings.scrollViews.matching(identifier: UTMAccessibilityID.Settings.pane).firstMatch
            guard pane.waitForExistence(timeout: 5) else {
                misplaced.append("\(name): the pane has no scroll view \(UTMAccessibilityID.Settings.pane)")
                continue
            }
            let sidebar = settings.scrollViews.containing(.outlineRow, identifier: nil).firstMatch
            XCTAssertTrue(sidebar.exists, "\(name): the sidebar is not in a scroll view")
            // kept with a failure, so that the cut-off pane can be seen
            let shot = XCTAttachment(screenshot: settings.screenshot())
            shot.name = "settings-ru-\(name)"
            add(shot)
            let minX = sidebar.frame.maxX - 1
            let maxX = settings.frame.maxX + 1
            // the first element out of place in each pane, so that one run names every pane that does not fit
            if let element = elements(of: try pane.snapshot()).first(where: { !$0.frame.isEmpty && ($0.frame.minX < minX || $0.frame.maxX > maxX) }) {
                misplaced.append("\(name): \(element.elementType.rawValue) '\(element.label)' at \(element.frame)")
            }
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 10, "too few panes were checked")
        XCTAssertTrue(misplaced.isEmpty, "not between the sidebar and the edge of the sheet \(settings.frame): \(misplaced.joined(separator: "; "))")
        element(UTMAccessibilityID.Settings.cancel).click()
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
