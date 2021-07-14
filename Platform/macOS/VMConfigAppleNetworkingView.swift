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
    @State private var mode: Network.NetworkMode?
    @State private var bridgedInterface: String?
    
    var body: some View {
        Form {
            Picker("Network Mode", selection: $mode) {
                Text("None")
                    .tag(nil as Network.NetworkMode?)
                ForEach(Network.NetworkMode.allCases) { mode in
                    Text(mode.rawValue)
                        .tag(mode as Network.NetworkMode?)
                }
            }
            if let mode = mode {
                HStack {
                    TextField("MAC Address", text: .constant("(none)"))
                    Button("Random") {
                        
                    }
                }
            }
            if mode == .Bridged {
                Section(header: Text("Bridged Settings")) {
                    Picker("Interface", selection: $bridgedInterface) {
                        ForEach(VZBridgedNetworkInterface.networkInterfaces, id: \.identifier) { interface in
                            Text(interface.identifier)
                                .tag(interface.identifier as String?)
                        }
                    }
                }
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
