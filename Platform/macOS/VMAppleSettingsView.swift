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

struct VMAppleSettingsView: View {
    @ObservedObject var config: UTMAppleConfiguration
    
    @State private var infoActive: Bool = true
    
    private var hasVenturaFeatures: Bool {
        if #available(macOS 13, *) {
            return true
        } else {
            return false
        }
    }
    
    var body: some View {
        NavigationLink(destination: VMConfigInfoView(config: $config.information).scrollable().settingsToolbar(), isActive: $infoActive) {
            Label("Information", systemImage: "info.circle")
        }
        NavigationLink {
            VMConfigAppleSystemView(config: $config.system)
                .scrollable()
                .settingsToolbar()
        } label: {
            Label("System", systemImage: "cpu")
        }
        NavigationLink {
            VMConfigAppleBootView(config: $config.system)
                .scrollable()
                .settingsToolbar()
        } label: {
            Label("Boot", systemImage: "power")
        }
        NavigationLink {
            VMConfigAppleVirtualizationView(config: $config.virtualization, operatingSystem: config.system.boot.operatingSystem)
                .scrollable()
                .settingsToolbar()
        } label: {
            Label("Virtualization", systemImage: "wrench.and.screwdriver")
        }
        if #available(macOS 12, *) {
            if hasVenturaFeatures || config.system.boot.operatingSystem == .linux {
                NavigationLink {
                    VMConfigAppleSharingView(config: config)
                        .padding()
                        .settingsToolbar()
                } label: {
                    Label("Sharing", systemImage: "person.crop.circle")
                }
            }
        }
        Section(header: Text("Devices")) {
            if #available(macOS 12, *) {
                if hasVenturaFeatures || config.system.boot.operatingSystem == .macOS {
                    ForEach($config.displays) { $display in
                        NavigationLink {
                            VMConfigAppleDisplayView(config: $display)
                                .scrollable()
                                .settingsToolbar {
                                    ToolbarItem(placement: .destructiveAction) {
                                        Button("Remove") {
                                            config.displays.removeAll(where: { $0.id == display.id })
                                            refresh()
                                        }
                                    }
                                }
                        } label: {
                            Label("Display", systemImage: "rectangle.on.rectangle")
                        }.contextMenu {
                            DestructiveButton("Remove") {
                                config.displays.removeAll(where: { $0.id == display.id })
                                refresh()
                            }
                        }
                    }
                }
            }
            ForEach($config.serials) { $serial in
                NavigationLink {
                    VMConfigAppleSerialView(config: $serial)
                        .scrollable()
                        .settingsToolbar {
                            ToolbarItem(placement: .destructiveAction) {
                                Button("Remove") {
                                    config.serials.removeAll(where: { $0.id == serial.id })
                                    refresh()
                                }
                            }
                        }
                } label: {
                    Label("Serial", systemImage: "rectangle.connected.to.line.below")
                }.contextMenu {
                    DestructiveButton("Remove") {
                        config.serials.removeAll(where: { $0.id == serial.id })
                        refresh()
                    }
                }
            }
            ForEach($config.networks) { $network in
                NavigationLink {
                    VMConfigAppleNetworkingView(config: $network)
                        .scrollable()
                        .settingsToolbar {
                            ToolbarItem(placement: .destructiveAction) {
                                Button("Remove") {
                                    config.networks.removeAll(where: { $0.id == network.id })
                                    refresh()
                                }
                            }
                        }
                } label: {
                    Label("Network", systemImage: "network")
                }.contextMenu {
                    DestructiveButton("Remove") {
                        config.networks.removeAll(where: { $0.id == network.id })
                        refresh()
                    }
                }
            }
            VMAppleSettingsAddDeviceMenuView(config: config)
        }
        Section(header: Text("Drives")) {
            VMDrivesSettingsView(drives: $config.drives, template: UTMAppleConfigurationDrive(newSize: 10240))
        }
    }

    private func refresh() {
        // SwiftUI bug: if a TextField is focused while a device is removed, the app will crash
        infoActive = true
    }
}

struct VMAppleSettingsView_Previews: PreviewProvider {
    @StateObject static var config = UTMAppleConfiguration()
    static var previews: some View {
        List {
            VMAppleSettingsView(config: config)
        }
        .frame(maxWidth: 400)
    }
}
