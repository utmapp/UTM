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

import Combine

@available(iOS 14, macOS 11, *)
class VMDriveImage: ObservableObject {
    @Published var size: Int = 10240
    @Published var removable: Bool = false
    @Published var imageTypeString: String? = UTMDiskImageType.disk.description
    @Published var interface: String? = "none"
    @Published var isRawImage: Bool = false
    private var cancellable = [AnyCancellable]()
    
    var imageType: UTMDiskImageType {
        get {
            UTMDiskImageType.enumFromString(imageTypeString)
        }
        
        set {
            imageTypeString = newValue.description
        }
    }
    
    init() {
        cancellable.append($interface.sink { newInterface in
            guard let newInterface = newInterface else {
                return
            }
            self.isRawImage = !UTMQemuConfiguration.shouldConvertQcow2(forInterface: newInterface)
        })
    }
    
    func reset(forSystemTarget target: String?, architecture: String?, removable: Bool) {
        self.removable = removable
        self.imageType = removable ? .CD : .disk
        self.interface = UTMQemuConfiguration.defaultDriveInterface(forTarget: target, architecture: architecture, type: imageType)
        self.size = removable ? 0 : 10240
        self.isRawImage = false
    }
}
