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

struct DetailedSection<Content>: View where Content: View {
    private let titleKey: LocalizedStringKey
    private let description: LocalizedStringKey
    private let content: Content
    
    init(_ titleKey: LocalizedStringKey, description: LocalizedStringKey = "", @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.description = description
        self.content = content()
    }
    
    var body: some View {
        #if os(macOS)
        Section(content: {
            content
            Text(description)
                .lineLimit(nil)
                .font(.footnote)
                .padding(.bottom)
        }, header: { Text(titleKey) })
        #else
        Section(content: { content }, header: { Text(titleKey) }, footer: { Text(description) })
        #endif
    }
}

struct DetailedSection_Previews: PreviewProvider {
    static var previews: some View {
        DetailedSection("Section", description: "Description") {
            EmptyView()
        }
    }
}
