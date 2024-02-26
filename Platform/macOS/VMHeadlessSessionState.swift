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
import IOKit.pwr_mgt

/// Represents the UI state for a single headless VM session.
@MainActor class VMHeadlessSessionState: NSObject, ObservableObject, UTMVirtualMachineDelegate {
    let vm: any UTMVirtualMachine
    var onStop: (() -> Void)?
    
    @Published var vmState: UTMVirtualMachineState = .stopped
    
    private var hasStarted: Bool = false
    private var preventIdleSleepAssertion: IOPMAssertionID?
    
    @Setting("PreventIdleSleep") private var isPreventIdleSleep: Bool = false
    
    init(for vm: any UTMVirtualMachine, onStop: (() -> Void)?) {
        self.vm = vm
        self.onStop = onStop
        super.init()
        vm.delegate = self
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
    }

    nonisolated func virtualMachine(_ vm: any UTMVirtualMachine, didTransitionToState state: UTMVirtualMachineState) {
        Task { @MainActor in
            vmState = state
            if state == .started {
                hasStarted = true
                didStart()
            }
            if state == .stopped {
                if hasStarted {
                    didStop() // graceful exit
                }
                hasStarted = false
            }
        }
    }
    
    nonisolated func virtualMachine(_ vm: any UTMVirtualMachine, didErrorWithMessage message: String) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .vmSessionError, object: nil, userInfo: ["Session": self, "Message": message])
            if !hasStarted {
                // if we got an error and haven't started, then cleanup
                didStop()
            }
        }
    }
    
    nonisolated func virtualMachine(_ vm: any UTMVirtualMachine, didCompleteInstallation success: Bool) {
        
    }
    
    nonisolated func virtualMachine(_ vm: any UTMVirtualMachine, didUpdateInstallationProgress progress: Double) {
        
    }
}

extension VMHeadlessSessionState {
    private func didStart() {
        NotificationCenter.default.post(name: .vmSessionCreated, object: nil, userInfo: ["Session": self])
        if isPreventIdleSleep {
            var preventIdleSleepAssertion: IOPMAssertionID = .zero
            let success = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,
                                                      IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                      "UTM Virtual Machine Background" as CFString,
                                                      &preventIdleSleepAssertion)
            if success == kIOReturnSuccess {
                self.preventIdleSleepAssertion = preventIdleSleepAssertion
            }
        }
    }
    
    private func didStop() {
        NotificationCenter.default.post(name: .vmSessionEnded, object: nil, userInfo: ["Session": self])
        if let preventIdleSleepAssertion = preventIdleSleepAssertion {
            IOPMAssertionRelease(preventIdleSleepAssertion)
        }
        onStop?()
    }
}

extension Notification.Name {
    static let vmSessionCreated = Self("VMSessionCreated")
    static let vmSessionEnded = Self("VMSessionEnded")
    static let vmSessionError = Self("VMSessionError")
}

// MARK: - Computer wakeup
extension VMHeadlessSessionState {
    @objc private func didWake(_ notification: NSNotification) {
        if let qemuVM = vm as? UTMQemuVirtualMachine {
            Task {
                try? await qemuVM.guestAgent?.guestSetTime(NSDate.now.timeIntervalSince1970)
            }
        }
    }
}
