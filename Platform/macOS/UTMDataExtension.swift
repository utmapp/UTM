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
import Darwin

enum UTMDataIPError: Error {
    case notRunning
    case guestAgentUnavailable
    case unsupportedBackend
}

@available(macOS 11, *)
extension UTMData {
    func queryIp(for box: VMData) async throws -> [String] {
        guard let vm = box.wrapped else {
            throw UTMDataIPError.unsupportedBackend
        }
        guard vm.state == .started else {
            throw UTMDataIPError.notRunning
        }
        if let appleVM = vm as? UTMAppleVirtualMachine {
            guard let network = appleVM.config.networks.first else {
                return []
            }
            return Self.ipFromARP(macAddress: network.macAddress.lowercased())
        }
        guard let qemuVM = vm as? UTMQemuVirtualMachine else {
            throw UTMDataIPError.unsupportedBackend
        }
        guard let guestAgent = await qemuVM.guestAgent else {
            throw UTMDataIPError.guestAgentUnavailable
        }
        let interfaces = try await guestAgent.guestNetworkGetInterfaces()
        var ipv4: [String] = []
        var ipv6: [String] = []
        for interface in interfaces {
            for ip in interface.ipAddresses {
                if ip.isIpV6Address {
                    if ip.ipAddress != "::1" && ip.ipAddress != "0:0:0:0:0:0:0:1" {
                        ipv6.append(ip.ipAddress)
                    }
                } else if ip.ipAddress != "127.0.0.1" {
                    ipv4.append(ip.ipAddress)
                }
            }
        }
        return ipv4 + ipv6
    }

    private static func normalizeMac(_ mac: String) -> String {
        mac.split(separator: ":").map { octet in
            let stripped = octet.drop(while: { $0 == "0" })
            return stripped.isEmpty ? "0" : String(stripped)
        }.joined(separator: ":")
    }

    private static func ipFromARP(macAddress: String) -> [String] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO]
        var needed = 0
        guard sysctl(&mib, 6, nil, &needed, nil, 0) == 0, needed > 0 else { return [] }
        var buf = [UInt8](repeating: 0, count: needed)
        guard sysctl(&mib, 6, &buf, &needed, nil, 0) == 0 else { return [] }
        let normalizedTarget = normalizeMac(macAddress)
        var offset = 0
        while offset + MemoryLayout<rt_msghdr>.stride <= needed {
            let msglen = Int(buf.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: rt_msghdr.self).rtm_msglen
            })
            guard msglen > 0, offset + msglen <= needed else { break }
            defer { offset += msglen }
            let sinStart = offset + MemoryLayout<rt_msghdr>.stride
            guard sinStart + 8 <= needed else { continue }
            let sinLen = Int(buf[sinStart])
            let sinFamily = buf[sinStart + 1]
            guard sinFamily == UInt8(AF_INET), sinLen >= 8 else { continue }
            let ipStr = buf[(sinStart + 4)..<(sinStart + 8)].map { String($0) }.joined(separator: ".")
            let sdlStart = sinStart + ((sinLen + 7) & ~7)
            guard sdlStart + 8 <= needed else { continue }
            let sdlFamily = buf[sdlStart + 1]
            let sdlNlen = Int(buf[sdlStart + 5])
            let sdlAlen = Int(buf[sdlStart + 6])
            guard sdlFamily == UInt8(AF_LINK), sdlAlen == 6 else { continue }
            let macStart = sdlStart + 8 + sdlNlen
            guard macStart + 6 <= needed else { continue }
            let mac = buf[macStart..<(macStart + 6)].map { String(format: "%x", $0) }.joined(separator: ":")
            if normalizeMac(mac) == normalizedTarget { return [ipStr] }
        }
        return []
    }
}

@available(macOS 11, *)
extension UTMData {
    private func makeSession(for vm: VMData) -> NSObject? {
        let close: () -> Void = {
            _ = self.vmWindows.removeValue(forKey: vm)
        }
        var session: NSObject?
        if let avm = vm.wrapped as? UTMAppleVirtualMachine {
            if avm.config.system.architecture == UTMAppleConfigurationSystem.currentArchitecture {
                let primarySerialIndex = avm.config.serials.firstIndex { $0.mode == .builtin }
                if let primarySerialIndex = primarySerialIndex {
                    session = VMDisplayAppleTerminalWindowController(primaryForIndex: primarySerialIndex, vm: avm, onClose: close)
                }
                if #available(macOS 12, *), !avm.config.displays.isEmpty {
                    session = VMDisplayAppleDisplayWindowController(vm: avm, onClose: close)
                } else if avm.config.displays.isEmpty && session == nil {
                    session = VMHeadlessSessionState(for: avm, onStop: close)
                }
            }
        }
        if let qvm = vm.wrapped as? UTMQemuVirtualMachine {
            if !qvm.config.displays.isEmpty {
                session = VMDisplayQemuMetalWindowController(vm: qvm, onClose: close)
            } else if !qvm.config.serials.filter({ $0.mode == .builtin }).isEmpty {
                session = VMDisplayQemuTerminalWindowController(vm: qvm, onClose: close)
            } else {
                session = VMHeadlessSessionState(for: qvm, onStop: close)
            }
        }
        return session
    }

    func startForControl(vm: VMData, options: UTMVirtualMachineStartOptions = []) async throws {
        guard let wrapped = vm.wrapped else {
            throw UTMDataError.virtualMachineUnavailable
        }
        guard wrapped.state == .stopped else {
            throw UTMDataError.virtualMachineUnavailable
        }
        let session: NSObject?
        let didCreate: Bool
        if let existing = vmWindows[vm] {
            // A stopped VM may still have its canonical window controller open
            // (for example after a graceful stop left the window visible).
            // Reuse it instead of creating a duplicate controller; any other
            // pre-existing session blocks a fresh start.
            guard let existingSession = existing as? VMDisplayWindowController else {
                throw UTMDataError.virtualMachineUnavailable
            }
            session = existingSession
            didCreate = false
        } else {
            guard let made = makeSession(for: vm) else {
                throw UTMDataError.virtualMachineUnavailable
            }
            vmWindows[vm] = made
            session = made
            didCreate = true
        }
        if let controller = session as? VMDisplayWindowController {
            wrapped.delegate = controller
            controller.showWindow(nil)
            controller.window!.makeMain()
        }
        do {
            try await wrapped.start(options: options)
            vm.state = wrapped.state
        } catch {
            if didCreate {
                if let controller = session as? VMDisplayWindowController {
                    controller.close()
                }
                if let currentSession = vmWindows[vm] as? NSObject, currentSession === session {
                    vmWindows.removeValue(forKey: vm)
                }
            }
            throw error
        }
    }

    func run(vm: VMData, options: UTMVirtualMachineStartOptions = [], startImmediately: Bool = true) {
        var window: Any? = vmWindows[vm]
        if window == nil {
            window = makeSession(for: vm)
            if window == nil {
                DispatchQueue.main.async {
                    self.alertItem = .message(NSLocalizedString("This virtual machine cannot be run on this machine.", comment: "UTMDataExtension"))
                }
            }
        }
        if let unwrappedWindow = window as? VMDisplayWindowController {
            vmWindows[vm] = unwrappedWindow
            vm.wrapped!.delegate = unwrappedWindow
            unwrappedWindow.showWindow(nil)
            unwrappedWindow.window!.makeMain()
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
            if vm.state == .started || vm.state == .paused {
                try? await wrapped.stop(usingMethod: .force)
            } else {
                try? await wrapped.stop(usingMethod: .kill)
            }
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
