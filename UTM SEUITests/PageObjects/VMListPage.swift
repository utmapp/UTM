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

public class VMListPage : BaseTest {
    
    override var rootElement: XCUIElement{
        return app.buttons["add"]
    }
    //PageElements
    lazy var addButton = app.buttons["add"]
    lazy var editButton = app.buttons["Edit"]
    lazy var doneButton = app.buttons["Done"]
    
    @discardableResult
    func tapAdd(completion: Completion=nil)-> Self{
        log("tap the add button")
        addButton.tap()
        return self
    }
    
    @discardableResult
    func tapEdit(completion: Completion=nil)-> Self{
        log("tap the edit button")
        editButton.tap()
        return self
    }
    
    @discardableResult
    func tapDone(completion: Completion=nil)-> Self{
        log("tap the done button")
        doneButton.tap()
        return self
    }
}
