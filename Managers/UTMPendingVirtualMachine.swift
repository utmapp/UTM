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

/// A Virtual Machine that has not finished downloading.
@available(iOS 14, macOS 11, *)
class UTMPendingVirtualMachine: Identifiable, Equatable {
    internal init(name: String, importTask: UTMImportFromWebTask) {
        self.url = importTask.url
        self.name = name
        self.downloadProgress = importTask.downloadProgress
        self.cancel = importTask.cancel
    }
    
    #if DEBUG
    /// init for SwiftUI Preview
    internal init(name: String) {
        self.url = URL(string: "https://getutm.app")!
        self.name = name
        self.downloadProgress = Progress(totalUnitCount: 0)
        self.cancel = {}
    }
    #endif
    
    private var url: URL
    let name: String
    let downloadProgress: Progress
    let cancel: () -> ()
    
    static func == (lhs: UTMPendingVirtualMachine, rhs: UTMPendingVirtualMachine) -> Bool {
        lhs.url == rhs.url
    }
    
    var id: String {
        url.absoluteString
    }
}
