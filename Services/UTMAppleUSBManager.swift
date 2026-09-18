//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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
import AccessoryAccess
import Virtualization

/// Discovers host USB devices for Apple Virtualization passthrough.
///
/// The user assigns devices to UTM in the system "Virtual Machine Accessories" menu bar item and
/// only assigned devices are reported here. There is a single listener registered with
/// AccessoryAccess for the whole process. When a device is reported it is connected to the
/// virtual machine that claimed it, otherwise to the only running virtual machine, otherwise to
/// the virtual machine whose window is in front. The manager also tracks which virtual machine holds
/// each device so a device is never offered to two guests at once.
@available(macOS 27, *)
@MainActor final class UTMAppleUSBManager: NSObject {
    /// A request to connect the next reported device matching an identity to a virtual machine
    final class Claim {
        let saved: UTMRegistryEntry.USBDevice
        weak var vm: UTMAppleVirtualMachine?
        var result: UTMAppleUSBDevice?
        var continuation: CheckedContinuation<UTMAppleUSBDevice, any Error>?

        init(saved: UTMRegistryEntry.USBDevice, vm: UTMAppleVirtualMachine) {
            self.saved = saved
            self.vm = vm
        }
    }

    private struct WeakVM {
        weak var vm: UTMAppleVirtualMachine?
    }

    static let shared = UTMAppleUSBManager()

    /// USB devices assigned to UTM and currently plugged into the host
    private(set) var devices: [UTMAppleUSBDevice] = []

    /// Virtual machine that holds each device, by registry ID
    private var owners: [UInt64: WeakVM] = [:]

    /// Running virtual machines that can receive devices
    private let virtualMachines = NSHashTable<UTMAppleVirtualMachine>.weakObjects()

    private var claims: [Claim] = []

    /// Devices the user disconnected which must not be connected again when the system reports them
    private var released: [UTMRegistryEntry.USBDevice] = []

    private var registration: Task<Void, any Error>?

    private override init() {
        super.init()
    }

    /// Register with AccessoryAccess if this has not been done yet.
    ///
    /// Registration can fail if the app is missing the entitlement or is not shown in the Dock.
    func ensureRegistered() async throws {
        if let registration = registration {
            try await registration.value
            return
        }
        let registration = Task<Void, any Error> {
            let connected = try await AAUSBAccessoryManager.shared.registerListener(self, matchingCriteria: [])
            for accessory in connected {
                deviceDidConnect(accessory)
            }
        }
        self.registration = registration
        do {
            try await registration.value
        } catch {
            self.registration = nil
            throw error
        }
    }

    /// Get all USB devices assigned to UTM and currently plugged into the host
    /// - Returns: List of devices
    func allDevices() async throws -> [UTMAppleUSBDevice] {
        try await ensureRegistered()
        return devices
    }

    /// Find a plugged in device matching a saved identity
    /// - Parameter saved: Saved identity
    /// - Returns: The device if there is exactly one unclaimed match
    func device(matching saved: UTMRegistryEntry.USBDevice) -> UTMAppleUSBDevice? {
        let candidates = devices.filter { $0.matches(saved) && owner(of: $0) == nil }
        if candidates.count == 1 {
            return candidates[0]
        } else {
            return nil
        }
    }

