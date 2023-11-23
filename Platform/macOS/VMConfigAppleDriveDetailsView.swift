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

struct VMConfigAppleDriveDetailsView: View {
    @Binding var config: UTMAppleConfigurationDrive
    @Binding var requestDriveDelete: UTMAppleConfigurationDrive?

    var body: some View {
        Form {
            Toggle(isOn: $config.isExternal, label: {
                Text("Removable Drive")
            }).disabled(true)
            TextField("Name", text: .constant(config.imageURL?.lastPathComponent ?? NSLocalizedString("(New Drive)", comment: "VMConfigAppleDriveDetailsView")))
                .disabled(true)
            Toggle("Read Only?", isOn: $config.isReadOnly)
            if #available(macOS 14, *), !config.isExternal {
                Toggle(isOn: $config.isNvme,
                       label: {
                    Text("Use NVMe Interface")
                }).help("If checked, use NVMe instead of virtio as the disk interface, available on macOS 14+ for Linux guests only. This interface is slower but less likely to encounter filesystem errors.")
            }
            if #unavailable(macOS 12) {
                Button {
                    requestDriveDelete = config
                } label: {
                    Label("Delete Drive", systemImage: "externaldrive.badge.minus")
                        .foregroundColor(.red)
                }.help("Delete this drive.")
            }
        }
    }
}

struct VMConfigAppleDriveDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        VMConfigAppleDriveDetailsView(config: .constant(UTMAppleConfigurationDrive(newSize: 100)), requestDriveDelete: .constant(nil))
    }
}
