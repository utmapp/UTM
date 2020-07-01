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
    @Binding var editMode: Bool
    
    var body: some View {
        TabView {
            PreferencePane(label: { Text("System") }) {
                VMConfigSystemView(config: config).disabled(!editMode)
            }
            PreferencePane(label: { Text("QEMU") }) {
                VMConfigQEMUView(config: config).disabled(!editMode)
            }
            PreferencePane(label: { Text("Drives") }) {
                VMConfigDrivesView(config: config).disabled(!editMode)
            }
            PreferencePane(label: { Text("Display") }) {
                VMConfigDisplayView(config: config).disabled(!editMode)
            }
            PreferencePane(label: { Text("Input") }) {
                VMConfigInputView(config: config).disabled(!editMode)
            }
            PreferencePane(label: { Text("Network") }) {
                VMConfigNetworkView(config: config).disabled(!editMode)
            }
            PreferencePane(label: { Text("Sound") }) {
                VMConfigSoundView(config: config).disabled(!editMode)
            }
            PreferencePane(label: { Text("Sharing") }) {
                VMConfigSharingView(config: config).disabled(!editMode)
            }
        }
    }
}

struct PreferencePane<Label, Content>: View where Label: View, Content: View {
    var label: () -> Label
    var content: () -> Content
    
    var body: some View {
        VStack {
            ScrollView {
                content()
                .padding()
                Spacer()
            }
        }
        .tabItem {
            label()
        }
    }
}

struct VMSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VMSettingsView(config: config, editMode: .constant(true))
    }
}
