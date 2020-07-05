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

struct ContentView: View {
    @State private var examples = ["Windows", "Ubuntu", "Generic"]
    @State private var editMode = false
    @State private var selected: String? = nil
    @StateObject private var data = UTMData()
    
    var body: some View {
        NavigationView {
            let selection = Binding<Set<String>> {
                selected != nil ? [selected!] : []
            } set: {
                let newSelected = $0.first
                if selected != newSelected {
                    editMode = false
                    //FIXME: prompt user to discard changes
                }
                selected = newSelected
            }

            List(data.virtualMachines, selection: selection) { vm in
                VMCardView(vm: vm)
            }.listStyle(SidebarListStyle())
            .frame(minWidth: 250, idealWidth: 350)
            if selected == nil {
                VMPlaceholderView()
            } else {
                VMDetailsView(config: UTMConfiguration(name: selected!), editMode: $editMode, screenshot: NSImage(named: "\(selected!)-Screen"))
            }
        }.environmentObject(data)
        .navigationTitle("UTM")
        .navigationSubtitle(selected ?? "")
        .onAppear {
            data.refresh()
        }
        .toolbar {
            /* //FIXME: unhide sidebar if hidden
            ToolbarItem(placement: .navigation) {
                Button {
                    
                } label: {
                    Label("Hide/Show", systemImage: "sidebar.left")
                }.help("Hide or show the navigator")
            }
            */
            ToolbarItem {
                if selected != nil {
                    VMToolbar {
                        editMode.toggle()
                    }
                } else {
                    EmptyView()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    
                } label: {
                    Label("New", systemImage: "square.and.pencil")
                }.help("New VM")
            }
        }.frame(minWidth: 800, idealWidth: 1200, minHeight: 600, idealHeight: 800)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
