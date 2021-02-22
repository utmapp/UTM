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

@available(iOS 14, macOS 11, *)
struct VMConfigStringPicker<Label> : View where Label : View {
    @Binding var selection: String?
    var label: Label
    var rawValues: [String]
    var displayValues: [String]
    
    init(selection: Binding<String?>, label: Label, rawValues: [String]?, displayValues: [String]?) {
        self._selection = selection
        self.label = label
        self.rawValues = rawValues ?? []
        self.displayValues = displayValues ?? []
    }
    
    var body: some View {
        let binding = Binding<Int>(
            get: {
                guard let selection = self.selection else {
                    return 0
                }
                return self.rawValues.firstIndex(where: { $0.caseInsensitiveCompare(selection) == .orderedSame }) ?? 0
            },
            set: {
                self.selection = self.rawValues[$0]
            }
        )
        return Picker(selection: binding, label: self.label) {
            ForEach(self.displayValues.indices, id: \.self) { index in
                Text(self.displayValues[index]).tag(index)
            }
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigStringPickerView_Previews: PreviewProvider {
    @State static private var selected: String? = nil
    
    static var previews: some View {
        VStack {
            HStack {
                Text("Selected:")
                Spacer()
                Text(selected ?? "none")
            }
            VMConfigStringPicker(selection: $selected, label: Text("Test"), rawValues: ["a", "b", "c"], displayValues: ["A", "B", "C"])
        }
    }
}
