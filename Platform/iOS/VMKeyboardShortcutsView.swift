//
// Copyright © 2025 osy. All rights reserved.
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

struct VMKeyboardShortcutsView: View {
    let onShortcut: ([QEMUKeyCode]) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var keyboardShortcuts: [[QEMUKeyCode]] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(keyboardShortcuts, id: \.self) { element in
                    Button(element.title) {
                        onShortcut(element)
                        presentationMode.wrappedValue.dismiss()
                    }
                }.onDelete { indexSet in
                    keyboardShortcuts.remove(atOffsets: indexSet)
                }.onMove { indexSet, offset in
                    keyboardShortcuts.move(fromOffsets: indexSet, toOffset: offset)
                }
                NavigationLink("Add…") {
                    NewKeyboardShortcutView(keyboardShortcuts: $keyboardShortcuts)
                }
            }.navigationTitle("Keyboard Shortcut")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    EditButton()
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            keyboardShortcuts = UTMKeyboardShortcuts.shared.loadKeyboardShortcuts()
        }
        .onChange(of: keyboardShortcuts) { newValue in
            UTMKeyboardShortcuts.shared.saveKeyboardShortcuts(newValue)
        }
    }
}

private struct NewKeyboardShortcutView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var keyboardShortcuts: [[QEMUKeyCode]]
    @State private var newShortcut: [QEMUKeyCode] = []
    @State private var newKey: QEMUKeyCode?

    var body: some View {
        List {
            DetailedSection("Keys") {
                ForEach(newShortcut, id: \.self) { element in
                    Text(element.title)
                }.onDelete { indexSet in
                    newShortcut.remove(atOffsets: indexSet)
                }.onMove { indexSet, offset in
                    newShortcut.move(fromOffsets: indexSet, toOffset: offset)
                }
            }
            DetailedSection("New Key") {
                Picker("", selection: $newKey) {
                    Text("").tag(nil as QEMUKeyCode?)
                    ForEach(QEMUKeyCode.allCases) { keyCode in
                        if !newShortcut.contains(keyCode) {
                            Text(keyCode.title).tag(keyCode)
                        }
                    }
                }.pickerStyle(.wheel)
                Button("Add") {
                    if let key = newKey {
                        newShortcut.append(key)
                    }
                    newKey = nil
                }.disabled(newKey == nil)
            }
        }.navigationTitle("New Keyboard Shortcut")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                EditButton()
                Button("Save") {
                    if !newShortcut.isEmpty {
                        keyboardShortcuts.append(newShortcut)
                    }
                    presentationMode.wrappedValue.dismiss()
                }.disabled(newShortcut.isEmpty)
            }
        }
        .onAppear {
            newShortcut = []
            newKey = nil
        }
    }
}

#Preview {
    VMKeyboardShortcutsView() { _ in }
}
