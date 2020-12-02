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
struct VMConfigDriveDetailsView: View {
    @ObservedObject private var config: UTMConfiguration
    @Binding private var removable: Bool
    @Binding private var name: String?
    @Binding private var imageTypeString: String?
    @Binding private var interface: String?
    
    var imageType: UTMDiskImageType {
        get {
            UTMDiskImageType.enumFromString(imageTypeString)
        }
        
        set {
            imageTypeString = newValue.description
        }
    }
    
    init(config: UTMConfiguration, index: Int) {
        self.config = config // for observing updates
        self._removable = Binding<Bool> {
            return config.driveRemovable(for: index)
        } set: {
            config.setDriveRemovable($0, for: index)
        }
        self._name = Binding<String?> {
            return config.driveImagePath(for: index)
        } set: {
            if let name = $0 {
                config.setImagePath(name, for: index)
            }
        }
        self._imageTypeString = Binding<String?> {
            return config.driveImageType(for: index).description
        } set: {
            config.setDrive(UTMDiskImageType.enumFromString($0), for: index)
        }
        self._interface = Binding<String?> {
            return config.driveInterfaceType(for: index)
        } set: {
            if let interface = $0 {
                config.setDriveInterfaceType(interface, for: index)
            }
        }
    }
    
    var body: some View {
        Form {
            Toggle(isOn: $removable.animation(), label: {
                Text("Removable Drive")
            }).disabled(true)
            if !removable {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(name ?? "")
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                }
            }
            VMConfigStringPicker(selection: $imageTypeString, label: Text("Image Type"), rawValues: UTMConfiguration.supportedImageTypes(), displayValues: UTMConfiguration.supportedImageTypesPretty())
            if imageType == .disk || imageType == .CD {
                VMConfigStringPicker(selection: $interface, label: Text("Interface"), rawValues: UTMConfiguration.supportedDriveInterfaces(), displayValues: UTMConfiguration.supportedDriveInterfacesPretty())
            }
        }
    }
}
