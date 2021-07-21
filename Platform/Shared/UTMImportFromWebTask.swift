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

/// Unfinished: tries to download a file from the web and import it as a UTM virtual machine.
@available(iOS 14, macOS 11, *)
class UTMImportFromWebTask: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    private var data: UTMData!
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        /// TODO unzip downloaded file
        //try? data.importUTM(url: location)
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
