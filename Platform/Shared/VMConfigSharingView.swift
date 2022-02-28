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

@available(iOS 14, macOS 11, *)
struct VMConfigSharingView: View {
    @ObservedObject var config: UTMQemuConfiguration
    
    var body: some View {
        VStack {
            Form {
                if config.displayConsoleOnly {
                    Text("These settings are unavailable in console display mode.")
                }
                
                DetailedSection("Clipboard Sharing", description: "Requires SPICE guest agent tools to be installed.") {
                    Toggle(isOn: $config.shareClipboardEnabled, label: {
                        Text("Enable Clipboard Sharing")
                    })
                }
                
                DetailedSection("Shared Directory", description: "Requires SPICE WebDAV service to be installed.") {
                    Toggle(isOn: $config.shareDirectoryEnabled.animation(), label: {
                        Text("Enable Directory Sharing")
                    }).onChange(of: config.shareDirectoryEnabled, perform: { _ in
                        // remove legacy bookmark data
                        config.shareDirectoryBookmark = nil
                    })
                    Toggle(isOn: $config.shareDirectoryReadOnly, label: {
                        Text("Read Only")
                    })
                    Text("Note: select the path to share from the main screen.")
                }
            }.disabled(config.displayConsoleOnly)
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigSharingView_Previews: PreviewProvider {
    @State static private var config = UTMQemuConfiguration()
    
    static var previews: some View {
        VMConfigSharingView(config: config)
    }
}
