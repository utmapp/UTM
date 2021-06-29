//
// Copyright © 2021 osy. All rights reserved.
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

class UTM_SEUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testConfiguringVM() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        let tablesQuery = app.tables
        app.navigationBars["UTM SE"].buttons["add"].tap()
        
        try configureVM(app: app, tables: tablesQuery, configuration: 1)
        


        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func configureVM(app: XCUIElement, tables: XCUIElementQuery, configuration: Int) throws {
        
        
        tables.buttons["Information"].tap()
        app.navigationBars["Information"].buttons["Settings"].tap()
        
        tables/*@START_MENU_TOKEN@*/.buttons["System"]/*[[".cells[\"System\"].buttons[\"System\"]",".buttons[\"System\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        tables/*@START_MENU_TOKEN@*/.sliders["0.235"].press(forDuration: 1.7);/*[[".cells[\"MB\"].sliders[\"0.235\"]",".tap()",".press(forDuration: 1.7);",".sliders[\"0.235\"]"],[[[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0,0]]@END_MENU_TOKEN@*/
//        app.navigationBars["System"].buttons["Settings"].tap()
//        tablesQuery/*@START_MENU_TOKEN@*/.buttons["QEMU"]/*[[".cells[\"QEMU\"].buttons[\"QEMU\"]",".buttons[\"QEMU\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
//        tablesQuery/*@START_MENU_TOKEN@*/.switches["Debug Logging"]/*[[".cells[\"Debug Logging\"].switches[\"Debug Logging\"]",".switches[\"Debug Logging\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
//        app.navigationBars["QEMU"].buttons["Settings"].tap()
//        tablesQuery/*@START_MENU_TOKEN@*/.buttons["Drives"]/*[[".cells[\"Drives\"].buttons[\"Drives\"]",".buttons[\"Drives\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
//        app.navigationBars["Drives"].buttons["New Drive"].tap()
//        app.navigationBars["_TtGC7SwiftUI19UIHosting"].buttons["Done"].tap()
//        tablesQuery/*@START_MENU_TOKEN@*/.buttons["disk-0.qcow2, disk, -, ide"]/*[[".cells[\"disk-0.qcow2, disk, -, ide\"].buttons[\"disk-0.qcow2, disk, -, ide\"]",".buttons[\"disk-0.qcow2, disk, -, ide\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
//        tablesQuery/*@START_MENU_TOKEN@*/.buttons["Image Type"]/*[[".cells[\"Image Type\"].buttons[\"Image Type\"]",".buttons[\"Image Type\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
//        tablesQuery/*@START_MENU_TOKEN@*/.buttons["CD/DVD (ISO) Image"]/*[[".cells[\"CD\/DVD (ISO) Image\"].buttons[\"CD\/DVD (ISO) Image\"]",".buttons[\"CD\/DVD (ISO) Image\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
//        tablesQuery/*@START_MENU_TOKEN@*/.buttons["Interface"]/*[[".cells[\"Interface\"].buttons[\"Interface\"]",".buttons[\"Interface\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
