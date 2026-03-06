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
import QEMUKitInternal

@MainActor
@objc(UTMScriptingVirtualMachineImpl)
class UTMScriptingVirtualMachineImpl: NSObject, UTMScriptable {
    @nonobjc var box: VMData
    @nonobjc var data: UTMData
    @nonobjc var vm: (any UTMVirtualMachine)! {
        box.wrapped
    }
    
    @objc var id: String {
        vm.id.uuidString
    }
    
    @objc var name: String {
        box.detailsTitleLabel
    }
    
    @objc var notes: String {
        box.detailsNotes ?? ""
    }
    
    @objc var machine: String {
        box.detailsSystemTargetLabel
    }
    
    @objc var architecture: String {
        box.detailsSystemArchitectureLabel
    }
    
    @objc var memory: String {
        box.detailsSystemMemoryLabel
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
        case .stopped: return .stopped
        case .starting: return .starting
        case .started: return .started
        case .pausing: return .pausing
        case .paused: return .paused
        case .resuming: return .resuming
        case .stopping: return .stopping
        case .saving: return .pausing // FIXME: new entries
        case .restoring: return .resuming // FIXME: new entries
        }
    }
    
    @objc var serialPorts: [UTMScriptingSerialPortImpl] {
        if let config = vm.config as? UTMQemuConfiguration {
            return config.serials.indices.map({ UTMScriptingSerialPortImpl(qemuSerial: config.serials[$0], parent: self, index: $0) })
        } else if let config = vm.config as? UTMAppleConfiguration {
            return config.serials.indices.map({ UTMScriptingSerialPortImpl(appleSerial: config.serials[$0], parent: self, index: $0) })
        } else {
            return []
        }
    }
    
    var guestAgent: QEMUGuestAgent! {
        get async {
            await (vm as? UTMQemuVirtualMachine)?.guestAgent
        }
    }
    
    var qemuProcess: UTMQemuSystem? {
        get async {
            await (vm as? UTMQemuVirtualMachine)?.system
        }
    }
    
    override var objectSpecifier: NSScriptObjectSpecifier? {
        let appDescription = NSApplication.classDescription() as! NSScriptClassDescription
        return NSUniqueIDSpecifier(containerClassDescription: appDescription,
                                   containerSpecifier: nil,
                                   key: "scriptingVirtualMachines",
                                   uniqueID: id)
    }
    
    init(for vm: VMData, data: UTMData) {
        self.box = vm
        self.data = data
    }
    
    @objc func start(_ command: NSScriptCommand) {
        let shouldSaveState = command.evaluatedArguments?["saveFlag"] as? Bool ?? true
        let bootRecoveryMode = command.evaluatedArguments?["bootRecoveryFlag"] as? Bool ?? false

        withScriptCommand(command) { [self] in
            var options: UTMVirtualMachineStartOptions = []

            if !shouldSaveState {
                guard type(of: vm).capabilities.supportsDisposibleMode else {
                    throw ScriptingError.operationNotSupported
                }
                options.insert(.bootDisposibleMode)
            }
            if bootRecoveryMode {
                guard type(of: vm).capabilities.supportsRecoveryMode else {
                    throw ScriptingError.operationNotSupported
                }
                options.insert(.bootRecovery)
            }

            data.run(vm: box, startImmediately: false)
            if vm.state == .stopped {
                try await vm.start(options: options)
            } else if vm.state == .paused {
                try await vm.resume()
            } else {
                throw ScriptingError.operationNotAvailable
            }
        }
    }
    
    @objc func suspend(_ command: NSScriptCommand) {
        let shouldSaveState = command.evaluatedArguments?["saveFlag"] as? Bool ?? false
        withScriptCommand(command) { [self] in
            guard vm.state == .started else {
                throw ScriptingError.notRunning
            }
            try await vm.pause()
            if shouldSaveState {
                try await vm.saveSnapshot(name: nil)
            }
        }
    }
    
    @objc func stop(_ command: NSScriptCommand) {
        let stopMethod: UTMScriptingStopMethod
        if let stopMethodValue = command.evaluatedArguments?["stopBy"] as? AEKeyword {
            stopMethod = UTMScriptingStopMethod(rawValue: stopMethodValue) ?? .force
        } else {
            stopMethod = .force
        }
        withScriptCommand(command) { [self] in
            guard vm.state == .started || stopMethod == .kill else {
                throw ScriptingError.notRunning
            }
            switch stopMethod {
            case .force:
                try await vm.stop(usingMethod: .force)
            case .kill:
                try await vm.stop(usingMethod: .kill)
            case .request:
                try await vm.stop(usingMethod: .request)
            }
        }
    }
    
    @objc func delete(_ command: NSDeleteCommand) {
        withScriptCommand(command) { [self] in
            guard vm.state == .stopped else {
                throw ScriptingError.notStopped
            }
            try await data.delete(vm: box, alsoRegistry: true)
        }
    }
    
    @objc func clone(_ command: NSCloneCommand) {
        let properties = command.evaluatedArguments?["WithProperties"] as? [AnyHashable : Any]
        withScriptCommand(command) { [self] in
            guard vm.state == .stopped else {
                throw ScriptingError.notStopped
            }
            let newVM = try await data.clone(vm: box)
            if let properties = properties, let newConfiguration = properties["configuration"] as? [AnyHashable : Any] {
                let wrapper = UTMScriptingConfigImpl(newVM.config!)
                try wrapper.updateConfiguration(from: newConfiguration)
                try await data.save(vm: newVM)
            }
        }
    }
    
    @objc func export(_ command: NSCloneCommand) {
        let exportUrl = command.evaluatedArguments?["file"] as? URL
        withScriptCommand(command) { [self] in
            guard vm.state == .stopped else {
                throw ScriptingError.notStopped
            }
            try await data.export(vm: box, to: exportUrl!)
        }
    }
}

