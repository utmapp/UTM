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

struct VMAppleSettingsAddDeviceMenuView: View {
    @ObservedObject var config: UTMAppleConfiguration
    
    private var isAddDisplayEnabled: Bool {
        if #available(macOS 13, *), config.displays.isEmpty && config.system.boot.operatingSystem != .none {
            return true
        } else if #available(macOS 12, *), config.displays.isEmpty && config.system.boot.operatingSystem == .macOS {
            return true
        } else {
            return false
        }
    }
    
    var body: some View {
        Menu {
            Button {
                let newDisplay = UTMAppleConfigurationDisplay()
                config.displays.append(newDisplay)
            } label: {
                Label("Display", systemImage: "rectangle.on.rectangle")
            }.disabled(!isAddDisplayEnabled)
            Button {
                let newSerial = UTMAppleConfigurationSerial()
                config.serials.append(newSerial)
            } label: {
                Label("Serial", systemImage: "rectangle.connected.to.line.below")
            }
            Button {
                let newNetwork = UTMAppleConfigurationNetwork()
                config.networks.append(newNetwork)
            } label: {
                Label("Network", systemImage: "network")
            }
        } label: {
            Label("New…", systemImage: "plus")
        }.help("Add a new device.")
        .menuStyle(.borderlessButton)
    }
}

struct VMAppleSettingsAddDeviceMenuView_Previews: PreviewProvider {
    @StateObject static private var config = UTMAppleConfiguration()
    
    static var previews: some View {
        VMAppleSettingsAddDeviceMenuView(config: config)
    }
}
