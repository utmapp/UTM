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
struct VMConfigDriveCreateView: View {
    let minSizeMib = 1
    
    @ObservedObject var driveImage: VMDriveImage
    
    var body: some View {
        Form {
            Toggle(isOn: $driveImage.removable.animation(), label: {
                Text("Removable")
            })
            if !driveImage.removable {
                HStack {
                    Text("Size")
                    Spacer()
                    TextField("Size", value: $driveImage.size, formatter: NumberFormatter(), onCommit: validateSize)
                        .multilineTextAlignment(.trailing)
                    Text("MB")
                }
            }
            VMConfigStringPicker(selection: $driveImage.imageTypeString, label: Text("Image Type"), rawValues: UTMConfiguration.supportedImageTypes(), displayValues: UTMConfiguration.supportedImageTypesPretty())
            if driveImage.imageType == .disk || driveImage.imageType == .CD {
                VMConfigStringPicker(selection: $driveImage.interface, label: Text("Interface"), rawValues: UTMConfiguration.supportedDriveInterfaces(), displayValues: UTMConfiguration.supportedDriveInterfaces())
            }
        }
    }
    
    private func validateSize() {
        if driveImage.size < minSizeMib {
            driveImage.size = minSizeMib
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigDriveCreateView_Previews: PreviewProvider {
    @StateObject static private var driveImage = VMDriveImage()
    
    static var previews: some View {
        VMConfigDriveCreateView(driveImage: driveImage)
    }
}
