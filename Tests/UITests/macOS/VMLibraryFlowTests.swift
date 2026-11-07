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

/// Flows through the library, the wizard and the settings window, without starting a VM.
final class VMLibraryFlowTests: UTMUITestCase {
    private let vmName = "UI Test VM"

    func testCreatingAVmThroughTheWizardShowsItInTheLibraryAndItsDetails() {
        createVM(named: vmName)
        element(UTMAccessibilityID.Library.card(named: vmName), timeout: 30).click()
        // selecting the VM shows its details (f7c38dc5 crashed here)
        XCTAssertTrue(app.staticTexts["Architecture"].firstMatch.waitForExistence(timeout: 10))
        element(UTMAccessibilityID.Details.delete).click()
        dialogButton("Delete").click()
        let card = app.descendants(matching: .any).matching(identifier: UTMAccessibilityID.Library.card(named: vmName)).firstMatch
        XCTAssertTrue(card.waitForNonExistence(timeout: 30), "the VM is still listed after deletion")
    }

    /// A failed create reports its error (dfb8fdb5): here a second VM with the same name.
    func testCreatingAVmWithAnExistingNameShowsAnError() {
        createVM(named: vmName)
        element(UTMAccessibilityID.Library.card(named: vmName), timeout: 30)
        createVM(named: vmName)
        let message = app.staticTexts["An existing virtual machine already exists with this name."].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 30), "no error was shown for the duplicate name")
        dialogButton("OK").click()
    }

    /// The Emulate choice does not depend on JIT being available at launch (87f47e24).
    func testWizardOffersEmulation() {
        element(UTMAccessibilityID.Library.newVM).click()
        XCTAssertTrue(element(UTMAccessibilityID.Wizard.emulate).isEnabled)
        element(UTMAccessibilityID.Wizard.cancel).click()
    }

    /// The settings window's Save and Cancel are reachable, in the detail column right of the
    /// sidebar (a1e1087f: the toolbar spanned the sidebar too and the buttons ended up off-screen).
    func testSettingsSaveAndCancelAreReachable() {
        createVM(named: vmName)
        element(UTMAccessibilityID.Library.card(named: vmName), timeout: 30).click()
        element(UTMAccessibilityID.Details.edit).click()
        let sidebarRow = element(UTMAccessibilityID.Settings.information)
        let save = element(UTMAccessibilityID.Settings.save)
        let cancel = element(UTMAccessibilityID.Settings.cancel)
        XCTAssertTrue(save.isHittable)
        XCTAssertTrue(cancel.isHittable)
        XCTAssertGreaterThanOrEqual(cancel.frame.minX, sidebarRow.frame.maxX, "Cancel \(cancel.frame) is not right of the sidebar \(sidebarRow.frame)")
        XCTAssertGreaterThanOrEqual(save.frame.minX, sidebarRow.frame.maxX, "Save \(save.frame) is not right of the sidebar \(sidebarRow.frame)")
        cancel.click()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
    }

    /// A huge drive size does not crash the app (8c18e750).
    func testHugeDriveSizeDoesNotCrash() {
        createVM(named: vmName)
        element(UTMAccessibilityID.Library.card(named: vmName), timeout: 30).click()
        element(UTMAccessibilityID.Details.edit).click()
        element(UTMAccessibilityID.Settings.newDrive).click()
        let size = element(UTMAccessibilityID.Drive.size)
        size.click()
        size.typeKey("a", modifierFlags: .command)
        size.typeText("99999999999999999999\t")
        XCTAssertEqual(app.state, .runningForeground)
        let create = element(UTMAccessibilityID.Drive.create)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(create.waitForNonExistence(timeout: 10), "the new drive popover did not close")
        element(UTMAccessibilityID.Settings.cancel).click()
    }
}
