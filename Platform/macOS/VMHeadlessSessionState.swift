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

/// Represents the UI state for a single headless VM session.
@MainActor class VMHeadlessSessionState: NSObject, ObservableObject {
    let vm: UTMVirtualMachine
    var onStop: ((Notification) -> Void)?
    
    @Published var vmState: UTMVMState = .vmStopped
    
    @Published var fatalError: String?
    
    private var hasStarted: Bool = false
    
    init(for vm: UTMVirtualMachine, onStop: ((Notification) -> Void)?) {
        self.vm = vm
        self.onStop = onStop
        super.init()
        vm.delegate = self
    }
}

extension VMHeadlessSessionState: UTMVirtualMachineDelegate {
    nonisolated func virtualMachine(_ vm: UTMVirtualMachine, didTransitionTo state: UTMVMState) {
        Task { @MainActor in
            vmState = state
            if state == .vmStarted {
                hasStarted = true
            }
            if state == .vmStopped {
                if hasStarted {
                    stop() // graceful exit
                }
                hasStarted = false
            }
        }
    }
    
    nonisolated func virtualMachine(_ vm: UTMVirtualMachine, didErrorWithMessage message: String) {
        Task { @MainActor in
            fatalError = message
            NotificationCenter.default.post(name: .vmSessionError, object: nil, userInfo: ["Session": self, "Message": message])
            if !hasStarted {
                // if we got an error and haven't started, then cleanup
                stop()
            }
        }
    }
}

extension VMHeadlessSessionState {
    func start() {
        NotificationCenter.default.post(name: .vmSessionCreated, object: nil, userInfo: ["Session": self])
        vm.requestVmStart()
    }
    
    func stop() {
        NotificationCenter.default.post(name: .vmSessionEnded, object: nil, userInfo: ["Session": self])
    }
}

extension Notification.Name {
    static let vmSessionCreated = Self("VMSessionCreated")
    static let vmSessionEnded = Self("VMSessionEnded")
    static let vmSessionError = Self("VMSessionError")
}
