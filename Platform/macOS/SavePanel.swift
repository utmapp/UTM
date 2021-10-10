//
// Copyright © 2021 osy. All rights reserved.
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

@available(macOS 11, *)
struct SavePanel: NSViewRepresentable {
    @EnvironmentObject private var data: UTMData
    @Binding var isPresented: Bool
    var shareItem: VMShareItemModifier.ShareItem?

    func makeNSView(context: Context) -> some NSView {
        return NSView()
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        if isPresented {
            guard let shareItem = shareItem else {
                return
            }
            
            // Initializing the SavePanel and setting it's properties
            let savePanel = NSSavePanel()
            savePanel.directoryURL = URL(fileURLWithPath: "/Users/\(NSUserName())/Downloads")
            
            switch shareItem {
            case .debugLog:
                savePanel.title = "Select where to save debug log:"
                savePanel.nameFieldStringValue = "debug"
                savePanel.allowedContentTypes = [.appleLog]
            case let .utmVm(sourceUrl):
                savePanel.title = "Select where to save UTM Virtual Machine:"
                savePanel.nameFieldStringValue = sourceUrl.deletingPathExtension().lastPathComponent
                savePanel.allowedContentTypes = [.UTM]
            case .qemuCommand:
                savePanel.title = "Select where to export QEMU command:"
                savePanel.nameFieldStringValue = "command"
                savePanel.allowedContentTypes = [.plainText]
            }
            
            // Calling savePanel.begin with the appropriate completion handlers
            switch shareItem {
            case .debugLog(let sourceUrl), .utmVm(let sourceUrl):
                savePanel.beginSheetModal(for: nsView.window!) { result in
                    if result == .OK {
                        if let destUrl = savePanel.url {
                            do {
                                let fileManager = FileManager.default
                                
                                // All this mess is because FileManager.replaceItemAt deletes the source item
                                let tempUrl = fileManager.temporaryDirectory.appendingPathComponent(sourceUrl.lastPathComponent)
                                if fileManager.fileExists(atPath: tempUrl.path) {
                                    try fileManager.removeItem(at: tempUrl)
                                }
                                try fileManager.copyItem(at: sourceUrl, to: tempUrl)
                                
                                _ = try fileManager.replaceItemAt(destUrl, withItemAt: tempUrl)
                            } catch {
                                data.alertMessage = AlertMessage(error.localizedDescription)
                            }
                        }
                    }
                }
            case .qemuCommand(let command):
                savePanel.beginSheetModal(for: nsView.window!) { result in
                    if result == .OK {
                        if let destUrl = savePanel.url {
                            do {
                                try command.write(to: destUrl, atomically: true, encoding: .utf8)
                            } catch {
                                data.alertMessage = AlertMessage(error.localizedDescription)
                            }
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                isPresented = false
            }
        }
    }
}
