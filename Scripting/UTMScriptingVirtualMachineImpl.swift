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

@MainActor
@objc(UTMScriptingVirtualMachineImpl)
class UTMScriptingVirtualMachineImpl: NSObject {
    private var vm: UTMVirtualMachine
    private var data: UTMData
    
    @objc var id: String {
        vm.id.uuidString
    }
    
    @objc var name: String {
        vm.detailsTitleLabel
    }
    
    @objc var notes: String {
        vm.detailsNotes ?? ""
    }
    
    @objc var machine: String {
        vm.detailsSystemTargetLabel
    }
    
    @objc var architecture: String {
        vm.detailsSystemArchitectureLabel
    }
    
    @objc var memory: String {
        vm.detailsSystemMemoryLabel
    }
    
    @objc var backend: UTMScriptingBackend {
        if vm is UTMQemuVirtualMachine {
            return .qemu
        } else if vm is UTMAppleVirtualMachine {
            return .apple
        } else {
            return .unavailable
        }
    }
    
    @objc var status: UTMScriptingStatus {
        switch vm.state {
        case .vmStopped: return .stopped
        case .vmStarting: return .starting
        case .vmStarted: return .started
        case .vmPausing: return .pausing
        case .vmPaused: return .paused
        case .vmResuming: return .resuming
        case .vmStopping: return .stopping
        @unknown default: return .stopped
        }
    }
    
    @objc var serialPorts: [UTMScriptingSerialPortImpl] {
        if let config = vm.config.qemuConfig {
            return config.serials.indices.map({ UTMScriptingSerialPortImpl(qemuSerial: config.serials[$0], parent: self, index: $0) })
        } else if let config = vm.config.appleConfig {
            return config.serials.indices.map({ UTMScriptingSerialPortImpl(appleSerial: config.serials[$0], parent: self, index: $0) })
        } else {
            return []
        }
    }
    
    override var objectSpecifier: NSScriptObjectSpecifier? {
        let appDescription = NSApplication.classDescription() as! NSScriptClassDescription
        return NSUniqueIDSpecifier(containerClassDescription: appDescription,
                                   containerSpecifier: nil,
                                   key: "scriptingVirtualMachines",
                                   uniqueID: id)
    }
    
    init(for vm: UTMVirtualMachine, data: UTMData) {
        self.vm = vm
        self.data = data
    }
    
    private func withScriptCommand<Result>(_ command: NSScriptCommand, body: @MainActor @escaping () async throws -> Result) {
        guard command.evaluatedReceivers as? Self == self else {
            return
        }
        command.suspendExecution()
        // we need to run this in next event loop due to the need to return before calling resume
        DispatchQueue.main.async {
            Task {
                do {
                    let result = try await body()
                    await MainActor.run {
                        if result is Void {
                            command.resumeExecution(withResult: nil)
                        } else {
                            command.resumeExecution(withResult: result)
                        }
                    }
                } catch {
                    await MainActor.run {
                        command.scriptErrorNumber = errOSAGeneralError
                        command.scriptErrorString = error.localizedDescription
                        command.resumeExecution(withResult: nil)
                    }
                }
            }
        }
    }
    
    @objc func start(_ command: NSScriptCommand) {
        withScriptCommand(command) { [self] in
            data.run(vm: vm, startImmediately: false)
            if vm.state == .vmStopped {
                try await vm.vmStart()
            } else if vm.state == .vmPaused {
                try await vm.vmResume()
            } else {
                throw ScriptingError.operationNotAvailable
            }
        }
    }
    
    @objc func suspend(_ command: NSScriptCommand) {
        let shouldSaveState = command.evaluatedArguments?["doneFlag"] as? Bool ?? false
        withScriptCommand(command) { [self] in
            try await vm.vmPause(save: shouldSaveState)
        }
    }
    
    @objc func stop(_ command: NSScriptCommand) {
        let stopMethod = command.evaluatedArguments?["stopBy"] as? UTMScriptingStopMethod ?? .force
        withScriptCommand(command) { [self] in
            switch stopMethod {
            case .force:
                try await vm.vmStop(force: false)
            case .kill:
                try await vm.vmStop(force: true)
            case .request:
                vm.requestGuestPowerDown()
            }
        }
    }
}

extension UTMScriptingVirtualMachineImpl {
    enum ScriptingError: Error, LocalizedError {
        case operationNotAvailable
        
        var localizedDescription: String {
            switch self {
            case .operationNotAvailable: return "Operation not available."
            }
        }
    }
}
