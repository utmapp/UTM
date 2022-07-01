//
// Copyright © 2022 osy. All rights reserved.
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

import Foundation

/// Settings for single disk device
@available(iOS 13, macOS 11, *)
protocol UTMConfigurationDrive: Codable, Hashable, Identifiable {
    /// If not removable, this is the name of the file in the bundle.
    var imageName: String? { get }
    
    /// Size of the image when creating a new image (in MiB). Not saved.
    var sizeMib: Int { get }
    
    /// If true, the drive image will be mounted as read-only.
    var isReadOnly: Bool { get }
    
    /// If true, the drive image will not be copied to the bundle.
    var isRemovable: Bool { get }
    
    /// If valid, will point to the actual location of the drive image. Not saved.
    var imageURL: URL? { get set }
    
    /// Unique identifier for this drive
    var id: String { get }
    
    /// Create a new copy with a unique ID
    /// - Returns: Copy
    func clone() -> Self
}

@available(iOS 13, macOS 11, *)
extension UTMConfigurationDrive {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}
