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
                .conditionalFrame(maxWidth: 600, alignment: .leading)
                .lineLimit(nil)
                .font(.footnote)
                .padding(.bottom)
        }, header: { Text(titleKey) })
        #else
        Section(content: { content }, header: { Text(titleKey) }, footer: { Text(description) })
        #endif
    }
}

private extension View {
    @ViewBuilder func conditionalFrame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        if #available(macOS 13, *) {
            // SwiftUI: on macOS 13, this is required or the layout will be broken
            self.frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth, minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight, alignment: alignment)
        } else {
            // SwiftUI: on macOS 12 and below, the above breaks the layout
            self
        }
    }
}

struct DetailedSection_Previews: PreviewProvider {
    static var previews: some View {
        DetailedSection("Section", description: "Description") {
            EmptyView()
        }
    }
}
