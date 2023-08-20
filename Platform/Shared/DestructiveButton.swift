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

struct DestructiveButton<Label>: View where Label : View {
    private let action: () -> Void
    private let label: Label
    
    init(action: @escaping () -> Void, label: () -> Label) {
        self.action = action
        self.label = label()
    }
    
    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) where Label == Text {
        self.action = action
        self.label = Text(titleKey)
    }
    
    var body: some View {
        if #available(iOS 15, macOS 12, *) {
            #if os(iOS) || os(visionOS)
            Button(role: .destructive, action: action, label: {
                label.foregroundColor(.red)
            })
            #else
            Button(role: .destructive, action: action, label: { label })
            #endif
        } else {
            #if os(iOS) || os(visionOS)
            Button(action: action, label: {
                label.foregroundColor(.red)
            })
            #else
            Button(action: action, label: { label })
            #endif
        }
    }
}

struct DestructiveButton_Previews: PreviewProvider {
    static var previews: some View {
        DestructiveButton {
            
        } label: {
            Text("Test")
        }
    }
}
