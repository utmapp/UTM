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
    @ObservedObject var config: UTMConfiguration
    var save: (UTMConfiguration) -> Void
    
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        NavigationView {
            Form {
                List {
                    HStack {
                        Text("Name")
                        TextField("Name", text: $config.name)
                            .multilineTextAlignment(.trailing)
                    }
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
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }, label: {
                Text("Cancel")
            }), trailing: HStack {
                Button(action: {
                    save(config)
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Text("Save")
                })
            })
        }.disabled(data.busy)
        .overlay(BusyOverlay())
    }
}

struct RoundRectIconLabelStyle: LabelStyle {
    var color: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        Label(
            title: { configuration.title },
            icon: {
                RoundedRectangle(cornerRadius: 10.0, style: .circular)
                    .frame(width: 32, height: 32)
                    .foregroundColor(color)
                    .overlay(configuration.icon.foregroundColor(.white))
            })
    }
}

struct VMSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VMSettingsView(config: config) { _ in }
    }
}
