//
// 
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

extension UTMConfigurable {
    var existingCustomIconURL: URL? {
        if let current = self.selectedCustomIconPath {
            return current // if we just selected a path
        }
        guard let parent = self.existingPath else {
            return nil
        }
        guard let icon = self.icon else {
            return nil
        }
        return parent.appendingPathComponent(icon) // from saved config
    }
    
    var existingIconURL: URL? {
        guard let icon = self.icon else {
            return nil
        }
        if let path = Bundle.main.path(forResource: icon, ofType: "png", inDirectory: "Icons") {
            return URL(fileURLWithPath: path)
        } else {
            return nil
        }
    }
}

@objc extension UTMQemuConfiguration: ObservableObject {
    func propertyWillChange() -> Void {
        if #available(iOS 13, macOS 11, *) {
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
}

@objc extension UTMQemuConfigurationPortForward: ObservableObject {
    func propertyWillChange() -> Void {
        if #available(iOS 13, macOS 11, *) {
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
}

@objc extension UTMViewState: ObservableObject {
    func propertyWillChange() -> Void {
        if #available(iOS 13, macOS 11, *) {
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
}

extension UTMDiskImageType: CustomStringConvertible {
    public var description: String {
        let index = rawValue
        let imageTypeList = UTMQemuConfiguration.supportedImageTypes()
        if index >= 0 && index < imageTypeList.count {
            return imageTypeList[index]
        } else {
            return ""
        }
    }
    
    static public func enumFromString(_ str: String?) -> UTMDiskImageType {
        let imageTypeList = UTMQemuConfiguration.supportedImageTypes()
        guard let unwrapStr = str else {
            return UTMDiskImageType.disk
        }
        guard let index = imageTypeList.firstIndex(of: unwrapStr) else {
            return UTMDiskImageType.disk
        }
        return UTMDiskImageType(rawValue: index) ?? UTMDiskImageType.disk
    }
}
