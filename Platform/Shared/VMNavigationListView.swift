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
import TipKit

struct VMNavigationListView: View {
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        if #available(iOS 16, macOS 13, *) {
            NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
                List(selection: $data.selectedVM) {
                    listBody
                }.modifier(VMListModifier())
            } detail: {
                if let vm = data.selectedVM {
                    VMDetailsView(vm: vm)
                } else {
                    VMPlaceholderView()
                    #if os(visionOS)
                        .toolbar {
                            UTMPreferenceButtonToolbarContent()
                        }
                    #endif
                }
            }.navigationSplitViewStyle(.balanced)
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
        #if !WITH_REMOTE // FIXME: implement remote feature
        .onDelete(perform: delete)
        #endif

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
    @State private var donatePresented = false

    private let _donateTip: Any?
    private let _createTip: Any?

    @available(iOS 17, macOS 14, *)
    private var donateTip: UTMTipDonate {
        _donateTip as! UTMTipDonate
    }

    @available(iOS 17, macOS 14, *)
    private var createTip: UTMTipCreateVM {
        _createTip as! UTMTipCreateVM
    }

    init() {
        if #available(iOS 17, macOS 14, *) {
            _donateTip = UTMTipDonate()
            _createTip = UTMTipCreateVM()
        } else {
            _donateTip = nil
            _createTip = nil
        }
    }

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
            #if !WITH_REMOTE // FIXME: implement remote feature
            ToolbarItem(placement: .navigationBarLeading) {
                if #available(iOS 17, visionOS 99, *) {
                    Button {
                        createTip.invalidate(reason: .actionPerformed)
                        data.newVM()
                    } label: {
                        Image(systemName: "plus") // SwiftUI bug: tip won't show up if this is a label
                    }.help("Create a new VM")
                    .popoverTip(createTip, arrowEdge: .top)
                } else {
                    newButton
                }
            }
            #endif
            #if !WITH_REMOTE
            ToolbarItem(placement: .navigationBarLeading) {
                if #available(iOS 17, visionOS 99, *) {
                    Button {
                        donateTip.invalidate(reason: .actionPerformed)
                        donatePresented.toggle()
                    } label: {
                        Image(systemName: "heart.fill") // SwiftUI bug: tip won't show up if this is a label
                    }.popoverTip(donateTip, arrowEdge: .top) { action in
                        donateTip.invalidate(reason: .actionPerformed)
                        if action.id == "donate" {
                            donatePresented.toggle()
                        }
                    }
                } else {
                    Button {
                        donatePresented.toggle()
                    } label: {
                        Label("Donate", systemImage: "heart.fill")
                    }
                }
            }
            #endif
            #if !os(visionOS) && !WITH_REMOTE
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
                #if !WITH_REMOTE
                UTMSettingsView()
                #endif
            } else if donatePresented {
                #if !os(macOS) && !WITH_REMOTE
                UTMDonateView()
                #endif
            }
        }
        .onChange(of: data.showNewVMSheet) { newValue in
            if newValue {
                settingsPresented = false
                donatePresented = false
                sheetPresented = true
            }
        }
        .onChange(of: settingsPresented) { newValue in
            if newValue {
                data.showNewVMSheet = false
                donatePresented = false
                sheetPresented = true
            }
        }
        .onChange(of: donatePresented) { newValue in
            if newValue {
                data.showNewVMSheet = false
                settingsPresented = false
                sheetPresented = true
            }
        }
        .onChange(of: sheetPresented) { newValue in
            if !newValue {
                settingsPresented = false
                donatePresented = false
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
        #if !os(macOS) && !WITH_REMOTE
        .sheet(isPresented: $donatePresented) {
            UTMDonateView()
        }
        #endif
        .onReceive(NSNotification.OpenVirtualMachine) { _ in
            data.showNewVMSheet = false
        }
        #endif
    }
    
    private var newButton: some View {
        Button(action: { data.newVM() }, label: {
            Label("New VM", systemImage: "plus").labelStyle(.iconOnly)
        }).help("Create a new VM")
    }
}
