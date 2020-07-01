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

struct VMConfigNetworkPortForwardView: View {
    @ObservedObject var config: UTMConfiguration
    @StateObject private var newConfigPort = UTMConfigurationPortForward()
    @State private var editingNewPort = false
    @State private var selectedIndex = 0
    
    var body: some View {
        Section(header: HStack {
                Text("Port Forward")
                Spacer()
                Button(action: { editingNewPort = true }, label: {
                    Text("New")
                }).popover(isPresented: $editingNewPort, arrowEdge: .bottom) {
                    PortForwardEdit(config: config, configPort: UTMConfigurationPortForward(), index: config.countPortForwards).padding()
                        .frame(width: 250)
                }
            }, footer: EmptyView().padding(.bottom)) {
            List {
                ForEach(0..<config.countPortForwards, id: \.self) { index in
                    let configPort = config.portForward(for: index)!
                    let editingNewPortBinding = Binding<Bool> {
                        selectedIndex == index
                    } set: {
                        if $0 {
                            selectedIndex = index
                        } else {
                            selectedIndex = -1
                        }
                    }

                    Button(action: { editingNewPortBinding.wrappedValue = true }, label: {
                        Text("\(configPort.guestAddress ?? ""):\(String(configPort.guestPort)) ➡️ \(configPort.hostAddress ?? ""):\(String(configPort.hostPort)) (\(configPort.protocol ?? ""))")
                    }).buttonStyle(PlainButtonStyle())
                    .popover(isPresented: editingNewPortBinding, arrowEdge: .bottom) {
                        PortForwardEdit(config: config, configPort: configPort, index: index).padding()
                            .frame(width: 250)
                    }
                }
            }
        }
    }
}

struct PortForwardEdit: View {
    @ObservedObject var config: UTMConfiguration
    @StateObject var configPort: UTMConfigurationPortForward
    @State var index: Int
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        VStack {
            VMConfigPortForwardForm(configPort: configPort, index: index).multilineTextAlignment(.trailing)
            HStack {
                Spacer()
                Button(action: savePortForward, label: {
                    Text("Save")
                }).disabled(configPort.guestPort == 0 || configPort.hostPort == 0)
            }
        }
    }
    
    private func savePortForward() {
        config.updatePortForward(at: index, withValue: configPort)
        self.presentationMode.wrappedValue.dismiss()
    }
}

struct VMConfigNetworkPortForwardView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration(name: "Test")
    @State static private var configPort = UTMConfigurationPortForward()
    
    static var previews: some View {
        Group {
            Form {
                VMConfigNetworkPortForwardView(config: config)
            }.onAppear {
                if config.countPortForwards == 0 {
                    let newConfigPort = UTMConfigurationPortForward()
                    newConfigPort.protocol = "tcp"
                    newConfigPort.guestAddress = "1.2.3.4"
                    newConfigPort.guestPort = 1234
                    newConfigPort.hostAddress = "4.3.2.1"
                    newConfigPort.hostPort = 4321
                    config.newPortForward(newConfigPort)
                    newConfigPort.protocol = "udp"
                    newConfigPort.guestAddress = nil
                    newConfigPort.guestPort = 2222
                    newConfigPort.hostAddress = nil
                    newConfigPort.hostPort = 3333
                    config.newPortForward(newConfigPort)
                }
            }
        }
    }
}
