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

/// Flows through the library, the wizard and the settings sheet on iOS, without starting a VM.
final class VMLibraryFlowTests: UTMUITestCase {
    private let vmName = "UI Test VM"

    func testCreatingAVmThroughTheWizardShowsItInTheLibraryAndItsDetails() {
        createVM(named: vmName)
        // the new VM's details (f7c38dc5 crashed here)
        XCTAssertTrue(app.staticTexts["Architecture"].firstMatch.waitForExistence(timeout: 10))
        backToLibrary()
        element(UTMAccessibilityID.Library.card(named: vmName), timeout: 30).tap()
        element(UTMAccessibilityID.Details.delete).tap()
        dialogButton("Delete").tap()
        backToLibrary()
        let card = app.descendants(matching: .any).matching(identifier: UTMAccessibilityID.Library.card(named: vmName)).firstMatch
        XCTAssertTrue(card.waitForNonExistence(timeout: 30), "the VM is still listed after deletion")
    }

    /// A failed create reports its error (dfb8fdb5): here a second VM with the same name.
    func testCreatingAVmWithAnExistingNameShowsAnError() {
        createVM(named: vmName)
        backToLibrary()
        element(UTMAccessibilityID.Library.card(named: vmName), timeout: 30)
        saveVM(named: vmName)
        let message = app.staticTexts["An existing virtual machine already exists with this name."].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 30), "no error was shown for the duplicate name")
        dialogButton("OK").tap()
    }

    /// The Emulate choice does not depend on JIT being available at launch (87f47e24).
    func testWizardOffersEmulation() {
        element(UTMAccessibilityID.Library.newVM).tap()
        XCTAssertTrue(element(UTMAccessibilityID.Wizard.emulate).isEnabled)
        element(UTMAccessibilityID.Wizard.cancel).tap()
    }

    /// The settings sheet's Save and Cancel are reachable.
    func testSettingsSaveAndCancelAreReachable() {
        createVM(named: vmName)
        element(UTMAccessibilityID.Details.edit).tap()
        let save = element(UTMAccessibilityID.Settings.save)
        let cancel = element(UTMAccessibilityID.Settings.cancel)
        XCTAssertTrue(save.isHittable)
        XCTAssertTrue(cancel.isHittable)
        cancel.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
    }

    /// A huge drive size does not crash the app (8c18e750).
    func testHugeDriveSizeDoesNotCrash() {
        createVM(named: vmName)
        element(UTMAccessibilityID.Details.edit).tap()
        element(UTMAccessibilityID.Settings.newDrive).tap()
        // SwiftUI gives the field's label the same identifier, so ask for the text field
        let field = app.textFields.matching(identifier: UTMAccessibilityID.Drive.size).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the size field did not appear")
        field.tap()
        field.typeText("99999999999999999999")
        // the number pad has no Return key: moving to the unit button commits the value
        element(UTMAccessibilityID.Drive.sizeUnit).tap()
        XCTAssertEqual(app.state, .runningForeground)
        element(UTMAccessibilityID.Drive.cancel).tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "the new drive sheet did not close")
        element(UTMAccessibilityID.Settings.cancel).tap()
    }
}
