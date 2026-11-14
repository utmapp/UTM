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

    /// Coming back to the hardware page keeps the machine the user picked: the macOS wizard
    /// builds a new page on every visit, which used to apply the default machine again.
    func testWizardKeepsTheMachineWhenComingBackToTheHardwarePage() {
        element(UTMAccessibilityID.Library.newVM).click()
        element(UTMAccessibilityID.Wizard.emulate).click()
        element(UTMAccessibilityID.Wizard.osOther).click()
        let arm64 = app.radioButtons["ARM64 virtual machine (2014, ARM64)"].firstMatch
        XCTAssertTrue(arm64.waitForExistence(timeout: 10), "the machine choices did not appear")
        arm64.click()
        element(UTMAccessibilityID.Wizard.continue).click()
        XCTAssertTrue(app.radioButtons["None"].firstMatch.waitForExistence(timeout: 10), "the boot page did not appear")
        element(UTMAccessibilityID.Wizard.back).click()
        XCTAssertTrue(arm64.waitForExistence(timeout: 10), "the hardware page did not come back")
        XCTAssertEqual((arm64.value as? NSNumber)?.boolValue, true, "the picked machine is no longer selected")
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
        // a click on the settings window's title bar closes the popover; Escape can reach the
        // settings window and close it too
        let settings = app.windows.containing(.any, identifier: UTMAccessibilityID.Settings.cancel).firstMatch
        settings.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01)).click()
        XCTAssertTrue(create.waitForNonExistence(timeout: 10), "the new drive popover did not close")
        element(UTMAccessibilityID.Settings.cancel).click()
    }

    /// A click on a port forward row selects it and a double click opens it (#7600: the
    /// double-click overlay on top of the table took every click outside its rightmost 40
    /// points, so a row could only be selected with the keyboard).
    func testClickingAPortForwardSelectsIt() {
        createVM(named: vmName)
        element(UTMAccessibilityID.Library.card(named: vmName), timeout: 30).click()
        element(UTMAccessibilityID.Details.edit).click()
        let network = app.outlines.buttons["Network"].firstMatch
        XCTAssertTrue(network.waitForExistence(timeout: 10), "the settings have no Network page")
        network.click()
        // the mode picker has no label of its own: find it by the default mode
        let mode = app.popUpButtons.matching(NSPredicate(format: "value == %@", "Shared Network")).firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 10), "the network page did not appear")
        mode.click()
        app.menuItems["Emulated VLAN"].firstMatch.click()
        let portForward = app.outlines.buttons["Port Forward"].firstMatch
        XCTAssertTrue(portForward.waitForExistence(timeout: 10), "the settings have no Port Forward page")
        portForward.click()
        let newButton = app.buttons["New…"].firstMatch
        XCTAssertTrue(newButton.waitForExistence(timeout: 10), "the port forward page did not appear")
        newButton.click()
        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 10), "the new port forward popover did not appear")
        // the fields in order: guest address, guest port, host address, host port
        let fields = popover.textFields
        XCTAssertTrue(fields.element(boundBy: 3).waitForExistence(timeout: 10), "the port fields did not appear")
        fields.element(boundBy: 1).click()
        fields.element(boundBy: 1).typeText("22")
        fields.element(boundBy: 3).click()
        fields.element(boundBy: 3).typeText("2222")
        popover.buttons["Save"].firstMatch.click()
        XCTAssertTrue(popover.waitForNonExistence(timeout: 10), "the new port forward popover did not close")
        // the table's row with the new host port
        let row = app.outlineRows.containing(NSPredicate(format: "value == %@", "2222")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the new port forward is not listed")
        let edit = app.buttons["Edit…"].firstMatch
        XCTAssertFalse(edit.exists, "a port forward was selected before the click")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).click()
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "clicking the port forward did not select it")
        // a double click opens the port forward for editing (macOS 13 and later); it is aimed
        // away from the first click so the two are not counted as one triple click
        if #available(macOS 13, *) {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).doubleClick()
            XCTAssertTrue(popover.buttons["Delete"].firstMatch.waitForExistence(timeout: 5), "double-clicking the port forward did not open it")
            // deleting it there also takes away the buttons for the selected row
            popover.buttons["Delete"].firstMatch.click()
            XCTAssertTrue(popover.waitForNonExistence(timeout: 10), "the port forward popover did not close")
            XCTAssertTrue(row.waitForNonExistence(timeout: 10), "the deleted port forward is still listed")
            XCTAssertTrue(edit.waitForNonExistence(timeout: 5), "Edit… is still shown for the deleted port forward")
        }
        element(UTMAccessibilityID.Settings.cancel).click()
    }
}
