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

@MainActor
@objc(UTMScriptingUSBDeviceImpl)
class UTMScriptingUSBDeviceImpl: NSObject, UTMScriptable {
    @nonobjc var box: CSUSBDevice
    
    private var data: UTMData? {
        (NSApp.scriptingDelegate as? AppDelegate)?.data
    }
    
    @objc var id: Int {
        box.usbBusNumber << 16 | box.usbPortNumber
    }
    
    @objc var name: String {
        box.name ?? String(format: "%04X:%04X", box.usbVendorId, box.usbProductId)
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
    
    init(for usbDevice: CSUSBDevice) {
        self.box = usbDevice
    }
    
    /// Return the same USB device in context of a USB manager
    ///
    /// This is required because we may be using `CSUSBDevice` objects returned from a different `CSUSBManager`
    /// - Parameters:
    ///   - usbDevice: USB device
    ///   - usbManager: USB manager
    /// - Returns: USB device in same context as the manager
    private func same(usbDevice: CSUSBDevice, for usbManager: CSUSBManager) -> CSUSBDevice? {
        for other in usbManager.usbDevices {
            if other.isEqual(to: usbDevice) {
                return other
            }
        }
        return nil
    }
    
    @objc func connect(_ command: NSScriptCommand) {
        let scriptingVM = command.evaluatedArguments?["vm"] as? UTMScriptingVirtualMachineImpl
        withScriptCommand(command) { [self] in
            guard let vm = scriptingVM?.vm as? UTMQemuVirtualMachine else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.operationNotSupported
            }
            guard let usbManager = vm.ioService?.primaryUsbManager else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.operationNotAvailable
            }
            guard let usbDevice = same(usbDevice: box, for: usbManager) else {
                throw ScriptingError.deviceNotFound
            }
            try await usbManager.connectUsbDevice(usbDevice)
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
            guard managers.count > 0 else {
                throw UTMScriptingVirtualMachineImpl.ScriptingError.notRunning
            }
            var found = false
            for manager in managers {
                if let device = same(usbDevice: box, for: manager), manager.isUsbDeviceConnected(device) {
                    found = true
                    try await manager.disconnectUsbDevice(device)
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

// MARK: - NSApplication extension
extension AppDelegate {
    @MainActor
    @objc var scriptingUsbDevices: [UTMScriptingUSBDeviceImpl] {
        guard let data = data else {
            return []
        }
        guard let anyManager = data.virtualMachines.compactMap({ vmData in
            guard let vm = vmData.wrapped as? UTMQemuVirtualMachine else {
                return nil as CSUSBManager?
            }
            return vm.ioService?.primaryUsbManager
        }).first else {
            return []
        }
        return anyManager.usbDevices.map({ UTMScriptingUSBDeviceImpl(for: $0) })
    }
}
