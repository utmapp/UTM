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
import IQKeyboardManagerSwift

@available(iOS 14, *)
struct ContentView: View {
    @StateObject private var newConfiguration = UTMConfiguration()
    @State private var editMode = false
    @EnvironmentObject private var data: UTMData
    @State private var newPopupPresented = false
    @State private var newVMScratchPresented = false
    @State private var jitAlertPresented = false
    @Environment(\.openURL) var openURL
    
    var body: some View {
        NavigationView {
            List {
                ForEach(data.virtualMachines) { vm in
                    NavigationLink(
                        destination: VMDetailsView(vm: vm),
                        tag: vm,
                        selection: $data.selectedVM,
                        label: { VMCardView(vm: vm) })
                        .modifier(VMContextMenuModifier(vm: vm))
                }.onMove(perform: data.move)
                .onDelete(perform: delete)
            }.listStyle(SidebarListStyle())
            .navigationTitle("UTM")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    newButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $newVMScratchPresented, onDismiss: {
                newConfiguration.resetDefaults()
            }, content: {
                VMSettingsView(vm: nil, config: newConfiguration)
                    .environmentObject(data)
                    .onAppear {
                        newConfiguration.name = data.newDefaultVMName()
                    }
            })
            VMPlaceholderView(createNewVMPresented: $newVMScratchPresented)
        }.disabled(data.busy)
        .onOpenURL(perform: importUTM)
        .onAppear {
            data.refresh()
            data.enableNetworking()
            IQKeyboardManager.shared.enable = true
            if !Main.jitAvailable {
                jitAlertPresented.toggle()
            }
        }
        .alert(isPresented: $jitAlertPresented, content: {
            Alert(title: Text("Your version of iOS does not support running VMs while unmodified. You must either run UTM while jailbroken or with a remote debugger attached."))
        })
        .overlay(data.showSettingsModal ? AnyView(EmptyView()) : AnyView(BusyOverlay()))
    }
    
    private var newButton: some View {
        return Button(action: { newVMScratchPresented.toggle() }, label: {
            Label("New VM", systemImage: "plus").labelStyle(IconOnlyLabelStyle())
        })
        #if false // FIXME: when bug is fixed with actionSheet
        Button(action: { newPopupPresented.toggle() }, label: {
            Label("New VM", systemImage: "plus").labelStyle(IconOnlyLabelStyle())
        })
        .actionSheet(isPresented: $newPopupPresented) {
            ActionSheet(title: Text("New VM"),
                        message: Text("You can download an existing VM configuration for popular operating systems from the UTM gallery or start from scratch."),
                        buttons: [.default(Text("Go to Gallery"), action: newVMFromTemplate),
                                  .default(Text("Start from Scratch"), action: { newVMScratchPresented.toggle() })
                        ])
        }
        #endif
    }
    
    private func newVMFromTemplate() {
        openURL(URL(string: "https://getutm.app/gallery/")!)
    }
    
    private func delete(indexSet: IndexSet) {
        let selected = data.virtualMachines[indexSet]
        for vm in selected {
            data.busyWork {
                try data.delete(vm: vm)
            }
        }
    }
    
    private func importUTM(url: URL) {
        guard url.isFileURL else {
            return // ignore
        }
        data.busyWork {
            try data.importUTM(url: url)
        }
    }
}

@available(iOS 14, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
