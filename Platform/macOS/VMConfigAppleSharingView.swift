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

@available(macOS 12, *)
struct VMConfigAppleSharingView: View {
    @ObservedObject var config: UTMAppleConfiguration
    @EnvironmentObject private var data: UTMData
    @State private var selectedID: UUID?
    @State private var isImporterPresented: Bool = false
    @State private var isAddReadOnly: Bool = false
    
    var body: some View {
        Form {
            if config.system.boot.operatingSystem == .macOS {
                Text("Shared directories in macOS VMs are only available in macOS 13 and later.")
            }
            Table(config.sharedDirectories, selection: $selectedID) {
                TableColumn("Shared Path") { share in
                    Text(share.directoryURL?.path ?? "")
                }
                TableColumn("Read Only?") { share in
                    Toggle("", isOn: .constant(share.isReadOnly))
                        .disabled(true)
                        .help("To change this, remove the shared directory and add it again.")
                }
            }
            HStack {
                Spacer()
                Button("Delete") {
                    config.sharedDirectories.removeAll { share in
                        share.id == selectedID
                    }
                }.disabled(selectedID == nil)
                Button("Add") {
                    isImporterPresented.toggle()
                }
            }.fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.folder]) { result in
                data.busyWorkAsync {
                    let url = try result.get()
                    if await config.sharedDirectories.contains(where: { existing in
                        url == existing.directoryURL
                    }) {
                        throw NSLocalizedString("This directory is already being shared.", comment: "VMConfigAppleSharingView")
                    }
                    await MainActor.run {
                        config.sharedDirectories.append(UTMAppleConfigurationSharedDirectory(directoryURL: url, isReadOnly: isAddReadOnly))
                    }
                }
            }
            HStack {
                Spacer()
                Toggle("Add read only", isOn: $isAddReadOnly)
            }
        }
    }
}

@available(macOS 12, *)
struct VMConfigAppleSharingView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfiguration()
    
    static var previews: some View {
        VMConfigAppleSharingView(config: config)
    }
}
