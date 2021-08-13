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

@available(iOS 14, macOS 11, *)
struct VMConfigQEMUView: View {
    private struct Argument: Identifiable {
        let id: Int
        let string: String
    }
    
    @ObservedObject var config: UTMConfiguration
    @State private var newArg: String = ""
    @State private var showExportLog: Bool = false
    @State private var showExportArgs: Bool = false
    @EnvironmentObject private var data: UTMData
    
    private var logExists: Bool {
        guard let path = config.existingPath else {
            return false
        }
        let logPath = path.appendingPathComponent(UTMConfiguration.debugLogName())
        return FileManager.default.fileExists(atPath: logPath.path)
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Logging")) {
                    Toggle(isOn: $config.debugLogEnabled, label: {
                        Text("Debug Logging")
                    })
                    Button("Export Debug Log") {
                        showExportLog.toggle()
                    }.modifier(VMShareItemModifier(isPresented: $showExportLog, items: exportDebugLog))
                    .disabled(!logExists)
                }
                Section(header: Text("QEMU Arguments")) {
                    Button("Export QEMU Command") {
                        showExportArgs.toggle()
                    }.modifier(VMShareItemModifier(isPresented: $showExportArgs, items: exportArgs))
                    Toggle(isOn: $config.ignoreAllConfiguration.animation(), label: {
                        Text("Advanced: Bypass configuration and manually specify arguments")
                    })
                    let qemuSystem = UTMQemuSystem(configuration: config, imgPath: URL(fileURLWithPath: "Images"))
                    let fixedArgs = arguments(from: qemuSystem.argv)
                    #if os(macOS)
                    VStack {
                        ForEach(fixedArgs) { arg in
                            TextField("", text: .constant(arg.string))
                        }.disabled(true)
                        CustomArguments(config: config)
                        TextField("New...", text: $newArg, onEditingChanged: addArg)
                    }
                    #else
                    List {
                        ForEach(fixedArgs) { arg in
                            Text(arg.string)
                        }.foregroundColor(.secondary)
                        CustomArguments(config: config)
                        TextField("New...", text: $newArg, onEditingChanged: addArg)
                    }
                    #endif
                }
            }.navigationBarItems(trailing: EditButton())
            .disableAutocorrection(true)
        }
    }
    
    private func exportDebugLog() -> [URL] {
        if let result = try? data.exportDebugLog(forConfig: config) {
            return result
        } else {
            return [] // TODO: implement error handling
        }
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
    
    private func addArg(editing: Bool) {
        guard !editing else {
            return
        }
        if newArg != "" {
            config.newArgument(newArg)
        }
        newArg = ""
    }
    
    private func exportArgs() -> [String] {
        let existingPath = config.existingPath ?? URL(fileURLWithPath: "Images")
        let qemuSystem = UTMQemuSystem(configuration: config, imgPath: existingPath)
        qemuSystem.updateArgv(withUserOptions: true)
        var argString = "qemu-system-\(config.systemArchitecture ?? "unknown")"
        for arg in qemuSystem.argv {
            if arg.contains(" ") {
                argString += " \"\(arg)\""
            } else {
                argString += " \(arg)"
            }
        }
        return [argString]
    }
    
    private func arguments(from list: [String]) -> [Argument] {
        list.indices.map { i in
            Argument(id: i, string: list[i])
        }
    }
}

@available(iOS 14, macOS 11, *)
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
                TextField("Argument", text: argBinding, onEditingChanged: { editing in
                    if !editing && argBinding.wrappedValue == "" {
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

@available(iOS 14, macOS 11, *)
struct VMConfigQEMUView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMConfigQEMUView(config: config)
    }
}
