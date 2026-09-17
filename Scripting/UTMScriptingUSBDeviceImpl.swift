//
// Copyright © 2023 osy. All rights reserved.
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
import CocoaSpice

/// Properties of a host USB device shared by every backend
protocol UTMScriptableUSBDevice: AnyObject {
    var usbName: String? { get }
    var usbManufacturerName: String? { get }
    var usbProductName: String? { get }
    var usbSerial: String? { get }
    var usbVendorId: Int { get }
    var usbProductId: Int { get }
    var usbBusNumber: Int { get }
    var usbPortNumber: Int { get }
}

extension CSUSBDevice: UTMScriptableUSBDevice {
    var usbName: String? {
        name
    }
}

@available(macOS 27, *)
extension UTMAppleUSBDevice: UTMScriptableUSBDevice {
    var usbName: String? {
        name
    }
}

@MainActor
@objc(UTMScriptingUSBDeviceImpl)
class UTMScriptingUSBDeviceImpl: NSObject, UTMScriptable {
    @nonobjc var box: any UTMScriptableUSBDevice
    
    private var data: UTMData? {
        (NSApp.scriptingDelegate as? AppDelegate)?.data
    }
    
    @objc var id: Int {
        box.usbBusNumber << 16 | box.usbPortNumber
    }
    
    @objc var name: String {
        box.usbName ?? String(format: "%04X:%04X", box.usbVendorId, box.usbProductId)
    }
    
    @objc var manufacturerName: String {
        box.usbManufacturerName ?? name
    }
    
    @objc var productName: String {
        box.usbProductName ?? name
    }
    
    @objc var vendorId: Int {
        box.usbVendorId
    }
    
    @objc var productId: Int {
        box.usbProductId
    }
    
    override var objectSpecifier: NSScriptObjectSpecifier? {
        let appDescription = NSApplication.classDescription() as! NSScriptClassDescription
        return NSUniqueIDSpecifier(containerClassDescription: appDescription,
                                   containerSpecifier: nil,
                                   key: "scriptingUsbDevices",
                                   uniqueID: id)
    }
    
    init(for usbDevice: any UTMScriptableUSBDevice) {
        self.box = usbDevice
    }
    
    /// Return the same USB device from a list of devices
    ///
    /// This is required because we may be using device objects returned from a different manager (or backend).
    /// - Parameters:
    ///   - usbDevice: USB device
    ///   - devices: Devices to search
    /// - Returns: USB device in the list
    private func same<Device: UTMScriptableUSBDevice>(usbDevice: any UTMScriptableUSBDevice, in devices: [Device]) -> Device? {
        if let usbDevice = usbDevice as? Device, let device = devices.first(where: { $0 === usbDevice }) {
            return device
        }
        if let device = devices.first(where: { $0.matchesLocation(of: usbDevice) }) {
            return device
        }
        if let device = devices.first(where: { $0.matchesSerial(of: usbDevice) }) {
            return device
        }
        let matchingDevices = devices.filter({ $0.matchesVidPid(of: usbDevice) })
        if matchingDevices.count == 1 {
            return matchingDevices[0]
        }
        return nil
    }
    
    /// Return the same USB device in context of a USB manager
    ///
    /// This is required because we may be using `CSUSBDevice` objects returned from a different `CSUSBManager`
    /// - Parameters:
    ///   - usbDevice: USB device
    ///   - usbManager: USB manager
    /// - Returns: USB device in same context as the manager
    private func same(usbDevice: any UTMScriptableUSBDevice, for usbManager: CSUSBManager) -> CSUSBDevice? {
        let devices = usbManager.usbDevices
        if let usbDevice = usbDevice as? CSUSBDevice, let device = devices.first(where: { $0.isEqual(to: usbDevice) }) {
            return device
        }
        return same(usbDevice: usbDevice, in: devices)
    }
    
