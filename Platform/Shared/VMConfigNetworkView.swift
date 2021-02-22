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
    @ObservedObject var config: UTMConfiguration
    @State private var showAdvanced: Bool = false
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Hardware"), footer: EmptyView().padding(.bottom)) {
                    Toggle(isOn: $config.networkEnabled.animation(), label: {
                        Text("Enabled")
                    })
                    if config.networkEnabled {
                        VMConfigStringPicker(selection: $config.networkCard, label: Text("Emulated Network Card"), rawValues: UTMConfiguration.supportedNetworkCards(forArchitecture: config.systemArchitecture), displayValues: UTMConfiguration.supportedNetworkCards(forArchitecturePretty: config.systemArchitecture))
                    }
                }.disabled(UTMConfiguration.supportedNetworkCards(forArchitecture: config.systemArchitecture)?.isEmpty ?? true)
                
                if config.networkEnabled {
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
                    
                    VMConfigNetworkPortForwardView(config: config)
                }
            }
        }
    }
}

@available(iOS 14, macOS 11, *)
struct IPConfigurationSection: View {
    @ObservedObject var config: UTMConfiguration
    
    var body: some View {
        Section(header: Text("IP Configuration"), footer: EmptyView().padding(.bottom)) {
            Toggle(isOn: $config.networkIsolate, label: {
                Text("Isolate Guest from Host")
            })
            Group {
                HStack {
                    Text("Guest Network")
                    Spacer()
                    TextField("10.0.2.0/24", text: $config.networkAddress.bound)
                        .keyboardType(.asciiCapable)
                }
                HStack {
                    Text("Guest Network (IPv6)")
                    Spacer()
                    TextField("fec0::/64", text: $config.networkAddressIPv6.bound)
                        .keyboardType(.asciiCapable)
                }
                HStack {
                    Text("Host Address")
                    Spacer()
                    TextField("10.0.2.2", text: $config.networkHost.bound)
                        .keyboardType(.decimalPad)
                }
                HStack {
                    Text("Host Address (IPv6)")
                    Spacer()
                    TextField("fec0::2", text: $config.networkHostIPv6.bound)
                        .keyboardType(.asciiCapable)
                }
                HStack {
                    Text("DHCP Start")
                    Spacer()
                    TextField("10.0.2.0.15", text: $config.networkDhcpStart.bound)
                        .keyboardType(.decimalPad)
                }
                HStack {
                    Text("DHCP Host")
                    Spacer()
                    TextField("", text: $config.networkDhcpHost.bound)
                        .keyboardType(.asciiCapable)
                }
                HStack {
                    Text("DHCP Domain Name")
                    Spacer()
                    TextField("", text: $config.networkDhcpDomain.bound)
                        .keyboardType(.asciiCapable)
                }
                HStack {
                    Text("DNS Server")
                    Spacer()
                    TextField("10.0.2.0.15", text: $config.networkDnsServer.bound)
                        .keyboardType(.decimalPad)
                }
                HStack {
                    Text("DNS Server (IPv6)")
                    Spacer()
                    TextField("fec0::3", text: $config.networkDnsServerIPv6.bound)
                        .keyboardType(.asciiCapable)
                }
                HStack {
                    Text("DNS Search Domains")
                    Spacer()
                    TextField("", text: $config.networkDnsSearch.bound)
                        .keyboardType(.asciiCapable)
                }
            }
        }.disableAutocorrection(true)
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigNetworkingView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMConfigNetworkView(config: config)
    }
}
