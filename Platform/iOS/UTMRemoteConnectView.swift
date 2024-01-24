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

struct UTMRemoteConnectView: View {
    @ObservedObject var remoteClientState: UTMRemoteClient.State
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var data: UTMData
    @State private var selectedServer: UTMRemoteClient.State.Server?
    @State private var isAutoConnect: Bool = false

    private var idiom: UIUserInterfaceIdiom {
        UIDevice.current.userInterfaceIdiom
    }

    private var remoteClient: UTMRemoteClient {
        data.remoteClient
    }

    var body: some View {
        VStack {
            HStack {
                ProgressView().progressViewStyle(.circular)
                Spacer()
                Button {
                    openURL(URL(string: "https://docs.getutm.app/remote/")!)
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                Button {

                } label: {
                    Label("New Connection", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
            }.padding()
            List {
                Section(header: Text("Saved")) {
                    ForEach(remoteClientState.savedServers) { server in
                        Button {
                            isAutoConnect = true
                            selectedServer = server
                        } label: {
                            Text(server.name)
                        }.contextMenu {
                            Button {
                                isAutoConnect = false
                                selectedServer = server
                            } label: {
                                Label("Edit…", systemImage: "slider.horizontal.3")
                            }
                            DestructiveButton("Delete") {

                            }
                        }
                    }.onDelete { indexSet in

                    }
                }
                Section(header: Text("Found")) {
                    ForEach(remoteClientState.foundServers) { server in
                        Button {
                            isAutoConnect = true
                            selectedServer = server
                        } label: {
                            Text(server.name)
                        }
                    }
                }
            }.listStyle(.plain)
        }.frame(maxWidth: idiom == .pad ? 600 : nil)
        .sheet(item: $selectedServer) { server in
            ServerConnectView(remoteClientState: remoteClientState, server: server, isAutoConnect: $isAutoConnect)
        }
        .onAppear {
            Task {
                await remoteClient.startScanning()
            }
        }
        .onDisappear {
            Task {
                await remoteClient.stopScanning()
            }
        }
    }
}

private struct ServerConnectView: View {
    @ObservedObject var remoteClientState: UTMRemoteClient.State
    @State var server: UTMRemoteClient.State.Server
    @Binding var isAutoConnect: Bool

    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>

    @State private var isConnecting: Bool = false
    @State private var isPasswordRequired: Bool = false
    @State private var willBeSaved: Bool = true

    private var remoteClient: UTMRemoteClient {
        data.remoteClient
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $server.name)
                    TextField("Server", text: .constant(server.hostname))
                } header: {
                    Text("Connection")
                }
                if isPasswordRequired {
                    Section {
                        if #available(iOS 15, *) {
                            FocusedPasswordView(password: $server.password.bound)
                        } else {
                            SecureField("Password", text: $server.password.bound)
                        }
                    } header: {
                        Text("Authentication")
                    }
                }
                Section {
                    Toggle("Save Connection", isOn: $willBeSaved)
                } header: {
                    Text("Options")
                }
            }.disabled(isConnecting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Close")
                    }.disabled(isConnecting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if isConnecting {
                            ProgressView().progressViewStyle(.circular)
                            Button {
                                connect()
                            } label: {
                                Text("Cancel")
                            }
                        } else {
                            Button {
                                connect()
                            } label: {
                                Text("Connect")
                            }
                        }
                    }
                }
            }
        }
        .alert(item: $remoteClientState.alertMessage) { item in
            Alert(title: Text(item.message))
        }
        .onAppear {
            if isAutoConnect {
                connect()
            }
        }
    }

    private func connect() {
        Task {
            isConnecting = true
            do {
                try await remoteClient.connect(server, shouldSaveDetails: willBeSaved)
            } catch {
                if case UTMRemoteClient.ConnectionError.passwordRequired = error {
                    withAnimation {
                        isPasswordRequired = true
                    }
                } else {
                    remoteClientState.showErrorAlert(error.localizedDescription)
                }
            }
            isConnecting = false
        }
    }
}

@available(iOS 15, *)
private struct FocusedPasswordView: View {
    @Binding var password: String

    @FocusState private var isFocused: Bool

    var body: some View {
        SecureField("Password", text: $password)
            .focused($isFocused)
            .onAppear {
                isFocused = true
            }
    }
}

#Preview {
    UTMRemoteConnectView(remoteClientState: .init())
}