    @objc func connect(_ command: NSScriptCommand) {
        let scriptingVM = command.evaluatedArguments?["vm"] as? UTMScriptingVirtualMachineImpl
        withScriptCommand(command) { [self] in
            if let vm = scriptingVM?.vm as? UTMQemuVirtualMachine {
                guard let usbManager = vm.ioService?.primaryUsbManager else {
                    throw UTMScriptingVirtualMachineImpl.ScriptingError.operationNotAvailable
                }
                guard let usbDevice = same(usbDevice: box, for: usbManager) else {
                    throw ScriptingError.deviceNotFound
                }
                try await usbManager.connectUsbDevice(usbDevice)
            } else if #available(macOS 27, *), let vm = scriptingVM?.vm as? UTMAppleVirtualMachine {
                guard vm.hasUsbRedirection else {
                    throw UTMScriptingVirtualMachineImpl.ScriptingError.operationNotAvailable
                }
                let devices = try await UTMAppleUSBManager.shared.allDevices()
                guard let usbDevice = same(usbDevice: box, in: devices) else {
                    throw ScriptingError.deviceNotFound
                }
                try await vm.connectUsbDevice(usbDevice, takingOver: true)
            } else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.operationNotSupported
            }
        }
    }
    
    @objc func disconnect(_ command: NSScriptCommand) {
        withScriptCommand(command) { [self] in
            guard let data = data else {
                throw ScriptingError.notReady
            }
            let managers = data.virtualMachines.compactMap({ vmdata in
                guard let vm = vmdata.wrapped as? UTMQemuVirtualMachine else {
                    return nil as CSUSBManager?
                }
                return vm.ioService?.primaryUsbManager
            })
            var appleVMs: [UTMAppleVirtualMachine] = []
            if #available(macOS 27, *) {
                appleVMs = data.virtualMachines.compactMap({ vmdata in
                    guard let vm = vmdata.wrapped as? UTMAppleVirtualMachine, vm.state == .started, vm.hasUsbRedirection else {
                        return nil
                    }
                    return vm
                })
            }
            guard managers.count > 0 || appleVMs.count > 0 else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.notRunning
            }
            var found = false
            for manager in managers {
                if let device = same(usbDevice: box, for: manager), manager.isUsbDeviceConnected(device) {
                    found = true
                    try await manager.disconnectUsbDevice(device)
                }
            }
            if #available(macOS 27, *) {
                for vm in appleVMs {
                    if let device = same(usbDevice: box, in: vm.connectedUsbDevices) {
                        found = true
                        try await vm.disconnectUsbDevice(device)
                    }
                }
            }
            if !found {
                throw ScriptingError.deviceNotConnected
            }
        }
    }
}

// MARK: - Errors
extension UTMScriptingUSBDeviceImpl {
    enum ScriptingError: Error, LocalizedError {
        case notReady
        case deviceNotFound
        case deviceNotConnected
        
        var errorDescription: String? {
            switch self {
            case .notReady: return NSLocalizedString("UTM is not ready to accept commands.", comment: "UTMScriptingUSBDeviceImpl")
            case .deviceNotFound: return NSLocalizedString("The device cannot be found.", comment: "UTMScriptingUSBDeviceImpl")
            case .deviceNotConnected: return NSLocalizedString("The device is not currently connected.", comment: "UTMScriptingUSBDeviceImpl")
            }
        }
    }
}

private extension UTMScriptableUSBDevice {
    func matchesVidPid(of other: any UTMScriptableUSBDevice) -> Bool {
        usbVendorId == other.usbVendorId && usbProductId == other.usbProductId
    }

    func matchesLocation(of other: any UTMScriptableUSBDevice) -> Bool {
        matchesVidPid(of: other) && usbBusNumber == other.usbBusNumber && usbPortNumber == other.usbPortNumber
    }

    func matchesSerial(of other: any UTMScriptableUSBDevice) -> Bool {
        guard let serial = usbSerial, let otherSerial = other.usbSerial, !serial.isEmpty else {
            return false
        }
        return matchesVidPid(of: other) && serial == otherSerial
    }
}

// MARK: - NSApplication extension
extension AppDelegate {
    @MainActor
    @objc var scriptingUsbDevices: [UTMScriptingUSBDeviceImpl] {
        guard let data = data else {
            return []
        }
        if let anyManager = data.virtualMachines.compactMap({ vmData in
            guard let vm = vmData.wrapped as? UTMQemuVirtualMachine else {
                return nil as CSUSBManager?
            }
            return vm.ioService?.primaryUsbManager
        }).first {
            return anyManager.usbDevices.map({ UTMScriptingUSBDeviceImpl(for: $0) })
        }
        if #available(macOS 27, *) {
            let hasAppleVM = data.virtualMachines.contains { vmData in
                guard let vm = vmData.wrapped as? UTMAppleVirtualMachine else {
                    return false
                }
                return vm.state == .started && vm.hasUsbRedirection
            }
            if hasAppleVM {
                return UTMAppleUSBManager.shared.devices.map({ UTMScriptingUSBDeviceImpl(for: $0) })
            }
        }
        return []
    }
}
