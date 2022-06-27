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
    @Binding var diskImage: DiskImage
    let onDelete: () -> Void

    var body: some View {
        Form {
            TextField("Name", text: .constant(diskImage.imageURL?.lastPathComponent ?? NSLocalizedString("(New Drive)", comment: "VMConfigAppleDriveDetailsView")))
                .disabled(true)
            Toggle("Read Only?", isOn: $diskImage.isReadOnly)
            Toggle("Run using a snapshot? (similar to qemu --snapshot)", isOn: $diskImage.isRunAsSnapshot)
            Button(action: onDelete) {
                Label("Delete Drive", systemImage: "externaldrive.badge.minus")
                    .foregroundColor(.red)
            }.help("Delete this drive.")
        }
    }
}

struct VMConfigAppleDriveDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        VMConfigAppleDriveDetailsView(diskImage: .constant(DiskImage(newSize: 100)), onDelete: {})
    }
}
