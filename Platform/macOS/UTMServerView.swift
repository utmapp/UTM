//
// Copyright © 2023 osy. All rights reserved.
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

@available(macOS 13, *)
struct UTMServerView: View {
    @EnvironmentObject private var remoteServer: UTMRemoteServer.State
    @State private var isDeletingAll: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Toggle("Enable UTM Server", isOn: Binding<Bool>(get: {
                    remoteServer.isServerActive
                }, set: { value in
                    if value {
                        remoteServer.requestServerAction(.start)
                    } else {
                        remoteServer.requestServerAction(.stop)
                    }
                }))
                Spacer()
                Button {
                    isDeletingAll = true
                } label: {
                    Text("Reset Identity")
                }
                .alert("Confirmation", isPresented: $isDeletingAll) {
                    Button(role: .destructive) {
                        remoteServer.allClients.removeAll()
                        remoteServer.requestServerAction(.reset)
                    } label: {
                        Text("Reset Identity")
                    }.keyboardShortcut(.defaultAction)
                } message: {
                    Text("Do you want to forget all clients and generate a new server identity? Any clients that previously paired with this server will be instructed to manually unpair with this server before they can connect again.")
                }
            }.padding([.top, .leading, .trailing])
            ServerOverview()
            Divider()
            HStack {
                if let address = remoteServer.externalIPAddress, let port = remoteServer.externalPort {
                    Text("Server IP: \(address), Port: \(String(port))")
                        .textSelection(.enabled)
                }
                Spacer()
                if remoteServer.isServerActive {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.green)
                    Text("Running")
                } else {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.red)
                    Text("Stopped")
                }
            }.padding([.bottom, .leading, .trailing])
        }.disabled(remoteServer.isBusy)
    }
}

@available(macOS 13, *)
fileprivate struct ServerOverview: View {
    @EnvironmentObject private var remoteServer: UTMRemoteServer.State
    @State private var sortOrder = [KeyPathComparator(\UTMRemoteServer.State.Client.name)]
    @State private var selectedFingerprints = Set<UTMRemoteServer.State.ClientFingerprint>()
    @State private var isDeleting: Bool = false

    var body: some View {
        Table(remoteServer.allClients, selection: $selectedFingerprints, sortOrder: $sortOrder) {
            TableColumn("") { client in
                if remoteServer.isConnected(client.fingerprint) {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.green)
                }
            }.width(16)
            TableColumn("Name", value: \.name)
                .width(ideal: 200)
            TableColumn("Fingerprint") { client in
                Text((client.fingerprint ^ remoteServer.serverFingerprint).hexString())
            }.width(ideal: 300)
            TableColumn("Last Seen", value: \.lastSeen) { client in
                Text(DateFormatter.localizedString(from: client.lastSeen, dateStyle: .short, timeStyle: .short))
            }.width(ideal: 150)
            TableColumn("Status") { client in
                if remoteServer.isConnected(client.fingerprint) {
                    Text("Connected")
                } else if remoteServer.isBlocked(client.fingerprint) {
                    Text("Blocked")
                } else if !remoteServer.isApproved(client.fingerprint) {
                    HStack {
                        Button {
                            remoteServer.approve(client.fingerprint)
                        } label: {
                            Text("Approve")
                        }.buttonStyle(.bordered)
                        Button {
                            remoteServer.block(client.fingerprint)
                        } label: {
                            Text("Block")
                        }.buttonStyle(.bordered)
                    }
                }
            }.width(ideal: 140)
        }
        .contextMenu(forSelectionType: UTMRemoteServer.State.ClientFingerprint.self) { items in
            if items.count == 1 {
                if remoteServer.isConnected(items.first!) {
                    Button {
                        remoteServer.disconnect(items.first!)
                    } label: {
                        Text("Disconnect")
                    }
                }
                if !remoteServer.isApproved(items.first!) {
                    Button {
                        remoteServer.approve(items.first!)
                    } label: {
                        Text("Approve")
                    }
                }
                if !remoteServer.isBlocked(items.first!) {
                    Button {
                        remoteServer.block(items.first!)
                    } label: {
                        Text("Block")
                    }
                }
            }
            if items.count > 0 {
                Button {
                    isDeleting = true
                    selectedFingerprints = items
                } label: {
                    Text("Delete")
                }
            }
        }
        .onChange(of: sortOrder) {
            remoteServer.allClients.sort(using: $0)
        }
        .onDeleteCommand {
            isDeleting = true
        }
        .alert("Confirmation", isPresented: $isDeleting) {
            Button(role: .destructive) {
                remoteServer.allClients.removeAll(where: { selectedFingerprints.contains($0.fingerprint) })
            } label: {
                Text("Delete")
            }.keyboardShortcut(.defaultAction)
        } message: {
            Text("Do you want to forget the selected client(s)?")
        }
    }
}

@available(macOS 13, *)
#Preview {
    UTMServerView()
}
