//
// Copyright © 2021 osy. All rights reserved.
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

struct VMQEMUSettingsView: View {
    let vm: UTMVirtualMachine?
    @ObservedObject var config: UTMQemuConfiguration
    @Binding var selectedDriveIndex: Int?

    @State private var infoActive: Bool = true
    
    var body: some View {
        NavigationLink(destination: VMConfigInfoView(config: config).scrollable(), isActive: $infoActive) {
            Label("Information", systemImage: "info.circle")
        }
        Group {
            NavigationLink(destination: VMConfigSystemView(config: config).scrollable()) {
                Label("System", systemImage: "cpu")
            }
            NavigationLink(destination: VMConfigAdvancedSystemView(config: config).scrollable()) {
                Label("Advanced", systemImage: "wrench.and.screwdriver")
                    .padding(.leading)
            }
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
        Group {
            NavigationLink(destination: VMConfigNetworkView(config: config).scrollable()) {
                Label("Network", systemImage: "network")
            }
            NavigationLink(destination: VMConfigAdvancedNetworkView(config: config).scrollable()) {
                Label("Advanced", systemImage: "wrench.and.screwdriver")
                    .padding(.leading)
            }
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

struct VMQEMUSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMQEMUSettingsView(vm: nil, config: config, selectedDriveIndex: .constant(0))
    }
}
