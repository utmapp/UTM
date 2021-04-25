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
#if !os(macOS)
import IQKeyboardManagerSwift
#endif

@available(iOS 14, macOS 11, *)
struct ContentView: View {
    @StateObject private var newConfiguration = UTMConfiguration()
    @State private var editMode = false
    @EnvironmentObject private var data: UTMData
    @State private var newPopupPresented = false
    @State private var importSheetPresented = false
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
            }.optionalSidebarFrame()
            .listStyle(SidebarListStyle())
            .navigationTitle("UTM")
            .navigationOptionalSubtitle(data.selectedVM?.configuration.name ?? "")
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .navigation) {
                    newButton
                }
                #else
                ToolbarItem(placement: .navigationBarLeading) {
                    newButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                #endif
            }
            .sheet(isPresented: $data.showNewVMSheet, onDismiss: {
                //FIXME: SwiftUI bug this is never called on macOS
                newConfiguration.resetDefaults()
            }, content: {
                VMSettingsView(vm: nil, config: newConfiguration)
                    .environmentObject(data)
                    .onAppear {
                        newConfiguration.name = data.newDefaultVMName()
                    }
            })
            .onChange(of: data.showNewVMSheet) { value in
                //FIXME: this doesn't always work on iOS
                if !value {
                    newConfiguration.resetDefaults()
                }
            }
            VMPlaceholderView()
        }.overlay(data.showSettingsModal ? AnyView(EmptyView()) : AnyView(BusyOverlay()))
        .environmentObject(data)
        .optionalWindowFrame()
        .disabled(data.busy && !data.showNewVMSheet && !data.showSettingsModal)
        .onOpenURL(perform: importUTM)
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        .onReceive(NSNotification.NewVirtualMachine) { _ in
            data.newVM()
        }.onReceive(NSNotification.ImportVirtualMachine) { _ in
            importSheetPresented = true
        }.fileImporter(isPresented: $importSheetPresented, allowedContentTypes: [.UTM], onCompletion: selectImportedUTM)
        .onAppear {
            data.refresh()
            #if os(macOS)
            NSWindow.allowsAutomaticWindowTabbing = false
            #else
            data.enableNetworking()
            IQKeyboardManager.shared.enable = true
            if !Main.jitAvailable {
                data.busyWork {
                    throw NSLocalizedString("Your version of iOS does not support running VMs while unmodified. You must either run UTM while jailbroken or with a remote debugger attached.", comment: "ContentView")
                }
            }
            #endif
        }
    }
    
    #if os(macOS)
    private var newButton: some View {
        Button(action: { newPopupPresented.toggle() }, label: {
            Label("New VM", systemImage: "plus").labelStyle(IconOnlyLabelStyle())
        })
        .help("New VM")
        .popover(isPresented: $newPopupPresented, arrowEdge: .bottom) {
            VStack {
                Text("You can download an existing VM configuration for popular operating systems from the UTM gallery or start from scratch.")
                Spacer()
                Link("Go To Gallery", destination: URL(string: "https://getutm.app/gallery/")!)
                Button("Start from Scratch") {
                    data.newVM()
                }
            }.frame(width: 200, height: 150)
            .padding()
        }
    }
    #else
    // BUG: iOS cannot show actionSheet from toolbar
    private var newButton: some View {
        Button(action: { data.newVM() }, label: {
            Label("New VM", systemImage: "plus").labelStyle(IconOnlyLabelStyle())
        })
    }
    #endif
    
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
    
    private func selectImportedUTM(result: Result<URL, Error>) {
        data.busyWork {
            let url = try result.get()
            try data.importUTM(url: url)
        }
    }
}

#if os(macOS)
@available(macOS 11, *)
fileprivate extension View {
    func navigationOptionalSubtitle<S>(_ subtitle: S) -> some View where S : StringProtocol {
        return self.navigationSubtitle(subtitle)
    }
    
    func optionalSidebarFrame() -> some View {
        return self.frame(minWidth: 250, idealWidth: 350)
    }
    
    func optionalWindowFrame() -> some View {
        return self.frame(minWidth: 800, idealWidth: 1200, minHeight: 600, idealHeight: 800)
    }
}
#else
@available(iOS 14, *)
fileprivate extension View {
    // ignore subtitle on iOS
    func navigationOptionalSubtitle<S>(_ subtitle: S) -> some View where S : StringProtocol {
        return self
    }
    
    // ignore frame size
    func optionalSidebarFrame() -> some View {
        return self
    }
    
    // ignore frame size
    func optionalWindowFrame() -> some View {
        return self
    }
}
#endif

@available(iOS 14, macOS 11, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
