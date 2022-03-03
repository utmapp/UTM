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

@available(iOS 14, macOS 11, *)
struct DefaultPicker<SelectionValue, Content>: View where SelectionValue: Hashable, Content: View {
    private let titleKey: LocalizedStringKey?
    private let selection: Binding<SelectionValue>
    private let content: Content
    
    init(_ titleKey: LocalizedStringKey? = nil, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.selection = selection
        self.content = content()
    }
    
    var body: some View {
        #if os(macOS)
        Picker(titleKey ?? "", selection: selection) {
            content
        }
        #else
        if #available(iOS 15, *) {
            HStack {
                let picker = Picker("", selection: selection) {
                    content
                }
                if let titleKey = titleKey {
                    Text(titleKey)
                    Spacer()
                    picker
                } else {
                    picker
                }
            }
        } else {
            Picker(titleKey ?? "", selection: selection) {
                content
            }.pickerStyle(.automatic)
        }
        #endif
    }
}

@available(iOS 14, macOS 11, *)
struct DefaultPicker_Previews: PreviewProvider {
    static var previews: some View {
        DefaultPicker("Test", selection: .constant(0)) {
            Text("Zero").tag(0)
            Text("One").tag(1)
            Text("Two").tag(2)
        }
    }
}
