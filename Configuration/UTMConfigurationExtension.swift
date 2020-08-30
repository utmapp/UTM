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

@objc extension UTMConfiguration: ObservableObject {
    private static let gibInMib = 1024
    
    var systemTargetPretty: String {
        guard let arch = self.systemArchitecture else {
            return ""
        }
        guard let target = self.systemTarget else {
            return ""
        }
        guard let targets = UTMConfiguration.supportedTargets(forArchitecture: arch) else {
            return ""
        }
        guard let prettyTargets = UTMConfiguration.supportedTargets(forArchitecturePretty: arch) else {
            return ""
        }
        guard let index = targets.firstIndex(of: target) else {
            return ""
        }
        return prettyTargets[index]
    }
    
    var systemArchitecturePretty: String {
        let archs = UTMConfiguration.supportedArchitectures()
        let prettyArchs = UTMConfiguration.supportedArchitecturesPretty()
        guard let arch = self.systemArchitecture else {
            return ""
        }
        guard let index = archs.firstIndex(of: arch) else {
            return ""
        }
        return prettyArchs[index]
    }
    
    var systemMemoryPretty: String {
        guard let memory = self.systemMemory else {
            return NSLocalizedString("Unknown", comment: "UTMConfigurationExtension")
        }
        if memory.intValue > UTMConfiguration.gibInMib {
            return String(format: "%.1f GB", memory.floatValue / Float(UTMConfiguration.gibInMib))
        } else {
            return String(format: "%d MB", memory.intValue)
        }
    }
    
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
    
    func propertyWillChange() -> Void {
        if #available(iOS 13, macOS 11, *) {
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
}

@objc extension UTMConfigurationPortForward: ObservableObject {
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
        let imageTypeList = UTMConfiguration.supportedImageTypes()
        if index >= 0 && index < imageTypeList.count {
            return imageTypeList[index]
        } else {
            return ""
        }
    }
    
    static public func enumFromString(_ str: String?) -> UTMDiskImageType {
        let imageTypeList = UTMConfiguration.supportedImageTypes()
        guard let unwrapStr = str else {
            return UTMDiskImageType.disk
        }
        guard let index = imageTypeList.firstIndex(of: unwrapStr) else {
            return UTMDiskImageType.disk
        }
        return UTMDiskImageType(rawValue: index) ?? UTMDiskImageType.disk
    }
}