// MARK: - Guest agent suite
@objc extension UTMScriptingVirtualMachineImpl {
    @nonobjc private func withGuestAgent<Result>(_ block: (QEMUGuestAgent) async throws -> Result) async throws -> Result {
        guard vm.state == .started else {
            throw ScriptingError.notRunning
        }
        guard let vm = vm as? UTMQemuVirtualMachine else {
            throw ScriptingError.operationNotSupported
        }
        guard let guestAgent = await vm.guestAgent else {
            throw ScriptingError.guestAgentNotRunning
        }
        return try await block(guestAgent)
    }
    
    @objc func valueInOpenFilesWithUniqueID(_ id: Int) -> UTMScriptingGuestFileImpl {
        UTMScriptingGuestFileImpl(from: id, parent: self)
    }
    
    @objc func openFile(_ command: NSScriptCommand) {
        let path = command.evaluatedArguments?["path"] as? String
        let mode = command.evaluatedArguments?["mode"] as? AEKeyword
        let isUpdate = command.evaluatedArguments?["isUpdate"] as? Bool ?? false
        withScriptCommand(command) { [self] in
            guard let path = path else {
                throw ScriptingError.invalidParameter
            }
            let modeValue: String
            if let mode = mode {
                switch UTMScriptingOpenMode(rawValue: mode) {
                case .reading: modeValue = "r"
                case .writing: modeValue = "w"
                case .appending: modeValue = "a"
                default: modeValue = "r"
                }
            } else {
                modeValue = "r"
            }
            return try await withGuestAgent { guestAgent in
                let handle = try await guestAgent.guestFileOpen(path, mode: modeValue + (isUpdate ? "+" : ""))
                return UTMScriptingGuestFileImpl(from: handle, parent: self)
            }
        }
    }
    
    @objc func valueInProcessesWithUniqueID(_ id: Int) -> UTMScriptingGuestProcessImpl {
        UTMScriptingGuestProcessImpl(from: id, parent: self)
    }
    
    @objc func execute(_ command: NSScriptCommand) {
        let path = command.evaluatedArguments?["path"] as? String
        let argv = command.evaluatedArguments?["argv"] as? [String]
        let envp = command.evaluatedArguments?["envp"] as? [String]
        let input = command.evaluatedArguments?["input"] as? String
        let isBase64Encoded = command.evaluatedArguments?["isBase64Encoded"] as? Bool ?? false
        let isCaptureOutput = command.evaluatedArguments?["isCaptureOutput"] as? Bool ?? false
        let inputData = dataFromText(input, isBase64Encoded: isBase64Encoded)
        withScriptCommand(command) { [self] in
            guard let path = path else {
                throw ScriptingError.invalidParameter
            }
            return try await withGuestAgent { guestAgent in
                let pid = try await guestAgent.guestExec(path, argv: argv, envp: envp, input: inputData, captureOutput: isCaptureOutput)
                return UTMScriptingGuestProcessImpl(from: pid, parent: self)
            }
        }
    }
    
