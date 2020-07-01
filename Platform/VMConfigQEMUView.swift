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

struct VMConfigQEMUView: View {
    @ObservedObject var config: UTMConfiguration
    @State private var customArgsOnly: Bool = false //FIXME: implement this
    @State private var newArg: String = ""
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Logging")) {
                    Toggle(isOn: $config.debugLogEnabled, label: {
                        Text("Debug Logging")
                    })
                    Button("Export Debug Log", action: exportDebugLog)
                }
                Section(header: Text("QEMU Arguments")) {
                    Toggle(isOn: $customArgsOnly, label: {
                        Text("Advanced: Bypass configuration and manually specify arguments")
                    })
                    let qemuSystem = UTMQemuSystem(configuration: config, imgPath: URL(fileURLWithPath: "/path/to/Images"))
                    let fixedArgs = qemuSystem.argv
                    #if os(macOS)
                    VStack {
                        ForEach(fixedArgs, id: \.self) { arg in
                            TextField("", text: .constant(arg))
                        }.disabled(true)
                        CustomArguments(config: config)
                        TextField("New...", text: $newArg, onEditingChanged: {_ in }, onCommit: addArg)
                    }
                    #else
                    List {
                        ForEach(fixedArgs, id: \.self) { arg in
                            Text(arg)
                        }.foregroundColor(.secondary)
                        CustomArguments(config: config)
                        TextField("New...", text: $newArg, onEditingChanged: {_ in }, onCommit: addArg)
                    }
                    #endif
                }
            }.navigationBarItems(trailing: EditButton())
        }
    }
    
    private func exportDebugLog() {
        //FIXME: implement
    }
    
    private func deleteArg(offsets: IndexSet) {
        for offset in offsets {
            config.removeArgument(at: offset)
        }
    }
    
    private func moveArg(source: IndexSet, destination: Int) {
        for offset in source {
            config.moveArgumentIndex(offset, to: destination)
        }
    }
    
    private func addArg() {
        if newArg != "" {
            config.newArgument(newArg)
        }
        newArg = ""
    }
}

struct CustomArguments: View {
    @ObservedObject var config: UTMConfiguration
    
    var body: some View {
        ForEach(0..<config.countArguments, id: \.self) { i in
            let argBinding = Binding<String> {
                if i < config.countArguments {
                    return config.argument(for: i) ?? ""
                } else {
                    // WA for a SwiftUI bug on macOS that uses old countArguments
                    return ""
                }
            } set: {
                config.updateArgument(at: i, withValue: $0)
            }
            HStack {
                TextField("Argument", text: argBinding, onCommit: {
                    if argBinding.wrappedValue == "" {
                        config.removeArgument(at: i)
                    }
                })
                #if os(macOS)
                Spacer()
                if i != 0 {
                    Button(action: { config.moveArgumentIndex(i, to: i-1) }, label: {
                        Label("Move Up", systemImage: "arrow.up").labelStyle(IconOnlyLabelStyle())
                    })
                }
                #endif
            }
        }.onDelete(perform: deleteArg)
        .onMove(perform: moveArg)
    }
    
    private func deleteArg(offsets: IndexSet) {
        for offset in offsets {
            config.removeArgument(at: offset)
        }
    }
    
    private func moveArg(source: IndexSet, destination: Int) {
        for offset in source {
            config.moveArgumentIndex(offset, to: destination)
        }
    }
}

struct VMConfigQEMUView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        VMConfigQEMUView(config: config)
    }
}
