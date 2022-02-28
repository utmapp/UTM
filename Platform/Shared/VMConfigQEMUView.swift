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
    
    @ObservedObject var config: UTMQemuConfiguration
    @State private var showExportLog: Bool = false
    @State private var showExportArgs: Bool = false
    @EnvironmentObject private var data: UTMData
    
    private var logExists: Bool {
        guard let path = config.existingPath else {
            return false
        }
        let logPath = path.appendingPathComponent(UTMQemuConfiguration.debugLogName)
        return FileManager.default.fileExists(atPath: logPath.path)
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Tweaks")) {
                    #if os(macOS)
                    Toggle(isOn: $config.useHypervisor, label: {
                        Text("Use Hypervisor")
                    }).disabled(!config.isTargetArchitectureMatchHost)
                    #endif
                    Toggle(isOn: $config.rtcUseLocalTime, label: {
                        Text("Use local time for base clock")
                    }).help("If checked, use local time for RTC which is required for Windows. Otherwise, use UTC clock.")
                }
                Section(header: Text("Logging")) {
                    Toggle(isOn: $config.debugLogEnabled, label: {
                        Text("Debug Logging")
                    })
                    Button("Export Debug Log") {
                        showExportLog.toggle()
                    }.modifier(VMShareItemModifier(isPresented: $showExportLog, shareItem: exportDebugLog()))
                    .disabled(!logExists)
                }
                Section(header: Text("QEMU Arguments")) {
                    Button("Export QEMU Command") {
                        showExportArgs.toggle()
                    }.modifier(VMShareItemModifier(isPresented: $showExportArgs, shareItem: exportArgs()))
                    Toggle(isOn: $config.ignoreAllConfiguration.animation(), label: {
                        Text("Do not generate any arguments based on current configuration")
                    })
                    let qemuSystem = UTMQemuSystem(configuration: config, imgPath: URL(fileURLWithPath: "Images"))
                    let fixedArgs = arguments(from: qemuSystem.argv)
                    #if os(macOS)
                    VStack {
                        ForEach(fixedArgs) { arg in
                            TextField("", text: .constant(arg.string))
                        }.disabled(true)
                        CustomArguments(config: config)
                        NewArgumentTextField(config: config)
                    }
                    #else
                    List {
                        ForEach(fixedArgs) { arg in
                            Text(arg.string)
                        }.foregroundColor(.secondary)
                        CustomArguments(config: config)
                        NewArgumentTextField(config: config)
                    }
                    #endif
                }
            }.navigationBarItems(trailing: EditButton())
            .disableAutocorrection(true)
        }
    }
    
    private func exportDebugLog() -> VMShareItemModifier.ShareItem? {
        guard let path = config.existingPath else {
            return nil
        }
        let srcLogPath = path.appendingPathComponent(UTMQemuConfiguration.debugLogName)
        return .debugLog(srcLogPath)
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
    
    private func exportArgs() -> VMShareItemModifier.ShareItem {
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
        return .qemuCommand(argString)
    }
    
    private func arguments(from list: [String]) -> [Argument] {
        list.indices.map { i in
            Argument(id: i, string: list[i])
        }
    }
}

@available(iOS 14, macOS 11, *)
struct CustomArguments: View {
    @ObservedObject var config: UTMQemuConfiguration
    
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
                DefaultTextField("", text: argBinding, prompt: "(Delete)", onEditingChanged: { editing in
                    if !editing && argBinding.wrappedValue == "" {
                        config.removeArgument(at: i)
                    }
                })
                #if os(macOS)
                Spacer()
                if i != 0 {
                    Button(action: { config.moveArgumentIndex(i, to: i-1) }, label: {
                        Label("Move Up", systemImage: "arrow.up").labelStyle(.iconOnly)
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
struct NewArgumentTextField: View {
    @ObservedObject var config: UTMQemuConfiguration
    @State private var newArg: String = ""
    
    var body: some View {
        Group {
            DefaultTextField("", text: $newArg, prompt: "New...", onEditingChanged: addArg)
        }.onDisappear {
            if newArg != "" {
                addArg(editing: false)
            }
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
}

@available(iOS 14, macOS 11, *)
struct VMConfigQEMUView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMConfigQEMUView(config: config)
    }
}
