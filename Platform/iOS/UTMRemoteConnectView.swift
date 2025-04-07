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

private let kTimeoutSeconds: UInt64 = 60

struct UTMRemoteConnectView: View {
    @ObservedObject var remoteClientState: UTMRemoteClient.State
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var data: UTMRemoteData
    @State private var selectedServer: UTMRemoteClient.State.SavedServer?
    @State private var isAutoConnect: Bool = false

    private var remoteClient: UTMRemoteClient {
        data.remoteClient
    }

    var body: some View {
        VStack {
            HStack {
                if remoteClientState.isScanning {
                    ProgressView().progressViewStyle(.circular)
                }
                Spacer()
                Text("Select a UTM Server")
                    .font(.headline)
                Spacer()
                Button {
                    openURL(URL(string: "https://docs.getutm.app/remote/")!)
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                Button {
                    selectedServer = .init()
                } label: {
                    Label("New Connection", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
            }.padding()
            List {
                if remoteClientState.savedServers.count > 0 {
                    Section(header: Text("Saved")) {
                        ForEach(remoteClientState.savedServers) { server in
                            Button {
                                isAutoConnect = true
                                selectedServer = server
                            } label: {
                                MacDeviceLabel(server.name.isEmpty ? server.hostname : server.name, device: .init(model: server.model))
                            }.disabled(!server.isAvailable)
                            .contextMenu {
                                Button {
                                    isAutoConnect = false
                                    selectedServer = server
                                } label: {
                                    Label("Edit…", systemImage: "slider.horizontal.3")
                                }
                                DestructiveButton("Delete") {
                                    remoteClientState.delete(server: server)
                                    Task {
                                        await remoteClient.refresh()
                                    }
                                }
                            }
                        }.onDelete { indexSet in
                            remoteClientState.savedServers.remove(atOffsets: indexSet)
                            Task {
                                await remoteClient.refresh()
                            }
                        }
                    }
                }
                Section(header: Text("Discovered"), footer: helpText) {
                    ForEach(remoteClientState.foundServers) { server in
                        Button {
                            isAutoConnect = true
                            selectedServer = UTMRemoteClient.State.SavedServer(from: server)
                        } label: {
                            MacDeviceLabel(server.name, device: .init(model: server.model))
                        }
                    }
                }
            }.listStyle(.insetGrouped)
        }.alert(item: $remoteClientState.alertMessage) { item in
            Alert(title: Text(item.message), primaryButton: .default(Text("Open Settings")) {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }, secondaryButton: .cancel(Text("Retry")) {
                if !remoteClientState.isScanning {
                    Task {
                        await remoteClient.startScanning()
                    }
                }
            })
        }
        .sheet(item: $selectedServer) { server in
            if #available(iOS 15, *) {
                ServerConnectView(remoteClientState: remoteClientState, server: server, isAutoConnect: $isAutoConnect)
            } else {
                ServerConnectView(remoteClientState: remoteClientState, server: server, isAutoConnect: $isAutoConnect)
                    .environmentObject(data)
            }
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
        .onChange(of: scenePhase) { newValue in
            if newValue == .active && !remoteClientState.isScanning {
                Task {
                    await remoteClient.startScanning()
                }
            }
        }
    }

    @ViewBuilder
    private var helpText: some View {
        if remoteClientState.foundServers.isEmpty {
            Text("Make sure the latest version of UTM is running on your Mac and UTM Server is enabled. You can download UTM from the Mac App Store.")
        }
    }
}

private struct ServerConnectView: View {
    @ObservedObject var remoteClientState: UTMRemoteClient.State
    @State var server: UTMRemoteClient.State.SavedServer
    @Binding var isAutoConnect: Bool

    @EnvironmentObject private var data: UTMRemoteData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>

    @State private var connectionTask: Task<Void, Error>?
    private var isConnecting: Bool {
        connectionTask != nil
    }
    @State private var isPasswordRequired: Bool = false
    @State private var isTrustButton: Bool = false

    private var remoteClient: UTMRemoteClient {
        data.remoteClient
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if #available(iOS 15, *) {
                        TextField("", text: $server.name, prompt: Text("Name (optional)"))
                    } else {
                        DefaultTextField("", text: $server.name, prompt: "Name (optional)")
                    }
                } header: {
                    Text("Name")
                }
                Section {
                    if server.endpoint != nil {
                        Text(server.hostname)
                    } else {
                        if #available(iOS 15, *) {
                            TextField("", text: $server.hostname, prompt: Text("Hostname or IP address"))
                                .keyboardType(.asciiCapable)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            TextField("", value: $server.port, format: .number.grouping(.never), prompt: Text("Port"))
                                .keyboardType(.decimalPad)
                        } else {
                            DefaultTextField("", text: $server.hostname, prompt: "Hostname or IP address")
                                .keyboardType(.asciiCapable)
                                .autocorrectionDisabled()
                            NumberTextField("", number: $server.port, prompt: "Port")
                        }
                    }
                } header: {
                    Text("Host")
                }
                let fingerprint = (server.fingerprint ^ remoteClient.fingerprint).hexString()
                if !fingerprint.isEmpty {
                    Section {
                        if #available(iOS 16.4, *) {
                            Text(fingerprint).monospaced()
                        } else {
                            Text(fingerprint)
                        }
                    } header: {
                        Text("Fingerprint")
                    }
                }
                if isPasswordRequired {
                    Section {
                        if #available(iOS 15, *) {
                            FocusedPasswordView(password: $server.password.bound)
                        } else {
                            SecureField("Password", text: $server.password.bound)
                        }
                        Toggle("Save Password", isOn: $server.shouldSavePassword)
                    } header: {
                        Text("Password")
                    }
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
                                connectionTask?.cancel()
                            } label: {
                                Text("Cancel")
                            }
                        } else {
                            Button {
                                connect()
                            } label: {
                                if isTrustButton {
                                    Text("Trust")
                                } else {
                                    Text("Connect")
                                }
                            }.disabled(server.hostname.isEmpty || !server.isAvailable)
                        }
                    }
                }
            }
        }
        .onAppear {
            // if we have an existing password, assume it should be saved
            if server.password?.isEmpty == false {
                server.shouldSavePassword = true
            }
            if isAutoConnect {
                connect()
            }
        }
        .alert(item: $remoteClientState.alertMessage) { item in
            Alert(title: Text(item.message))
        }
    }

    private func connect() {
        guard connectionTask == nil else {
            return
        }
        connectionTask = Task {
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: kTimeoutSeconds * NSEC_PER_SEC)
                connectionTask?.cancel()
                remoteClientState.showErrorAlert(NSLocalizedString("Timed out trying to connect.", comment: "UTMRemoteConnectView"))
            }
            if #available(iOS 15, *) {
                await _connect()
            } else {
                Task(priority: .userInteractive) {
                    await _connect()
                }
            }
            timeoutTask.cancel()
            connectionTask = nil
        }
    }

    private func _connect() async {
        do {
            try await remoteClient.connect(server)
        } catch {
            if case UTMRemoteClient.ConnectionError.passwordRequired = error {
                withAnimation {
                    isPasswordRequired = true
                    isTrustButton = false
                }
            } else if case UTMRemoteClient.ConnectionError.fingerprintUntrusted(let fingerprint) = error, server.fingerprint.isEmpty {
                withAnimation {
                    server.fingerprint = fingerprint
                    isTrustButton = true
                }
                remoteClientState.showErrorAlert(error.localizedDescription)
            } else if error is CancellationError {
                // ignore it
            } else {
                remoteClientState.showErrorAlert(error.localizedDescription)
            }
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
