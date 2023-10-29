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
    struct ID: Hashable, Codable {
        private var id = UUID()
    }

    struct WindowID: Hashable, Codable {
        private var id = UUID()
    }

    struct GlobalWindowID: Hashable, Codable {
        private(set) var sessionID: VMSessionState.ID
        private(set) var windowID: VMSessionState.WindowID
    }

    static private(set) var allActiveSessions: [ID: VMSessionState] = [:]

    let id: ID = ID()

    let vm: UTMQemuVirtualMachine
    
    var qemuConfig: UTMQemuConfiguration {
        vm.config
    }
    
    @Published var vmState: UTMVirtualMachineState = .stopped
    
    @Published var fatalError: String?
    
    @Published var nonfatalError: String?
    
    @Published var primaryInput: CSInput?
    
    #if WITH_USB
    private var primaryUsbManager: CSUSBManager?
    
    private var usbManagerQueue = DispatchQueue(label: "USB Manager Queue", qos: .utility)
    
    @Published var mostRecentConnectedDevice: CSUSBDevice?
    
    @Published var allUsbDevices: [CSUSBDevice] = []
    
    @Published var connectedUsbDevices: [CSUSBDevice] = []
    #endif
    
    @Published var isUsbBusy: Bool = false
    
    @Published var devices: [VMWindowState.Device] = []
    
    @Published var windows: [GlobalWindowID] = []

    @Published var primaryWindow: WindowID?

    @Published var activeWindow: WindowID?

    @Published var windowDeviceMap: [WindowID: VMWindowState.Device] = [:]

    @Published var externalWindowBinding: Binding<VMWindowState>?
    
    @Published var hasShownMemoryWarning: Bool = false
    
    private var hasAutosave: Bool = false

    init(for vm: UTMQemuVirtualMachine) {
        self.vm = vm
        super.init()
        vm.delegate = self
        vm.ioServiceDelegate = self
    }

    func newWindow() -> GlobalWindowID {
        GlobalWindowID(sessionID: id, windowID: WindowID())
    }

    func registerWindow(_ window: WindowID, isExternal: Bool = false) {
        let globalWindow = GlobalWindowID(sessionID: id, windowID: window)
        windows.append(globalWindow)
        if !isExternal, primaryWindow == nil {
            primaryWindow = window
        }
        if !isExternal, activeWindow == nil {
            activeWindow = window
        }
        assignDefaultDisplay(for: window, isExternal: isExternal)
    }
    
    func removeWindow(_ window: WindowID) {
        let globalWindow = GlobalWindowID(sessionID: id, windowID: window)
        windows.removeAll { $0 == globalWindow }
        if primaryWindow == window {
            primaryWindow = windows.first?.windowID
        }
        if activeWindow == window {
            activeWindow = windows.first?.windowID
        }
        windowDeviceMap.removeValue(forKey: window)
    }
    
    private func assignDefaultDisplay(for window: WindowID, isExternal: Bool) {
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
    nonisolated func virtualMachine(_ vm: any UTMVirtualMachine, didTransitionToState state: UTMVirtualMachineState) {
        Task { @MainActor in
            vmState = state
            if state == .stopped {
                #if WITH_USB
                clearDevices()
                #endif
            }
        }
    }
    
    nonisolated func virtualMachine(_ vm: any UTMVirtualMachine, didErrorWithMessage message: String) {
        Task { @MainActor in
            fatalError = message
        }
    }
    
    nonisolated func virtualMachine(_ vm: any UTMVirtualMachine, didCompleteInstallation success: Bool) {
        
    }
    
    nonisolated func virtualMachine(_ vm: any UTMVirtualMachine, didUpdateInstallationProgress progress: Double) {
        
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
            for window in windows {
                let windowId = window.windowID
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
            for window in windows {
                let windowId = window.windowID
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
            for window in windows {
                let windowId = window.windowID
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
            for window in windows {
                let windowId = window.windowID
                if windowDeviceMap[windowId] == device {
                    windowDeviceMap[windowId] = nil
                }
            }
        }
    }
    
    #if WITH_USB
    nonisolated func spiceDidChangeUsbManager(_ usbManager: CSUSBManager?) {
        Task { @MainActor in
            primaryUsbManager?.delegate = nil
            primaryUsbManager = usbManager
            usbManager?.delegate = self
            refreshDevices()
        }
    }
    #endif
}

#if WITH_USB
extension VMSessionState: CSUSBManagerDelegate {
    nonisolated func spiceUsbManager(_ usbManager: CSUSBManager, deviceError error: String, for device: CSUSBDevice) {
        Task { @MainActor in
            nonfatalError = error
            refreshDevices()
        }
    }
    
    nonisolated func spiceUsbManager(_ usbManager: CSUSBManager, deviceAttached device: CSUSBDevice) {
        Task { @MainActor in
            if vmState == .started {
                mostRecentConnectedDevice = device
            }
            allUsbDevices.append(device)
        }
    }
    
    nonisolated func spiceUsbManager(_ usbManager: CSUSBManager, deviceRemoved device: CSUSBDevice) {
        Task { @MainActor in
            connectedUsbDevices.removeAll(where: { $0 == device })
            allUsbDevices.removeAll(where: { $0 == device })
        }
    }
    
    private func withUsbManagerSerialized<T>(_ task: @escaping () async throws -> T, onSuccess: @escaping @MainActor (T) -> Void = { _ in }, onError: @escaping @MainActor (Error) -> Void = { _ in }) {
        usbManagerQueue.async {
            let event = DispatchSemaphore(value: 0)
            Task.detached { [self] in
                await MainActor.run {
                    isUsbBusy = true
                }
                do {
                    let result = try await task()
                    await MainActor.run {
                        isUsbBusy = false
                        onSuccess(result)
                    }
                } catch {
                    await MainActor.run {
                        isUsbBusy = false
                        onError(error)
                    }
                }
                event.signal()
            }
            event.wait()
        }
    }
    
    func refreshDevices() {
        guard let usbManager = self.primaryUsbManager else {
            logger.error("no usb manager connected")
            return
        }
        withUsbManagerSerialized {
            let devices = usbManager.usbDevices
            for device in devices {
                let name = device.name // cache descriptor read
                logger.debug("found device: \(name ?? "(unknown)")")
            }
            return devices
        } onSuccess: { devices in
            self.allUsbDevices = devices
        }
    }
    
    func connectDevice(_ usbDevice: CSUSBDevice) {
        guard let usbManager = self.primaryUsbManager else {
            logger.error("no usb manager connected")
            return
        }
        guard !connectedUsbDevices.contains(usbDevice) else {
            logger.warning("connecting a device that is already connected")
            return
        }
        withUsbManagerSerialized {
            try await usbManager.connectUsbDevice(usbDevice)
        } onSuccess: {
            self.connectedUsbDevices.append(usbDevice)
        } onError: { error in
            self.nonfatalError = error.localizedDescription
        }
    }
    
    func disconnectDevice(_ usbDevice: CSUSBDevice) {
        guard let usbManager = self.primaryUsbManager else {
            logger.error("no usb manager connected")
            return
        }
        guard usbManager.isUsbDeviceConnected(usbDevice) else {
            logger.warning("disconnecting a device that is not connected")
            return
        }
        withUsbManagerSerialized {
            self.connectedUsbDevices.removeAll(where: { $0 == usbDevice })
            try await usbManager.disconnectUsbDevice(usbDevice)
        } onError: { error in
            self.nonfatalError = error.localizedDescription
        }
    }
    
    private func clearDevices() {
        Task { @MainActor in
            connectedUsbDevices.removeAll()
            allUsbDevices.removeAll()
        }
    }
}
#endif

extension VMSessionState {
    func start(options: UTMVirtualMachineStartOptions = []) {
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
        Self.allActiveSessions[id] = self
        NotificationCenter.default.post(name: .vmSessionCreated, object: nil, userInfo: ["Session": self])
        vm.requestVmStart(options: options)
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
        Self.allActiveSessions.removeValue(forKey: id)
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
        Task {
            try? await vm.deleteSnapshot(name: nil)
            try await vm.stop(usingMethod: .force)
            self.stop()
        }
    }
    
    func pauseResume() {
        let shouldSaveState = !vm.isRunningAsDisposible
        if vm.state == .started {
            vm.requestVmPause(save: shouldSaveState)
        } else if vm.state == .paused {
            vm.requestVmResume()
        }
    }
    
    func reset() {
        vm.requestVmReset()
    }
    
    func didReceiveMemoryWarning() {
        let shouldAutosave = UserDefaults.standard.bool(forKey: "AutosaveLowMemory")
        
        if shouldAutosave {
            logger.info("Saving VM state on low memory warning.")
            Task {
                // ignore error
                try? await vm.saveSnapshot(name: nil)
            }
        }
    }
    
    func didEnterBackground() {
        logger.info("Entering background")
        let shouldAutosaveBackground = UserDefaults.standard.bool(forKey: "AutosaveBackground")
        if shouldAutosaveBackground && vmState == .started {
            logger.info("Saving snapshot")
            var task: UIBackgroundTaskIdentifier = .invalid
            task = UIApplication.shared.beginBackgroundTask {
                logger.info("Background task end")
                UIApplication.shared.endBackgroundTask(task)
                task = .invalid
            }
            Task {
                do {
                    try await vm.saveSnapshot()
                    self.hasAutosave = true
                    logger.info("Save snapshot complete")
                } catch {
                    logger.error("error saving snapshot: \(error)")
                }
                UIApplication.shared.endBackgroundTask(task)
                task = .invalid
            }
        }
    }
    
    func didEnterForeground() {
        logger.info("Entering foreground!")
        if (hasAutosave && vmState == .started) {
            logger.info("Deleting snapshot")
            vm.requestVmDeleteState()
        }
    }
}

extension Notification.Name {
    static let vmSessionCreated = Self("VMSessionCreated")
    static let vmSessionEnded = Self("VMSessionEnded")
}
