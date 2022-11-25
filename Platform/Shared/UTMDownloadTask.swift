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

/// Downloads a file and creates a pending VM placeholder.
class UTMDownloadTask: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    let url: URL
    let name: String
    private var downloadTask: Task<UTMVirtualMachine?, Error>!
    private var taskContinuation: CheckedContinuation<UTMVirtualMachine?, Error>?
    @MainActor private(set) lazy var pendingVM: UTMPendingVirtualMachine = createPendingVM()
    
    private let kMaxRetries = 5
    private var retries = 0
    
    var fileManager: FileManager {
        FileManager.default
    }
    
    init(for url: URL, named name: String) {
        self.url = url
        self.name = name
    }
    
    /// Called by subclass when download is completed
    /// - Parameter location: Downloaded file location
    /// - Returns: Processed UTM virtual machine
    func processCompletedDownload(at location: URL) async throws -> UTMVirtualMachine {
        throw "Not Implemented"
    }
    
    internal func urlSession(_ session: URLSession, downloadTask sessionTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard !downloadTask.isCancelled else {
            sessionTask.cancel()
            return
        }
        guard let taskContinuation = taskContinuation else {
            return
        }
        self.taskContinuation = nil
        // need to move the file because it will be deleted after delegate returns
        let tmpUrl = fileManager.temporaryDirectory.appendingPathComponent("\(location.lastPathComponent).2")
        do {
            if fileManager.fileExists(atPath: tmpUrl.path) {
                try fileManager.removeItem(at: tmpUrl)
            }
            try fileManager.moveItem(at: location, to: tmpUrl)
        } catch {
            taskContinuation.resume(throwing: error)
            return
        }
        Task {
            await pendingVM.setDownloadFinishedNowProcessing()
            do {
                let vm = try await processCompletedDownload(at: tmpUrl)
                taskContinuation.resume(returning: vm)
            } catch {
                taskContinuation.resume(throwing: error)
            }
            try? fileManager.removeItem(at: tmpUrl) // clean up
#if os(macOS)
            await NSApplication.shared.requestUserAttention(.informationalRequest)
#endif
        }
    }
    
    /// received when the download progresses
    internal func urlSession(_ session: URLSession, downloadTask sessionTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard !downloadTask.isCancelled else {
            sessionTask.cancel()
            return
        }
        retries = 0 // reset retry counter on success
        Task {
            await pendingVM.setDownloadProgress(new: bytesWritten,
                                                currentTotal: totalBytesWritten,
                                                estimatedTotal: totalBytesExpectedToWrite)
        }
    }
    
    /// when the session ends with an error, it could be cancelled or an actual error
    internal func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let error = error as? NSError
        if let resumeData = error?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            retries += 1
            guard retries > kMaxRetries else {
                logger.warning("Retrying download due to connection error...")
                let task = session.downloadTask(withResumeData: resumeData)
                task.resume()
                return
            }
        }
        guard let taskContinuation = taskContinuation else {
            return
        }
        self.taskContinuation = nil
        self.retries = 0 // reset retry counter
        if let error = error {
            if error.code == NSURLErrorCancelled {
                /// download was cancelled normally
                taskContinuation.resume(returning: nil)
            } else {
                /// other error
                logger.error("\(error.localizedDescription)")
                taskContinuation.resume(throwing: error)
            }
        } else {
            taskContinuation.resume(returning: nil)
        }
    }
    
    internal func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        guard let taskContinuation = taskContinuation else {
            return
        }
        self.taskContinuation = nil
        if let error = error {
            taskContinuation.resume(throwing: error)
        } else {
            taskContinuation.resume(returning: nil)
        }
    }
    
    /// Create a placeholder object to show
    /// - Returns: Pending VM
    @MainActor private func createPendingVM() -> UTMPendingVirtualMachine {
        return UTMPendingVirtualMachine(name: name) {
            self.cancel()
        }
    }
    
    
    /// Starts the download
    /// - Returns: Completed download or nil if canceled
    func download() async throws -> UTMVirtualMachine? {
        /// begin the download
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        downloadTask = Task.detached { [self] in
            let sessionDownload = session.downloadTask(with: url)
            await pendingVM.setDownloadStarting()
            return try await withCheckedThrowingContinuation({ continuation in
                self.taskContinuation = continuation
                sessionDownload.resume()
            })
        }
        return try await downloadTask.value
    }
    
    /// Try to cancel the download
    func cancel() {
        downloadTask?.cancel()
    }
}
