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

struct DefaultTextField: View {
    private let titleKey: LocalizedStringKey
    private let text: Binding<String>
    private let prompt: LocalizedStringKey
    private let onEditingChanged: (Bool) -> Void
    
    init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey = "", onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.titleKey = titleKey
        self.text = text
        self.prompt = prompt
        self.onEditingChanged = onEditingChanged
    }
    
    var body: some View {
        let stack = HStack {
            Text(titleKey)
            if titleKey.localizedString.count > 0 {
                Spacer()
            }
            TextField(prompt, text: text, onEditingChanged: onEditingChanged)
        }
        #if os(macOS)
        if #available(iOS 15, macOS 12, *) {
            DefaultTextFieldNew(titleKey, text: text, prompt: prompt, onEditingChanged: onEditingChanged)
        } else {
            stack
        }
        #else
        stack
        #endif
    }
}

@available(iOS 15, macOS 12, *)
struct DefaultTextFieldNew: View {
    private let titleKey: LocalizedStringKey
    @Binding var text: String
    private let prompt: LocalizedStringKey
    private let onEditingChanged: (Bool) -> Void
    @FocusState private var focused: Bool
    
    init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey = "", onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.titleKey = titleKey
        self._text = text
        self.prompt = prompt
        self.onEditingChanged = onEditingChanged
    }
    
    var body: some View {
        TextField(titleKey, text: $text, prompt: Text(prompt))
            .focused($focused)
            .onChange(of: text) { newValue in
                onEditingChanged(focused)
            }
            .onSubmit {
                focused = false
                onEditingChanged(false)
            }
    }
}

struct DefaultTextField_Previews: PreviewProvider {
    static var previews: some View {
        DefaultTextField("Test", text: .constant("Value"), prompt: "Prompt")
    }
}
