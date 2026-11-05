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

/// Launches the test build of UTM on the simulator with empty defaults and documents.
///
/// The app is the iOS target built with the test bundle prefix; `-UTMTestReset` empties its
/// container and `-UTMTestMode` keeps the release notes and screenshots out of the way. The
/// app runs in English, since the few controls without an identifier are found by their label.
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

    /// A button of the alert or action sheet in front, by label.
    ///
    /// Confirmations are action sheets on an iPhone and popovers on an iPad; errors are alerts.
    /// Querying the whole app for a label would also match toolbar buttons of the same name.
    func dialogButton(_ label: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let dialog = app.descendants(matching: .any).matching(NSPredicate(format: "elementType == %d OR elementType == %d OR elementType == %d", XCUIElement.ElementType.sheet.rawValue, XCUIElement.ElementType.alert.rawValue, XCUIElement.ElementType.popover.rawValue)).firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: timeout), "no dialog appeared for the \(label) button", file: file, line: line)
        let button = dialog.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "the dialog has no \(label) button", file: file, line: line)
        return button
    }

    /// Returns from the details of a VM to the library; an iPhone pushes the details, an
    /// iPad shows them next to the list.
    func backToLibrary() {
        let back = app.navigationBars.buttons["BackButton"].firstMatch
        if back.waitForExistence(timeout: 2) {
            back.tap()
        }
    }

    /// Walks the wizard to create a QEMU VM with no boot image and the given name, and
    /// taps Save.
    func saveVM(named name: String) {
        element(UTMAccessibilityID.Library.newVM).tap()
        element(UTMAccessibilityID.Wizard.emulate).tap()
        element(UTMAccessibilityID.Wizard.osOther).tap()
        element(UTMAccessibilityID.Wizard.continue).tap()
        // the boot page: the inline boot device picker's "None" row (the picker itself has
        // no element of its own on iOS)
        let none = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'None'")).firstMatch
        XCTAssertTrue(none.waitForExistence(timeout: 10), "the boot device choices did not appear")
        none.tap()
        element(UTMAccessibilityID.Wizard.continue).tap()
        element(UTMAccessibilityID.Wizard.storageSize)
        element(UTMAccessibilityID.Wizard.continue).tap()
        element(UTMAccessibilityID.Wizard.continue).tap()
        let nameField = element(UTMAccessibilityID.Wizard.name)
        nameField.tap()
        nameField.clearText()
        nameField.typeText(name)
        element(UTMAccessibilityID.Wizard.save).tap()
    }

    /// Creates a QEMU VM with no boot image and the given name; the app then shows the
    /// new VM's details.
    func createVM(named name: String) {
        saveVM(named: name)
        element(UTMAccessibilityID.Details.edit, timeout: 30)
    }
}

extension XCUIElement {
    /// Deletes the text of a focused text field.
    func clearText() {
        guard let value = value as? String, !value.isEmpty else {
            return
        }
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
    }
}
