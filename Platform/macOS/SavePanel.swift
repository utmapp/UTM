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
    var shareItem: Any

    func makeNSView(context: Context) -> some NSView {
        return NSView()
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        if isPresented {
            let savePanel = NSSavePanel()
            savePanel.directoryURL = URL(fileURLWithPath: "/Users/\(NSUserName())/Downloads")

            if let sourceUrl = shareItem as? URL {
                if sourceUrl.pathExtension == "log" {
                    savePanel.title = "Select where to save debug log:"
                    savePanel.nameFieldStringValue = "debug"
                    savePanel.allowedContentTypes = [.appleLog]
                } else if sourceUrl.pathExtension == "utm" {
                    savePanel.title = "Select where to save UTM Virtual Machine:"
                    savePanel.nameFieldStringValue = sourceUrl.deletingPathExtension().lastPathComponent
                    savePanel.allowedContentTypes = [.UTM]
                } else { return }

                savePanel.begin { result in
                    if result == .OK {
                        if let destUrl = savePanel.url {
                            do {
                                try FileManager.default.copyItem(at: sourceUrl, to: destUrl)
                            } catch {
                                data.alertMessage = AlertMessage(error.localizedDescription)
                            }
                        }
                    }
                }
            } else if let command = shareItem as? String {
                savePanel.title = "Select where to export QEMU command:"
                savePanel.nameFieldStringValue = "command"
                savePanel.allowedContentTypes = [.plainText]

                savePanel.begin { result in
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
