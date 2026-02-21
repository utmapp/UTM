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
            Spacer()
            Form {
                Section(header: Text("Debug")) {
                    Button {
                        showExportArgs.toggle()
                    } label: {
                        Text("Export QEMU Command…")
                    }.help("Export all arguments as a text file. This is only for debugging purposes as UTM's built-in QEMU differs from upstream QEMU in supported arguments.")
                    Spacer()
                }
            }
            .frame(maxHeight: 200) // constrain the Form's height
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(VMShareItemModifier(isPresented: $showExportArgs, shareItem: exportShareItem))
    }
}
