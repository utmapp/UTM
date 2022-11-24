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

@available(macOS 12, *)
struct VMConfigNetworkPortForwardView: View {
    @Binding var config: UTMQemuConfigurationNetwork
    @State private var isEditingNewPort = false
    @State private var isEditingExistingPort = false
    @State private var selectedId: UUID?
    @State private var editPortForward: UTMQemuConfigurationPortForward?
    
    var body: some View {
        VStack {
            Table(config.portForward, selection: $selectedId) {
                TableColumn("Protocol") { row in
                    Text(row.protocol.prettyValue)
                }
                TableColumn("Guest Address") { row in
                    Text(row.guestAddress ?? "")
                }
                TableColumn("Guest Port") { row in
                    Text(String(row.guestPort))
                }
                TableColumn("Host Address") { row in
                    Text(row.hostAddress ?? "")
                }
                TableColumn("Host Port") { row in
                    Text(String(row.hostPort))
                }
            }.onDoubleClick {
                editPortForward = config.portForward.first(where: { $0.id == selectedId })
            }
            HStack {
                Spacer()
                if let selectedId = selectedId {
                    Button("Delete") {
                        config.portForward.removeAll(where: { $0.id == selectedId })
                        self.selectedId = nil
                    }
                    Button("Edit…") {
                        editPortForward = config.portForward.first(where: { $0.id == selectedId })
                    }.popover(item: $editPortForward, arrowEdge: .top) { item in
                        PortForwardEdit(config: $config, forward: item).padding()
                            .frame(width: 250)
                    }
                }
                Button("New…") {
                    isEditingNewPort.toggle()
                }.popover(isPresented: $isEditingNewPort, arrowEdge: .top) {
                    PortForwardEdit(config: $config, forward: .init()).padding()
                        .frame(width: 250)
                }
            }.padding()
        }
    }
}

@available(macOS 11, *)
struct VMConfigNetworkPortForwardLegacyView: View {
    @Binding var config: UTMQemuConfigurationNetwork
    @State private var editingNewPort = false
    @State private var selectedPortForward: UTMQemuConfigurationPortForward?
    
    var body: some View {
        Section(header: HStack {
                Text("Port Forward")
                Spacer()
                Button(action: { editingNewPort = true }, label: {
                    Text("New…")
                }).popover(isPresented: $editingNewPort, arrowEdge: .bottom) {
                    PortForwardEdit(config: $config, forward: .init()).padding()
                        .frame(width: 250)
                }
            }) {
            VStack {
                ForEach(config.portForward) { forward in
                    let isPopoverShown = Binding<Bool> {
                        selectedPortForward == forward
                    } set: { value in
                        if value {
                            selectedPortForward = forward
                        } else {
                            selectedPortForward = nil
                        }
                    }

                    Button(action: { isPopoverShown.wrappedValue = true }, label: {
                        let guest = "\(forward.guestAddress ?? ""):\(forward.guestPort)"
                        let host = "\(forward.hostAddress ?? ""):\(forward.hostPort)"
                        Text("\(guest) ➡️ \(host)")
                    }).buttonStyle(.bordered)
                    .popover(isPresented: isPopoverShown, arrowEdge: .bottom) {
                        PortForwardEdit(config: $config, forward: forward).padding()
                            .frame(width: 250)
                    }
                }
            }
        }
    }
}

@available(macOS 11, *)
struct PortForwardEdit: View {
    @Binding var config: UTMQemuConfigurationNetwork
    @State var forward: UTMQemuConfigurationPortForward
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        VStack {
            VMConfigPortForwardForm(forward: $forward).multilineTextAlignment(.trailing)
            HStack {
                Spacer()
                let index = config.portForward.firstIndex(where: { $0.id == forward.id })
                if let index = index {
                    Button(action: {
                        config.portForward.remove(at: index)
                        closePopup()
                    }, label: {
                        Text("Delete")
                    })
                }
                Button(action: {
                    if let index = index {
                        config.portForward[index] = forward
                    } else {
                        config.portForward.append(forward)
                    }
                    closePopup()
                }, label: {
                    Text("Save")
                }).disabled(forward.guestPort == 0 || forward.hostPort == 0)
            }
        }
    }
    
    private func closePopup() {
        self.presentationMode.wrappedValue.dismiss()
    }
}

@available(macOS 11, *)
struct VMConfigNetworkPortForwardView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationNetwork()
    
    static var previews: some View {
        Group {
            Form {
                if #available(macOS 12, *) {
                    VMConfigNetworkPortForwardView(config: $config)
                } else {
                    VMConfigNetworkPortForwardLegacyView(config: $config)
                }
            }.onAppear {
                if config.portForward.count == 0 {
                    var newConfigPort = UTMQemuConfigurationPortForward()
                    newConfigPort.protocol = .tcp
                    newConfigPort.guestAddress = "1.2.3.4"
                    newConfigPort.guestPort = 1234
                    newConfigPort.hostAddress = "4.3.2.1"
                    newConfigPort.hostPort = 4321
                    config.portForward.append(newConfigPort)
                    newConfigPort.protocol = .udp
                    newConfigPort.guestAddress = ""
                    newConfigPort.guestPort = 2222
                    newConfigPort.hostAddress = ""
                    newConfigPort.hostPort = 3333
                    config.portForward.append(newConfigPort)
                }
            }
        }
    }
}
