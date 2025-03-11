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
    @State private var mountTag: String = ""

    var body: some View {

        Form {
            VStack(alignment: .leading, spacing: 16.0) {
                if #available(macOS 13.0, *) {
                    // Information text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shared directories in macOS VMs are only available in macOS 13 and later.")
                            .padding(.top, 4)
                        LabeledContent("(Advanced) Custom mount tag") {
                            TextField("", text: $mountTag)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300)
                                .onChange(of: mountTag) { newValue in
                                    config.sharedDirectoryMountTag = newValue.isEmpty ? nil : newValue
                                }
                        }
                        .help("The name that shared directories will use when mounted in the guest. Useful when applications have issues with spaces in paths.")
                        .onAppear {
                            mountTag = config.sharedDirectoryMountTag ?? ""
                        }
                        Text("note: This disable automatic mounting. You must use `mountfs_virtio tag path` in the guset.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("e.g. $ mkdir ~/shared; mountfs_virtio \(mountTag.isEmpty ? "tag" : mountTag) ~/shared")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                // Table section
                VStack(alignment: .leading, spacing: 9.0) {
                    Table(config.sharedDirectories, selection: $selectedID) {
                        TableColumn("Shared Path") { share in
                            Text(share.directoryURL?.path ?? "")
                        }
                        TableColumn("Read Only?") { share in
                            Toggle("", isOn: .constant(share.isReadOnly))
                                .disabled(true)
                                .labelsHidden()
                        }
                    }
                    .frame(minHeight: 200)
                    // Buttons
                    HStack {
                        Spacer()
                        Button("Delete") {
                            config.sharedDirectories.removeAll { share in
                                share.id == selectedID
                            }
                        }
                        .disabled(selectedID == nil)
                        .buttonStyle(.bordered)

                        Button("Add") {
                            isImporterPresented.toggle()
                        }
                        .buttonStyle(.bordered)
                    }
                    .fileImporter(
                        isPresented: $isImporterPresented,
                        allowedContentTypes: [.folder]
                    ) { result in
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
                    // Read only toggle
                    HStack {
                        Spacer()
                        Toggle("Add read only", isOn: $isAddReadOnly)
                    }
                }
            }
            .padding([.horizontal, .bottom], 9.0)
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
