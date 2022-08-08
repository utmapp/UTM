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

struct NumberTextFieldOld: View {
    private var titleKey: LocalizedStringKey
    @Binding private var number: NSNumber?
    private var promptKey: LocalizedStringKey
    private var onEditingChanged: (Bool) -> Void
    private let formatter: NumberFormatter
    
    init(_ titleKey: LocalizedStringKey, number: Binding<NSNumber?>, prompt: LocalizedStringKey, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.titleKey = titleKey
        self._number = number
        self.onEditingChanged = onEditingChanged
        self.formatter = NumberFormatter()
        self.formatter.usesGroupingSeparator = false
        self.formatter.usesSignificantDigits = false
        self.promptKey = prompt
    }
    
    var body: some View {
        HStack {
            Text(titleKey)
            Spacer()
            TextField(promptKey, text: Binding<String>(get: { () -> String in
                guard let number = number, let string = formatter.string(from: number) else {
                    return ""
                }
                return number.intValue == 0 ? "" : string
            }, set: {
                // make sure we never set nil
                self.number = self.formatter.number(from: $0) ?? 0
            }), onEditingChanged: onEditingChanged)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
        }
    }
}

@available(iOS 15, macOS 12, *)
struct NumberTextFieldNew: View {
    private var titleKey: LocalizedStringKey
    @Binding private var number: NSNumber?
    private var promptKey: LocalizedStringKey
    private var onEditingChanged: (Bool) -> Void
    
    // Due to FB9581726 we cannot make `focused` available only on newer APIs.
    // Therefore we have to mark the availability on the entire struct.
    @FocusState private var focused: Bool
    
    init(_ titleKey: LocalizedStringKey, number: Binding<NSNumber?>, prompt: LocalizedStringKey, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.titleKey = titleKey
        self._number = number
        self.onEditingChanged = onEditingChanged
        self.promptKey = prompt
    }
    
    var body: some View {
        Group {
            #if os(macOS)
            TextField(titleKey, value: $number, format: NSNumber.StringFormatStyle(), prompt: Text(promptKey))
                .focused($focused)
            #else
            HStack {
                Text(titleKey)
                Spacer()
                TextField(titleKey, value: $number, format: NSNumber.StringFormatStyle(), prompt: Text(promptKey))
                    .focused($focused)
            }
            #endif
        }.keyboardType(.numberPad)
        .onChange(of: number) { _ in
            onEditingChanged(focused)
        }
        .onSubmit {
            focused = false
            onEditingChanged(false)
        }
        .multilineTextAlignment(.trailing)
    }
}

struct NumberTextField: View {
    private var titleKey: LocalizedStringKey
    @Binding private var number: NSNumber?
    private var promptKey: LocalizedStringKey
    private var onEditingChanged: (Bool) -> Void
    
    init(_ titleKey: LocalizedStringKey, number: Binding<NSNumber?>, prompt: LocalizedStringKey = "0", onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.titleKey = titleKey
        self._number = number
        self.onEditingChanged = onEditingChanged
        self.promptKey = prompt
    }
    
    init(_ titleKey: LocalizedStringKey, number: Binding<Int>, prompt: LocalizedStringKey = "0", onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        let nsnumber = Binding<NSNumber?> {
            return number.wrappedValue as NSNumber
        } set: { newValue in
            number.wrappedValue = newValue?.intValue ?? 0
        }
        self.init(titleKey, number: nsnumber, prompt: prompt, onEditingChanged: onEditingChanged)
    }
    
    var body: some View {
        if #available(iOS 15, macOS 12, *) {
            NumberTextFieldNew(titleKey, number: $number, prompt: promptKey, onEditingChanged: onEditingChanged)
        } else {
            NumberTextFieldOld(titleKey, number: $number, prompt: promptKey, onEditingChanged: onEditingChanged)
        }
    }
}

@available(iOS 15, macOS 12, *)
extension NSNumber {
    struct StringFormatStyle: ParseableFormatStyle {
        var parseStrategy: StringParseStrategy {
            return StringParseStrategy()
        }
        
        func format(_ value: NSNumber) -> String {
            let formatter = NumberFormatter()
            formatter.usesGroupingSeparator = false
            formatter.usesSignificantDigits = false
            let string = formatter.string(from: value) ?? ""
            return value.intValue == 0 ? "" : string
        }
    }
    
    struct StringParseStrategy: ParseStrategy {
        func parse(_ value: String) throws -> NSNumber {
            let formatter = NumberFormatter()
            formatter.usesGroupingSeparator = false
            formatter.usesSignificantDigits = false
            return formatter.number(from: value) ?? 0
        }
    }
}

struct NumberTextField_Previews: PreviewProvider {
    static var previews: some View {
        NumberTextField("Test", number: .constant(123 as NSNumber))
    }
}
