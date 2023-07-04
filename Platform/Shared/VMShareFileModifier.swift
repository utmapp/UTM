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

struct VMShareItemModifier: ViewModifier {
    @Binding var isPresented: Bool
    let shareItem: ShareItem?
    
    #if os(macOS)
    func body(content: Content) -> some View {
        ZStack {
            SavePanel(isPresented: $isPresented, shareItem: shareItem)
            content
        }
    }
    #else
    func body(content: Content) -> some View {
        content.popover(isPresented: $isPresented) {
            if let shareItem = shareItem?.toActivityItem() {
                ActivityView(activityItems: [shareItem as Any])
                    .ignoresSafeArea()
            }
        }
    }
    #endif
    
    enum ShareItem {
        case debugLog(URL)
        case utmCopy(VMData)
        case utmMove(VMData)
        case qemuCommand(String)
        
        @MainActor func toActivityItem() -> Any {
            switch self {
            case .debugLog(let url):
                return url
            case .utmCopy(let vm), .utmMove(let vm):
                return vm.pathUrl
            case .qemuCommand(let command):
                return command
            }
        }
    }
}
