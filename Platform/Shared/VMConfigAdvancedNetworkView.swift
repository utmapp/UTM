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

@available(macOS 11, *)
struct VMConfigAdvancedNetworkView: View {
    @ObservedObject var config: UTMQemuConfiguration

    var body: some View {
        ScrollView {
            Form {
                IPConfigurationSection(config: config)
            }.padding()
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
