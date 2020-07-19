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

// TODO: sync with external changes to config
class VMDriveImage: ObservableObject {
    @Published var size: Int
    
    @Published var removable: Bool {
        didSet {
            if let config = self.config {
                config.setDriveRemovable(removable, for: index!)
            }
        }
    }
    
    @Published var name: String? {
        didSet {
            if let config = self.config, let name = self.name {
                config.setImagePath(name, for: index!)
            }
        }
    }
    
    @Published var imageTypeString: String? {
        didSet {
            if let config = self.config, let _ = self.imageTypeString {
                config.setDrive(imageType, for: index!)
            }
        }
    }
    
    @Published var interface: String? {
        didSet {
            if let config = self.config, let interface = self.interface {
                config.setDriveInterfaceType(interface, for: index!)
            }
        }
    }
    
    var imageType: UTMDiskImageType {
        get {
            UTMDiskImageType.enumFromString(imageTypeString)
        }
        
        set {
            imageTypeString = newValue.description
        }
    }
    
    private var config: UTMConfiguration?
    private var index: Int?
    
    init() {
        self.config = nil
        self.index = nil
        self.size = 10240
        self.removable = false
        self.name = UUID().uuidString
        self.imageType = .disk
        self.interface = UTMConfiguration.defaultDriveInterface()
    }
    
    convenience init(config: UTMConfiguration, index: Int) {
        self.init()
        self.config = config
        self.index = index
        self.size = 0
        self.removable = config.driveRemovable(for: index)
        self.imageType = config.driveImageType(for: index)
        self.name = config.driveImagePath(for: index)
        self.interface = config.driveInterfaceType(for: index)
    }
    
    func create(config: UTMConfiguration) {
        let interface = self.interface ?? UTMConfiguration.defaultDriveInterface()
        if removable {
            config.newRemovableDrive(imageType, interface: interface)
        } else {
            config.newDrive(name ?? "", type: imageType, interface: interface)
        }
    }
}