    @objc func queryIp(_ command: NSScriptCommand) {
        withScriptCommand(command) { [self] in
            // Apple Virtualization backend: no guest agent available
            if let appleVM = vm as? UTMAppleVirtualMachine {
                guard appleVM.state == .started else {
                    throw ScriptingError.notRunning
                }

                guard let network = appleVM.config.networks.first else {
                    return []
                }
                let macAddress = network.macAddress.lowercased()
                return Self.ipFromARP(macAddress: macAddress)
            }

            // Non-Apple backend (QEMU): use guest agent
            return try await withGuestAgent { guestAgent in
                let interfaces = try await guestAgent.guestNetworkGetInterfaces()
                var ipv4: [String] = []
                var ipv6: [String] = []
                for interface in interfaces {
                    for ip in interface.ipAddresses {
                        if ip.isIpV6Address {
                            if ip.ipAddress != "::1" && ip.ipAddress != "0:0:0:0:0:0:0:1" {
                                ipv6.append(ip.ipAddress)
                            }
                        } else {
                            if ip.ipAddress != "127.0.0.1" {
                                ipv4.append(ip.ipAddress)
                            }
                        }
                    }
                }
                return ipv4 + ipv6
            }
        }
    }
}

extension UTMScriptingVirtualMachineImpl {

    /// Normalizes a colon-separated MAC address by stripping leading zeros from each
    /// octet so that `%x`-formatted bytes compare equal to stored representations.
    ///
    /// Example: `"ce:09:f1:ce:7f:f2"` → `"ce:9:f1:ce:7f:f2"`
    private static func normalizeMac(_ mac: String) -> String {
        mac.split(separator: ":").map { octet in
            let stripped = octet.drop(while: { $0 == "0" })
            return stripped.isEmpty ? "0" : String(stripped)
        }.joined(separator: ":")
    }

    /// Find the IP address for the given MAC by querying the kernel ARP cache via
    /// `sysctl(CTL_NET, PF_ROUTE, …, NET_RT_FLAGS, RTF_LLINFO)`.
    ///
    /// - Parameter macAddress: Lowercase colon-separated MAC, e.g. `"ce:09:f1:ce:7f:f2"`.
    /// - Returns: A single-element array with the IP, or empty if not found.
    static func ipFromARP(macAddress: String) -> [String] {
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

            // Sockaddrs start immediately after rt_msghdr.
            // First: sockaddr_in (destination IP). Layout: len(1) family(1) port(2) addr(4) …
            let sinStart = offset + MemoryLayout<rt_msghdr>.stride
            guard sinStart + 8 <= needed else { continue }
            let sinLen    = Int(buf[sinStart])
            let sinFamily = buf[sinStart + 1]
            guard sinFamily == UInt8(AF_INET), sinLen >= 8 else { continue }
            let ipStr = buf[(sinStart + 4)..<(sinStart + 8)].map { String($0) }.joined(separator: ".")

            // Second: sockaddr_dl (link-layer MAC). Padded to sizeof(long) = 8.
            // Layout: len(1) family(1) index(2) type(1) nlen(1) alen(1) slen(1) data[nlen+alen…]
            let sdlStart = sinStart + ((sinLen + 7) & ~7)
            guard sdlStart + 8 <= needed else { continue }
            let sdlFamily = buf[sdlStart + 1]
            let sdlNlen   = Int(buf[sdlStart + 5])
            let sdlAlen   = Int(buf[sdlStart + 6])
            guard sdlFamily == UInt8(AF_LINK), sdlAlen == 6 else { continue }

            let macStart = sdlStart + 8 + sdlNlen
            guard macStart + 6 <= needed else { continue }
            let mac = buf[macStart..<(macStart + 6)].map { String(format: "%x", $0) }.joined(separator: ":")
            if normalizeMac(mac) == normalizedTarget {
                return [ipStr]
            }
        }
        return []
    }
}


// MARK: - Errors
extension UTMScriptingVirtualMachineImpl {
    enum ScriptingError: Error, LocalizedError {
        case operationNotAvailable
        case operationNotSupported
        case notRunning
        case notStopped
        case guestAgentNotRunning
        case invalidParameter
        
        var errorDescription: String? {
            switch self {
            case .operationNotAvailable: return NSLocalizedString("Operation not available.", comment: "UTMScriptingVirtualMachineImpl")
            case .operationNotSupported: return NSLocalizedString("Operation not supported by the backend.", comment: "UTMScriptingVirtualMachineImpl")
            case .notRunning: return NSLocalizedString("The virtual machine is not running.", comment: "UTMScriptingVirtualMachineImpl")
            case .notStopped: return NSLocalizedString("The virtual machine must be stopped before this operation can be performed.", comment: "UTMScriptingVirtualMachineImpl")
            case .guestAgentNotRunning: return NSLocalizedString("The QEMU guest agent is not running or not installed on the guest.", comment: "UTMScriptingVirtualMachineImpl")
            case .invalidParameter: return NSLocalizedString("One or more required parameters are missing or invalid.", comment: "UTMScriptingVirtualMachineImpl")
            }
        }
    }
}
