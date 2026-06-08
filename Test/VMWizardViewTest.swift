import XCTest

final class VMWizardViewTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
   
    @MainActor
    func testClickExitButton() throws {
        // Launch the application
        let app = XCUIApplication()
        app.launch()
        
        // Wait for the window to appear
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should appear")
        
        // Find and click the close button (red button in top-left corner)
        let closeButton = window.buttons[XCUIIdentifierCloseWindow]
        XCTAssertTrue(closeButton.exists, "Close button should exist")
        
        // Click the close button to exit
        closeButton.click()
        
        // Verify the app or window is closed
        XCTAssertFalse(window.exists, "Window should be closed after clicking close button")
    }
}
