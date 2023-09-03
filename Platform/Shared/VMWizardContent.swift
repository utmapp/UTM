//
// Copyright © 2023 osy. All rights reserved.
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

struct VMWizardContent<Content>: View where Content: View {
    let titleKey: LocalizedStringKey
    let content: Content
    
    init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.content = content()
    }
    
    var body: some View {
        #if os(macOS)
        Text(titleKey)
            .font(.largeTitle)
        #endif
        List {
            #if os(macOS)
            if #available(macOS 13, *) {
                content.listRowSeparator(.hidden)
            } else {
                content
            }
            #else
            content
            #endif
        }
        #if os(iOS) || os(visionOS)
        .navigationTitle(Text(titleKey))
        #endif
    }
}

#Preview {
    VMWizardContent("Test") {
        Text("Test 1")
        Text("Test 2")
    }
}
