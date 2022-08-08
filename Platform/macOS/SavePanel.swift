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
            
            guard let window = nsView.window else {
                return
            }
            
            // Initializing the SavePanel and setting its properties
            let savePanel = NSSavePanel()
            if let downloadsUrl = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                savePanel.directoryURL = downloadsUrl
            }
            
            switch shareItem {
            case .debugLog:
                savePanel.title = NSLocalizedString("Select where to save debug log:", comment: "SavePanel")
                savePanel.nameFieldStringValue = "debug"
                savePanel.allowedContentTypes = [.appleLog]
            case .utmCopy(let vm), .utmMove(let vm):
                savePanel.title = NSLocalizedString("Select where to save UTM Virtual Machine:", comment: "SavePanel")
                savePanel.nameFieldStringValue = vm.path.lastPathComponent
                savePanel.allowedContentTypes = [.UTM]
            case .qemuCommand:
                savePanel.title = NSLocalizedString("Select where to export QEMU command:", comment: "SavePanel")
                savePanel.nameFieldStringValue = "command"
                savePanel.allowedContentTypes = [.plainText]
            }
            
            // Calling savePanel.begin with the appropriate completion handlers
            // SwiftUI BUG: if we don't wait, there is a crash due to an access issue
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                switch shareItem {
                case .debugLog(let sourceUrl):
                    savePanel.beginSheetModal(for: window) { result in
                        if result == .OK {
                            if let destUrl = savePanel.url {
                                data.busyWorkAsync {
                                    let fileManager = FileManager.default
                                    
                                    // All this mess is because FileManager.replaceItemAt deletes the source item
                                    let tempUrl = fileManager.temporaryDirectory.appendingPathComponent(sourceUrl.lastPathComponent)
                                    if fileManager.fileExists(atPath: tempUrl.path) {
                                        try fileManager.removeItem(at: tempUrl)
                                    }
                                    try fileManager.copyItem(at: sourceUrl, to: tempUrl)
                                    
                                    _ = try fileManager.replaceItemAt(destUrl, withItemAt: tempUrl)
                                }
                            }
                        }
                        isPresented = false
                    }
                case .utmCopy(let vm), .utmMove(let vm):
                    savePanel.beginSheetModal(for: window) { result in
                        if result == .OK {
                            if let destUrl = savePanel.url {
                                data.busyWorkAsync {
                                    if case .utmMove(_) = shareItem {
                                        try await data.move(vm: vm, to: destUrl)
                                    } else {
                                        try await data.export(vm: vm, to: destUrl)
                                    }
                                }
                            }
                        }
                        isPresented = false
                    }
                case .qemuCommand(let command):
                    savePanel.beginSheetModal(for: window) { result in
                        if result == .OK {
                            if let destUrl = savePanel.url {
                                data.busyWork {
                                    try command.write(to: destUrl, atomically: true, encoding: .utf8)
                                }
                            }
                        }
                        isPresented = false
                    }
                }
            }
        }
    }
}
