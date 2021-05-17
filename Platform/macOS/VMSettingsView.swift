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

@available(macOS 11, *)
struct VMSettingsView: View {
    let vm: UTMVirtualMachine?
    @ObservedObject var config: UTMConfiguration
    
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        ToolbarTabView {
            PreferencePane(label: "Information", systemImage: "info.circle", cancel: cancel, save: save) {
                VMConfigInfoView(config: config)
                    .environmentObject(data)
            }
            PreferencePane(label: "System", systemImage: "cpu", cancel: cancel, save: save) {
                VMConfigSystemView(config: config)
                    .environmentObject(data)
            }
            PreferencePane(label: "QEMU", systemImage: "shippingbox", cancel: cancel, save: save) {
                VMConfigQEMUView(config: config)
                    .environmentObject(data)
            }
            PreferencePane(label: "Drives", systemImage: "internaldrive", cancel: cancel, save: save) {
                VMConfigDrivesView(config: config)
                    .environmentObject(data)
            }
            PreferencePane(label: "Display", systemImage: "rectangle.on.rectangle", cancel: cancel, save: save) {
                VMConfigDisplayView(config: config)
                    .environmentObject(data)
            }
            PreferencePane(label: "Input", systemImage: "keyboard", cancel: cancel, save: save) {
                VMConfigInputView(config: config)
                    .environmentObject(data)
            }
            PreferencePane(label: "Network", systemImage: "network", cancel: cancel, save: save) {
                VMConfigNetworkView(config: config)
                    .environmentObject(data)
            }
            PreferencePane(label: "Sound", systemImage: "speaker.wave.2", cancel: cancel, save: save) {
                VMConfigSoundView(config: config)
                    .environmentObject(data)
            }
            PreferencePane(label: "Sharing", systemImage: "person.crop.circle.fill", cancel: cancel, save: save) {
                VMConfigSharingView(config: config)
                    .environmentObject(data)
            }
        }.frame(minWidth: 800, minHeight: 400)
        .disabled(data.busy)
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
        if let existing = self.vm {
            data.busyWork {
                try data.discardChanges(forVM: existing)
            }
        }
    }
}

@available(macOS 11, *)
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
                }.keyboardShortcut(.cancelAction)
                Button(action: save) {
                    Text("Save")
                }.keyboardShortcut("S", modifiers: .command)
            }.padding([.bottom, .trailing])
        }.toolbarTabItem(label, systemImage: systemImage)
    }
}

@available(macOS 11, *)
struct VMSettingsView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMSettingsView(vm: nil, config: config)
    }
}
