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

struct ContentView: View {
    @State private var editMode = false
    @EnvironmentObject private var data: UTMData
    @State private var newPopupPresented = false
    @State private var newVMScratchPresented = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(data.virtualMachines) { vm in
                    NavigationLink(
                        destination: VMDetailsView(vm: vm),
                        tag: vm,
                        selection: $data.selectedVM,
                        label: { VMCardView(vm: vm) })
                }.onMove(perform: data.move)
                .onDelete(perform: data.remove)
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
            .sheet(isPresented: $newVMScratchPresented) {
                VMSettingsView(config: UTMConfiguration(name: data.newDefaultName())) { config in
                    data.busyWork() { try data.create(config: config) }
                }.environmentObject(data)
            }
            VMPlaceholderView()
        }.disabled(data.busy)
        .onAppear {
            data.refresh()
            IQKeyboardManager.shared.enable = true
        }
        .overlay(BusyOverlay())
    }
    
    private var newButton: some View {
        Button(action: { newPopupPresented.toggle() }, label: {
            Label("New VM", systemImage: "plus").labelStyle(IconOnlyLabelStyle())
        })
        .actionSheet(isPresented: $newPopupPresented) {
            let sheet = ActionSheet(title: Text("New VM"),
                                    message: Text("Would you like to pick a template?"),
                                    buttons: [
                                        .default(Text("Template"), action: newVMFromTemplate),
                                        .default(Text("Advanced"), action: { newVMScratchPresented.toggle() })
                                    ])
            return sheet
        }
    }
    
    private func newVMFromTemplate() {
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
