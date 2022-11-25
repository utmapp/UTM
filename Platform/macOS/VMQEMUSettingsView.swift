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
    @EnvironmentObject private var data: UTMData

    @State private var infoActive: Bool = true
    @State private var isResetConfig: Bool = false
    @State private var isNewDriveShown: Bool = false
    
    var body: some View {
        NavigationLink(destination: VMConfigInfoView(config: $config.information).scrollable(), isActive: $infoActive) {
            Label("Information", systemImage: "info.circle")
        }
        NavigationLink(destination: VMConfigSystemView(config: $config.system, isResetConfig: $isResetConfig).scrollable()) {
            Label("System", systemImage: "cpu")
        }.onChange(of: isResetConfig) { newValue in
            if newValue {
                config.reset(forArchitecture: config.system.architecture, target: config.system.target)
                isResetConfig = false
            }
        }
        NavigationLink(destination: VMConfigQEMUView(config: $config.qemu, system: $config.system, fetchFixedArguments: { config.generatedArguments }).scrollable()) {
            Label("QEMU", systemImage: "shippingbox")
        }
        NavigationLink(destination: VMConfigInputView(config: $config.input).scrollable()) {
            Label("Input", systemImage: "keyboard")
        }
        NavigationLink(destination: VMConfigSharingView(config: $config.sharing).scrollable()) {
            Label("Sharing", systemImage: "person.crop.circle")
        }
        Section(header: Text("Devices")) {
            ForEach($config.displays) { $display in
                NavigationLink(destination: VMConfigDisplayView(config: $display, system: $config.system).scrollable()) {
                    Label("Display", systemImage: "rectangle.on.rectangle")
                }.contextMenu {
                    DestructiveButton("Remove") {
                        config.displays.removeAll(where: { $0.id == display.id })
                    }
                }
            }
            ForEach($config.serials) { $serial in
                NavigationLink(destination: VMConfigSerialView(config: $serial, system: $config.system).scrollable()) {
                    Label("Serial", systemImage: "rectangle.connected.to.line.below")
                }.contextMenu {
                    DestructiveButton("Remove") {
                        config.serials.removeAll(where: { $0.id == serial.id })
                    }
                }
            }
            ForEach($config.networks) { $network in
                NavigationLink(destination: VMConfigNetworkView(config: $network, system: $config.system).scrollable()) {
                    Label("Network", systemImage: "network")
                }.contextMenu {
                    DestructiveButton("Remove") {
                        config.networks.removeAll(where: { $0.id == network.id })
                    }
                }
                if #available(macOS 12, *), network.mode == .emulated {
                    NavigationLink(destination: VMConfigNetworkPortForwardView(config: $network)) {
                        Label("Port Forward", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            .padding(.leading)
                    }
                }
            }
            ForEach($config.sound) { $sound in
                NavigationLink(destination: VMConfigSoundView(config: $sound, system: $config.system).scrollable()) {
                    Label("Sound", systemImage: "speaker.wave.2")
                }.contextMenu {
                    DestructiveButton("Remove") {
                        config.sound.removeAll(where: { $0.id == sound.id })
                    }
                }
            }
            VMSettingsAddDeviceMenuView(config: config)
        }
        Section(header: Text("Drives")) {
            VMDrivesSettingsView(drives: $config.drives, template: UTMQemuConfigurationDrive(forArchitecture: config.system.architecture, target: config.system.target))
        }
    }
}

struct VMQEMUSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMQEMUSettingsView(config: config)
    }
}
