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
    @Environment(\.presentationMode) var presentationMode
    @State private var keyboardShortcuts: [[QEMUKeyCode]] = []
    @State private var isEditing: Bool = false
    @State private var currentlyEditingIndex: SelectedIndex?
    @State private var currentlyEditingShortcut: [QEMUKeyCode] = []
    
    let onDismiss: () -> Void
    
    init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    onDismiss()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Done")
                }
            }
            List(selection: $currentlyEditingIndex) {
                ForEach(Array(keyboardShortcuts.enumerated()), id: \.element) { index, element in
                    Text(element.title)
                        .tag(SelectedIndex(id: index))
                        .contextMenu {
                            Button("Edit") {
                                isEditing.toggle()
                            }
                            DestructiveButton("Delete") {
                                keyboardShortcuts.remove(at: index)
                            }
                        }
                }.onDelete { indexSet in
                    keyboardShortcuts.remove(atOffsets: indexSet)
                }.onMove { indexSet, offset in
                    keyboardShortcuts.move(fromOffsets: indexSet, toOffset: offset)
                }
            }.borderedList()
            .frame(height: 200)
            HStack {
                Spacer()
                if let index = currentlyEditingIndex?.id {
                    DestructiveButton("Delete") {
                        keyboardShortcuts.remove(at: index)
                    }
                    Button {
                        isEditing.toggle()
                    } label: {
                        Text("Edit")
                    }
                }
                Button {
                    currentlyEditingIndex = nil
                    currentlyEditingShortcut = []
                    isEditing.toggle()
                } label: {
                    Text("New")
                }
            }
        }
        .sheet(isPresented: $isEditing, onDismiss: {
            if let index = currentlyEditingIndex {
                if !currentlyEditingShortcut.isEmpty {
                    keyboardShortcuts[index.id] = currentlyEditingShortcut
                } else {
                    keyboardShortcuts.remove(at: index.id)
                }
            } else {
                if !currentlyEditingShortcut.isEmpty {
                    keyboardShortcuts.append(currentlyEditingShortcut)
                }
            }
        }, content: {
            EditKeyboardShortcutView(keyboardShortcut: $currentlyEditingShortcut).padding()
        })
        .onAppear {
            keyboardShortcuts = UTMKeyboardShortcuts.shared.loadKeyboardShortcuts()
        }
        .onChange(of: keyboardShortcuts) { newValue in
            UTMKeyboardShortcuts.shared.saveKeyboardShortcuts(newValue)
        }
        .onChange(of: currentlyEditingIndex) { newValue in
            if let index = newValue?.id {
                currentlyEditingShortcut = keyboardShortcuts[index]
            } else {
                currentlyEditingShortcut = []
            }
        }
    }
}

private struct EditKeyboardShortcutView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var keyboardShortcut: [QEMUKeyCode]
    @State private var currentlyEditingIndex: SelectedIndex?
    @State private var currentlyEditingKey: QEMUKeyCode?

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Done")
                }
            }
            List(selection: $currentlyEditingIndex) {
                ForEach(Array(keyboardShortcut.enumerated()), id: \.element) { index, keyCode in
                    Text(keyCode.title)
                        .tag(SelectedIndex(id: index))
                        .contextMenu {
                            DestructiveButton("Delete") {
                                keyboardShortcut.remove(at: index)
                            }
                        }
                }.onDelete { indexSet in
                    keyboardShortcut.remove(atOffsets: indexSet)
                }.onMove { indexSet, offset in
                    keyboardShortcut.move(fromOffsets: indexSet, toOffset: offset)
                }
            }.borderedList()
            .frame(height: 100)
            Spacer()
            HStack {
                Picker("New Key", selection: $currentlyEditingKey) {
                    Text("").tag(nil as QEMUKeyCode?)
                    ForEach(QEMUKeyCode.allCases) { keyCode in
                        if !keyboardShortcut.contains(keyCode) {
                            Text(keyCode.title).tag(keyCode)
                        }
                    }
                }
                Spacer()
                if let index = currentlyEditingIndex?.id {
                    DestructiveButton("Delete") {
                        keyboardShortcut.remove(at: index)
                    }
                    Button {
                        if let currentlyEditingKey = currentlyEditingKey {
                            keyboardShortcut[index] = currentlyEditingKey
                        }
                        currentlyEditingKey = nil
                    } label: {
                        Text("Update")
                    }.disabled(currentlyEditingKey == nil)
                }
                Button {
                    if let currentlyEditingKey = currentlyEditingKey {
                        keyboardShortcut.append(currentlyEditingKey)
                    }
                    currentlyEditingKey = nil
                    currentlyEditingIndex = nil
                } label: {
                    Text("Add")
                }.disabled(currentlyEditingKey == nil)
            }
        }
    }
}

private struct SelectedIndex: Identifiable, Hashable {
    var id: Int
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private extension View {
    @ViewBuilder
    func borderedList() -> some View {
        if #available(macOS 12, *) {
            self.listStyle(.bordered)
        } else {
            self.border(.gray)
        }
    }
}

#Preview {
    VMKeyboardShortcutsView()
}
