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

@available(macOS 12, *)
struct VMConfigAppleNetworkingView: View {
    @ObservedObject var config: UTMAppleConfiguration
    @EnvironmentObject private var data: UTMData
    @State private var newMacAddress: String?
    
    private var networkMode: Binding<Network.NetworkMode?> {
        Binding<Network.NetworkMode?> {
            config.networkDevices.first?.networkMode
        } set: { newValue in
            if let mode = newValue {
                var newNetwork: Network
                if let network = config.networkDevices.first {
                    newNetwork = network
                    newNetwork.networkMode = mode
                } else {
                    newNetwork = Network(newInterfaceForMode: mode)
                }
                config.networkDevices = [newNetwork]
            } else {
                config.networkDevices = []
            }
        }
    }
    
    private var macAddress: Binding<String> {
        Binding<String> {
            if let newMacAddress = newMacAddress {
                return newMacAddress
            } else if !config.networkDevices.isEmpty {
                return config.networkDevices[0].macAddress
            } else {
                return ""
            }
        } set: { newValue in
            newMacAddress = newValue
        }
    }
    
    private var bridgeInterfaceIdentifier: Binding<String> {
        Binding<String> {
            config.networkDevices.first?.bridgeInterfaceIdentifier ?? ""
        } set: { newValue in
            if !config.networkDevices.isEmpty {
                config.networkDevices[0].bridgeInterfaceIdentifier = newValue
            }
        }
    }
    
    var body: some View {
        Form {
            Picker("Network Mode", selection: networkMode) {
                Text("None")
                    .tag(nil as Network.NetworkMode?)
                ForEach(Network.NetworkMode.allCases) { mode in
                    Text(mode.rawValue)
                        .tag(mode as Network.NetworkMode?)
                }
            }
            if let _ = networkMode.wrappedValue {
                HStack {
                    TextField("MAC Address", text: macAddress, onCommit: {
                        commitMacAddress()
                    })
                    Button("Random") {
                        let random = VZMACAddress.randomLocallyAdministered().string
                        newMacAddress = random
                        commitMacAddress()
                    }
                }
            }
            if networkMode.wrappedValue == .Bridged {
                Section(header: Text("Bridged Settings")) {
                    Picker("Interface", selection: bridgeInterfaceIdentifier) {
                        ForEach(VZBridgedNetworkInterface.networkInterfaces, id: \.identifier) { interface in
                            Text(interface.identifier)
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
        newMacAddress = nil
        if let _ = VZMACAddress(string: macAddress) {
            if !config.networkDevices.isEmpty {
                config.networkDevices[0].macAddress = macAddress
            }
        } else {
            data.busyWork {
                throw NSLocalizedString("Invalid MAC address.", comment: "VMConfigAppleNetworkingView")
            }
        }
    }
}

@available(macOS 12, *)
struct VMConfigAppleNetworkingView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfiguration()
    
    static var previews: some View {
        VMConfigAppleNetworkingView(config: config)
    }
}
