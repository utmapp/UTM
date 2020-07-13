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
import UniformTypeIdentifiers

struct FilePicker: UIViewControllerRepresentable {
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let filePicker: FilePicker
        
        init(filePicker: FilePicker) {
            self.filePicker = filePicker
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt: [URL]) {
            filePicker.onSelection(didPickDocumentsAt)
        }
    }
    
    let contentTypes: [UTType]
    let asCopy: Bool
    let onSelection: ([URL]) -> Void
    
    init(forOpeningContentTypes contentTypes: [UTType],
         asCopy: Bool = false, onSelection: @escaping ([URL]) -> Void) {
        self.contentTypes = contentTypes
        self.asCopy = asCopy
        self.onSelection = onSelection
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: asCopy)
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {
        
    }
    
    func makeCoordinator() -> Self.Coordinator {
        Coordinator(filePicker: self)
    }
}

struct FilePicker_Previews: PreviewProvider {
    static var previews: some View {
        FilePicker(forOpeningContentTypes: [.item]) { _ in
            
        }
    }
}
