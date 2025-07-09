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

extension UTMConfigurationDrive {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}

// MARK: - Saving data

extension UTMConfigurationDrive {
    private var bytesInMib: UInt64 { 1048576 }
    
    @MainActor mutating func saveData(to dataURL: URL) async throws -> [URL] {
        guard !isExternal else {
            return [] // nothing to save
        }
        let fileManager = FileManager.default
        if let imageURL = imageURL {
            #if os(macOS)
            let newURL = try await UTMQemuConfiguration.copyItemIfChanged(from: imageURL, to: dataURL, customCopy: isRawImage ? nil : convertQcow2Image)
            #else
            let newURL = try await UTMQemuConfiguration.copyItemIfChanged(from: imageURL, to: dataURL)
            #endif
            self.imageName = newURL.lastPathComponent
            self.imageURL = newURL
            return [newURL]
        } else if imageName == nil {
            let newName = "\(id).\(isRawImage ? "img" : "qcow2")"
            let newURL = dataURL.appendingPathComponent(newName)
            guard !fileManager.fileExists(atPath: newURL.path) else {
                throw UTMConfigurationError.driveAlreadyExists(newURL)
            }
            if isRawImage {
                #if os(macOS)
                if let appleDrive = self as? UTMAppleConfigurationDrive, appleDrive.isASIF {
                    try await createAsifImage(at: newURL, size: sizeMib)
                } else {
                    try await createRawImage(at: newURL, size: sizeMib)
                }
                #else
                try await createRawImage(at: newURL, size: sizeMib)
                #endif
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
        let size = UInt64(sizeMib) * bytesInMib
        try await Task.detached {
            guard FileManager.default.createFile(atPath: newURL.path, contents: nil, attributes: nil) else {
                throw UTMConfigurationError.cannotCreateDiskImage
            }
            let handle = try FileHandle(forWritingTo: newURL)
            try handle.truncate(atOffset: size)
            try handle.close()
        }.value
    }

    private func createQcow2Image(at newURL: URL, size sizeMib: Int) async throws {
        #if WITH_REMOTE
        fatalError("Not implemented")
        #else
        try await Task.detached {
            if !QEMUGenerateDefaultQcow2File(newURL as CFURL, sizeMib) {
                throw UTMConfigurationError.cannotCreateDiskImage
            }
        }.value
        #endif
    }
    
    private func createAsifImage(at newURL: URL, size sizeMib: Int) async throws {
        let numBlocks = sizeMib * Int(bytesInMib) / 512
        guard let asif = UTMASIFImage.sharedInstance() else {
            throw UTMConfigurationError.cannotCreateDiskImage
        }
        try await Task.detached {
            try asif.createBlank(with: newURL, numBlocks: numBlocks)
        }.value
    }
    
    #if os(macOS)
    private func convertQcow2Image(at sourceURL: URL, to destFolderURL: URL) async throws -> URL {
        let destQcow2 = UTMData.newImage(from: sourceURL,
                                         to: destFolderURL,
                                         withExtension: "qcow2")
        try await UTMQemuImage.convert(from: sourceURL, toQcow2: destQcow2)
        return destQcow2
    }
    #endif
}
