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
struct VMConfigConstantPicker<T: QEMUConstant>: View {
    @Binding private var stringSelection: String
    private let titleKey: LocalizedStringKey?
    private let type: QEMUConstant.Type
    
    init(_ titleKey: LocalizedStringKey? = nil, selection: Binding<T>) {
        self._stringSelection = Binding(get: {
            selection.wrappedValue.rawValue
        }, set: { newValue in
            selection.wrappedValue = T(rawValue: newValue)!
        })
        self.titleKey = titleKey
        self.type = T.self
    }
    
    init<S>(_ titleKey: LocalizedStringKey? = nil, selection: Binding<S>, type: QEMUConstant.Type) where T == AnyQEMUConstant {
        self._stringSelection = Binding(get: {
            (selection.wrappedValue as! QEMUConstant).rawValue
        }, set: { newValue in
            selection.wrappedValue = AnyQEMUConstant(rawValue: newValue) as! S
        })
        self.titleKey = titleKey
        self.type = type
    }
    
    var body: some View {
        DefaultPicker(titleKey, selection: $stringSelection) {
            ForEach(type.allPrettyValues) { displayValue in
                Text(displayValue).tag(rawValue(for: displayValue))
            }
        }
    }
    
    private nonmutating func rawValue(for displayValue: String) -> String {
        let index = type.allPrettyValues.firstIndex(of: displayValue)!
        return type.allRawValues[index]
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigConstantPicker_Previews: PreviewProvider {
    @State static private var fixedType: QEMUArchitecture = .aarch64
    @State static private var dynamicType: QEMUCPU = QEMUCPU_aarch64.default
    
    static var previews: some View {
        VStack {
            HStack {
                Text("Selected:")
                Spacer()
                Text(fixedType.prettyValue)
                Text(dynamicType.prettyValue)
            }
            VMConfigConstantPicker("Text", selection: $fixedType)
            VMConfigConstantPicker(selection: $dynamicType, type: QEMUCPU_aarch64.self)
        }
    }
}
