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
import Virtualization

struct VMConfigAppleNetworkingView: View {
    @Binding var config: UTMAppleConfigurationNetwork
    @EnvironmentObject private var data: UTMData
    @State private var newMacAddress: String?
    
    private var isHostOnlySupported: Bool {
        #if compiler(>=6.3)
        if #available(macOS 26, *) {
            return true
        } else {
            return false
        }
        #else
        return false
        #endif
    }

    var body: some View {
        Form {
            Picker("Network Mode", selection: $config.mode) {
                ForEach(UTMAppleConfigurationNetwork.NetworkMode.allCases, id: \.rawValue) { mode in
                    Text(mode.prettyValue)
                        .tag(mode)
                        .disabled(mode == .host && !isHostOnlySupported)
                }
            }
            HStack {
                TextField("MAC Address", text: $newMacAddress.bound, onCommit: {
                    commitMacAddress()
                })
                .onAppear {
                    newMacAddress = config.macAddress
                }
                Button("Random") {
                    let random = VZMACAddress.randomLocallyAdministered().string
                    newMacAddress = random
                    commitMacAddress()
                }
            }
            if config.mode == .host {
                Section(header: Text("Host Only Settings")) {
                    if isHostOnlySupported {
                        Text("The guest can communicate with this Mac, but not the internet.")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Host Only requires macOS 26 or later.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            if config.mode == .bridged {
                Section(header: Text("Bridged Settings")) {
                    Picker("Interface", selection: $config.bridgeInterface) {
                        Text("Automatic")
                            .tag(nil as String?)
                        ForEach(VZBridgedNetworkInterface.networkInterfaces, id: \.identifier) { interface in
                            Text(interface.localizedDisplayName.map { "\($0) (\(interface.identifier))" } ?? interface.identifier)
                                .tag(interface.identifier as String?)
                        }
                    }
                }
            }
        }
    }
    
    private func commitMacAddress() {
        guard let macAddress = newMacAddress else {
            return
        }
        if let _ = VZMACAddress(string: macAddress) {
            config.macAddress = macAddress
        } else {
            data.busyWork {
                throw NSLocalizedString("Invalid MAC address.", comment: "VMConfigAppleNetworkingView")
            }
        }
    }
}

struct VMConfigAppleNetworkingView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfigurationNetwork()
    
    static var previews: some View {
        VMConfigAppleNetworkingView(config: $config)
    }
}
