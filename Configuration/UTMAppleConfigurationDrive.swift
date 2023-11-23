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
    var isSparse: Bool
    var isExternal: Bool
    var imageURL: URL?
    var imageName: String?
    
    private(set) var id = UUID().uuidString
    
    var isRawImage: Bool {
        true // always true for Apple VMs
    }
    
    private enum CodingKeys: String, CodingKey {
        case isReadOnly = "ReadOnly"
        case isSparse = "Sparse"
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
        isSparse = true
        isExternal = false
    }
    
    init(newSize: Int, isSparse: Bool = true) {
        sizeMib = newSize
        isReadOnly = false
        isExternal = false
        self.isSparse = isSparse
    }
    
    init(existingURL url: URL?, isExternal: Bool = false) {
        self.imageURL = url
        self.isReadOnly = isExternal
        self.isExternal = isExternal
        self.isSparse = true
    }
    
    init(from decoder: Decoder) throws {
        guard let dataURL = decoder.userInfo[.dataURL] as? URL else {
            throw UTMConfigurationError.invalidDataURL
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
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
        isReadOnly = try container.decodeIfPresent(Bool.self, forKey: .isReadOnly) ?? isExternal
        isSparse = try container.decodeIfPresent(Bool.self, forKey: .isSparse) ?? true
        id = try container.decode(String.self, forKey: .identifier)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !isExternal {
            try container.encodeIfPresent(imageName, forKey: .imageName)
        }
        try container.encode(isReadOnly, forKey: .isReadOnly)
        try container.encode(isSparse, forKey: .isSparse)
        try container.encode(id, forKey: .identifier)
    }
    
    func vzDiskImage() throws -> VZDiskImageStorageDeviceAttachment? {
        if let imageURL = imageURL {
            if #available(macOS 12, *) {
                /*
                 * virtual disk cache mode have bugs,
                 * when it is enabled or set to auto (default value)
                 * may cause linux file system corrputed, especially in the case of heavy IO loads
                 */
                return try VZDiskImageStorageDeviceAttachment(url: imageURL, readOnly: isReadOnly, cachingMode:VZDiskImageCachingMode.uncached, synchronizationMode: VZDiskImageSynchronizationMode.full)
            } else {
                return try VZDiskImageStorageDeviceAttachment(url: imageURL, readOnly: isReadOnly)
            }
        } else {
            return nil
        }
    }
    
    func hash(into hasher: inout Hasher) {
        imageName?.hash(into: &hasher)
        sizeMib.hash(into: &hasher)
        isReadOnly.hash(into: &hasher)
        isSparse.hash(into: &hasher)
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
        isSparse = oldDrive.isSparse
        isExternal = oldDrive.isExternal
        imageURL = oldDrive.imageURL
    }
}
