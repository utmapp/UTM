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

enum ConfirmAction: Identifiable, Equatable {
    case confirmCloneVM(vm: VMData)
    case confirmDeleteVM(vm: VMData)
    case confirmStopVM(vm: VMData)
    case confirmMoveVM(vm: VMData)

    struct ID: Hashable {
        let index: Int
        let uuid: UUID
    }

    @MainActor
    var id: ID {
        switch self {
        case .confirmCloneVM(let vm):
            return ID(index: 0, uuid: vm.id)
        case .confirmDeleteVM(let vm):
            return ID(index: 1, uuid: vm.id)
        case .confirmStopVM(let vm):
            return ID(index: 2, uuid: vm.id)
        case .confirmMoveVM(let vm):
            return ID(index: 3, uuid: vm.id)
        }
    }

    @MainActor
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

struct VMConfirmActionModifier: ViewModifier {
    @Binding var confirmAction: ConfirmAction?
    var workaroundSwipeBug: Bool = false
    let onConfirm: (ConfirmAction) -> Void
    @EnvironmentObject private var data: UTMData
    @State private var isPresented: Bool = false

    @ViewBuilder func body(content: Content) -> some View {
        // SwiftUI bug: swipe + confirmationDialog is broken
        if !workaroundSwipeBug, #available(iOS 15, macOS 12, *) {
            newBody(content: content)
        } else {
            oldBody(content: content)
        }
    }

    @ViewBuilder func oldBody(content: Content) -> some View {
        content.alert(item: $confirmAction) { action in
            switch action {
            case .confirmCloneVM(let vm):
                if vm.isShortcut {
                    return Alert(title: Text("Do you want to copy this VM and all its data to internal storage?"), primaryButton: .cancel(), secondaryButton: .default(Text("Copy")) {
                        data.busyWorkAsync {
                            try await data.clone(vm: vm)
                        }
                        onConfirm(action)
                    })
                } else {
                    return Alert(title: Text("Do you want to duplicate this VM and all its data?"), primaryButton: .cancel(),  secondaryButton: .default(Text("Copy")) {
                        data.busyWorkAsync {
                            try await data.clone(vm: vm)
                        }
                        onConfirm(action)
                    })
                }
            case .confirmDeleteVM(let vm):
                if vm.wrapped?.isShortcut ?? false {
                    return Alert(title: Text("Do you want to remove this shortcut? The data will not be deleted."), primaryButton: .cancel(), secondaryButton: .destructive(Text("Remove")) {
                        data.busyWorkAsync {
                            await data.listRemove(vm: vm)
                        }
                        onConfirm(action)
                    })
                } else {
                    return Alert(title: Text("Do you want to delete this VM and all its data?"), primaryButton: .cancel(), secondaryButton: .destructive(Text("Delete")) {
                        data.busyWorkAsync {
                            try await data.delete(vm: vm)
                        }
                        onConfirm(action)
                    })
                }
            case .confirmStopVM(let vm):
                return Alert(title: Text("Do you want to force stop this VM and lose all unsaved data?"), primaryButton: .cancel(), secondaryButton: .destructive(Text("Stop")) {
                    data.stop(vm: vm)
                    onConfirm(action)
                })
            case .confirmMoveVM(_):
                return Alert(title: Text("Do you want to move this VM to another location? This will copy the data to the new location, delete the data from the original location, and then create a shortcut."), primaryButton: .cancel(), secondaryButton: .destructive(Text("Confirm")) {
                    onConfirm(action)
                })
            }
        }
    }

    @available(iOS 15, macOS 12, *)
    @ViewBuilder func newBody(content: Content) -> some View {
        content.confirmationDialog("Confirm", isPresented: $isPresented, presenting: confirmAction) { action in
            Button("Cancel", role: .cancel) {}
            switch action {
            case .confirmCloneVM(let vm):
                Button("Copy") {
                    data.busyWorkAsync {
                        try await data.clone(vm: vm)
                    }
                    onConfirm(action)
                }
            case .confirmDeleteVM(let vm):
                if vm.wrapped?.isShortcut ?? false {
                    Button("Remove", role: .destructive) {
                        data.busyWorkAsync {
                            await data.listRemove(vm: vm)
                        }
                        onConfirm(action)
                    }
                } else {
                    Button("Delete", role: .destructive) {
                        data.busyWorkAsync {
                            try await data.delete(vm: vm)
                        }
                        onConfirm(action)
                    }
                }
            case .confirmStopVM(let vm):
                Button("Stop", role: .destructive) {
                    data.stop(vm: vm)
                    onConfirm(action)
                }
            case .confirmMoveVM(_):
                if #available(iOS 26, macOS 26, visionOS 26, *) {
                    Button("Confirm", role: .confirm) {
                        onConfirm(action)
                    }
                } else {
                    Button("Confirm") {
                        onConfirm(action)
                    }
                }
            }
        } message: { action in
            switch action {
            case .confirmCloneVM(let vm):
                if vm.isShortcut {
                    Text("Do you want to copy this VM and all its data to internal storage?")
                } else {
                    Text("Do you want to duplicate this VM and all its data?")
                }
            case .confirmDeleteVM(let vm):
                if vm.wrapped?.isShortcut ?? false {
                    Text("Do you want to remove this shortcut? The data will not be deleted.")
                } else {
                    Text("Do you want to delete this VM and all its data?")
                }
            case .confirmStopVM(_):
                Text("Do you want to force stop this VM and lose all unsaved data?")
            case .confirmMoveVM(_):
                Text("Do you want to move this VM to another location? This will copy the data to the new location, delete the data from the original location, and then create a shortcut.")
            }
        }
        .onChange(of: confirmAction) { newValue in
            if newValue != nil {
                isPresented = true
            }
        }
    }
}
