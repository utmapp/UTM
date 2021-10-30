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
import Zip

/// Downloads a ZIPped UTM file from the web, unzips it and imports it as a UTM virtual machine.
@available(iOS 14, macOS 11, *)
class UTMImportFromWebTask: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
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
        do {
            if fileManager.fileExists(atPath: downloadedZip.absoluteString) {
                try fileManager.removeItem(at: downloadedZip)
            }
            try fileManager.moveItem(at: location, to: downloadedZip)
            let unzippedPath = tempDir.appendingPathComponent(originalFilename.replacingOccurrences(of: ".zip", with: ""))
            try Zip.unzipFile(downloadedZip, destination: unzippedPath, overwrite: true, password: nil)
            /// remove the downloaded ZIP file
            try fileManager.removeItem(at: downloadedZip)
            handleUnzipped(unzippedPath)
            /// remove unzipped file
            try FileManager.default.removeItem(at: unzippedPath)
        } catch {
            logger.error(Logger.Message(stringLiteral: error.localizedDescription))
            try? fileManager.removeItem(at: downloadedZip)
        }
        /// remove downloading VM View Model
        DispatchQueue.main.async { [self] in
            data.removePendingVM(pendingVM)
            pendingVM = nil
            isDone = true
        }
    }
    
    /// received when the download progresses
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
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
    
    /// Call on background queue
    private func handleUnzipped(_ unzippedFolder: URL) {
        do {
            let path = unzippedFolder.path
            /// try to find .utm file in unzipped folder
            if let utmFilename = try FileManager.default.contentsOfDirectory(atPath: path).first(where: { $0.hasSuffix(".utm") }) {
                /// got filename
                let utmURL = URL(fileURLWithPath: path).appendingPathComponent(utmFilename, isDirectory: false)
                try self.data.importUTM(url: utmURL)
            } else {
                /// utm file not in folder
                logger.error("No UTM file in extracted ZIP")
            }
        } catch {
            logger.error(Logger.Message(stringLiteral: error.localizedDescription))
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
        pendingVM = UTMPendingVirtualMachine(name: nameWithoutZIP, importTask: self)
        return pendingVM
    }
    
    /// Cancels the network request, if any.
    /// Cancelling the file operations that occur after the download has finished is not supported.
    func cancel() {
        guard !isDone && !downloadTask.progress.isFinished else { return }
        downloadTask.cancel()
        downloadTask = nil
    }
}
