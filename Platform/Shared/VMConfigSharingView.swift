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

struct VMConfigSharingView: View {
    @Binding var config: UTMQemuConfigurationSharing
    @State private var isImporterPresented: Bool = false
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        VStack {
            Form {
                DetailedSection("Clipboard Sharing", description: "Requires SPICE guest agent tools to be installed.") {
                    Toggle(isOn: $config.hasClipboardSharing, label: {
                        Text("Enable Clipboard Sharing")
                    })
                }
                
                DetailedSection("Shared Directory", description: "WebDAV requires installing SPICE daemon. VirtFS requires installing device drivers.") {
                    VMConfigConstantPicker("Directory Share Mode", selection: $config.directoryShareMode)
                    if config.directoryShareMode != .none {
                        FileBrowseField(url: $config.directoryShareUrl, isFileImporterPresented: $isImporterPresented)
                        Toggle(isOn: $config.isDirectoryShareReadOnly, label: {
                            Text("Read Only")
                        })
                    }
                }.globalFileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.folder]) { result in
                    data.busyWorkAsync {
                        let url = try result.get()
                        await MainActor.run {
                            config.directoryShareUrl = url
                        }
                    }
                }
            }
        }
    }
}

struct VMConfigSharingView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfigurationSharing()
    
    static var previews: some View {
        VMConfigSharingView(config: $config)
    }
}
