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

class Logger {
    func log(_ mlog: String) {
        NSLog(mlog)
    }
}

public class BaseTest {
    typealias Completion = (()-> Void)?
    let app = XCUIApplication()
    let log = Logger().log
    required init(timeout: TimeInterval = 10, completion: Completion = nil){
        log("waiting \(timeout)s for \(String(describing: self)) existence")
        XCTAssert(rootElement.waitForExistence(timeout: timeout),
                  "Page \(String(describing: self)) waited, but not loaded")
        completion?()
    }
    var rootElement: XCUIElement {
        fatalError("Subclass should override rootElement")
    }
    
    // Button
    func button(_ name:String)->XCUIElement {
        return app.buttons[name]
    }

    // Navigation Bar
    func navBar(_ name:String)->XCUIElement {
        return app.navigationBars[name]
    }

    // SecureField
    func secureField(_ name:String)->XCUIElement {
        return app.secureTextFields[name]
    }

    // TextField
    func textField(_ name:String)->XCUIElement {
        return app.textFields[name]
    }

    // TextView
    func textView(_ name:String)->XCUIElement {
        return app.textViews[name]
    }

    // Text
    func text(_ name:String)->XCUIElement {
        return app.staticTexts[name]
    }

}
