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
import Virtualization

/// Downloads an IPSW from the web and adds it to the VM.
@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 12, *)
class UTMDownloadIPSWTask: NSObject, UTMDownloadable, URLSessionDelegate, URLSessionDownloadDelegate {
    let data: UTMData
    let name: String
    let url: URL
    let onSuccess: (URL) -> Void
    private var downloadTask: URLSessionTask!
    private var pendingVM: UTMPendingVirtualMachine!
    private var restoreImage: Any?
    private(set) var isDone: Bool = false
    
    init(data: UTMData, name: String, url: URL, onSuccess: @escaping (URL) -> Void) {
        self.data = data
        self.name = name
        self.url = url
        self.onSuccess = onSuccess
    }
    
    internal func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.downloadTask = nil
        DispatchQueue.main.async { [self] in
            pendingVM.setDownloadProgress(1)
        }
        onSuccess(location)
        /// remove downloading VM View Model
        DispatchQueue.main.async { [self] in
            isDone = true
            data.removePendingVM(pendingVM)
            pendingVM = nil
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
        /// make sure the session didn't already finish
        guard pendingVM != nil else { return }
        if let error = error {
            let error = error as NSError
            if error.code == NSURLErrorCancelled {
                /// download was cancelled normally
            } else {
                /// other error
                fail(with: error.localizedDescription)
            }
            isDone = true
            data.removePendingVM(pendingVM)
            pendingVM = nil
        }
    }
    
    internal func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            fail(with: error.localizedDescription)
        }
    }
    
    /// Downloads a ZIP-compressed file from the provided URL and imports the UTM file inside, if there is one.
    func startDownload() -> UTMPendingVirtualMachine {
        pendingVM = UTMPendingVirtualMachine(name: name, task: self)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask.resume()
        return pendingVM
    }
    
    /// Cancels the network request, if any.
    /// Cancelling the file operations that occur after the download has finished is not supported.
    func cancel() {
        guard downloadTask != nil && !downloadTask.progress.isFinished else { return }
        downloadTask.cancel()
        downloadTask = nil
    }
    
    internal func fail(with errorMessage: String) {
        self.pendingVM = nil
        let pendingVM = pendingVM
        DispatchQueue.main.async {
            logger.error("\(errorMessage)")
            self.isDone = true
            if pendingVM != nil {
                self.data.removePendingVM(pendingVM!)
            }
            self.data.alertMessage = AlertMessage(errorMessage)
        }
    }
}
