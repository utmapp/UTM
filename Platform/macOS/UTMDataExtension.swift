//
// Copyright © 2020 osy. All rights reserved.
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
import Carbon.HIToolbox

@available(macOS 11, *)
extension UTMData {
    func run(vm: VMData, options: UTMVirtualMachineStartOptions = [], startImmediately: Bool = true) {
        var window: Any? = vmWindows[vm]
        if window == nil {
            let close = {
                self.vmWindows.removeValue(forKey: vm)
                window = nil
            }
            if let avm = vm.wrapped as? UTMAppleVirtualMachine {
                if avm.config.system.architecture == UTMAppleConfigurationSystem.currentArchitecture {
                    let primarySerialIndex = avm.config.serials.firstIndex { $0.mode == .builtin }
                    if let primarySerialIndex = primarySerialIndex {
                        window = VMDisplayAppleTerminalWindowController(primaryForIndex: primarySerialIndex, vm: avm, onClose: close)
                    }
                    if #available(macOS 12, *), !avm.config.displays.isEmpty {
                        window = VMDisplayAppleDisplayWindowController(vm: avm, onClose: close)
                    } else if avm.config.displays.isEmpty && window == nil {
                        window = VMHeadlessSessionState(for: avm, onStop: close)
                    }
                }
            }
            if let qvm = vm.wrapped as? UTMQemuVirtualMachine {
                if !qvm.config.displays.isEmpty {
                    window = VMDisplayQemuMetalWindowController(vm: qvm, onClose: close)
                } else if !qvm.config.serials.filter({ $0.mode == .builtin }).isEmpty {
                    window = VMDisplayQemuTerminalWindowController(vm: qvm, onClose: close)
                } else {
                    window = VMHeadlessSessionState(for: qvm, onStop: close)
                }
            }
            if window == nil {
                DispatchQueue.main.async {
                    self.alertMessage = AlertMessage(NSLocalizedString("This virtual machine cannot be run on this machine.", comment: "UTMDataExtension"))
                }
            }
        }
        if let unwrappedWindow = window as? VMDisplayWindowController {
            vmWindows[vm] = unwrappedWindow
            vm.wrapped!.delegate = unwrappedWindow
            unwrappedWindow.showWindow(nil)
            unwrappedWindow.window!.makeMain()
            if vm.wrapped!.config.information.isFullScreenStart && !unwrappedWindow.window!.styleMask.contains(.fullScreen) {
                unwrappedWindow.window!.toggleFullScreen(nil)
            }
            
            if startImmediately {
                unwrappedWindow.requestAutoStart(options: options)
            }
        } else if let unwrappedWindow = window as? VMHeadlessSessionState {
            vmWindows[vm] = unwrappedWindow
            if startImmediately {
                if vm.wrapped!.state == .paused {
                    vm.wrapped!.requestVmResume()
                } else if vm.wrapped!.state == .stopped {
                    vm.wrapped!.requestVmStart(options: options)
                }
            }
        } else {
            logger.critical("Failed to create window controller.")
        }
    }
    
    /// Start a remote session and return SPICE server port.
    /// - Parameters:
    ///   - vm: VM to start
    ///   - options: Start options
    ///   - server: Remote server
    /// - Returns: Port number to SPICE server
    func startRemote(vm: VMData, options: UTMVirtualMachineStartOptions, forClient client: UTMRemoteServer.Remote) async throws -> UTMRemoteMessageServer.StartVirtualMachine.ServerInformation {
        guard let wrapped = vm.wrapped as? UTMQemuVirtualMachine, type(of: wrapped).capabilities.supportsRemoteSession else {
            throw UTMDataError.unsupportedBackend
        }
        if let existingSession = vmWindows[vm] as? VMRemoteSessionState, let spiceServerInfo = wrapped.spiceServerInfo {
            if wrapped.state == .paused {
                try await wrapped.resume()
            }
            existingSession.client = client
            return spiceServerInfo
        }
        guard vmWindows[vm] == nil else {
            throw UTMDataError.virtualMachineUnavailable
        }
        let session = VMRemoteSessionState(for: wrapped, client: client) {
            self.vmWindows.removeValue(forKey: vm)
        }
        try await wrapped.start(options: options.union(.remoteSession))
        vmWindows[vm] = session
        guard let spiceServerInfo = wrapped.spiceServerInfo else {
            throw UTMDataError.unsupportedBackend
        }
        return spiceServerInfo
    }

    func stop(vm: VMData) {
        guard let wrapped = vm.wrapped else {
            return
        }
        Task {
            if wrapped.registryEntry.isSuspended {
                try? await wrapped.deleteSnapshot(name: nil)
            }
            try? await wrapped.stop(usingMethod: .force)
            await MainActor.run {
                self.close(vm: vm)
            }
        }
    }
    
    func close(vm: VMData) {
        if let window = vmWindows.removeValue(forKey: vm) as? VMDisplayWindowController {
            DispatchQueue.main.async {
                window.close()
            }
        }
    }
}
