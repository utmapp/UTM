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

struct VMConfigConstantPicker: View {
    private struct Identifier: Hashable {
        let string: String
        
        init(_ string: String) {
            self.string = string
        }
        
        func hash(into hasher: inout Hasher) {
            string.hash(into: &hasher)
        }
    }
    
    @Binding private var selection: Identifier
    private let titleKey: LocalizedStringKey?
    private let type: any QEMUConstant.Type
    
    init<T: QEMUConstant>(_ titleKey: LocalizedStringKey? = nil, selection: Binding<T>) {
        self._selection = Binding(get: {
            Identifier(selection.wrappedValue.rawValue)
        }, set: { newValue in
            selection.wrappedValue = T(rawValue: newValue.string)!
        })
        self.titleKey = titleKey
        self.type = T.self
    }
    
    init<S>(_ titleKey: LocalizedStringKey? = nil, selection: Binding<S>, type: any QEMUConstant.Type) {
        self._selection = Binding(get: {
            Identifier((selection.wrappedValue as! any QEMUConstant).rawValue)
        }, set: { newValue in
            selection.wrappedValue = type.init(rawValue: newValue.string)! as! S
        })
        self.titleKey = titleKey
        self.type = type
    }
    
    var body: some View {
        Picker(titleKey ?? "", selection: $selection) {
            ForEach(type.shownPrettyValues) { displayValue in
                Text(displayValue).tag(identifier(for: displayValue))
            }
        }
    }
    
    private nonmutating func identifier(for displayValue: String) -> Identifier {
        let index = type.allPrettyValues.firstIndex(of: displayValue)!
        return Identifier(type.allRawValues[index])
    }
}

struct VMConfigConstantPicker_Previews: PreviewProvider {
    @State static private var fixedType: QEMUArchitecture = .aarch64
    @State static private var dynamicType: any QEMUCPU = QEMUCPU_aarch64.default
    
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
