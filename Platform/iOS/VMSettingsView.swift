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

struct VMSettingsView: View {
    let vm: VMData
    @ObservedObject var config: UTMQemuConfiguration
    
    @State private var isResetConfig: Bool = false
    @StateObject private var devicesState = DevicesState()
    
    @StateObject private var globalFileImporterShim = GlobalFileImporterShim()
    
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        NavigationView {
            Form {
                List {
                    NavigationLink(
                        destination: VMConfigInfoView(config: $config.information).navigationTitle("Information"),
                        label: {
                            Label("Information", systemImage: "info.circle")
                                .labelStyle(.roundRectIcon)
                        })
                    NavigationLink(
                        destination: VMConfigSystemView(config: $config.system, isResetConfig: $isResetConfig).navigationTitle("System"),
                        label: {
                            Label("System", systemImage: "cpu")
                                .labelStyle(.roundRectIcon)
                        })
                    .onChange(of: isResetConfig) { newValue in
                        if newValue {
                            config.reset(forArchitecture: config.system.architecture, target: config.system.target)
                            isResetConfig = false
                        }
                    }
                    NavigationLink(
                        destination: VMConfigQEMUView(config: $config.qemu, system: $config.system, fetchFixedArguments: {
                            config.generatedArguments
                        }).navigationTitle("QEMU"),
                        label: {
                            Label("QEMU", systemImage: "shippingbox")
                                .labelStyle(.roundRectIcon)
                        })
                    NavigationLink(
                        destination: VMConfigInputView(config: $config.input, hasUsbSupport: config.system.architecture.hasUsbSupport).navigationTitle("Input"),
                        label: {
                            Label("Input", systemImage: "keyboard")
                                .labelStyle(.roundRectIcon)
                        })
                    NavigationLink(
                        destination: VMConfigSharingView(config: $config.sharing).navigationTitle("Sharing"),
                        label: {
                            Label("Sharing", systemImage: "person.crop.circle")
                                .labelStyle(.roundRectIcon)
                        })
                    Devices(config: config, state: devicesState)
                }
            }
            #if !os(visionOS)
            .navigationTitle("Settings")
            #endif
            .navigationViewStyle(.stack)
            .settingsNavigation(addDeviceContent: {
                VMSettingsAddDeviceMenuView(config: config, isCreateDriveShown: $devicesState.isCreateDriveShown, isImportDriveShown: $devicesState.isImportDriveShown)
            }, editContent: {
                EditButton()
            }, cancelContent: {
                Button(action: cancel) {
                    Text("Cancel")
                }
            }, saveContent: {
                Button(action: save) {
                    Text("Save")
                }
            })
            .fileImporter(isPresented: $globalFileImporterShim.isPresented, allowedContentTypes: globalFileImporterShim.allowedContentTypes, onCompletion: globalFileImporterShim.onCompletion)
        }.environmentObject(globalFileImporterShim)
        .disabled(data.busy)
        .overlay(BusyOverlay())
    }
    
    func save() {
        data.busyWorkAsync {
            try await data.save(vm: vm)
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    func cancel() {
        presentationMode.wrappedValue.dismiss()
        data.busyWork {
            try data.discardChanges(for: self.vm)
        }
    }
}

/// Private state shared between VMSettingsView and Devices
///
/// You may be reading this and wonder "why not use @State and @Binding instead?" Well, after a long session of debugging, it was revealed that lots of odd behaviours happen before
/// trial and error led us to the following code. For example, settings would not get updated, or updating settings would cause random crashes, or deleting a device crashes. (Seems to be
/// limited to iOS 14). Anyways, this code is less than optimal but it's what resulted from a natural evolution of code that would not cause any (known) problems in iOS 14.
private class DevicesState: ObservableObject {
    @Published var isCreateDriveShown: Bool = false
    @Published var isImportDriveShown: Bool = false
}

private struct Devices: View {
    @ObservedObject var config: UTMQemuConfiguration
    @ObservedObject var state: DevicesState
    
    var body: some View {
        Section(header: Text("Devices")) {
            ForEach($config.displays) { $display in
                NavigationLink(destination: VMConfigDisplayView(config: $display, system: $config.system).navigationTitle("Display")) {
                    Label("Display", systemImage: "rectangle.on.rectangle")
                        .labelStyle(RoundRectIconLabelStyle(color: .green))
                }
            }.onDelete { offsets in
                config.displays.remove(atOffsets: offsets)
            }
            ForEach($config.serials) { $serial in
                NavigationLink(destination: VMConfigSerialView(config: $serial, system: $config.system).navigationTitle("Serial")) {
                    Label("Serial", systemImage: "rectangle.connected.to.line.below")
                        .labelStyle(RoundRectIconLabelStyle(color: .green))
                }
            }.onDelete { offsets in
                config.serials.remove(atOffsets: offsets)
            }
            ForEach($config.networks) { $network in
                NavigationLink(destination: VMConfigNetworkView(config: $network, system: $config.system).navigationTitle("Network")) {
                    Label("Network", systemImage: "network")
                        .labelStyle(RoundRectIconLabelStyle(color: .green))
                }
            }.onDelete { offsets in
                config.networks.remove(atOffsets: offsets)
            }
            ForEach($config.sound) { $sound in
                NavigationLink(destination: VMConfigSoundView(config: $sound, system: $config.system).navigationTitle("Sound")) {
                    Label("Sound", systemImage: "speaker.wave.2")
                        .labelStyle(RoundRectIconLabelStyle(color: .green))
                }
            }.onDelete { offsets in
                config.sound.remove(atOffsets: offsets)
            }
        }
        Section(header: Text("Drives")) {
            VMDrivesSettingsView(config: config, isCreateDriveShown: $state.isCreateDriveShown, isImportDriveShown: $state.isImportDriveShown)
                .labelStyle(RoundRectIconLabelStyle(color: .yellow))
        }
    }
}

struct RoundRectIconLabelStyle: LabelStyle {
    var color: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        Label(
            title: { configuration.title },
            icon: {
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 10.0, style: .circular)
                        .frame(width: 32, height: 32)
                        .foregroundColor(color)
                    configuration.icon.foregroundColor(.white)
                        .imageScale(.medium)
                }
            })
    }
}

extension LabelStyle where Self == RoundRectIconLabelStyle {
    static var roundRectIcon: RoundRectIconLabelStyle {
        RoundRectIconLabelStyle()
    }
}

private extension View {
    @ViewBuilder func settingsNavigation(@ViewBuilder addDeviceContent: () -> some View, @ViewBuilder editContent: () -> some View, @ViewBuilder cancelContent: () -> some View, @ViewBuilder saveContent: () -> some View) -> some View {
        if #available(iOS 26, visionOS 26, *) {
            self.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    addDeviceContent()
                }
                #if os(iOS)
                ToolbarSpacer(placement: .topBarLeading)
                #endif
                ToolbarItem(placement: .topBarLeading) {
                    editContent()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    cancelContent()
                }
                #if os(iOS)
                ToolbarSpacer(placement: .topBarTrailing)
                #endif
                ToolbarItem(placement: .topBarTrailing) {
                    saveContent()
                }
            }
        } else {
            self.navigationBarItems(leading: HStack {
                addDeviceContent()
                editContent()
            }, trailing: HStack {
                cancelContent()
                saveContent()
            })
        }
    }
}

struct VMSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMSettingsView(vm: VMData(from: .empty), config: config)
    }
}
