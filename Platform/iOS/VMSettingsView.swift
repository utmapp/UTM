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
    
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
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
                    })
                NavigationLink(
                    destination: VMConfigQEMUView(config: config).navigationTitle("QEMU"),
                    label: {
                        Label("QEMU", systemImage: "q.circle")
                    })
                NavigationLink(
                    destination: VMConfigDrivesView(config: config).navigationTitle("Drives"),
                    label: {
                        Label("Drives", systemImage: "internaldrive")
                    })
                NavigationLink(
                    destination: VMConfigDisplayView(config: config).navigationTitle("Display"),
                    label: {
                        Label("Display", systemImage: "rectangle.on.rectangle")
                    })
                NavigationLink(
                    destination: VMConfigInputView(config: config).navigationTitle("Input"),
                    label: {
                        Label("Input", systemImage: "keyboard")
                    })
                NavigationLink(
                    destination: VMConfigNetworkView(config: config).navigationTitle("Network"),
                    label: {
                        Label("Network", systemImage: "network")
                    })
                NavigationLink(
                    destination: VMConfigSoundView(config: config).navigationTitle("Sound"),
                    label: {
                        Label("Sound", systemImage: "speaker.wave.2")
                    })
                NavigationLink(
                    destination: VMConfigSharingView(config: config).navigationTitle("Sharing"),
                    label: {
                        Label("Sharing", systemImage: "person.crop.circle.fill")
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
    }
}

struct VMSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VMSettingsView(config: config) { _ in }
    }
}
