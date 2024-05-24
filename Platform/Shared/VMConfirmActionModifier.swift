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
    case confirmDeleteShortcut
    case confirmStopVM
    case confirmMoveVM
    
    var id: Int { rawValue }
}

struct VMConfirmActionModifier: ViewModifier {
    let vm: VMData
    @Binding var confirmAction: ConfirmAction?
    let onConfirm: () -> Void
    @EnvironmentObject private var data: UTMData
    
    func body(content: Content) -> some View {
        content.alert(item: $confirmAction) { action in
            switch action {
            case .confirmCloneVM:
                if vm.isShortcut {
                    return Alert(title: Text("Do you want to copy this VM and all its data to internal storage?"), primaryButton: .cancel(), secondaryButton: .default(Text("Yes")) {
                        data.busyWorkAsync {
                            try await data.clone(vm: vm)
                        }
                        onConfirm()
                    })
                } else {
                    return Alert(title: Text("Do you want to duplicate this VM and all its data?"), primaryButton: .cancel(),  secondaryButton: .default(Text("Yes")) {
                        data.busyWorkAsync {
                            try await data.clone(vm: vm)
                        }
                        onConfirm()
                    })
                }
            case .confirmDeleteVM:
                return Alert(title: Text("Do you want to delete this VM and all its data?"), primaryButton: .cancel(), secondaryButton: .destructive(Text("Delete")) {
                    data.busyWorkAsync {
                        try await data.delete(vm: vm)
                    }
                    onConfirm()
                })
            case .confirmDeleteShortcut:
                return Alert(title: Text("Do you want to remove this shortcut? The data will not be deleted."), primaryButton: .cancel(), secondaryButton: .destructive(Text("Remove")) {
                    data.busyWorkAsync {
                        await data.listRemove(vm: vm)
                    }
                    onConfirm()
                })
            case .confirmStopVM:
                return Alert(title: Text("Do you want to force stop this VM and lose all unsaved data?"), primaryButton: .cancel(), secondaryButton: .destructive(Text("Stop")) {
                    data.stop(vm: vm)
                    onConfirm()
                })
            case .confirmMoveVM:
                return Alert(title: Text("Do you want to move this VM to another location? This will copy the data to the new location, delete the data from the original location, and then create a shortcut."), primaryButton: .cancel(), secondaryButton: .destructive(Text("Confirm")) {
                    onConfirm()
                })
            }
        }
    }
}
