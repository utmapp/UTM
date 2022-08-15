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
    @Binding var config: UTMQemuConfigurationNetwork
    
    var body: some View {
        Section(header: Text("Port Forward")) {
            List {
                ForEach($config.portForward) { $forward in
                    NavigationLink(
                        destination: PortForwardEdit(forward: forward,
                                                     onSave: { forward = $0 },
                                                     onDelete: { config.portForward.removeAll(where: { $0 == forward }) }),
                        label: {
                            VStack(alignment: .leading) {
                                let guest = "\(forward.guestAddress ?? ""):\(forward.guestPort)"
                                let host = "\(forward.hostAddress ?? ""):\(forward.hostPort)"
                                Text("\(guest) ➡️ \(host)")
                                Text(forward.protocol.prettyValue).font(.subheadline)
                            }
                        })
                }.onDelete(perform: deletePortForwards)
                NavigationLink(
                    destination: PortForwardEdit(onSave: {
                        config.portForward.append($0)
                    }),
                    label: {
                        Text("New")
                })
            }
        }
    }
    
    private func deletePortForwards(offsets: IndexSet) {
        config.portForward.remove(atOffsets: offsets)
    }
}

struct PortForwardEdit: View {
    @State var forward: UTMQemuConfigurationPortForward = .init()
    var onSave: ((UTMQemuConfigurationPortForward) -> Void)
    var onDelete: (() -> Void)? = nil
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        Form {
            List {
                VMConfigPortForwardForm(forward: $forward).multilineTextAlignment(.trailing)
            }
        }.navigationBarItems(trailing:
            HStack {
                if let onDelete = self.onDelete {
                    Button(action: { closePopup(after: onDelete) }, label: {
                        Text("Delete")
                    }).foregroundColor(.red)
                    .padding()
                }
                Button(action: { closePopup(after: { onSave(forward) }) }, label: {
                    Text("Save")
                }).disabled(forward.guestPort == 0 || forward.hostPort == 0)
            }
        )
    }
    
    private func closePopup(after action: () -> Void) {
        action()
        self.presentationMode.wrappedValue.dismiss()
    }
}

struct VMConfigNetworkPortForwardView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationNetwork()
    static var previews: some View {
        Group {
            Form {
                VMConfigNetworkPortForwardView(config: $config)
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
            PortForwardEdit(onSave: { _ in })
        }
    }
}
