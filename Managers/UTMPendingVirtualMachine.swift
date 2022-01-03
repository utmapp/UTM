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
class UTMPendingVirtualMachine: Equatable, Identifiable, ObservableObject {
    internal init(name: String, task: UTMDownloadable) {
        self.name = name
        self.cancel = task.cancel
    }
    
    #if DEBUG
    /// init for SwiftUI Preview
    internal init(name: String) {
        self.name = name
        self.downloadProgress = 0.41
        self.cancel = {}
    }
    #endif
    
    private var uuid = UUID()
    let name: String
    @Published private(set) var downloadProgress: CGFloat = 0
    let cancel: () -> ()
    
    static func == (lhs: UTMPendingVirtualMachine, rhs: UTMPendingVirtualMachine) -> Bool {
        lhs.uuid == rhs.uuid
    }
    
    var id: UUID {
        uuid
    }
    
    public func setDownloadProgress(_ progress: Float) {
        objectWillChange.send()
        downloadProgress = CGFloat(progress)
    }
}
