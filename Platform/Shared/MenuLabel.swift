//
// Copyright © 2022 osy. All rights reserved.
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

import SwiftUI

struct MenuLabel: View {
    private let label: Label<Text, Image>
    
    init(_ titleKey: LocalizedStringKey, systemImage name: String) {
        label = Label(titleKey, systemImage: name)
    }
    
    init<S>(_ title: S, systemImage name: String) where S : StringProtocol {
        label = Label(title, systemImage: name)
    }
    
    var body: some View {
        if #available(iOS 14.5, *) {
            label.labelStyle(.titleAndIcon)
        } else {
            // prior to iOS 14.5, menu with title and icon doesn't show up
            label.labelStyle(.titleOnly)
        }
    }
}

struct MenuLabel_Previews: PreviewProvider {
    static var previews: some View {
        MenuLabel("Test", systemImage: "face")
    }
}
