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
struct NumberTextFieldOld: View {
    private var titleKey: LocalizedStringKey
    @Binding private var number: NSNumber?
    private var onEditingChanged: (Bool) -> Void
    private let formatter: NumberFormatter
    
    init(_ titleKey: LocalizedStringKey, number: Binding<NSNumber?>, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.titleKey = titleKey
        self._number = number
        self.onEditingChanged = onEditingChanged
        self.formatter = NumberFormatter()
        self.formatter.usesGroupingSeparator = false
        self.formatter.usesSignificantDigits = false
    }
    
    var body: some View {
        TextField(titleKey, text: Binding<String>(get: { () -> String in
            guard let number = self.number else {
                return ""
            }
            return self.formatter.string(from: number) ?? ""
        }, set: {
            // make sure we never set nil
            self.number = self.formatter.number(from: $0) ?? NSNumber(value: 0)
        }), onEditingChanged: onEditingChanged)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
    }
}

#if swift(>=5.5)
@available(iOS 15, macOS 12, *)
struct NumberTextFieldNew: View {
    private var titleKey: LocalizedStringKey
    @Binding private var number: NSNumber?
    private var onEditingChanged: (Bool) -> Void
    
    // Due to FB9581726 we cannot make `focused` available only on newer APIs.
    // Therefore we have to mark the availability on the entire struct.
    @FocusState private var focused: Bool
    
    init(_ titleKey: LocalizedStringKey, number: Binding<NSNumber?>, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.titleKey = titleKey
        self._number = number
        self.onEditingChanged = onEditingChanged
    }
    
    var body: some View {
        TextField(value: $number, format: NSNumber.StringFormatStyle(), prompt: Text(titleKey), label: {
            EmptyView()
        })
            .keyboardType(.numberPad)
            .focused($focused)
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
#endif

@available(iOS 13, macOS 11, *)
struct NumberTextField: View {
    private var titleKey: LocalizedStringKey
    @Binding private var number: NSNumber?
    private var onEditingChanged: (Bool) -> Void
    
    init(_ titleKey: LocalizedStringKey, number: Binding<NSNumber?>, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.titleKey = titleKey
        self._number = number
        self.onEditingChanged = onEditingChanged
    }
    
    init(_ titleKey: LocalizedStringKey, number: Binding<Int>, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        let nsnumber = Binding<NSNumber?> {
            return NSNumber(value: number.wrappedValue)
        } set: { newValue in
            number.wrappedValue = newValue?.intValue ?? 0
        }
        self.init(titleKey, number: nsnumber, onEditingChanged: onEditingChanged)
    }
    
    var body: some View {
        #if swift(>=5.5)
        if #available(iOS 15, macOS 12, *) {
            NumberTextFieldNew(titleKey, number: $number, onEditingChanged: onEditingChanged)
        } else {
            NumberTextFieldOld(titleKey, number: $number, onEditingChanged: onEditingChanged)
        }
        #else
        NumberTextFieldOld(titleKey, number: $number, onEditingChanged: onEditingChanged)
        #endif
    }
}

#if swift(>=5.5)
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
            return formatter.string(from: value) ?? ""
        }
    }
    
    struct StringParseStrategy: ParseStrategy {
        func parse(_ value: String) throws -> NSNumber {
            let formatter = NumberFormatter()
            formatter.usesGroupingSeparator = false
            formatter.usesSignificantDigits = false
            return formatter.number(from: value) ?? NSNumber(value: 0)
        }
    }
}
#endif

@available(iOS 13, macOS 11, *)
struct NumberTextField_Previews: PreviewProvider {
    static var previews: some View {
        NumberTextField("Test", number: .constant(NSNumber(value: 123)))
    }
}
