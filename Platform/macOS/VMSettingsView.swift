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
    
    var body: some View {
        ToolbarTabView {
            PreferencePane(label: "System", systemImage: "cpu", save: { save(config) }) {
                VMConfigSystemView(config: config)
            }
            PreferencePane(label: "QEMU", systemImage: "shippingbox", save: { save(config) }) {
                VMConfigQEMUView(config: config)
            }
            PreferencePane(label: "Drives", systemImage: "internaldrive", save: { save(config) }) {
                VMConfigDrivesView(config: config)
            }
            PreferencePane(label: "Display", systemImage: "rectangle.on.rectangle", save: { save(config) }) {
                VMConfigDisplayView(config: config)
            }
            PreferencePane(label: "Input", systemImage: "keyboard", save: { save(config) }) {
                VMConfigInputView(config: config)
            }
            PreferencePane(label: "Network", systemImage: "network", save: { save(config) }) {
                VMConfigNetworkView(config: config)
            }
            PreferencePane(label: "Sound", systemImage: "speaker.wave.2", save: { save(config) }) {
                VMConfigSoundView(config: config)
            }
            PreferencePane(label: "Sharing", systemImage: "person.crop.circle.fill", save: { save(config) }) {
                VMConfigSharingView(config: config)
            }
        }.frame(minWidth: 800, minHeight: 400)
    }
}

struct PreferencePane<Content: View>: View {
    let label: LocalizedStringKey
    let systemImage: String
    let save: () -> Void
    let content: Content
    
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    init(label: LocalizedStringKey, systemImage: String, save: @escaping () -> Void, content: () -> Content) {
        self.label = label
        self.systemImage = systemImage
        self.save = save
        self.content = content()
    }
    
    var body: some View {
        VStack {
            ScrollView {
                content.padding()
            }
            Divider()
            HStack {
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel")
                }
                Button(action: {
                    save()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Save")
                }
            }.padding([.bottom, .trailing])
        }.toolbarTabItem(label, systemImage: systemImage)
    }
}

struct VMSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VMSettingsView(config: config) { _ in
            
        }
    }
}
