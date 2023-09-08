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

class UTMSpiceIO: NSObject, CSConnectionDelegate, QEMUInterface {
    public let UTMErrorDomain: String = "com.utmapp.utm"
    var connectDelegate: QEMUInterfaceConnectDelegate?
    
    var logHandler: LogHandler_t {
        CSMain.shared.logHandler!
    }
    
    var socketUrl: URL
    var options: UTMSpiceIOOptions
    var primaryDisplay: CSDisplay?
    var primaryInput: CSInput?
    var primarySerial: CSPort?
    var displays: [CSDisplay]
    var serials: [CSPort]
    #if !WITH_QEMU_TCI
    var primaryUsbManager: CSUSBManager?
    #endif
    var delegate: UTMSpiceIODelegate?
    var spiceConnection: CSConnection?
    var spice: CSMain?
    var sharedDirectory: URL?
    var port: Int
    var dynamicResolutionSupported: Bool
    var isConnected: Bool
    
    public init(socketUrl: URL, options: UTMSpiceIOOptions) {
        super.init()
        self.socketUrl = socketUrl
        self.options = options
        self.displays = []
        self.serials = []
    }
    
    public func initializeSpiceIfNeeded() {
        if spiceConnection == nil {
            var relativeSocketFile = URL(fileURLWithPath: socketUrl.lastPathComponent)
            spiceConnection = CSConnection(unixSocketFile: relativeSocketFile)
            spiceConnection!.delegate = self
            spiceConnection!.audioEnabled = (options.rawValue & UTMSpiceIOOptions.UTMSpiceIOOptionsHasAudio.rawValue) == UTMSpiceIOOptions.UTMSpiceIOOptionsHasAudio.rawValue
            spiceConnection!.session.shareClipboard = (options.rawValue & UTMSpiceIOOptions.UTMSpiceIOOptionsHasClipboardSharing.rawValue) == UTMSpiceIOOptions.UTMSpiceIOOptionsHasClipboardSharing.rawValue
            spiceConnection!.session.pasteboardDelegate = UTMPasteboard.general
        }
    }
    
    public func changeSharedDirectory(url: URL) {
        if sharedDirectory != nil {
            endSharingDirectory()
        }
        sharedDirectory = url
        startSharingDirectory()
    }
    
    public func startSharingDirectory() {
        if sharedDirectory != nil {
            UTMLog("Setting share directory to %@", sharedDirectory!.path);
            _ = sharedDirectory!.startAccessingSecurityScopedResource()
            spiceConnection!.session.setSharedDirectory(sharedDirectory!.path, readOnly: (options.rawValue & UTMSpiceIOOptions.UTMSpiceIOOptionsIsShareReadOnly.rawValue) == UTMSpiceIOOptions.UTMSpiceIOOptionsIsShareReadOnly.rawValue)
        }
    }
    
    public func endSharingDirectory() {
        if sharedDirectory != nil {
            sharedDirectory!.stopAccessingSecurityScopedResource()
            sharedDirectory = nil
        }
    }
    
    public func setLogHandler(logHandler: @escaping LogHandler_t) {
        CSMain.shared.logHandler = logHandler
    }
    
