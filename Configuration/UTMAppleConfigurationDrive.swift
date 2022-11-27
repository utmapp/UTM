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
import Virtualization

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
struct UTMAppleConfigurationDrive: UTMConfigurationDrive {
    private let bytesInMib = 1048576
    
    var sizeMib: Int = 0
    var isReadOnly: Bool
    var isExternal: Bool
    var imageURL: URL?
    var imageName: String?
    
    private(set) var id = UUID().uuidString
    
    var isRawImage: Bool {
        true // always true for Apple VMs
    }
    
    private enum CodingKeys: String, CodingKey {
        case isReadOnly = "ReadOnly"
        case imageName = "ImageName"
        case bookmark = "Bookmark" // legacy only
        case identifier = "Identifier"
    }
    
    var sizeString: String {
        let sizeBytes: Int64
        if let attributes = try? imageURL?.resourceValues(forKeys: [.fileSizeKey]), let fileSize = attributes.fileSize {
            sizeBytes = Int64(fileSize)
        } else {
            sizeBytes = Int64(sizeMib) * Int64(bytesInMib)
        }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .binary)
    }
    
    init(newSize: Int) {
        sizeMib = newSize
        isReadOnly = false
        isExternal = false
    }
    
    init(existingURL url: URL, isReadOnly: Bool = false, isExternal: Bool = false) {
        self.imageURL = url
        self.isReadOnly = isReadOnly
        self.isExternal = isExternal
    }
    
    init(from decoder: Decoder) throws {
        guard let dataURL = decoder.userInfo[.dataURL] as? URL else {
            throw UTMConfigurationError.invalidDataURL
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isReadOnly = try container.decode(Bool.self, forKey: .isReadOnly)
        if let imageName = try container.decodeIfPresent(String.self, forKey: .imageName) {
            self.imageName = imageName
            imageURL = dataURL.appendingPathComponent(imageName)
            isExternal = false
        } else if let bookmark = try container.decodeIfPresent(Data.self, forKey: .bookmark) {
            var stale: Bool = false
            imageURL = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
            imageName = imageURL?.lastPathComponent
            isExternal = true
        } else {
            imageURL = nil
            imageName = nil
            isExternal = true
        }
        id = try container.decode(String.self, forKey: .identifier)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isReadOnly, forKey: .isReadOnly)
        if !isExternal {
            try container.encodeIfPresent(imageName, forKey: .imageName)
        }
        try container.encode(id, forKey: .identifier)
    }
    
    func vzDiskImage() throws -> VZDiskImageStorageDeviceAttachment? {
        if let imageURL = imageURL {
            return try VZDiskImageStorageDeviceAttachment(url: imageURL, readOnly: isReadOnly)
        } else {
            return nil
        }
    }
    
    func hash(into hasher: inout Hasher) {
        imageName?.hash(into: &hasher)
        sizeMib.hash(into: &hasher)
        isReadOnly.hash(into: &hasher)
        isExternal.hash(into: &hasher)
        id.hash(into: &hasher)
    }
    
    func clone() -> UTMAppleConfigurationDrive {
        var cloned = self
        cloned.id = UUID().uuidString
        return cloned
    }
}

// MARK: - Conversion of old config format

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfigurationDrive {
    init(migrating oldDrive: DiskImage) {
        sizeMib = oldDrive.sizeMib
        isReadOnly = oldDrive.isReadOnly
        isExternal = oldDrive.isExternal
        imageURL = oldDrive.imageURL
    }
}
