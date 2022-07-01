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
    var imageName: String? { get set }
    
    /// Size of the image when creating a new image (in MiB).
    var sizeMib: Int { get }
    
    /// If true, the drive image will be mounted as read-only.
    var isReadOnly: Bool { get }
    
    /// If true, a bookmark is stored in the package.
    var isExternal: Bool { get }
    
    /// If true, the created image will be raw format and not QCOW2. Not saved.
    var isRawImage: Bool { get }
    
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

// MARK: - Saving data

@available(iOS 13, macOS 11, *)
extension UTMConfigurationDrive {
    private var bytesInMib: UInt64 { 1048576 }
    
    @MainActor mutating func saveData(to dataURL: URL) async throws -> [URL] {
        guard !isExternal else {
            return [] // nothing to save
        }
        let fileManager = FileManager.default
        if let imageURL = imageURL {
            let newURL = try await UTMQemuConfiguration.copyItemIfChanged(from: imageURL, to: dataURL)
            self.imageName = newURL.lastPathComponent
            self.imageURL = newURL
            return [newURL]
        } else if imageName == nil {
            let newName = "\(id).\(isRawImage ? "img" : "qcow2")"
            let newURL = dataURL.appendingPathComponent(newName)
            guard !fileManager.fileExists(atPath: newURL.path) else {
                throw UTMConfigurationError.driveAlreadyExists
            }
            if isRawImage {
                try await createRawImage(at: newURL, size: sizeMib)
            } else {
                try await createQcow2Image(at: newURL, size: sizeMib)
            }
            self.imageName = newName
            self.imageURL = newURL
            return [newURL]
        } else {
            let existingURL = dataURL.appendingPathComponent(imageName!)
            return [existingURL]
        }
    }
    
    private func createRawImage(at newURL: URL, size sizeMib: Int) async throws {
        let fileManager = FileManager.default
        let size = UInt64(sizeMib) * bytesInMib
        try await Task.detached {
            guard fileManager.createFile(atPath: newURL.path, contents: nil, attributes: nil) else {
                throw UTMConfigurationError.cannotCreateDiskImage
            }
            let handle = try FileHandle(forWritingTo: newURL)
            try handle.truncate(atOffset: size)
            try handle.close()
        }.value
    }
    
    private func createQcow2Image(at newURL: URL, size sizeMib: Int) async throws {
        try await Task.detached {
            if !GenerateDefaultQcow2File(newURL as CFURL, sizeMib) {
                throw UTMConfigurationError.cannotCreateDiskImage
            }
        }.value
    }
}
