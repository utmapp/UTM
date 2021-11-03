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
struct VMShareItemModifier: ViewModifier {
    @Binding var isPresented: Bool
    // TODO: Change name to shareItem
    let makeShareItem: () -> ShareItem?
    
    #if os(macOS)
    func body(content: Content) -> some View {
        ZStack {
            SavePanel(isPresented: $isPresented, shareItem: makeShareItem())
            content
        }
    }
    #else
    func body(content: Content) -> some View {
        content.popover(isPresented: $isPresented) {
            if let shareItem = makeShareItem()?.toActivityItem() {
                ActivityView(activityItems: [shareItem as Any])
            }
        }
    }
    #endif
    
    enum ShareItem {
        case debugLog(URL)
        case utmVm(URL)
        case qemuCommand(String)
        
        func toActivityItem() -> Any {
            switch self {
            case .debugLog(let url), .utmVm(let url):
                return url
            case .qemuCommand(let command):
                return command
            }
        }
    }
}
