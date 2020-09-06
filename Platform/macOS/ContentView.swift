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
struct ContentView: View {
    @State private var editMode = false
    @StateObject private var data = UTMData()
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
                .onDelete(perform: delete)
            }.frame(minWidth: 250, idealWidth: 350)
            .listStyle(SidebarListStyle())
            .navigationTitle("UTM")
            .navigationSubtitle(data.selectedVM?.configuration.name ?? "")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    newButton
                }
            }
            VMPlaceholderView(createNewVMPresented: $newVMScratchPresented)
            .sheet(isPresented: $newVMScratchPresented) {
                VMSettingsView(vm: nil, config: UTMConfiguration(name: data.newDefaultVMName()))
                    .environmentObject(data)
            }
        }.environmentObject(data)
        .frame(minWidth: 800, idealWidth: 1200, minHeight: 600, idealHeight: 800)
        .disabled(data.busy)
        .onAppear {
            data.refresh()
        }
        .overlay(BusyOverlay())
    }
    
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
                    newVMScratchPresented.toggle()
                }
            }.frame(width: 200, height: 150)
            .padding()
        }
    }
    
    private func delete(indexSet: IndexSet) {
        let selected = data.virtualMachines[indexSet]
        for vm in selected {
            data.busyWork {
                try data.delete(vm: vm)
            }
        }
    }
}

@available(macOS 11, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
