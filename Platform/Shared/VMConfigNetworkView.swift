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

struct VMConfigNetworkView: View {
    @Binding var config: UTMQemuConfigurationNetwork
    @Binding var system: UTMQemuConfigurationSystem
    @State private var showAdvanced: Bool = false
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Hardware")) {
                    #if os(macOS)
                    VMConfigConstantPicker("Network Mode", selection: $config.mode)
                    if config.mode == .bridged {
                        DefaultTextField("Bridged Interface", text: $config.bridgeInterface.bound, prompt: "en0")
                            .keyboardType(.asciiCapable)
                    }
                    #endif
                    VMConfigConstantPicker("Emulated Network Card", selection: $config.hardware, type: system.architecture.networkDeviceType)
                }
                
                HStack {
                    DefaultTextField("MAC Address", text: $config.macAddress, prompt: "00:00:00:00:00:00")
                    Button("Random") {
                        config.macAddress = UTMQemuConfigurationNetwork.randomMacAddress()
                    }
                }

                Toggle(isOn: $showAdvanced.animation(), label: {
                    Text("Show Advanced Settings")
                })

                if showAdvanced {
                    Section(header: Text("IP Configuration")) {
                        IPConfigurationSection(config: $config).multilineTextAlignment(.trailing)
                    }
                }

                #if os(macOS)
                /// Bridged and shared networking doesn't support port forwarding
                if #unavailable(macOS 12), config.mode == .emulated {
                    VMConfigNetworkPortForwardLegacyView(config: $config)
                }
                #else
                VMConfigNetworkPortForwardView(config: $config)
                #endif
            }
        }
    }
}

struct VMConfigNetworkingView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationNetwork()
    @State static private var system = UTMQemuConfigurationSystem()
    
    static var previews: some View {
        VMConfigNetworkView(config: $config, system: $system)
    }
}
