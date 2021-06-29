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

public class SettingsPage : BaseTest {
    
    override var rootElement: XCUIElement{
        return app.buttons["Information"]
    }
    //PageElements
    lazy var cancelButton = app.buttons["Cancel"]
    lazy var saveButton = app.buttons["Save"]
    
    lazy var informationButton = app.buttons["Information"]
    lazy var systemButton = app.buttons["System"]
    lazy var qemuButton = app.buttons["QEMU"]
    lazy var drivesButton = app.buttons["Drives"]
    lazy var displayButton = app.buttons["Display"]
    lazy var inputButton = app.buttons["Input"]
    lazy var networkButton = app.buttons["Network"]
    lazy var soundButton = app.buttons["Sound"]
    lazy var sharingButton = app.buttons["Sharing"]

    
    @discardableResult
    func tapCancel(completion: Completion=nil)-> Self{
        log("tap the cancel button")
        cancelButton.tap()
        return self
    }
    @discardableResult
    func tapSave(completion: Completion=nil)-> Self{
        log("tap the save button")
        saveButton.tap()
        return self
    }
    
    @discardableResult
    func tapInformation(completion: Completion=nil)-> Self{
        log("tap the information button")
        informationButton.tap()
        return self
    }
    
    @discardableResult
    func tapSystem(completion: Completion=nil)-> Self{
        log("tap the system button")
        systemButton.tap()
        return self
    }
    
    @discardableResult
    func tapQEMU(completion: Completion=nil)-> Self{
        log("tap the done button")
        qemuButton.tap()
        return self
    }
}

