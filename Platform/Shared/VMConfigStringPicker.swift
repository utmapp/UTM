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

struct VMConfigStringPicker: View {
    private let selection: Binding<String?>
    private let titleKey: LocalizedStringKey?
    private let rawValues: [String]
    private let displayValues: [String]
    
    init(_ titleKey: LocalizedStringKey? = nil, selection: Binding<String?>, rawValues: [String]?, displayValues: [String]?) {
        self.selection = selection
        self.titleKey = titleKey
        self.rawValues = rawValues ?? []
        self.displayValues = displayValues ?? []
    }
    
    var body: some View {
        DefaultPicker(titleKey, selection: selection) {
            ForEach(displayValues) { displayValue in
                Text(displayValue).tag(rawValue(for: displayValue))
            }
        }
    }
    
    private func rawValue(for displayValue: String) -> String? {
        if let index = displayValues.firstIndex(of: displayValue) {
            return rawValues[index]
        } else {
            return nil
        }
    }
}

struct VMConfigStringPickerView_Previews: PreviewProvider {
    @State static private var selected: String? = nil
    
    static var previews: some View {
        VStack {
            HStack {
                Text("Selected:")
                Spacer()
                Text(selected ?? "none")
            }
            VMConfigStringPicker("Text", selection: $selected, rawValues: ["a", "b", "c"], displayValues: ["A", "B", "C"])
        }
    }
}
