//
// Copyright © 2022 osy. All rights reserved.
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

struct FileBrowseField: View {
    let titleKey: LocalizedStringKey
    @Binding var url: URL?
    @Binding var isFileImporterPresented: Bool
    let hasClearButton: Bool
    let onBrowse: () -> Void
    
    init(_ titleKey: LocalizedStringKey = "Path", url: Binding<URL?>, isFileImporterPresented: Binding<Bool>, hasClearButton: Bool = true, onBrowse: @escaping () -> Void = {}) {
        self.titleKey = titleKey
        self._url = url
        self._isFileImporterPresented = isFileImporterPresented
        self.hasClearButton = hasClearButton
        self.onBrowse = onBrowse
    }
    
    var body: some View {
        #if os(macOS)
        HStack {
            TextField(titleKey, text: .constant(url?.lastPathComponent ?? ""))
                .truncationMode(.head)
                .disabled(true)
            if hasClearButton {
                Button("Clear") {
                    url = nil
                }
            }
            Button("Browse…") {
                onBrowse()
                isFileImporterPresented.toggle()
            }
        }
        #else
        if let path = url?.path {
            Text(path)
                .lineLimit(1)
                .truncationMode(.head)
        } else {
            Text(titleKey)
                .foregroundColor(.secondary)
        }
        if hasClearButton {
            Button {
                url = nil
            } label: {
                Text("Clear")
            }
        }
        Button {
            onBrowse()
            isFileImporterPresented.toggle()
        } label: {
            Text("Browse…")
        }
        #endif
    }
}

struct FileBrowseField_Previews: PreviewProvider {
    static var previews: some View {
        FileBrowseField(url: .constant(URL(fileURLWithPath: "/")), isFileImporterPresented: .constant(false))
    }
}
