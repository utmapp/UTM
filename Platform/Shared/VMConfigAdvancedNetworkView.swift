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
@available(iOS, introduced: 14, unavailable)
struct VMConfigAdvancedNetworkView: View {
    @Binding var config: UTMQemuConfigurationNetwork

    var body: some View {
        ScrollView {
            Form {
                IPConfigurationSection(config: $config)
            }.padding()
        }
    }
}

struct IPConfigurationSection: View {
    @Binding var config: UTMQemuConfigurationNetwork

    var body: some View {
        Toggle(isOn: $config.isIsolateFromHost, label: {
            Text("Isolate Guest from Host")
        })
        Group {
            DefaultTextField("Guest Network", text: $config.vlanGuestAddress.bound, prompt: "10.0.2.0/24")
                .keyboardType(.asciiCapable)
            DefaultTextField("Guest Network (IPv6)", text: $config.vlanGuestAddressIPv6.bound, prompt: "fec0::/64")
                .keyboardType(.asciiCapable)
            if config.mode == .emulated {
                DefaultTextField("Host Address", text: $config.vlanHostAddress.bound, prompt: "10.0.2.2")
                    .keyboardType(.decimalPad)
                DefaultTextField("Host Address (IPv6)", text: $config.vlanHostAddressIPv6.bound, prompt: "fec0::2")
                    .keyboardType(.asciiCapable)
            }
            DefaultTextField("DHCP Start", text: $config.vlanDhcpStartAddress.bound, prompt: "10.0.2.15")
                .keyboardType(.decimalPad)
            if config.mode != .emulated {
                DefaultTextField("DHCP End", text: $config.vlanDhcpEndAddress.bound, prompt: "10.0.2.254")
                    .keyboardType(.decimalPad)
            }
            if config.mode == .emulated {
                DefaultTextField("DHCP Domain Name", text: $config.vlanDhcpDomain.bound)
                    .keyboardType(.asciiCapable)
                DefaultTextField("DNS Server", text: $config.vlanDnsServerAddress.bound, prompt: "10.0.2.3")
                    .keyboardType(.decimalPad)
                DefaultTextField("DNS Server (IPv6)", text: $config.vlanDnsServerAddressIPv6.bound, prompt: "fec0::3")
                    .keyboardType(.asciiCapable)
                DefaultTextField("DNS Search Domains", text: $config.vlanDnsSearchDomain.bound)
                    .keyboardType(.asciiCapable)
            }
        }.disableAutocorrection(true)
    }
}
