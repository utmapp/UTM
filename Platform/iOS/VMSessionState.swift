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
import AVFAudio
import SwiftUI

/// Represents the UI state for a single VM session.
@MainActor class VMSessionState: NSObject, ObservableObject {
    static private(set) var currentSession: VMSessionState?
    
    let vm: UTMQemuVirtualMachine
    
    var qemuConfig: UTMQemuConfiguration! {
        vm.config.qemuConfig
    }
    
    @Published var vmState: UTMVMState = .vmStopped
    
    @Published var fatalError: String?
    
    @Published var nonfatalError: String?
    
    @Published var primaryInput: CSInput?
    
    #if !WITH_QEMU_TCI
    private var primaryUsbManager: CSUSBManager?
    
    @Published var mostRecentConnectedDevice: CSUSBDevice?
    
    @Published var allUsbDevices: [CSUSBDevice] = []
    
    @Published var connectedUsbDevices: [CSUSBDevice] = []
    #endif
    
    @Published var isUsbBusy: Bool = false
    
    @Published var devices: [VMWindowState.Device] = []
    
    @Published var windows: [UUID] = []
    
    @Published var primaryWindow: UUID?
    
    @Published var activeWindow: UUID?
    
    @Published var windowDeviceMap: [UUID: VMWindowState.Device] = [:]
    
    @Published var externalWindowBinding: Binding<VMWindowState>?
    
    init(for vm: UTMQemuVirtualMachine) {
        self.vm = vm
        super.init()
        vm.delegate = self
        vm.ioDelegate = self
    }
    
    func registerWindow(_ window: UUID, isExternal: Bool = false) {
        windows.append(window)
        if !isExternal, primaryWindow == nil {
            primaryWindow = window
        }
        if !isExternal, activeWindow == nil {
            activeWindow = window
        }
        assignDefaultDisplay(for: window, isExternal: isExternal)
    }
    
    func removeWindow(_ window: UUID) {
        windows.removeAll { $0 == window }
        if primaryWindow == window {
            primaryWindow = windows.first
        }
        if activeWindow == window {
            activeWindow = windows.first
        }
        windowDeviceMap.removeValue(forKey: window)
    }
    
    private func assignDefaultDisplay(for window: UUID, isExternal: Bool) {
        // default first to next GUI, then to next serial
        let filtered = devices.filter {
            if case .display(_, _) = $0 {
                return true
            } else {
                return false
            }
        }
        for device in filtered {
            if !windowDeviceMap.values.contains(device) {
                windowDeviceMap[window] = device
                return
            }
        }
        if isExternal {
            return // no serial device for external display
        }
        for device in devices {
            if !windowDeviceMap.values.contains(device) {
                windowDeviceMap[window] = device
                return
            }
        }
    }
}

extension VMSessionState: UTMVirtualMachineDelegate {
    nonisolated func virtualMachine(_ vm: UTMVirtualMachine, didTransitionTo state: UTMVMState) {
        Task { @MainActor in
            vmState = state
            if state == .vmStopped {
                #if !WITH_QEMU_TCI
                clearDevices()
                #endif
            }
        }
    }
    
    nonisolated func virtualMachine(_ vm: UTMVirtualMachine, didErrorWithMessage message: String) {
        Task { @MainActor in
            fatalError = message
        }
    }
}

extension VMSessionState: UTMSpiceIODelegate {
    nonisolated func spiceDidCreateInput(_ input: CSInput) {
        Task { @MainActor in
            guard primaryInput == nil else {
                return
            }
            primaryInput = input
        }
    }
    
    nonisolated func spiceDidDestroyInput(_ input: CSInput) {
        Task { @MainActor in
            guard primaryInput == input else {
                return
            }
            primaryInput = nil
        }
    }
    
    nonisolated func spiceDidCreateDisplay(_ display: CSDisplay) {
        Task { @MainActor in
            assert(display.monitorID < qemuConfig.displays.count)
            let device = VMWindowState.Device.display(display, display.monitorID)
            devices.append(device)
            // associate with the next available window
            for windowId in windows {
                if windowDeviceMap[windowId] == nil {
                    if windowId == primaryWindow && !display.isPrimaryDisplay {
                        // prefer the primary display for the primary window
                        continue
                    }
                    if windowId != primaryWindow && display.isPrimaryDisplay {
                        // don't assign primary display to non-primary window either
                        continue
                    }
                    windowDeviceMap[windowId] = device
                }
            }
        }
    }
    
    nonisolated func spiceDidDestroyDisplay(_ display: CSDisplay) {
        Task { @MainActor in
            let device = VMWindowState.Device.display(display, display.monitorID)
            devices.removeAll { $0 == device }
            for windowId in windows {
                if windowDeviceMap[windowId] == device {
                    windowDeviceMap[windowId] = nil
                }
            }
        }
    }
    
    nonisolated func spiceDidUpdateDisplay(_ display: CSDisplay) {
        // nothing to do
    }
    
    nonisolated private func configIdForSerial(_ serial: CSPort) -> Int? {
        let prefix = "com.utmapp.terminal."
        guard serial.name?.hasPrefix(prefix) ?? false else {
            return nil
        }
        return Int(serial.name!.dropFirst(prefix.count))
    }
    
