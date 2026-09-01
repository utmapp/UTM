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
import Logging
import ZIPFoundation

/// Downloads a VM and creates a pending VM placeholder.
class UTMDownloadVMTask: UTMDownloadTask {
    init(for url: URL) {
        super.init(for: url, named: UTMDownloadVMTask.name(for: url))
    }
    
    static private func name(for url: URL) -> String {
        /// try to detect the filename from the URL
        let filename = url.lastPathComponent
        var nameWithoutZIP = "UTM Virtual Machine"
        /// Try to get the start index of the `.zip` part of the filename
        if let index = filename.range(of: ".zip", options: [])?.lowerBound {
            nameWithoutZIP = String(filename[..<index])
        }
        return nameWithoutZIP
    }
    
    override func processCompletedDownload(at location: URL, response: URLResponse?) async throws -> any UTMVirtualMachine {
        let tempDir = fileManager.temporaryDirectory
        let originalFilename = url.lastPathComponent
        let downloadedZip = tempDir.appendingPathComponent(originalFilename)
        var fileURL: URL? = nil
        do {
            if fileManager.fileExists(atPath: downloadedZip.path) {
                try fileManager.removeItem(at: downloadedZip)
            }
            try fileManager.moveItem(at: location, to: downloadedZip)
            let utmURL = try partialUnzipOnlyUtmVM(zipFileURL: downloadedZip, destinationFolder: UTMData.defaultStorageUrl, fileManager: fileManager)
            /// set the url so we know, if it fails after this step the UTM in the ZIP is corrupted
            fileURL = utmURL
            /// remove the downloaded ZIP file
            try fileManager.removeItem(at: downloadedZip)
            /// load the downloaded VM into the UI
            let vm = try await VMData(url: utmURL)
            return await vm.wrapped!
        } catch {
            logger.error(Logger.Message(stringLiteral: error.localizedDescription))
            if let fileURL = fileURL {
                /// remove imported UTM, as it is corrupted
                try? fileManager.removeItem(at: fileURL)
            } else {
                /// failed earlier
                try? fileManager.removeItem(at: downloadedZip)
            }
            throw error
        }
    }
    
    private func partialUnzipOnlyUtmVM(zipFileURL: URL, destinationFolder: URL, fileManager: FileManager) throws -> URL {
        let utmFileEnding = ".utm"
        let utmDirectoryEnding = "\(utmFileEnding)/"
        if let archive = Archive(url: zipFileURL, accessMode: .read),
           /// find the UTM directory and its contents
           let utmFolderInZip = archive.first(where: { $0.path.hasSuffix(utmDirectoryEnding) }) {
            /// get the UTM package filename
            let originalFileName = URL(fileURLWithPath: utmFolderInZip.path).lastPathComponent
            var destinationUtmDirectory = originalFileName
            /// check if the UTM already exists
            var duplicateIndex = 2
            while fileManager.fileExists(atPath: destinationFolder.appendingPathComponent(destinationUtmDirectory).path) {
                destinationUtmDirectory = originalFileName.replacingOccurrences(of: utmFileEnding, with: " (\(duplicateIndex))\(utmFileEnding)")
                duplicateIndex += 1
            }
            /// got destination folder name
            let destinationURL = destinationFolder.appendingPathComponent(destinationUtmDirectory, isDirectory: true)
            /// create the .utm directory
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: false)
            do {
                /// get and extract all files contained in the UTM directory, except the `__MACOSX` folder
                let containedFiles = archive.filter({ $0.path.hasPrefix(utmFolderInZip.path) && !$0.path.hasSuffix(utmDirectoryEnding) && !$0.path.contains("__MACOSX") })
                for file in containedFiles {
                    /// we never store a symlink in a package, and a link target that survives a containment
                    /// check can still be resolved outside of the package when it is written through later
                    guard file.type != .symlink else {
                        throw UnzipUnsafePathError()
                    }
                    let relativePath = String(file.path.dropFirst(utmFolderInZip.path.count))
                    let isDirectory = file.path.hasSuffix("/")
                    let fileURL = try containedDestination(for: relativePath, in: destinationURL, isDirectory: isDirectory)
                    _ = try archive.extract(file, to: fileURL, skipCRC32: true)
                }
            } catch {
                /// a partially extracted package would still be picked up as a VM by the library
                try? fileManager.removeItem(at: destinationURL)
                throw error
            }
            return destinationURL
        } else {
            throw UnzipNoUTMFileError()
        }
    }
    
    /// Resolve an archive entry's relative path inside `destinationFolder` and reject any escape.
    ///
    /// A crafted archive can name an entry `some.utm/../../elsewhere`. `appendingPathComponent()` does not
    /// resolve `..`, so the traversal would only be resolved by the filesystem at write time.
    private func containedDestination(for relativePath: String, in destinationFolder: URL, isDirectory: Bool) throws -> URL {
        let candidate = destinationFolder.appendingPathComponent(relativePath, isDirectory: isDirectory)
        /// POSIX `fopen()` collapses repeated separators before resolving `..`, so an entry named `/../elsewhere`
        /// would otherwise standardize to a contained path here but escape once written. Collapse them first.
        var path = candidate.path
        while path.contains("//") {
            path = path.replacingOccurrences(of: "//", with: "/")
        }
        let resolved = URL(fileURLWithPath: path, isDirectory: isDirectory).standardized
        let root = URL(fileURLWithPath: destinationFolder.path, isDirectory: true).standardized
        guard resolved.path.hasPrefix(root.path + "/") else {
            throw UnzipUnsafePathError()
        }
        return resolved
    }
    
    private class UnzipUnsafePathError: LocalizedError {
        var errorDescription: String? {
            NSLocalizedString("The downloaded ZIP archive contains an invalid path.", comment: "Error shown when importing a ZIP file from web that contains an entry pointing outside of the virtual machine directory.")
        }
    }
    
    private class UnzipNoUTMFileError: LocalizedError {
        var errorDescription: String? {
            NSLocalizedString("There is no UTM file in the downloaded ZIP archive.", comment: "Error shown when importing a ZIP file from web that doesn't contain a UTM Virtual Machine.")
        }
    }
    
    private class CreateUTMFailed: LocalizedError {
        var errorDescription: String? {
            NSLocalizedString("Failed to parse the downloaded VM.", comment: "UTMDownloadVMTask")
        }
    }
}
