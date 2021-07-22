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

/// Unfinished: tries to download a file from the web and import it as a UTM virtual machine.
@available(iOS 14, macOS 11, *)
class UTMImportFromWebTask: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    private var data: UTMData!
    
    /// Call on background queue
    internal func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let originalFilename = downloadTask.originalRequest!.url!.lastPathComponent
        let downloadedZip = tempDir.appendingPathComponent(originalFilename)
        do {
            if fileManager.fileExists(atPath: downloadedZip.absoluteString) {
                try fileManager.removeItem(at: downloadedZip)
            }
            try fileManager.moveItem(at: location, to: downloadedZip)
            let unzippedURL = try Zip.quickUnzipFile(downloadedZip)
            /// remove the downloaded ZIP file
            try fileManager.removeItem(at: downloadedZip)
            handleUnzipped(unzippedURL)
            /// remove unzipped file
            try FileManager.default.removeItem(at: unzippedURL)
        } catch {
            logger.error(Logger.Message(stringLiteral: error.localizedDescription))
            try? fileManager.removeItem(at: downloadedZip)
        }
    }
    
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
    
    static func start(with data: UTMData, downloadFrom url: URL) {
        DispatchQueue.global(qos: .background).async {
            let importTask = UTMImportFromWebTask()
            importTask.data = data
            let session = URLSession(configuration: .ephemeral, delegate: importTask, delegateQueue: OperationQueue.current)
            let downloadTask = session.downloadTask(with: url)
            downloadTask.resume()
        }
    }
}
