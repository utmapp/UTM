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

@available(iOS 14, macOS 11, *)
class VMDriveImage: ObservableObject {
    @Published var size: Int = 10240
    @Published var removable: Bool = false
    @Published var imageTypeString: String? = UTMDiskImageType.disk.description
    @Published var interface: String? = "none"
    
    var imageType: UTMDiskImageType {
        get {
            UTMDiskImageType.enumFromString(imageTypeString)
        }
        
        set {
            imageTypeString = newValue.description
        }
    }
    
    func reset(forSystemTarget target: String?, removable: Bool) {
        self.removable = removable
        self.imageType = removable ? .CD : .disk
        self.interface = UTMConfiguration.defaultDriveInterface(forTarget: target, type: imageType)
        self.size = removable ? 0 : 10240
    }
}
