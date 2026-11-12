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
                                currentlyEditingIndex = SelectedIndex(id: index)
                                currentlyEditingShortcut = element
                                isEditing.toggle()
                            }
                            DestructiveButton("Delete") {
                                removeShortcuts(atOffsets: [index])
                            }
                        }
                }.onDelete { indexSet in
                    removeShortcuts(atOffsets: indexSet)
                }.onMove { indexSet, offset in
                    moveShortcuts(fromOffsets: indexSet, toOffset: offset)
                }
            }.listStyle(.bordered)
            .frame(height: 200)
            HStack {
                Spacer()
                if let index = currentlyEditingIndex?.id, keyboardShortcuts.indices.contains(index) {
                    DestructiveButton("Delete") {
                        removeShortcuts(atOffsets: [index])
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
                    removeShortcuts(atOffsets: [index.id])
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
            currentlyEditingIndex = nil
        }
        .onChange(of: keyboardShortcuts) { newValue in
            UTMKeyboardShortcuts.shared.saveKeyboardShortcuts(newValue)
        }
        .onChange(of: currentlyEditingIndex) { newValue in
            if let index = newValue?.id, keyboardShortcuts.indices.contains(index) {
                currentlyEditingShortcut = keyboardShortcuts[index]
            } else {
                currentlyEditingShortcut = []
            }
        }
    }

    private func removeShortcuts(atOffsets offsets: IndexSet) {
        SelectedIndex.remove(atOffsets: offsets, from: &keyboardShortcuts, selection: &currentlyEditingIndex)
    }

    private func moveShortcuts(fromOffsets offsets: IndexSet, toOffset offset: Int) {
        SelectedIndex.move(fromOffsets: offsets, toOffset: offset, in: &keyboardShortcuts, selection: &currentlyEditingIndex)
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
                                removeKeys(atOffsets: [index])
                            }
                        }
                }.onDelete { indexSet in
                    removeKeys(atOffsets: indexSet)
                }.onMove { indexSet, offset in
                    moveKeys(fromOffsets: indexSet, toOffset: offset)
                }
            }.listStyle(.bordered)
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
                if let index = currentlyEditingIndex?.id, keyboardShortcut.indices.contains(index) {
                    DestructiveButton("Delete") {
                        removeKeys(atOffsets: [index])
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

    private func removeKeys(atOffsets offsets: IndexSet) {
        SelectedIndex.remove(atOffsets: offsets, from: &keyboardShortcut, selection: &currentlyEditingIndex)
    }

    private func moveKeys(fromOffsets offsets: IndexSet, toOffset offset: Int) {
        SelectedIndex.move(fromOffsets: offsets, toOffset: offset, in: &keyboardShortcut, selection: &currentlyEditingIndex)
    }
}

private struct SelectedIndex: Identifiable, Hashable {
    var id: Int
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func remove<T>(atOffsets offsets: IndexSet, from array: inout [T], selection: inout SelectedIndex?) {
        selection = following(selection, count: array.count) { $0.remove(atOffsets: offsets) }
        array.remove(atOffsets: offsets)
    }

    static func move<T>(fromOffsets offsets: IndexSet, toOffset offset: Int, in array: inout [T], selection: inout SelectedIndex?) {
        selection = following(selection, count: array.count) { $0.move(fromOffsets: offsets, toOffset: offset) }
        array.move(fromOffsets: offsets, toOffset: offset)
    }

    /// Keeps the selection on the same row after rows are removed or moved, or clears it if that row was removed.
    private static func following(_ selection: SelectedIndex?, count: Int, through change: (inout [Int]) -> Void) -> SelectedIndex? {
        guard let selection = selection else {
            return nil
        }
        var rows = Array(0..<count)
        change(&rows)
        return rows.firstIndex(of: selection.id).map { SelectedIndex(id: $0) }
    }
}

#Preview {
    VMKeyboardShortcutsView()
}
