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
struct VMSettingsView: View {
    let vm: UTMVirtualMachine?
    @ObservedObject var config: UTMConfiguration
    
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    @State private var infoActive: Bool = true
    @State private var selectedDriveIndex: Int?
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: VMConfigInfoView(config: config).scrollable(), isActive: $infoActive) {
                    Label("Information", systemImage: "info.circle")
                }
                NavigationLink(destination: VMConfigSystemView(config: config).scrollable()) {
                    Label("System", systemImage: "cpu")
                }
                NavigationLink(destination: VMConfigQEMUView(config: config).scrollable()) {
                    Label("QEMU", systemImage: "shippingbox")
                }
                NavigationLink(destination: VMConfigDisplayView(config: config).scrollable()) {
                    Label("Display", systemImage: "rectangle.on.rectangle")
                }
                NavigationLink(destination: VMConfigInputView(config: config).scrollable()) {
                    Label("Input", systemImage: "keyboard")
                }
                NavigationLink(destination: VMConfigNetworkView(config: config).scrollable()) {
                    Label("Network", systemImage: "network")
                }
                NavigationLink(destination: VMConfigSoundView(config: config).scrollable()) {
                    Label("Sound", systemImage: "speaker.wave.2")
                }
                NavigationLink(destination: VMConfigSharingView(config: config).scrollable()) {
                    Label("Sharing", systemImage: "person.crop.circle.fill")
                }
                Section(header: Text("Drives")) {
                    ForEach(0..<config.countDrives, id: \.self) { index in
                        NavigationLink(destination: VMConfigDriveDetailsView(config: config, index: index).scrollable(), tag: index, selection: $selectedDriveIndex) {
                            Label(config.driveLabel(for: index), systemImage: "externaldrive")
                        }
                    }.onMove(perform: moveDrives)
                }
            }.listStyle(.sidebar)
        }.frame(minWidth: 800, minHeight: 400)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                VMConfigDrivesButtons(vm: vm, config: config, selectedDriveIndex: $selectedDriveIndex)
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
        data.busyWork {
            if let existing = self.vm {
                try data.save(vm: existing)
            } else {
                try data.create(config: self.config)
            }
        }
    }
    
    func cancel() {
        presentationMode.wrappedValue.dismiss()
        if let existing = self.vm {
            data.busyWork {
                try data.discardChanges(forVM: existing)
            }
        }
    }
    
    func moveDrives(from source: IndexSet, to destination: Int) {
        for offset in source {
            let realDestination: Int
            if offset < destination {
                realDestination = destination - 1
            } else {
                realDestination = destination
            }
            config.moveDrive(offset, to: realDestination)
            if selectedDriveIndex == offset {
                selectedDriveIndex = realDestination
            }
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
    @State static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMSettingsView(vm: nil, config: config)
    }
}
