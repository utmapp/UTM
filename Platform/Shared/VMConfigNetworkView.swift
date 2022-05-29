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

@available(iOS 14, macOS 11, *)
struct VMConfigNetworkView: View {
    @ObservedObject var config: UTMLegacyQemuConfiguration
    @State private var showAdvanced: Bool = false
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Hardware")) {
                    #if os(macOS)
                    if #available(macOS 11.3, *) { // requires macOS 11.3 inherited sandbox fix
                        NetworkModeSection(config: config)
                    } else {
                        Toggle(isOn: $config.networkEnabled.animation(), label: {
                            Text("Enabled")
                        })
                    }
                    #else
                    Toggle(isOn: $config.networkEnabled.animation(), label: {
                        Text("Enabled")
                    })
                    #endif
                    if config.networkEnabled {
                        VMConfigStringPicker("Emulated Network Card", selection: $config.networkCard, rawValues: UTMLegacyQemuConfiguration.supportedNetworkCards(forArchitecture: config.systemArchitecture), displayValues: UTMLegacyQemuConfiguration.supportedNetworkCards(forArchitecturePretty: config.systemArchitecture))
                    }
                }.disabled(UTMLegacyQemuConfiguration.supportedNetworkCards(forArchitecture: config.systemArchitecture)?.isEmpty ?? true)
                
                if config.networkEnabled {
                    HStack {
                        DefaultTextField("MAC Address", text: $config.networkCardMac.bound, prompt: "00:00:00:00:00:00")
                        Button("Random") {
                            config.networkCardMac = UTMLegacyQemuConfiguration.generateMacAddress()
                        }
                    }

                    #if os(iOS)
                    Toggle(isOn: $showAdvanced.animation(), label: {
                        Text("Show Advanced Settings")
                    })

                    if showAdvanced {
                        Section(header: Text("IP Configuration")) {
                            IPConfigurationSection(config: config).multilineTextAlignment(.trailing)
                        }
                    }
                    #endif

                    /// Bridged and shared networking doesn't support port forwarding
                    if config.networkMode == "emulated" {
                        VMConfigNetworkPortForwardView(config: config)
                    }
                }
            }
        }
    }
}

@available(iOS 14, macOS 11, *)
struct NetworkModeSection: View {
    @ObservedObject var config: UTMLegacyQemuConfiguration
    
    var body: some View {
        VMConfigStringPicker("Network Mode", selection: $config.networkMode, rawValues: UTMLegacyQemuConfiguration.supportedNetworkModes(), displayValues: UTMLegacyQemuConfiguration.supportedNetworkModesPretty())
        if config.networkMode == "bridged" {
            DefaultTextField("Bridged Interface", text: $config.networkBridgeInterface.bound, prompt: "en0")
                .keyboardType(.asciiCapable)
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigNetworkingView_Previews: PreviewProvider {
    @State static private var config = UTMLegacyQemuConfiguration()
    
    static var previews: some View {
        VMConfigNetworkView(config: config)
    }
}
