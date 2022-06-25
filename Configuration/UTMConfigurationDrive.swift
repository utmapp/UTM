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
class UTMConfigurationDrive: Codable, Hashable, Identifiable, ObservableObject {
    static func == (lhs: UTMConfigurationDrive, rhs: UTMConfigurationDrive) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    /// If not removable, this is the name of the file in the bundle.
    @Published var imageName: String?
    
    /// Size of the image when creating a new image (in MiB). Not saved.
    @Published var sizeMib: Int = 0
    
    /// If true, the drive image will be mounted as read-only.
    @Published var isReadOnly: Bool = false
    
    /// If true, the drive image will not be copied to the bundle.
    @Published var isRemovable: Bool = false
    
    /// If valid, will point to the actual location of the drive image. Not saved.
    @Published var imageURL: URL?
    
    /// Unique identifier for this drive
    var id: String = ""
    
    enum CodingKeys: String, CodingKey {
        case imageName = "ImageName"
        case isRemovable = "Removable"
    }
    
    required init() {
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        imageName = try values.decodeIfPresent(String.self, forKey: .imageName)
        isRemovable = try values.decode(Bool.self, forKey: .isRemovable)
        if !isRemovable, let imageName = imageName, let dataURL = decoder.userInfo[.dataURL] as? URL {
            imageURL = dataURL.appendingPathComponent(imageName)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !isRemovable {
            try container.encodeIfPresent(imageName, forKey: .imageName)
        }
        try container.encode(isRemovable, forKey: .isRemovable)
    }
    
    func hash(into hasher: inout Hasher) {
        imageName?.hash(into: &hasher)
        isRemovable.hash(into: &hasher)
        id.hash(into: &hasher)
    }
    
    func copy() -> Self {
        let copy = Self()
        copy.imageName = imageName
        copy.sizeMib = sizeMib
        copy.isReadOnly = isReadOnly
        copy.isRemovable = isRemovable
        copy.imageURL = imageURL
        copy.id = id
        return copy
    }
}
