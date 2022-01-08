//
// Copyright © 2021 osy. All rights reserved.
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

/// Downloads a ZIPped UTM file from the web, unzips it and imports it as a UTM virtual machine.
@available(iOS 14, macOS 11, *)
class UTMImportFromWebTask: NSObject, UTMDownloadable, URLSessionDelegate, URLSessionDownloadDelegate {
    let data: UTMData
    let url: URL
    private var downloadTask: URLSessionTask!
    private var pendingVM: UTMPendingVirtualMachine!
    private(set) var isDone: Bool = false
    
    init(data: UTMData, url: URL) {
        self.data = data
        self.url = url
    }
    
    internal func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.downloadTask = nil
        DispatchQueue.main.async { [self] in
            pendingVM.setDownloadProgress(1)
        }
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let originalFilename = downloadTask.originalRequest!.url!.lastPathComponent
        let downloadedZip = tempDir.appendingPathComponent(originalFilename)
        var fileURL: URL? = nil
        do {
            if fileManager.fileExists(atPath: downloadedZip.path) {
                try fileManager.removeItem(at: downloadedZip)
            }
            try fileManager.moveItem(at: location, to: downloadedZip)
            let utmURL = try partialUnzipOnlyUtmVM(zipFileURL: downloadedZip, destinationFolder: data.documentsURL, fileManager: fileManager)
            /// set the url so we know, if it fails after this step the UTM in the ZIP is corrupted
            fileURL = utmURL
            /// remove the downloaded ZIP file
            try fileManager.removeItem(at: downloadedZip)
            /// load the downloaded VM into the UI
            try self.data.readUTMFromURL(fileURL: utmURL)
        } catch {
            logger.error(Logger.Message(stringLiteral: error.localizedDescription))
            DispatchQueue.main.async {
                self.data.alertMessage = AlertMessage(error.localizedDescription)
            }
            if let fileURL = fileURL {
                /// remove imported UTM, as it is corrupted
                try? fileManager.removeItem(at: fileURL)
            } else {
                /// failed earlier
                try? fileManager.removeItem(at: downloadedZip)
            }
        }
        /// remove downloading VM View Model
        DispatchQueue.main.async { [self] in
            data.removePendingVM(pendingVM)
            pendingVM = nil
            isDone = true
#if os(macOS)
            NSApplication.shared.requestUserAttention(.informationalRequest)
#endif
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
            var duplicateIndex = 1
            var exists = false
            repeat {
                exists = data.virtualMachines.contains(where: {
                    return $0.path != nil && $0.path!.lastPathComponent == destinationUtmDirectory
                })
                if exists {
                    destinationUtmDirectory = originalFileName.replacingOccurrences(of: utmFileEnding, with: " (\(duplicateIndex))\(utmFileEnding)")
                    duplicateIndex += 1
                }
            } while exists
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
        var localizedDescription: String {
            NSLocalizedString("There is no UTM file in the downloaded ZIP archive.", comment: "Error shown when importing a ZIP file from web that doesn't contain a UTM Virtual Machine.")
        }
    }
    
    /// received when the download progresses
    internal func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async { [self] in
            guard pendingVM != nil else { return }
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            pendingVM.setDownloadProgress(progress)
        }
    }
    
    /// when the session ends with an error, it could be cancelled or an actual error
    internal func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { [self] in
            /// make sure the session didn't already finish
            guard pendingVM != nil else { return }
            if let error = error {
                let error = error as NSError
                if error.code == NSURLErrorCancelled {
                    /// download was cancelled normally
                } else {
                    /// other error
                    logger.error("\(error.localizedDescription)")
                    data.alertMessage = AlertMessage(error.localizedDescription)
                }
                isDone = true
                data.removePendingVM(pendingVM)
                pendingVM = nil
            }
        }
    }
    
    internal func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DispatchQueue.main.async { [self] in
            /// make sure the session didn't already finish
            guard pendingVM != nil else { return }
            if let error = error {
                logger.error("\(error.localizedDescription)")
                isDone = true
                data.removePendingVM(pendingVM)
                data.alertMessage = AlertMessage(error.localizedDescription)
                pendingVM = nil
            }
        }
    }
    
    /// Downloads a ZIP-compressed file from the provided URL and imports the UTM file inside, if there is one.
    func startDownload() -> UTMPendingVirtualMachine {
        /// begin the download
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask.resume()
        /// try to detect the filename from the URL
        let filename = url.lastPathComponent
        var nameWithoutZIP = "UTM Virtual Machine"
        /// Try to get the start index of the `.zip` part of the filename
        if let index = filename.range(of: ".zip", options: [])?.lowerBound {
            nameWithoutZIP = String(filename[..<index])
        }
        pendingVM = UTMPendingVirtualMachine(name: nameWithoutZIP, task: self)
        return pendingVM
    }
    
    /// Cancels the network request, if any.
    /// Cancelling the file operations that occur after the download has finished is not supported.
    func cancel() {
        guard !isDone && downloadTask != nil && !downloadTask.progress.isFinished else { return }
        downloadTask.cancel()
        downloadTask = nil
    }
}
