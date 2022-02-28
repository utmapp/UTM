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
    @ObservedObject var config: UTMQemuConfiguration
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
                        VMConfigStringPicker("Emulated Network Card", selection: $config.networkCard, rawValues: UTMQemuConfiguration.supportedNetworkCards(forArchitecture: config.systemArchitecture), displayValues: UTMQemuConfiguration.supportedNetworkCards(forArchitecturePretty: config.systemArchitecture))
                    }
                }.disabled(UTMQemuConfiguration.supportedNetworkCards(forArchitecture: config.systemArchitecture)?.isEmpty ?? true)
                
                if config.networkEnabled {
                    HStack {
                        DefaultTextField("MAC Address", text: $config.networkCardMac.bound, prompt: "00:00:00:00:00:00")
                        Button("Random") {
                            config.networkCardMac = UTMQemuConfiguration.generateMacAddress()
                        }
                    }
                    
                    Toggle(isOn: $showAdvanced.animation(), label: {
                        Text("Show Advanced Settings")
                    })
                    
                    if showAdvanced {
                        #if os(macOS)
                        IPConfigurationSection(config: config)
                        #else
                        IPConfigurationSection(config: config).multilineTextAlignment(.trailing)
                        #endif
                    }
                    
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
    @ObservedObject var config: UTMQemuConfiguration
    
    var body: some View {
        VMConfigStringPicker("Network Mode", selection: $config.networkMode, rawValues: UTMQemuConfiguration.supportedNetworkModes(), displayValues: UTMQemuConfiguration.supportedNetworkModesPretty())
        if config.networkMode == "bridged" {
            DefaultTextField("Bridged Interface", text: $config.networkBridgeInterface.bound, prompt: "en0")
                .keyboardType(.asciiCapable)
        }
    }
}

@available(iOS 14, macOS 11, *)
struct IPConfigurationSection: View {
    @ObservedObject var config: UTMQemuConfiguration
    
    var body: some View {
        Section(header: Text("IP Configuration")) {
            Toggle(isOn: $config.networkIsolate, label: {
                Text("Isolate Guest from Host")
            })
            Group {
                DefaultTextField("Guest Network", text: $config.networkAddress.bound, prompt: "10.0.2.0/24")
                    .keyboardType(.asciiCapable)
                DefaultTextField("Guest Network (IPv6)", text: $config.networkAddressIPv6.bound, prompt: "fec0::/64")
                    .keyboardType(.asciiCapable)
                DefaultTextField("Host Address", text: $config.networkHost.bound, prompt: "10.0.2.2")
                    .keyboardType(.decimalPad)
                DefaultTextField("Host Address (IPv6)", text: $config.networkHostIPv6.bound, prompt: "fec0::2")
                    .keyboardType(.asciiCapable)
                DefaultTextField("DHCP Start", text: $config.networkDhcpStart.bound, prompt: "10.0.2.15")
                    .keyboardType(.decimalPad)
                DefaultTextField("DHCP Host", text: $config.networkDhcpHost.bound)
                    .keyboardType(.asciiCapable)
                DefaultTextField("DHCP Domain Name", text: $config.networkDhcpDomain.bound)
                    .keyboardType(.asciiCapable)
                DefaultTextField("DNS Server", text: $config.networkDnsServer.bound, prompt: "10.0.2.3")
                    .keyboardType(.decimalPad)
                DefaultTextField("DNS Server (IPv6)", text: $config.networkDnsServerIPv6.bound, prompt: "fec0::3")
                    .keyboardType(.asciiCapable)
                DefaultTextField("DNS Search Domains", text: $config.networkDnsSearch.bound)
                    .keyboardType(.asciiCapable)
            }
        }.disableAutocorrection(true)
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigNetworkingView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMConfigNetworkView(config: config)
    }
}
