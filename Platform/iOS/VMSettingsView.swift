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

@available(iOS 14, *)
struct VMSettingsView: View {
    let vm: UTMVirtualMachine?
    @ObservedObject var config: UTMConfiguration
    
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        NavigationView {
            Form {
                List {
                    NavigationLink(
                        destination: VMConfigInfoView(config: config).navigationTitle("Information"),
                        label: {
                            Label("Information", systemImage: "info.circle")
                                .labelStyle(RoundRectIconLabelStyle())
                        })
                    NavigationLink(
                        destination: VMConfigSystemView(config: config).navigationTitle("System"),
                        label: {
                            Label("System", systemImage: "cpu")
                                .labelStyle(RoundRectIconLabelStyle())
                        })
                    NavigationLink(
                        destination: VMConfigQEMUView(config: config).navigationTitle("QEMU"),
                        label: {
                            Label("QEMU", systemImage: "shippingbox")
                                .labelStyle(RoundRectIconLabelStyle())
                        })
                    NavigationLink(
                        destination: VMConfigDrivesView(config: config).navigationTitle("Drives"),
                        label: {
                            Label("Drives", systemImage: "internaldrive")
                                .labelStyle(RoundRectIconLabelStyle())
                        })
                    NavigationLink(
                        destination: VMConfigDisplayView(config: config).navigationTitle("Display"),
                        label: {
                            Label("Display", systemImage: "rectangle.on.rectangle")
                                .labelStyle(RoundRectIconLabelStyle(color: .green))
                        })
                    NavigationLink(
                        destination: VMConfigInputView(config: config).navigationTitle("Input"),
                        label: {
                            Label("Input", systemImage: "keyboard")
                                .labelStyle(RoundRectIconLabelStyle(color: .green))
                        })
                    NavigationLink(
                        destination: VMConfigNetworkView(config: config).navigationTitle("Network"),
                        label: {
                            Label("Network", systemImage: "network")
                                .labelStyle(RoundRectIconLabelStyle(color: .green))
                        })
                    NavigationLink(
                        destination: VMConfigSoundView(config: config).navigationTitle("Sound"),
                        label: {
                            Label("Sound", systemImage: "speaker.wave.2")
                                .labelStyle(RoundRectIconLabelStyle(color: .green))
                        })
                    NavigationLink(
                        destination: VMConfigSharingView(config: config).navigationTitle("Sharing"),
                        label: {
                            Label("Sharing", systemImage: "person.crop.circle.fill")
                                .labelStyle(RoundRectIconLabelStyle(color: .yellow))
                        })
                }
            }
            .navigationTitle("Settings")
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarItems(leading: Button(action: cancel, label: {
                Text("Cancel")
            }), trailing: HStack {
                Button(action: save, label: {
                    Text("Save")
                })
            })
        }.disabled(data.busy)
        .overlay(BusyOverlay())
    }
    
    func save() {
        presentationMode.wrappedValue.dismiss()
        data.busyWork {
            if let existing = self.vm {
                try data.save(vm: existing)
            } else {
                try data.create(config: self.config)
            }
        }
    }
    
    func cancel() {
        presentationMode.wrappedValue.dismiss()
        data.busyWork {
            try data.discardChanges(forVM: self.vm)
        }
    }
}

@available(iOS 14, *)
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
                }
            })
    }
}

@available(iOS 14, *)
struct VMSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMSettingsView(vm: nil, config: config)
    }
}
