//
// Copyright © 2020 osy. All rights reserved.
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

@available(iOS 13, macOS 11, *)
struct NumberTextField: View {
    private var titleKey: LocalizedStringKey
    @Binding private var number: NSNumber?
    private var onEditingChanged: (Bool) -> Void
    private var onCommit: () -> Void
    
    init(_ titleKey: LocalizedStringKey, number: Binding<NSNumber?>, onEditingChanged: @escaping (Bool) -> Void = { _ in }, onCommit: @escaping () -> Void = {}) {
        self.titleKey = titleKey
        self._number = number
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }
    
    var body: some View {
        TextField(titleKey, text: Binding<String>(get: { () -> String in
            guard let number = self.number else {
                return ""
            }
            return NumberFormatter().string(from: number) ?? ""
        }, set: {
            self.number = NumberFormatter().number(from: $0)
        }), onEditingChanged: onEditingChanged, onCommit: onCommit)
            .keyboardType(.numberPad)
    }
}

@available(iOS 13, macOS 11, *)
struct NumberTextField_Previews: PreviewProvider {
    static var previews: some View {
        NumberTextField("Test", number: .constant(NSNumber(value: 123)))
    }
}
