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

struct VMConfigQEMUArgumentsView: View {
    @ObservedObject var config: UTMQemuConfiguration
    @State private var selectedId: UUID?
    @State private var isEditingNewArgument = false
    @State private var editArgument: QEMUArgument?
    
    private var selectedIndex: Int? {
        config.qemu.additionalArguments.firstIndex(where: { $0.id == selectedId })
    }
    
    var body: some View {
        // GeometryReader keeps the ideal size small so the sheet does not grow to fit the whole command line
        GeometryReader { _ in
            VStack(alignment: .leading) {
                Table(config.qemu.additionalArguments, selection: $selectedId) {
                    TableColumn("Custom Arguments") { argument in
                        Text(argument.string)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .frame(height: 150)
                HStack {
                    Spacer()
                    Button("Move Up") {
                        move(by: -1)
                    }.disabled(selectedIndex == nil || selectedIndex == 0)
                    Button("Move Down") {
                        move(by: 1)
                    }.disabled(selectedIndex == nil || selectedIndex == config.qemu.additionalArguments.count - 1)
                    Button("Delete") {
                        if let index = selectedIndex {
                            config.qemu.additionalArguments.remove(at: index)
                            selectedId = nil
                        }
                    }.disabled(selectedIndex == nil)
                    Button("Edit…", action: editSelected)
                        .disabled(selectedIndex == nil)
                        .popover(item: $editArgument, arrowEdge: .top) { argument in
                            QEMUArgumentEdit(config: $config.qemu, argument: argument).padding()
                                .frame(width: 400)
                        }
                    Button("New…") {
                        isEditingNewArgument.toggle()
                    }.popover(isPresented: $isEditingNewArgument, arrowEdge: .top) {
                        QEMUArgumentEdit(config: $config.qemu, argument: QEMUArgument("")).padding()
                            .frame(width: 400)
                    }
                }
                VMConfigQEMUCommandLineView(config: config)
            }.padding()
        }
    }
    
    private func editSelected() {
        editArgument = config.qemu.additionalArguments.first(where: { $0.id == selectedId })
    }
    
    private func move(by offset: Int) {
        guard let index = selectedIndex else {
            return
        }
        let destination = offset < 0 ? index - 1 : index + 2
        config.qemu.additionalArguments.move(fromOffsets: IndexSet(integer: index), toOffset: destination)
    }
}

struct QEMUArgumentEdit: View {
    @Binding var config: UTMQemuConfigurationQEMU
    @State var argument: QEMUArgument
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    private var index: Int? {
        config.additionalArguments.firstIndex(where: { $0.id == argument.id })
    }
    
    var body: some View {
        VStack {
            TextField("Argument", text: $argument.string, prompt: Text("-option value"))
                .font(.system(.body, design: .monospaced))
                .disableAutocorrection(true)
                .onSubmit(save)
            HStack {
                Spacer()
                if let index = index {
                    Button("Delete") {
                        config.additionalArguments.remove(at: index)
                        closePopup()
                    }
                }
                Button("Save", action: save)
                    .disabled(argument.string.isEmpty)
            }
        }
    }
    
    private func save() {
        guard !argument.string.isEmpty else {
            return
        }
        if let index = index {
            config.additionalArguments[index] = argument
        } else {
            config.additionalArguments.append(argument)
        }
        closePopup()
    }
    
    private func closePopup() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct VMConfigQEMUArgumentsView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMConfigQEMUArgumentsView(config: config)
            .frame(width: 600, height: 500)
            .onAppear {
                if config.qemu.additionalArguments.isEmpty {
                    config.qemu.additionalArguments.append(QEMUArgument("-append"))
                    config.qemu.additionalArguments.append(QEMUArgument("\"root=/dev/vda1 console=ttyS0\""))
                }
            }
    }
}
