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

@available(macOS 11, *)
struct VMSettingsView<Config: ObservableObject & UTMConfigurable>: View {
    let vm: UTMVirtualMachine?
    let config: Config
    
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    @State private var selectedDriveIndex: Int?
    
    var body: some View {
        NavigationView {
            List {
                if let qemuVM = vm as? UTMQemuVirtualMachine {
                    //FIXME: Rework after config rewrite.
                    VMQEMUSettingsView(config: qemuVM.futureConfig, selectedDriveIndex: $selectedDriveIndex)
                } else if let appleVM = vm as? UTMAppleVirtualMachine {
                    //FIXME: Rework after config rewrite.
                    VMAppleSettingsView(config: appleVM.futureConfig, selectedDriveIndex: $selectedDriveIndex)
                }
            }.listStyle(.sidebar)
        }.frame(minWidth: 800, minHeight: 400)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if let qemuVM = vm as? UTMQemuVirtualMachine {
                    //FIXME: Rework after config rewrite.
                    let drives = Binding {
                        qemuVM.futureConfig.drives
                    } set: {
                        qemuVM.futureConfig.drives = $0
                    }
                    VMConfigDrivesMoveButtons(drives: drives, selectedDriveIndex: $selectedDriveIndex)
                } else if let appleVM = vm as? UTMAppleVirtualMachine {
                    //FIXME: Rework after config rewrite.
                    let drives = Binding {
                        appleVM.futureConfig.drives
                    } set: {
                        appleVM.futureConfig.drives = $0
                    }
                    VMConfigDrivesMoveButtons(drives: drives, selectedDriveIndex: $selectedDriveIndex)
                }
            }
            ToolbarItemGroup(placement: .cancellationAction) {
                Button(action: cancel) {
                    Text("Cancel")
                }
            }
            ToolbarItemGroup(placement: .confirmationAction) {
                Button(action: save) {
                    Text("Save")
                }
            }
        }.disabled(data.busy)
        .overlay(BusyOverlay())
    }
    
    func save() {
        presentationMode.wrappedValue.dismiss()
        data.busyWorkAsync {
            if let existing = self.vm {
                try await data.save(vm: existing)
            } else {
                _ = try await data.create(config: self.config)
            }
        }
    }
    
    func cancel() {
        presentationMode.wrappedValue.dismiss()
        data.busyWork {
            try data.discardChanges(for: self.vm)
        }
    }
}

@available(macOS 11, *)
struct ScrollableViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        ScrollView {
            content.padding()
            .frame(maxWidth: .infinity)
        }
    }
}

@available(macOS 11, *)
extension View {
    func scrollable() -> some View {
        self.modifier(ScrollableViewModifier())
    }
}

@available(macOS 11, *)
struct VMSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMLegacyQemuConfiguration()
    
    static var previews: some View {
        VMSettingsView(vm: nil, config: config)
    }
}
