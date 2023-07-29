//
// Copyright © 2023 osy. All rights reserved.
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

@available(macOS 12, *)
struct VMConfigQEMUArgumentsView: View {
    @Binding var config: UTMQemuConfigurationQEMU
    let architecture: QEMUArchitecture
    let fixedArguments: [QEMUArgument]
    
    private let fixedUuids: Set<UUID>
    @State private var selected: Set<UUID>
    @State private var selectedArgument = QEMUArgument("")
    @FocusState private var focused: UUID?
    @State private var showExportArgs: Bool = false
    
    private var customUuids: Set<UUID> {
        Set(config.additionalArguments.map({ $0.id }))
    }
    
    private var exportShareItem: VMShareItemModifier.ShareItem {
        var argString = "qemu-system-\(architecture.rawValue)"
        for arg in fixedArguments {
            if arg.string.contains(" ") {
                argString += " \"\(arg.string)\""
            } else {
                argString += " \(arg.string)"
            }
        }
        for arg in config.additionalArguments {
            argString += " \(arg.string)"
        }
        return .qemuCommand(argString)
    }
    
    init(config: Binding<UTMQemuConfigurationQEMU>, architecture: QEMUArchitecture, fixedArguments: [QEMUArgument]) {
        self._config = config
        self.architecture = architecture
        self.fixedArguments = fixedArguments
        self.fixedUuids = Set(fixedArguments.map({ $0.id }))
        self._selected = State<Set<UUID>>(initialValue: .init())
    }
    
    var body: some View {
        VStack {
            Table(of: QEMUArgument.self, selection: $selected) {
                TableColumn("Arguments") { arg in
                    let customSelected = selected.intersection(customUuids)
                    if fixedUuids.contains(arg.id) || customSelected.count > 1 || !customSelected.contains(arg.id) {
                        Text(arg.string)
                            .foregroundColor(fixedUuids.contains(arg.id) ? .secondary : .primary)
                            .textSelection(.enabled)
                    } else {
                        TextField("", text: $selectedArgument.string)
                            .focused($focused, equals: arg.id)
                            .onSubmit(of: .text) {
                                if let index = config.additionalArguments.firstIndex(of: arg) {
                                    config.additionalArguments[index] = selectedArgument
                                }
                            }
                    }
                }
            } rows: {
                ForEach(fixedArguments) { arg in
                    TableRow(arg)
                }
                ForEach(config.additionalArguments) { arg in
                    TableRow(arg)
                }
            }.onChange(of: selected) { newValue in
                // save changes to last selected argument
                if let index = config.additionalArguments.firstIndex(where: { $0.id == selectedArgument.id }) {
                    config.additionalArguments[index] = selectedArgument
                    selectedArgument = .init("")
                }
                // get new selected argument
                if let selectedId = selected.intersection(customUuids).first {
                    if let arg = config.additionalArguments.first(where: { $0.id == selectedId }) {
                        selectedArgument = arg
                    }
                }
            }
            Spacer()
            HStack {
                Button {
                    showExportArgs.toggle()
                } label: {
                    Text("Export QEMU Command…")
                }.help("Export all arguments as a text file. This is only for debugging purposes as UTM's built-in QEMU differs from upstream QEMU in supported arguments.")
                Spacer()
                let customSelected = selected.intersection(customUuids)
                if !customSelected.isEmpty {
                    if customSelected.count > 1 || customSelected.first != config.additionalArguments.first?.id {
                        Button {
                            for i in 1..<config.additionalArguments.count {
                                if customSelected.contains(config.additionalArguments[i].id) {
                                    config.additionalArguments.move(fromOffsets: .init(integer: i), toOffset: i - 1)
                                }
                            }
                        } label: {
                            Text("Move Up")
                        }
                    }
                    if customSelected.count > 1 || customSelected.first != config.additionalArguments.last?.id {
                        Button {
                            for i in (0..<config.additionalArguments.count-1).reversed() {
                                if customSelected.contains(config.additionalArguments[i].id) {
                                    config.additionalArguments.move(fromOffsets: .init(integer: i), toOffset: i + 2)
                                }
                            }
                        } label: {
                            Text("Move Down")
                        }
                    }
                    Button(role: .destructive) {
                        config.additionalArguments.removeAll(where: { customSelected.contains($0.id) })
                    } label: {
                        Text("Delete")
                    }
                }
                Button {
                    let new = QEMUArgument("")
                    config.additionalArguments.append(new)
                    selected.removeAll()
                    selected.insert(new.id)
                    focused = new.id
                } label: {
                    Text("New…")
                }
            }.padding([.bottom, .leading, .trailing])
        }.modifier(VMShareItemModifier(isPresented: $showExportArgs, shareItem: exportShareItem))
    }
}
