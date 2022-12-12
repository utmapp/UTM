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
    @MainActor func run(vm: UTMVirtualMachine) {
        var window: Any? = vmWindows[vm]
        if window == nil {
            let close = { (notification: Notification) -> Void in
                self.vmWindows.removeValue(forKey: vm)
                window = nil
            }
            if let avm = vm as? UTMAppleVirtualMachine {
                if avm.appleConfig.system.architecture == UTMAppleConfigurationSystem.currentArchitecture {
                    let primarySerialIndex = avm.appleConfig.serials.firstIndex { $0.mode == .builtin }
                    if let primarySerialIndex = primarySerialIndex {
                        window = VMDisplayAppleTerminalWindowController(primaryForIndex: primarySerialIndex, vm: avm, onClose: close)
                    }
                    if #available(macOS 12, *), !avm.appleConfig.displays.isEmpty {
                        window = VMDisplayAppleDisplayWindowController(vm: vm, onClose: close)
                    } else if avm.appleConfig.displays.isEmpty && window == nil {
                        window = VMHeadlessSessionState(for: avm, onStop: close)
                    }
                }
            }
            if let qvm = vm as? UTMQemuVirtualMachine {
                if qvm.config.qemuHasDisplay {
                    window = VMDisplayQemuMetalWindowController(vm: qvm, onClose: close)
                } else if qvm.config.qemuHasTerminal {
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
            vm.delegate = unwrappedWindow
            unwrappedWindow.showWindow(nil)
            unwrappedWindow.window!.makeMain()
            unwrappedWindow.requestAutoStart()
        } else if let unwrappedWindow = window as? VMHeadlessSessionState {
            vmWindows[vm] = unwrappedWindow
            unwrappedWindow.start()
        } else {
            logger.critical("Failed to create window controller.")
        }
    }
    
    func stop(vm: UTMVirtualMachine) {
        if vm.hasSaveState {
            vm.requestVmDeleteState()
        }
        vm.vmStop(force: false, completion: { _ in
            self.close(vm: vm)
        })
    }
    
    func close(vm: UTMVirtualMachine) {
        if let window = vmWindows.removeValue(forKey: vm) as? VMDisplayWindowController {
            DispatchQueue.main.async {
                window.close()
            }
        }
    }
    
    func trySendTextSpice(vm: UTMVirtualMachine, text: String) {
        guard text.count > 0 else { return }
        if let vc = vmWindows[vm] as? VMDisplayQemuMetalWindowController {
            KeyCodeMap.createKeyMapIfNeeded()
            
            func sleep() {
                Thread.sleep(forTimeInterval: 0.05)
            }
            func keyDown(keyCode: Int) {
                if let scanCodes = KeyCodeMap.keyCodeToScanCodes[keyCode] {
                    vc.keyDown(scanCode: Int(scanCodes.down))
                    sleep()
                }
            }
            func keyUp(keyCode: Int) {
                /// Due to how Spice works we need to send keyUp for the .down scan code
                /// instead of sending the key down for the scan code that indicates key up.
                if let scanCodes = KeyCodeMap.keyCodeToScanCodes[keyCode] {
                    vc.keyUp(scanCode: Int(scanCodes.down))
                    sleep()
                }
            }
            func press(keyCode: Int) {
                keyDown(keyCode: keyCode)
                keyUp(keyCode: keyCode)
            }
            
            func simulateKeyPress(_ keyCodeDict: [String: Int]) {
                /// Press modifier keys if necessary
                let optionUsed = keyCodeDict["option"] == 1
                if optionUsed {
                    keyDown(keyCode: kVK_Option)
                    sleep()
                }
                let shiftUsed = keyCodeDict["shift"] == 1
                if shiftUsed {
                    keyDown(keyCode: kVK_Shift)
                    sleep()
                }
                let fnUsed = keyCodeDict["function"] == 1
                if fnUsed {
                    keyDown(keyCode: kVK_Function)
                    sleep()
                }
                let ctrlUsed = keyCodeDict["control"] == 1
                if ctrlUsed {
                    keyDown(keyCode: kVK_Control)
                    sleep()
                }
                let cmdUsed = keyCodeDict["command"] == 1
                if cmdUsed {
                    keyDown(keyCode: kVK_Command)
                    sleep()
                }
                /// Press the key now
                let keyCode = keyCodeDict["virtKeyCode"]!
                press(keyCode: keyCode)
                /// Release modifiers
                if optionUsed {
                    keyUp(keyCode: kVK_Option)
                    sleep()
                }
                if shiftUsed {
                    keyUp(keyCode: kVK_Shift)
                    sleep()
                }
                if fnUsed {
                    keyUp(keyCode: kVK_Function)
                    sleep()
                }
                if ctrlUsed {
                    keyUp(keyCode: kVK_Control)
                    sleep()
                }
                if cmdUsed {
                    keyUp(keyCode: kVK_Command)
                    sleep()
                }
            }
            DispatchQueue.global(qos: .userInitiated).async {
                text.enumerated().forEach { stringItem in
                    let char = stringItem.element
                    /// drop unknown chars
                    if let keyCodeDict = KeyCodeMap.characterToKeyCode(character: char) {
                        simulateKeyPress(keyCodeDict)
                    } else {
                        logger.warning("SendText dropping unknown char: \(char)")
                    }
                }
            }
        } else if let terminal = vmWindows[vm] as? VMDisplayTerminal {
            terminal.sendString(text)
        }
    }
    
    func tryClickAtPoint(vm: UTMQemuVirtualMachine, point: CGPoint, button: CSInputButton) {
        if let vc = vmWindows[vm] as? VMDisplayQemuMetalWindowController {
            vc.mouseMove(absolutePoint: point, button: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                vc.mouseDown(button: button)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    vc.mouseUp(button: button)
                }
            }
        }
    }
}