    nonisolated func spiceDidCreateSerial(_ serial: CSPort) {
        Task { @MainActor in
            guard let id = configIdForSerial(serial) else {
                logger.error("cannot setup window for serial '\(serial.name ?? "(null)")'")
                return
            }
            let device = VMWindowState.Device.serial(serial, id)
            assert(id < qemuConfig.serials.count)
            assert(qemuConfig.serials[id].mode == .builtin && qemuConfig.serials[id].terminal != nil)
            devices.append(device)
            // associate with the next available window
            for windowId in windows {
                if windowDeviceMap[windowId] == nil {
                    if windowId == primaryWindow && !qemuConfig.displays.isEmpty {
                        // prefer a GUI display over console for primary if both are available
                        continue
                    }
                    if windowId == externalWindowBinding?.wrappedValue.id {
                        // do not set serial with external display
                        continue
                    }
                    windowDeviceMap[windowId] = device
                }
            }
        }
    }
    
    nonisolated func spiceDidDestroySerial(_ serial: CSPort) {
        Task { @MainActor in
            guard let id = configIdForSerial(serial) else {
                return
            }
            let device = VMWindowState.Device.serial(serial, id)
            devices.removeAll { $0 == device }
            for windowId in windows {
                if windowDeviceMap[windowId] == device {
                    windowDeviceMap[windowId] = nil
                }
            }
        }
    }
    
    #if !WITH_QEMU_TCI
    nonisolated func spiceDidChangeUsbManager(_ usbManager: CSUSBManager?) {
        Task { @MainActor in
            primaryUsbManager?.delegate = nil
            primaryUsbManager = usbManager
            usbManager?.delegate = self
        }
    }
    #endif
}

#if !WITH_QEMU_TCI
extension VMSessionState: CSUSBManagerDelegate {
    nonisolated func spiceUsbManager(_ usbManager: CSUSBManager, deviceError error: String, for device: CSUSBDevice) {
        Task { @MainActor in
            nonfatalError = error
        }
    }
    
    nonisolated func spiceUsbManager(_ usbManager: CSUSBManager, deviceAttached device: CSUSBDevice) {
        Task { @MainActor in
            mostRecentConnectedDevice = device
        }
    }
    
    nonisolated func spiceUsbManager(_ usbManager: CSUSBManager, deviceRemoved device: CSUSBDevice) {
        Task { @MainActor in
            disconnectDevice(device)
        }
    }
    
    func refreshDevices() {
        guard let usbManager = self.primaryUsbManager else {
            logger.error("no usb manager connected")
            return
        }
        isUsbBusy = true
        Task.detached { [self] in
            let devices = usbManager.usbDevices
            await MainActor.run {
                allUsbDevices = devices
                isUsbBusy = false
            }
        }
    }
    
    func connectDevice(_ usbDevice: CSUSBDevice) {
        guard let usbManager = self.primaryUsbManager else {
            logger.error("no usb manager connected")
            return
        }
        isUsbBusy = true
        Task.detached { [self] in
            let (success, message) = await usbManager.connectUsbDevice(usbDevice)
            await MainActor.run {
                if success {
                    self.connectedUsbDevices.append(usbDevice)
                } else {
                    nonfatalError = message
                }
                isUsbBusy = false
            }
        }
    }
    
    func disconnectDevice(_ usbDevice: CSUSBDevice) {
        guard let usbManager = self.primaryUsbManager else {
            logger.error("no usb manager connected")
            return
        }
        isUsbBusy = true
        Task.detached { [self] in
            await usbManager.disconnectUsbDevice(usbDevice)
            await MainActor.run {
                connectedUsbDevices.removeAll(where: { $0 == usbDevice })
                isUsbBusy = false
            }
        }
    }
    
    private func clearDevices() {
        connectedUsbDevices.removeAll()
        allUsbDevices.removeAll()
    }
}
#endif

extension VMSessionState {
    func start() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            let preferDeviceMicrophone = UserDefaults.standard.bool(forKey: "PreferDeviceMicrophone")
            var options: AVAudioSession.CategoryOptions = [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP, .allowAirPlay]
            if !preferDeviceMicrophone {
                options.insert(.allowBluetooth)
            }
            try audioSession.setCategory(.playAndRecord, options: options)
            try audioSession.setActive(true)
        } catch {
            logger.warning("Error starting audio session: \(error.localizedDescription)")
        }
        Self.currentSession = self
        NotificationCenter.default.post(name: .vmSessionCreated, object: nil, userInfo: ["Session": self])
        vm.requestVmStart()
    }
    
    @objc private func suspend() {
        // dummy function for selector
    }
    
    func stop() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false)
        } catch {
            logger.warning("Error stopping audio session: \(error.localizedDescription)")
        }
        // tell other screens to shut down
        Self.currentSession = nil
        NotificationCenter.default.post(name: .vmSessionEnded, object: nil, userInfo: ["Session": self])
        // animate to home screen
        let app = UIApplication.shared
        app.performSelector(onMainThread: #selector(suspend), with: nil, waitUntilDone: true)
        
        // wait 2 seconds while app is going background
        Thread.sleep(forTimeInterval: 2)
        
        // exit app when app is in background
        exit(0)
    }
    
    func powerDown() {
        vm.requestVmDeleteState()
        vm.vmStop { _ in
            Task { @MainActor in
                self.stop()
            }
        }
    }
    
    func pauseResume() {
        let shouldSaveState = !vm.isRunningAsSnapshot
        if vm.state == .vmStarted {
            vm.requestVmPause(save: shouldSaveState)
        } else if vm.state == .vmPaused {
            vm.requestVmResume()
        }
    }
    
    func reset() {
        vm.requestVmReset()
    }
}

extension Notification.Name {
    static let vmSessionCreated = Self("VMSessionCreated")
    static let vmSessionEnded = Self("VMSessionEnded")
}
