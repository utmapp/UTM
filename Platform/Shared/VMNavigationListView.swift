//
// Copyright © 2022 osy. All rights reserved.
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

struct VMNavigationListView: View {
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        if #available(iOS 16, macOS 13, *) {
            NavigationSplitView {
                List(selection: $data.selectedVM) {
                    listBody
                }.modifier(VMListModifier())
            } detail: {
                if let vm = data.selectedVM {
                    VMDetailsView(vm: vm)
                } else {
                    VMPlaceholderView()
                }
            }
        } else {
            NavigationView {
                List {
                    listBody
                }.modifier(VMListModifier())
                VMPlaceholderView()
            }
        }
    }
    
    @ViewBuilder private var listBody: some View {
        ForEach(data.virtualMachines) { vm in
            if !vm.isLoaded {
                UTMUnavailableVMView(vm: vm)
            } else {
                if #available(iOS 16, macOS 13, visionOS 1, *) {
                    VMCardView(vm: vm)
                        .modifier(VMContextMenuModifier(vm: vm))
                        .tag(vm)
                } else {
                    NavigationLink(
                        destination: VMDetailsView(vm: vm),
                        tag: vm,
                        selection: $data.selectedVM,
                        label: { VMCardView(vm: vm) })
                    .modifier(VMContextMenuModifier(vm: vm))
                }
            }
        }.onMove(perform: move)
        .onDelete(perform: delete)
        
        if data.pendingVMs.count > 0 {
            Section(header: Text("Pending")) {
                ForEach(data.pendingVMs, id: \.name) { vm in
                    UTMPendingVMView(vm: vm)
                }.onDelete(perform: cancel)
            }.transition(.opacity)
        }
    }
    
    private func move(fromOffsets: IndexSet, toOffset: Int) {
        data.listMove(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    
    private func delete(indexSet: IndexSet) {
        let selected = data.virtualMachines[indexSet]
        for vm in selected {
            data.busyWorkAsync {
                try await data.delete(vm: vm)
            }
        }
    }
    
    private func cancel(indexSet: IndexSet) {
        let selected = data.pendingVMs[indexSet]
        for vm in selected {
            data.cancelDownload(for: vm)
        }
    }
}

private struct VMListModifier: ViewModifier {
    @EnvironmentObject private var data: UTMData
    @State private var settingsPresented = false
    @State private var sheetPresented = false
    
    func body(content: Content) -> some View {
        content
        #if os(macOS)
        .frame(minWidth: 250, idealWidth: 350)
        #endif
        .listStyle(.sidebar)
        .navigationTitle(productName)
        #if os(macOS)
        .navigationSubtitle(data.selectedVM?.detailsTitleLabel ?? "")
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .navigation) {
                newButton
            }
            #else
            ToolbarItem(placement: .navigationBarLeading) {
                newButton
            }
            #if !os(visionOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Settings") {
                    settingsPresented.toggle()
                }
            }
            #endif
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            #endif
        }
        #if os(iOS)
        // SwiftUI bug on iOS 14.4 and previous versions prevents multiple .sheet from working
        .sheet(isPresented: $sheetPresented) {
            if data.showNewVMSheet {
                VMWizardView()
            } else if settingsPresented {
                UTMSettingsView()
            }
        }
        .onChange(of: data.showNewVMSheet) { newValue in
            if newValue {
                settingsPresented = false
                sheetPresented = true
            }
        }
        .onChange(of: settingsPresented) { newValue in
            if newValue {
                data.showNewVMSheet = false
                sheetPresented = true
            }
        }
        .onChange(of: sheetPresented) { newValue in
            if !newValue {
                settingsPresented = false
                data.showNewVMSheet = false
            }
        }
        .onReceive(NSNotification.OpenVirtualMachine) { _ in
            sheetPresented = false
        }
        #else
        .sheet(isPresented: $data.showNewVMSheet) {
            VMWizardView()
        }
        .onReceive(NSNotification.OpenVirtualMachine) { _ in
            data.showNewVMSheet = false
        }
        #endif
    }
    
    private var newButton: some View {
        Button(action: { data.newVM() }, label: {
            Label("New VM", systemImage: "plus").labelStyle(.iconOnly)
        })
    }
}