// MARK: - API Server
extension UTMData: UTMAPIDelegate {
    /// Return the API socket URL path
    var defaultSocketUrl: URL {
        let appGroup = Bundle.main.infoDictionary?["AppGroupIdentifier"] as? String
        // default to unsigned sandbox path
        var parentURL: URL = FileManager.default.homeDirectoryForCurrentUser
        parentURL.appendPathComponent("tmp")
        if let appGroup = appGroup, !appGroup.hasPrefix("invalid.") {
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
                parentURL = containerURL
            }
        }
        return parentURL.appendingPathComponent("api.sock")
    }
    
    /// Find a VM by either UUID (first) or complete name (second)
    /// - Parameter id: UUID or name
    /// - Returns: Virtual machine if found
    private func findVirtualMachine(_ id: String) async throws -> UTMVirtualMachine {
        if let uuid = UUID(uuidString: id) {
            if let vm = await virtualMachines.first(where: { $0.id == uuid }) {
                return vm
            }
        }
        if let vm = await virtualMachines.first(where: { $0.detailsTitleLabel == id }) {
            return vm
        } else {
            throw UTMAPI.APIError.identifierNotFound
        }
    }
    
    func handleAPIRequest(_ request: any UTMAPIRequest) async throws -> any UTMAPIResponse {
        do {
            switch request.command {
            case .list: return try await handleAPIListRequest(request)
            case .status: return try await handleAPIStatusRequest(request)
            case .start: return try await handleAPIStartRequest(request)
            case .suspend: return try await handleAPISuspendRequest(request)
            case .stop: return try await handleAPIStopRequest(request)
            case .serial: return try await handleAPISerialRequest(request)
            case .error: throw UTMAPI.APIError.invalidCommand
            }
        } catch {
            return UTMAPI.ErrorResponse(error.localizedDescription)
        }
    }
    
    private func handleAPIListRequest(_ request: any UTMAPIRequest) async throws -> UTMAPI.ListResponse {
        var response = UTMAPI.ListResponse()
        response.entries = await virtualMachines.map { vm in
            UTMAPI.ListResponse.Entry(uuid: vm.id.uuidString,
                                      name: vm.detailsTitleLabel,
                                      status: vm.state.apiStatus)
        }
        return response
    }
    
    private func handleAPIStatusRequest(_ request: any UTMAPIRequest) async throws -> UTMAPI.StatusResponse {
        guard let request = request as? UTMAPI.StatusRequest else {
            throw UTMAPI.APIError.requestFormatMismatch
        }
        let vm = try await findVirtualMachine(request.identifier)
        var response = UTMAPI.StatusResponse()
        response.status = vm.state.apiStatus
        return response
    }
    
    private func handleAPIStartRequest(_ request: any UTMAPIRequest) async throws -> UTMAPI.StartResponse {
        guard let request = request as? UTMAPI.StartRequest else {
            throw UTMAPI.APIError.requestFormatMismatch
        }
        let vm = try await findVirtualMachine(request.identifier)
        if vm.state == .vmStopped {
            try await vm.vmStart()
        } else if vm.state == .vmPaused {
            try await vm.vmResume()
        } else {
            throw UTMAPI.APIError.operationNotAvailable
        }
        return UTMAPI.StartResponse()
    }
    
    private func handleAPISuspendRequest(_ request: any UTMAPIRequest) async throws -> UTMAPI.SuspendResponse {
        guard let request = request as? UTMAPI.SuspendRequest else {
            throw UTMAPI.APIError.requestFormatMismatch
        }
        let vm = try await findVirtualMachine(request.identifier)
        guard vm.state == .vmStarted else {
            throw UTMAPI.APIError.operationNotAvailable
        }
        try await vm.vmPause(save: request.shouldSaveState)
        return UTMAPI.SuspendResponse()
    }
    
    private func handleAPIStopRequest(_ request: any UTMAPIRequest) async throws -> UTMAPI.StopResponse {
        guard let request = request as? UTMAPI.StopRequest else {
            throw UTMAPI.APIError.requestFormatMismatch
        }
        let vm = try await findVirtualMachine(request.identifier)
        guard vm.state == .vmStarted else {
            throw UTMAPI.APIError.operationNotAvailable
        }
        switch request.type {
        case .request:
            try await vm.vmGuestPowerDown()
        case .force:
            try await vm.vmStop(force: false)
        case .kill:
            try await vm.vmStop(force: true)
        }
        return UTMAPI.StopResponse()
    }
    
    private func handleAPISerialRequest(_ request: any UTMAPIRequest) async throws -> UTMAPI.SerialResponse {
        guard let request = request as? UTMAPI.SerialRequest else {
            throw UTMAPI.APIError.requestFormatMismatch
        }
        let vm = try await findVirtualMachine(request.identifier)
        var response = UTMAPI.SerialResponse()
        if let vm = vm as? UTMQemuVirtualMachine {
            let serials = await vm.qemuConfig.serials.filter({ $0.mode == .tcpServer || $0.mode == .ptty })
            let index = request.index ?? 0
            guard index < serials.count else {
                throw UTMAPI.APIError.deviceNotFound
            }
            switch serials[index].mode {
            case .ptty:
                if let path = serials[index].pttyDevice?.path {
                    response.address = .ptty(path: path)
                }
            case .tcpServer:
                let address = serials[index].tcpHostAddress ?? "127.0.0.1"
                if let port = serials[index].tcpPort {
                    response.address = .tcp(address: address, port: port)
                }
            default:
                fatalError("Invalid serial device, should have been filtered out.")
            }
            response.total = serials.count
        } else if let vm = vm as? UTMAppleVirtualMachine {
            let serials = await vm.config.appleConfig!.serials.filter({ $0.mode == .ptty })
            let index = request.index ?? 0
            guard index < serials.count else {
                throw UTMAPI.APIError.deviceNotFound
            }
            if let path = serials[index].interface?.name {
                response.address = .ptty(path: path)
            }
            response.total = serials.count
        } else {
            fatalError("Unsupported VM backend.")
        }
        return response
    }
}

/// Convert UTM VM type to API type
extension UTMVMState {
    var apiStatus: UTMAPI.VMStatus {
        switch self {
        case .vmPausing, .vmResuming, .vmStarting, .vmStopping: return .busy
        case .vmPaused: return .paused
        case .vmStopped: return .stopped
        case .vmStarted: return .started
        @unknown default: return .unknown
        }
    }
}
