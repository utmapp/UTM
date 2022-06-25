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
    @ObservedObject var config: UTMQemuConfiguration
    @Binding var selectedDriveIndex: Int?
    @EnvironmentObject private var data: UTMData

    @State private var infoActive: Bool = true
    @State private var isResetConfig: Bool = false
    @State private var triggerRefresh: Bool = false
    
    var body: some View {
        NavigationLink(destination: VMConfigInfoView(config: config.information).scrollable(), isActive: $infoActive) {
            Label("Information", systemImage: "info.circle")
        }
        NavigationLink(destination: VMConfigSystemView(config: config.system, isResetConfig: $isResetConfig).scrollable()) {
            Label("System", systemImage: "cpu")
        }.onChange(of: isResetConfig) { newValue in
            if newValue {
                config.reset(forArchitecture: config.system.architecture, target: config.system.target)
                isResetConfig = false
            }
        }
        NavigationLink(destination: VMConfigQEMUView(config: config.qemu, system: config.system).scrollable()) {
            Label("QEMU", systemImage: "shippingbox")
        }
        ForEach(config.displays) { display in
            NavigationLink(destination: VMConfigDisplayView(config: display, system: config.system).scrollable()) {
                Label("Display", systemImage: "rectangle.on.rectangle")
            }
        }
        ForEach(config.serials) { serial in
            NavigationLink(destination: VMConfigSerialView(config: serial, system: config.system).scrollable()) {
                Label("Serial", systemImage: "cable.connector")
            }
        }
        NavigationLink(destination: VMConfigInputView(config: config.input).scrollable()) {
            Label("Input", systemImage: "keyboard")
        }
        ForEach(config.networks) { network in
            Group {
                NavigationLink(destination: VMConfigNetworkView(config: network, system: config.system).scrollable()) {
                    Label("Network", systemImage: "network")
                }
                NavigationLink(destination: VMConfigAdvancedNetworkView(config: network).scrollable()) {
                    Label("IP Configuration", systemImage: "mappin.circle")
                        .padding(.leading)
                }
            }
        }
        ForEach(config.sound) { sound in
            NavigationLink(destination: VMConfigSoundView(config: sound, system: config.system).scrollable()) {
                Label("Sound", systemImage: "speaker.wave.2")
            }
        }
        NavigationLink(destination: VMConfigSharingView(config: config.sharing).scrollable()) {
            Label("Sharing", systemImage: "person.crop.circle")
        }
        Section(header: Text("Drives")) {
            ForEach(config.drives) { drive in
                let driveIndex = config.drives.firstIndex(of: drive)!
                NavigationLink(destination: VMConfigDriveDetailsView(config: drive, triggerRefresh: $triggerRefresh, onDelete: {
                    config.drives.removeAll(where: { $0 == drive })
                    selectedDriveIndex = nil
                }).scrollable(), tag: driveIndex, selection: $selectedDriveIndex) {
                    Label(label(for: drive), systemImage: "externaldrive")
                }
            }.onMove { offsets, index in
                config.drives.move(fromOffsets: offsets, toOffset: index)
            }
            VMConfigNewDriveButton(config: config, qemuSystem: config.system)
                .buttonStyle(.link)
        }.onChange(of: triggerRefresh) { _ in
            // HACK: we need edits of drive to trigger a redraw
        }
    }
    
    private func label(for drive: UTMQemuConfigurationDrive) -> String {
        if drive.interface == .none && drive.imageName == QEMUPackageFileName.efiVariables.rawValue {
            return NSLocalizedString("EFI Variables", comment: "VMQEMUSettingsView")
        } else {
            return NSLocalizedString("\(drive.interface.prettyValue) Drive", comment: "VMQEMUSettingsView")
        }
    }
}

struct VMQEMUSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMQEMUSettingsView(config: config, selectedDriveIndex: .constant(0))
    }
}
