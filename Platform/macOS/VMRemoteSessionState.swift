//
// Copyright © 2024 osy. All rights reserved.
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
import IOKit.pwr_mgt

/// Represents the UI state for a single headless VM session.
class VMRemoteSessionState: VMHeadlessSessionState {
    let server: UTMRemoteServer

    init(for vm: any UTMVirtualMachine, server: UTMRemoteServer, onStop: (() -> Void)?) {
        self.server = server
        super.init(for: vm, onStop: onStop)
    }
    
    override func virtualMachine(_ vm: any UTMVirtualMachine, didTransitionToState state: UTMVirtualMachineState) {
        Task {
            do {
                super.virtualMachine(vm, didTransitionToState: state)
                try await server.broadcast { remote in
                    try await remote.virtualMachine(id: vm.id, didTransitionToState: state)
                }
            } catch {
                if state != .stopped {
                    try? await vm.stop(usingMethod: .kill)
                }
            }
        }
    }

    override func virtualMachine(_ vm: any UTMVirtualMachine, didErrorWithMessage message: String) {
        Task {
            await server.broadcast { remote in
                try? await remote.virtualMachine(id: vm.id, didErrorWithMessage: message)
            }
            super.virtualMachine(vm, didErrorWithMessage: message)
        }
    }
}
