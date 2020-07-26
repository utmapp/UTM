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
        ToolbarTabView {
            PreferencePane(label: "Information", systemImage: "info.circle", cancel: { presentationMode.wrappedValue.dismiss() }, save: { save(config) }) {
                VMConfigInfoView(config: config)
            }
            PreferencePane(label: "System", systemImage: "cpu", cancel: { presentationMode.wrappedValue.dismiss() }, save: { save(config) }) {
                VMConfigSystemView(config: config)
            }
            PreferencePane(label: "QEMU", systemImage: "shippingbox", cancel: { presentationMode.wrappedValue.dismiss() }, save: { save(config) }) {
                VMConfigQEMUView(config: config)
                    .environmentObject(data)
            }
            PreferencePane(label: "Drives", systemImage: "internaldrive", cancel: { presentationMode.wrappedValue.dismiss() }, save: { save(config) }) {
                VMConfigDrivesView(config: config)
                    .environmentObject(data)
            }
            PreferencePane(label: "Display", systemImage: "rectangle.on.rectangle", cancel: { presentationMode.wrappedValue.dismiss() }, save: { save(config) }) {
                VMConfigDisplayView(config: config)
            }
            PreferencePane(label: "Input", systemImage: "keyboard", cancel: { presentationMode.wrappedValue.dismiss() }, save: { save(config) }) {
                VMConfigInputView(config: config)
            }
            PreferencePane(label: "Network", systemImage: "network", cancel: { presentationMode.wrappedValue.dismiss() }, save: { save(config) }) {
                VMConfigNetworkView(config: config)
            }
            PreferencePane(label: "Sound", systemImage: "speaker.wave.2", cancel: { presentationMode.wrappedValue.dismiss() }, save: { save(config) }) {
                VMConfigSoundView(config: config)
            }
            PreferencePane(label: "Sharing", systemImage: "person.crop.circle.fill", cancel: { presentationMode.wrappedValue.dismiss() }, save: { save(config) }) {
                VMConfigSharingView(config: config)
            }
        }.frame(minWidth: 800, minHeight: 400)
        .overlay(BusyOverlay())
    }
}

struct PreferencePane<Content: View>: View {
    let label: LocalizedStringKey
    let systemImage: String
    let cancel: () -> Void // HACK: NSHostingView doesn't get presentationMode
    let save: () -> Void
    let content: Content
    
    init(label: LocalizedStringKey, systemImage: String, cancel: @escaping () -> Void, save: @escaping () -> Void, content: () -> Content) {
        self.label = label
        self.systemImage = systemImage
        self.cancel = cancel
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
                Button(action: cancel) {
                    Text("Cancel")
                }
                Button(action: {
                    save()
                    cancel()
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
