//
// Copyright © 2022 osy. All rights reserved.
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

struct VMSettingsAddDeviceMenuView: View {
    @ObservedObject var config: UTMQemuConfiguration
    @Binding var isCreateDriveShown: Bool
    @Binding var isImportDriveShown: Bool
    
    init(config: UTMQemuConfiguration, isCreateDriveShown: Binding<Bool>? = nil, isImportDriveShown: Binding<Bool>? = nil) {
        self.config = config
        if let isCreateDriveShown = isCreateDriveShown {
            _isCreateDriveShown = isCreateDriveShown
        } else {
            _isCreateDriveShown = .constant(false)
        }
        if let isImportDriveShown = isImportDriveShown {
            _isImportDriveShown = isImportDriveShown
        } else {
            _isImportDriveShown = .constant(false)
        }
    }
    
    private var isAddDisplayEnabled: Bool {
        if config.system.architecture == .sparc || config.system.architecture == .sparc64 {
            return config.displays.count < 1
        } else {
            return !config.system.architecture.displayDeviceType.allRawValues.isEmpty
        }
    }
    
    var body: some View {
        Menu {
            Button {
                let newDisplay = UTMQemuConfigurationDisplay(forArchitecture: config.system.architecture, target: config.system.target)
                config.displays.append(newDisplay!)
            } label: {
                Label("Display", systemImage: "rectangle.on.rectangle")
            }.disabled(!isAddDisplayEnabled)
            Button {
                let newSerial = UTMQemuConfigurationSerial(forArchitecture: config.system.architecture, target: config.system.target)
                config.serials.append(newSerial!)
            } label: {
                Label("Serial", systemImage: "rectangle.connected.to.line.below")
            }
            Button {
                let newNetwork = UTMQemuConfigurationNetwork(forArchitecture: config.system.architecture, target: config.system.target)
                config.networks.append(newNetwork!)
            } label: {
                Label("Network", systemImage: "network")
            }.disabled(config.system.architecture.networkDeviceType.allRawValues.isEmpty)
            Button {
                let newSound = UTMQemuConfigurationSound(forArchitecture: config.system.architecture, target: config.system.target)
                config.sound.append(newSound!)
            } label: {
                Label("Sound", systemImage: "speaker.wave.2")
            }.disabled(config.system.architecture.soundDeviceType.allRawValues.isEmpty)
            #if os(iOS) || os(visionOS)
            Divider()
            Button {
                isImportDriveShown.toggle()
            } label: {
                Label("Import Drive…", systemImage: "externaldrive")
            }
            Button {
                isCreateDriveShown.toggle()
            } label: {
                Label("New Drive…", systemImage: "externaldrive.badge.plus")
            }
            #endif
        } label: {
            if #available(iOS 15, macOS 11, *) {
                Label("New…", systemImage: "plus")
            } else {
                Label("New…", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
        }.help("Add a new device.")
        .menuStyle(.borderlessButton)
    }
}

struct VMSettingsAddDeviceMenuView_Previews: PreviewProvider {
    @StateObject static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMSettingsAddDeviceMenuView(config: config)
    }
}
