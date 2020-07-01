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
                        Text("System")
                    })
                NavigationLink(
                    destination: VMConfigQEMUView(config: config).navigationTitle("QEMU"),
                    label: {
                        Text("QEMU")
                    })
                NavigationLink(
                    destination: VMConfigDrivesView(config: config).navigationTitle("Drives"),
                    label: {
                        Text("Drives")
                    })
                NavigationLink(
                    destination: VMConfigDisplayView(config: config).navigationTitle("Display"),
                    label: {
                        Text("Display")
                    })
                NavigationLink(
                    destination: VMConfigInputView(config: config).navigationTitle("Input"),
                    label: {
                        Text("Input")
                    })
                NavigationLink(
                    destination: VMConfigNetworkView(config: config).navigationTitle("Network"),
                    label: {
                        Text("Network")
                    })
                NavigationLink(
                    destination: VMConfigSoundView(config: config).navigationTitle("Sound"),
                    label: {
                        Text("Sound")
                    })
                NavigationLink(
                    destination: VMConfigSharingView(config: config).navigationTitle("Sharing"),
                    label: {
                        Text("Sharing")
                    })
            }
        }
        .navigationTitle("Settings")
        .navigationBarItems(leading: Button(action: {
            presentationMode.wrappedValue.dismiss()
        }, label: {
            Text("Cancel")
        }), trailing: Button(action: {
            //FIXME: save
            presentationMode.wrappedValue.dismiss()
        }, label: {
            Text("Save")
        }))
    }
}

struct VMSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VMSettingsView(config: config)
    }
}
