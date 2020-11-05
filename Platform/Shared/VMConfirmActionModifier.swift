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

enum ConfirmAction: Int, Identifiable {
    case confirmCloneVM
    case confirmDeleteVM
    case confirmStopVM
    
    var id: Int { rawValue }
}

@available(iOS 14, macOS 11, *)
struct VMConfirmActionModifier: ViewModifier {
    let vm: UTMVirtualMachine
    @Binding var confirmAction: ConfirmAction?
    let onConfirm: () -> Void
    @EnvironmentObject private var data: UTMData
    
    func body(content: Content) -> some View {
        content.alert(item: $confirmAction) { action in
            switch action {
            case .confirmCloneVM:
                return Alert(title: Text("Do you want to duplicate this VM and all its data?"), primaryButton: .cancel(), secondaryButton: .default(Text("Yes")) {
                    data.busyWork {
                        try data.clone(vm: vm)
                    }
                    onConfirm()
                })
            case .confirmDeleteVM:
                return Alert(title: Text("Do you want to delete this VM and all its data?"), primaryButton: .cancel(), secondaryButton: .destructive(Text("Delete")) {
                    data.busyWork {
                        try data.delete(vm: vm)
                    }
                    onConfirm()
                })
            case .confirmStopVM:
                return Alert(title: Text("Do you want to force stop this VM and lose all unsaved data?"), primaryButton: .cancel(), secondaryButton: .destructive(Text("Stop")) {
                    data.busyWork {
                        try data.stop(vm: vm)
                    }
                    onConfirm()
                })
            }
        }
    }
}
