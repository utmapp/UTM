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
struct VMSettingsView<Config: UTMConfiguration>: View {
    let vm: VMData
    @ObservedObject var config: Config
    
    @EnvironmentObject private var data: UTMData
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        NavigationView {
            List {
                if config is UTMQemuConfiguration {
                    VMQEMUSettingsView(config: config as! UTMQemuConfiguration)
                } else if config is UTMAppleConfiguration {
                    VMAppleSettingsView(config: config as! UTMAppleConfiguration)
                }
            }.listStyle(.sidebar)
            Text("")
                .settingsToolbar()
        }
        .frame(minWidth: 800, minHeight: 400, alignment: .leading)
        .legacySettingsToolbar {
            ToolbarItemGroup(placement: .cancellationAction) {
                Button(action: cancel) {
                    Text("Cancel")
                }
            }
            ToolbarItemGroup(placement: .confirmationAction) {
                Button(action: save) {
                    Text("Save")
                }
            }
        }
        .environmentObject(vm)
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
        data.busyWorkAsync {
            try await data.discardChanges(for: vm)
        }
    }
}

@available(macOS 11, *)
struct ScrollableViewModifier: ViewModifier {
    @State private var scrollViewContentSize: CGSize = .zero
    
    func body(content: Content) -> some View {
        ScrollView {
            content
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                GeometryReader { geo -> Color in
                    DispatchQueue.main.async {
                        scrollViewContentSize = geo.size
                    }
                    return Color.clear
                }
            )
        }
        .frame(idealWidth: scrollViewContentSize.width)
    }
}

fileprivate struct EmptyToolbarContent: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem {
            EmptyView()
        }
    }
}

@available(macOS 12, *)
struct SettingsToolbarViewModifier<AdditionalContent>: ViewModifier where AdditionalContent: ToolbarContent {
    @EnvironmentObject private var vm: VMData
    @EnvironmentObject private var data: UTMData
    @Environment(\.dismiss) private var dismiss
    
    let additionalContent: AdditionalContent?
    
    fileprivate init() where AdditionalContent == EmptyToolbarContent {
        self.additionalContent = nil
    }
    
    init(additionalContent: () -> AdditionalContent) {
        self.additionalContent = additionalContent()
    }
    
    func body(content: Content) -> some View {
        let view = content.toolbar {
            ToolbarItemGroup(placement: .cancellationAction) {
                Button(action: cancel) {
                    Text("Cancel")
                }
            }
            ToolbarItemGroup(placement: .confirmationAction) {
                Form {
                    Button(action: save) {
                        Text("Save")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        if let additionalContent = additionalContent {
            view.toolbar {
                additionalContent
            }
        } else {
            view
        }
    }
    
    private func save() {
        data.busyWorkAsync {
            try await data.save(vm: vm)
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func cancel() {
        dismiss()
        data.busyWorkAsync {
            try await data.discardChanges(for: vm)
        }
    }
}

@available(macOS 11, *)
extension View {
    func scrollable() -> some View {
        self.modifier(ScrollableViewModifier())
    }
    
    @ViewBuilder
    fileprivate func legacySettingsToolbar<Content>(@ToolbarContentBuilder content: () -> Content) -> some View where Content: ToolbarContent {
        if #available(macOS 12, *) {
            self
        } else {
            self.toolbar(content: content)
        }
    }
    
    @ViewBuilder
    func settingsToolbar() -> some View {
        if #available(macOS 12, *) {
            self.modifier(SettingsToolbarViewModifier())
        } else {
            self
        }
    }
    
    @ViewBuilder
    func settingsToolbar<Content>(@ToolbarContentBuilder additionalContent: () -> Content) -> some View where Content: ToolbarContent {
        if #available(macOS 12, *) {
            self.modifier(SettingsToolbarViewModifier(additionalContent: additionalContent))
        } else {
            self
        }
    }
}

@available(macOS 11, *)
struct VMSettingsView_Previews: PreviewProvider {
    @State static private var qemuConfig = UTMQemuConfiguration()
    @State static private var appleConfig = UTMAppleConfiguration()
    @State static private var data = UTMData()
    
    static var previews: some View {
        VMSettingsView(vm: VMData(from: .empty), config: qemuConfig)
            .environmentObject(data)
            .previewDisplayName("QEMU VM Settings")
        VMSettingsView(vm: VMData(from: .empty), config: appleConfig)
            .environmentObject(data)
            .previewDisplayName("Apple VM Settings")
    }
}
