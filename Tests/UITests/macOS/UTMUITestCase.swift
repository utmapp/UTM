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

/// Launches the test build of UTM with empty defaults and documents.
///
/// The app is the macOS target built with the test bundle prefix, so it has its own
/// container; `-UTMTestReset` empties it and `-UTMTestMode` keeps the release notes, the
/// server and screenshots out of the way. The app runs in English, since the few controls
/// without an identifier are found by their label.
class UTMUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // the app this bundle targets: always the build under test, never an installed copy
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-UTMTestMode", "YES", "-UTMTestReset", "YES"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    /// The first element with this accessibility identifier, once it exists.
    @discardableResult
    func element(_ identifier: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(identifier) did not appear", file: file, line: line)
        return element
    }

    /// Whether an element with this identifier is on screen right now.
    func exists(_ identifier: String) -> Bool {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists
    }

    /// A button of the alert or confirmation sheet in front, by label.
    ///
    /// Alerts and confirmation dialogs are sheets on macOS; querying the whole app for a
    /// label would also match toolbar buttons and Touch Bar items of the same name.
    func dialogButton(_ label: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: timeout), "no sheet appeared for the \(label) button", file: file, line: line)
        let button = sheet.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "the sheet has no \(label) button", file: file, line: line)
        return button
    }

    /// Walks the wizard for an emulated QEMU VM with no boot image up to its summary page.
    func walkWizardToSummary() {
        element(UTMAccessibilityID.Library.newVM).click()
        element(UTMAccessibilityID.Wizard.emulate).click()
        element(UTMAccessibilityID.Wizard.osOther).click()
        element(UTMAccessibilityID.Wizard.continue).click()
        // the boot page: no boot image
        let none = app.radioButtons["None"].firstMatch
        XCTAssertTrue(none.waitForExistence(timeout: 10), "boot device choices did not appear")
        none.click()
        element(UTMAccessibilityID.Wizard.continue).click()
        element(UTMAccessibilityID.Wizard.storageSize)
        element(UTMAccessibilityID.Wizard.continue).click()
        element(UTMAccessibilityID.Wizard.continue).click()
    }

    /// Walks the wizard to create a QEMU VM with no boot image and the given name.
    func createVM(named name: String) {
        walkWizardToSummary()
        let nameField = element(UTMAccessibilityID.Wizard.name)
        nameField.click()
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText(name)
        element(UTMAccessibilityID.Wizard.save).click()
    }
}
