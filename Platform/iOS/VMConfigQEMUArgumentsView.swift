//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

struct VMConfigQEMUArgumentsView: View {
    @ObservedObject var config: UTMQemuConfiguration
    
    var body: some View {
        Form {
            Section(header: Text("Custom Arguments")) {
                ForEach($config.qemu.additionalArguments) { $argument in
                    NavigationLink {
                        QEMUArgumentEdit(argument: argument,
                                         onSave: { argument = $0 },
                                         onDelete: { config.qemu.additionalArguments.removeAll(where: { $0.id == argument.id }) })
                    } label: {
                        Text(argument.string)
                            .font(.system(.body, design: .monospaced))
                    }
                }.onDelete { offsets in
                    config.qemu.additionalArguments.remove(atOffsets: offsets)
                }.onMove { offsets, destination in
                    config.qemu.additionalArguments.move(fromOffsets: offsets, toOffset: destination)
                }
                NavigationLink("New") {
                    QEMUArgumentEdit(onSave: { config.qemu.additionalArguments.append($0) })
                }
            }
            VMConfigQEMUCommandLineView(config: config)
        }.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
}

struct QEMUArgumentEdit: View {
    @State var argument: QEMUArgument = QEMUArgument("")
    let onSave: (QEMUArgument) -> Void
    var onDelete: (() -> Void)? = nil
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        Form {
            Section(header: Text("Argument")) {
                TextField("-option value", text: $argument.string)
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
            }
        }
        .navigationTitle(onDelete == nil ? "New Argument" : "Edit Argument")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let onDelete = onDelete {
                    Button("Delete", role: .destructive) {
                        closePopup(after: onDelete)
                    }
                }
                Button("Save") {
                    closePopup(after: { onSave(argument) })
                }.disabled(argument.string.isEmpty)
            }
        }
    }
    
    private func closePopup(after action: () -> Void) {
        action()
        presentationMode.wrappedValue.dismiss()
    }
}

struct VMConfigQEMUArgumentsView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        NavigationView {
            VMConfigQEMUArgumentsView(config: config)
                .navigationTitle("Arguments")
        }.onAppear {
            if config.qemu.additionalArguments.isEmpty {
                config.qemu.additionalArguments.append(QEMUArgument("-append"))
                config.qemu.additionalArguments.append(QEMUArgument("\"root=/dev/vda1 console=ttyS0\""))
            }
        }
    }
}