    /// Find a plugged in device matching a saved identity, waiting for it to be reported
    ///
    /// Assigned devices are reported shortly after registration rather than in the registration result.
    /// - Parameters:
    ///   - saved: Saved identity
    ///   - timeout: How long to wait for the device
    /// - Returns: The device if there is exactly one unclaimed match before the timeout
    func device(matching saved: UTMRegistryEntry.USBDevice, timeout: Duration) async -> UTMAppleUSBDevice? {
        let deadline = ContinuousClock.now + timeout
        while true {
            if let device = device(matching: saved) {
                return device
            }
            if ContinuousClock.now >= deadline {
                return nil
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    // MARK: - Running virtual machines

    /// Start delivering devices to a virtual machine
    /// - Parameter vm: Virtual machine that started
    func addVirtualMachine(_ vm: UTMAppleVirtualMachine) {
        virtualMachines.add(vm)
    }

    /// Stop delivering devices to a virtual machine and release everything it holds
    /// - Parameter vm: Virtual machine that stopped
    func removeVirtualMachine(_ vm: UTMAppleVirtualMachine) {
        virtualMachines.remove(vm)
        owners = owners.filter { $0.value.vm != nil && $0.value.vm !== vm }
        claims.removeAll { claim in
            if claim.vm == nil || claim.vm === vm {
                claim.continuation?.resume(throwing: UTMAppleVirtualMachineError.operationNotAvailable)
                claim.continuation = nil
                return true
            }
            return false
        }
    }

    private var runningVirtualMachines: [UTMAppleVirtualMachine] {
        virtualMachines.allObjects.filter { $0.state == .started }
    }

    // MARK: - Ownership

    /// Virtual machine that holds the device
    /// - Parameter device: USB device
    /// - Returns: The virtual machine or nil if the device is not connected to any
    func owner(of device: UTMAppleUSBDevice) -> UTMAppleVirtualMachine? {
        owners[device.registryID]?.vm
    }

    /// Record that a virtual machine connected or disconnected a device
    /// - Parameters:
    ///   - vm: Virtual machine or nil when the device is disconnected
    ///   - device: USB device
    func setOwner(_ vm: UTMAppleVirtualMachine?, of device: UTMAppleUSBDevice) {
        if let vm = vm {
            owners[device.registryID] = WeakVM(vm: vm)
        } else {
            owners.removeValue(forKey: device.registryID)
        }
    }

    // MARK: - Claims

    /// Reserve the next reported device matching an identity for a virtual machine
    ///
    /// The device is reported again by the system shortly after it is disconnected from a guest,
    /// so this is how a device is moved between virtual machines and how devices are found after
    /// a saved state is restored.
    /// - Parameters:
    ///   - saved: Identity of the device
    ///   - vm: Virtual machine that will connect the device
    ///   - timeout: How long to wait for the device
    /// - Returns: A task that completes with the device
    func claim(_ saved: UTMRegistryEntry.USBDevice, for vm: UTMAppleVirtualMachine, timeout: Duration) -> Task<UTMAppleUSBDevice, any Error> {
        let claim = Claim(saved: saved, vm: vm)
        claims.append(claim)
        return Task { @MainActor in
            if let result = claim.result {
                return result
            }
            if let device = device(matching: saved) {
                claims.removeAll { $0 === claim }
                return device
            }
            return try await withCheckedThrowingContinuation { continuation in
                claim.continuation = continuation
                Task { @MainActor in
                    try? await Task.sleep(for: timeout)
                    guard claims.contains(where: { $0 === claim }) else {
                        return
                    }
                    claims.removeAll { $0 === claim }
                    claim.continuation?.resume(throwing: UTMAppleVirtualMachineError.usbDeviceNotFound(saved.name))
                    claim.continuation = nil
                }
            }
        }
    }

    /// Mark a device the user disconnected so it is not connected again when the system reports it
    /// - Parameter device: USB device
    func release(_ device: UTMAppleUSBDevice) {
        released.append(device.registryDevice)
    }

    /// Forget a release mark because the user connected the device again
    /// - Parameter device: USB device
    func unrelease(_ device: UTMAppleUSBDevice) {
        released.removeAll { device.matches($0) }
    }

    // MARK: - Device events

    private func deviceDidConnect(_ accessory: AAUSBAccessory) {
        guard !devices.contains(where: { $0.registryID == accessory.registryID }) else {
            return
        }
        let device = UTMAppleUSBDevice(accessory: accessory)
        devices.append(device)
        logger.debug("USB device reported by system: \(device.name)")
        if let index = claims.firstIndex(where: { device.matches($0.saved) }) {
            let claim = claims.remove(at: index)
            claim.result = device
            claim.continuation?.resume(returning: device)
            claim.continuation = nil
            return
        }
        if let index = released.firstIndex(where: { device.matches($0) }) {
            released.remove(at: index)
            return
        }
        let running = runningVirtualMachines
        let target: UTMAppleVirtualMachine?
        if running.count == 1 {
            target = running[0]
        } else {
            target = running.first { $0.isUsbPassthroughFrontmost }
        }
        if let target = target {
            Task {
                await target.autoConnectUsbDevice(device)
            }
        }
    }

    private func deviceDidDisconnect(_ accessory: AAUSBAccessory) {
        guard let index = devices.firstIndex(where: { $0.registryID == accessory.registryID }) else {
            return
        }
        let device = devices.remove(at: index)
        let owner = owner(of: device)
        owners.removeValue(forKey: device.registryID)
        logger.debug("USB device removed by system: \(device.name)")
        owner?.usbHostDeviceDidDisconnect(device)
    }
}

@available(macOS 27, *)
extension UTMAppleUSBManager: AAUSBAccessoryListener {
    nonisolated func usbAccessoryDidConnect(_ usbAccessory: AAUSBAccessory) {
        Task { @MainActor in
            deviceDidConnect(usbAccessory)
        }
    }

    nonisolated func usbAccessoryDidDisconnect(_ usbAccessory: AAUSBAccessory) {
        Task { @MainActor in
            deviceDidDisconnect(usbAccessory)
        }
    }
}

// MARK: - Per virtual machine passthrough state

/// Receives USB passthrough events for a single virtual machine
@available(macOS 27, *)
@MainActor protocol UTMAppleUSBPassthroughDelegate: AnyObject {
    /// Is a window of this virtual machine the main window? Newly assigned devices go to that virtual machine.
    ///
    /// The main window is used rather than the key window because the system menu bar item the user
    /// assigns devices from takes key status away from the app.
    func usbPassthroughIsFrontmost(_ vm: UTMAppleVirtualMachine) -> Bool

    /// A USB device connected to this virtual machine was disconnected by the system (for example, it was unplugged)
    func usbPassthrough(_ vm: UTMAppleVirtualMachine, deviceDidDisconnect device: UTMAppleUSBDevice)

    /// An automatic connection attempt failed
    func usbPassthrough(_ vm: UTMAppleVirtualMachine, device: UTMAppleUSBDevice, didFailWithError error: any Error)
}

/// USB passthrough state of a single virtual machine.
///
/// This is stored as `Any?` in `UTMAppleVirtualMachine` since it references macOS 27 types.
@available(macOS 27, *)
@MainActor final class UTMAppleUSBPassthroughState {
    struct Connection {
        let device: UTMAppleUSBDevice
        let vzDevice: VZUSBPassthroughDevice
    }

    /// Devices attached to the guest, by registry ID
    var connections: [UInt64: Connection] = [:]

    /// Devices added to the configuration before restoring a saved state, by device UUID
    var pendingRestore: [UUID: UTMAppleUSBDevice] = [:]

    /// Retained here since `VZUSBController.delegate` is weak
    let controllerDelegate: UTMAppleUSBControllerDelegate

    weak var delegate: (any UTMAppleUSBPassthroughDelegate)?

    init(vm: UTMAppleVirtualMachine) {
        controllerDelegate = UTMAppleUSBControllerDelegate(vm: vm)
    }
}

/// Forwards `VZUSBController` events to the virtual machine.
///
/// `UTMAppleVirtualMachine` implements `NSObjectProtocol` by hand for `VZVirtualMachineDelegate`
/// so this small object adopts the USB controller delegate instead.
@available(macOS 27, *)
final class UTMAppleUSBControllerDelegate: NSObject, VZUSBController.Delegate {
    private weak var vm: UTMAppleVirtualMachine?

    init(vm: UTMAppleVirtualMachine) {
        self.vm = vm
    }

    func usbController(_ usbController: VZUSBController, usbPassthroughDeviceDidDisconnect device: VZUSBPassthroughDevice) {
        let uuid = device.uuid
        Task { @MainActor in
            vm?.usbPassthroughDeviceDidDisconnect(uuid: uuid)
        }
    }
}