    public func start() throws {
        if spice == nil {
            spice = CSMain.shared
        }
        if (options.rawValue & UTMSpiceIOOptions.UTMSpiceIOOptionsHasDebugLog.rawValue) == UTMSpiceIOOptions.UTMSpiceIOOptionsHasDebugLog.rawValue {
            spice?.spiceSetDebug(true)
        }
        // TODO: Figure this out in Swift
        // g_setenv("SPICE_DISABLE_OPUS", "1", true)
        var curdir = socketUrl.deletingLastPathComponent().path
        if !FileManager.default.changeCurrentDirectoryPath(curdir) {
            throw NSError(domain: UTMErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Failed to change current directory.", comment: "UTMSpiceIO")])
        }
        if !spice!.spiceStart() {
            throw NSError(domain: UTMErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Failed to start SPICE client.", comment: "UTMSpiceIO")])
        }
        self.initializeSpiceIfNeeded()
    }
    
    public func connect() throws {
        if !spiceConnection!.connect() {
            throw NSError(domain: UTMErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Internal error trying to connect to SPICE server.", comment: "UTMSpiceIO")])
        }
    }
    
    public func disconnect() {
        endSharingDirectory()
        spiceConnection!.disconnect()
        spiceConnection!.delegate = nil
        spiceConnection = nil
        spice = nil
        primaryDisplay = nil
        displays.removeAll()
        primaryInput = nil
        primarySerial = nil
        serials.removeAll()
        #if !WITH_QEMU_TCI
        primaryUsbManager = nil
        #endif
    }
    
    public func screenshotWithCompletion(completion: @escaping screenshotCallback_t) {
        return primaryDisplay!.screenshot(completion: completion)
    }
    
    func spiceConnected(_ connection: CSConnection) {
        isConnected = true
        #if !WITH_QEMU_TCI
        primaryUsbManager = connection.usbManager
        delegate!.spiceDidChangeUsbManager(connection.usbManager)
        #endif
    }
    
    func spiceInputAvailable(_ connection: CSConnection, input: CSInput) {
        if primaryInput == nil {
            primaryInput = input
            delegate!.spiceDidCreateInput(input)
        }
    }
    
    func spiceInputUnavailable(_ connection: CSConnection, input: CSInput) {
        if primaryInput == input {
            primaryInput = nil
            delegate!.spiceDidDestroyInput(input)
        }
    }
    
    func spiceDisconnected(_ connection: CSConnection) {
        isConnected = false
    }
    
    func spiceError(_ connection: CSConnection, code: CSConnectionError, message: String?) {
        isConnected = false
        connectDelegate!.qemuInterface(self, didErrorWithMessage: message ?? "")
    }
    
    func spiceDisplayCreated(_ connection: CSConnection, display: CSDisplay) {
        if display.isPrimaryDisplay {
            primaryDisplay = display
        }
        displays.append(display)
        delegate!.spiceDidCreateDisplay(display)
    }
    
    func spiceDisplayUpdated(_ connection: CSConnection, display: CSDisplay) {
        if connection == spiceConnection {
            delegate!.spiceDidUpdateDisplay(display)
        }
    }
    
    func spiceDisplayDestroyed(_ connection: CSConnection, display: CSDisplay) {
        if connection == spiceConnection {
            displays.removeAll(where: { $0 == display })
            delegate!.spiceDidDestroyDisplay(display)
        }
    }
    
    func spiceAgentConnected(_ connection: CSConnection, supportingFeatures features: CSConnectionAgentFeature) {
        dynamicResolutionSupported = (features.rawValue & CSConnectionAgentFeature.monitorsConfig.rawValue) != 0
    }
    
    func spiceAgentDisconnected(_ connection: CSConnection) {
        dynamicResolutionSupported = false
    }
    
    func spiceForwardedPortOpened(_ connection: CSConnection, port: CSPort) {
        if port.name == "org.qemu.monitor.qmp.0" {
            var qemuPort = UTMQemuPort(from: port)
            connectDelegate!.qemuInterface(self, didCreateMonitorPort: qemuPort)
        }
        if port.name == "org.qemu.guest_agent.0" {
            var qemuPort = UTMQemuPort(from: port)
            connectDelegate!.qemuInterface(self, didCreateGuestAgentPort: qemuPort)
        }
        if port.name == "com.utmapp.terminal.0" {
            primarySerial = port
        }
        if (port.name ?? "").hasPrefix("com.utmapp.terminal.") {
            serials.append(port)
            delegate!.spiceDidCreateSerial(port)
        }
    }
    
    func spiceForwardedPortClosed(_ connection: CSConnection, port: CSPort) {
        if port.name == "org.qemu.monitor.qmp.0" {
        }
        if port.name == "org.qemu.guest_agent.0" {
        }
        if port.name == "com.utmapp.terminal.0" {
            primarySerial = nil
        }
        if (port.name ?? "").hasPrefix("com.utmapp.terminal.") {
            serials.removeAll(where: { $0 == port })
            delegate!.spiceDidDestroySerial(port)
        }
    }
    
    public func setDelegate(delegate: UTMSpiceIODelegate) {
        self.delegate = delegate
        if let input = primaryInput {
            self.delegate!.spiceDidCreateInput(input)
        }
        if let display = primaryDisplay {
            self.delegate!.spiceDidCreateDisplay(display)
        }
        if let serial = primarySerial {
            self.delegate!.spiceDidCreateSerial(serial)
        }
        #if !WITH_QEMU_TCI
        if let manager = primaryUsbManager {
            self.delegate!.spiceDidChangeUsbManager(manager)
        }
        #endif
        if self.delegate!.responds(to: #selector(UTMSpiceIODelegate.spiceDynamicResolutionSupportDidChange(_:))) {
            self.delegate!.spiceDynamicResolutionSupportDidChange!(dynamicResolutionSupported)
        }
        for display in displays {
            if display != primaryDisplay {
                self.delegate!.spiceDidCreateDisplay(display)
            }
        }
        for port in serials {
            if port != primarySerial {
                self.delegate!.spiceDidCreateSerial(port)
            }
        }
    }
    
    public func setDynamicResolutionSupported(_ dynamicResolutionSupported: Bool) {
        if self.dynamicResolutionSupported != dynamicResolutionSupported {
            if self.delegate!.responds(to: #selector(UTMSpiceIODelegate.spiceDynamicResolutionSupportDidChange(_:))) {
                self.delegate!.spiceDynamicResolutionSupportDidChange!(dynamicResolutionSupported)
            }
        }
        self.dynamicResolutionSupported = dynamicResolutionSupported
    }
}

enum UTMSpiceIOOptions: Int {
    case UTMSpiceIOOptionsNone = 0
    case UTMSpiceIOOptionsHasAudio = 1
    case UTMSpiceIOOptionsHasClipboardSharing = 10
    case UTMSpiceIOOptionsIsShareReadOnly = 100
    case UTMSpiceIOOptionsHasDebugLog = 1000
}
