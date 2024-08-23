//
// Copyright © 2024 osy. All rights reserved.
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

import TipKit

@available(iOS 17, macOS 14, *)
struct UTMTipDonate: Tip {
    @Parameter
    static var timesLaunched: Int = 0

    var title: Text {
        Text("Support UTM")
    }

    var message: Text? {
        Text("Enjoying the app? Consider making a donation to support development.")
    }

    var actions: [Action] {
        Action(id: "donate", title: "Donate")
        Action(id: "no-thanks", title: "No Thanks")
    }

    var rules: [Rule] {
        #Rule(Self.$timesLaunched) {
            $0 > 3
        }
    }
}

@available(iOS 17, macOS 14, *)
struct UTMTipHideToolbar: Tip {
    @Parameter
    static var didHideToolbar: Bool = true

    var title: Text {
        Text("Tap to hide/show toolbar")
    }

    var message: Text? {
        Text("When the toolbar is hidden, the icon will disappear after a few seconds. To show the icon again, tap anywhere on the screen.")
    }

    var rules: [Rule] {
        #Rule(Self.$didHideToolbar) {
            !$0
        }
    }
}

@available(iOS 17, macOS 14, *)
struct UTMTipCreateVM: Tip {
    @Parameter(.transient)
    static var isVMListEmpty: Bool = false

    var title: Text {
        Text("Start Here")
    }

    var message: Text? {
        Text("Create a new virtual machine or import an existing one.")
    }

    var rules: [Rule] {
        #Rule(Self.$isVMListEmpty) {
            $0
        }
    }
}
