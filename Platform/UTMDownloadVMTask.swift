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
            /// get and extract all files contained in the UTM directory, except the `__MACOSX` folder
            let containedFiles = archive.filter({ $0.path.contains(utmDirectoryEnding) && !$0.path.hasSuffix(utmDirectoryEnding) && !$0.path.contains("__MACOSX") })
            for file in containedFiles {
                let relativePath = file.path.replacingOccurrences(of: utmFolderInZip.path, with: "")
                let isDirectory = file.path.hasSuffix("/")
                _ = try archive.extract(file, to: destinationURL.appendingPathComponent(relativePath, isDirectory: isDirectory), skipCRC32: true)
            }
            return destinationURL
        } else {
            throw UnzipNoUTMFileError()
        }
    }
    
    private class UnzipNoUTMFileError: Error {
        var errorDescription: String? {
            NSLocalizedString("There is no UTM file in the downloaded ZIP archive.", comment: "Error shown when importing a ZIP file from web that doesn't contain a UTM Virtual Machine.")
        }
    }
    
    private class CreateUTMFailed: Error {
        var errorDescription: String? {
            NSLocalizedString("Failed to parse the downloaded VM.", comment: "UTMDownloadVMTask")
        }
    }
}
