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

class VMDisplayQemuWindowController: VMDisplayWindowController {
    private(set) var id: Int = 0
    private weak var vmUsbManager: CSUSBManager?
    private var allUsbDevices: [CSUSBDevice] = []
    private var connectedUsbDevices: [CSUSBDevice] = []
    @Setting("NoUsbPrompt") private var isNoUsbPrompt: Bool = false
    
    var qemuVM: UTMQemuVirtualMachine! {
        vm as? UTMQemuVirtualMachine
    }
    
    var vmQemuConfig: UTMQemuConfiguration! {
        vm?.config.qemuConfig
    }
    
    var defaultTitle: String {
        vmQemuConfig.information.name
    }
    
    var defaultSubtitle: String {
        if qemuVM.isRunningAsSnapshot {
            return NSLocalizedString("Disposable Mode", comment: "VMDisplayQemuDisplayController")
        } else {
            return ""
        }
    }
    
    convenience init(vm: UTMQemuVirtualMachine, id: Int) {
        self.init(vm: vm, onClose: nil)
        self.id = id
    }
    
    override var shouldSaveOnPause: Bool {
        !qemuVM.isRunningAsSnapshot
    }
    
    override func enterLive() {
        if !isSecondary {
            qemuVM.ioDelegate = self
        }
        startPauseToolbarItem.isEnabled = true
        #if arch(x86_64)
        if vmQemuConfig.qemu.hasHypervisor {
            // currently x86_64 HVF doesn't support suspending
            startPauseToolbarItem.isEnabled = false
        }
        #endif
        drivesToolbarItem.isEnabled = vmQemuConfig.drives.count > 0
        sharedFolderToolbarItem.isEnabled = vmQemuConfig.sharing.directoryShareMode == .webdav // virtfs cannot dynamically change
        usbToolbarItem.isEnabled = qemuVM.hasUsbRedirection
        window!.title = defaultTitle
        window!.subtitle = defaultSubtitle
        super.enterLive()
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if vm.state == .vmStopped {
            connectedUsbDevices.removeAll()
            allUsbDevices.removeAll()
            if isSecondary {
                close()
            }
        }
        super.enterSuspended(isBusy: busy)
    }
}

// MARK: - Removable drives

@objc extension VMDisplayQemuWindowController {
    @IBAction override func drivesButtonPressed(_ sender: Any) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let item = NSMenuItem()
        item.title = NSLocalizedString("Querying drives status...", comment: "VMDisplayWindowController")
        item.isEnabled = false
        menu.addItem(item)
        updateDrivesMenu(menu, drives: vmQemuConfig.drives)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @nonobjc func updateDrivesMenu(_ menu: NSMenu, drives: [UTMQemuConfigurationDrive]) {
        menu.removeAllItems()
        if drives.count == 0 {
            let item = NSMenuItem()
            item.title = NSLocalizedString("No drives connected.", comment: "VMDisplayWindowController")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let item = NSMenuItem()
            item.title = NSLocalizedString("Install Windows Guest Tools…", comment: "VMDisplayWindowController")
            item.isEnabled = !qemuVM.isGuestToolsInstallRequested
            item.target = self
            item.action = #selector(installWindowsGuestTools)
            menu.addItem(item)
        }
        for i in drives.indices {
            let drive = drives[i]
            if drive.imageType != .disk && drive.imageType != .cd && !drive.isExternal {
                continue // skip non-disks
            }
            let item = NSMenuItem()
            item.title = label(for: drive)
            if !drive.isExternal {
                item.isEnabled = false
            } else {
                let submenu = NSMenu()
                submenu.autoenablesItems = false
                let eject = NSMenuItem(title: NSLocalizedString("Eject", comment: "VMDisplayWindowController"),
                                       action: #selector(ejectDrive),
                                       keyEquivalent: "")
                eject.target = self
                eject.tag = i
                eject.isEnabled = qemuVM.externalImageURL(for: drive) != nil
                submenu.addItem(eject)
                let change = NSMenuItem(title: NSLocalizedString("Change", comment: "VMDisplayWindowController"),
                                        action: #selector(changeDriveImage),
                                        keyEquivalent: "")
                change.target = self
                change.tag = i
                change.isEnabled = true
                submenu.addItem(change)
                item.submenu = submenu
            }
            menu.addItem(item)
        }
        menu.update()
    }
    
    func ejectDrive(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for ejectDrive")
            return
        }
        let drive = vmQemuConfig.drives[menu.tag]
        Task.detached(priority: .background) { [self] in
            do {
                try await qemuVM.eject(drive)
            } catch {
                Task { @MainActor in
                    showErrorAlert(error.localizedDescription)
                }
            }
        }
    }
    
    func openDriveImage(forDriveIndex index: Int) {
        let drive = vmQemuConfig.drives[index]
        let openPanel = NSOpenPanel()
        openPanel.title = NSLocalizedString("Select Drive Image", comment: "VMDisplayWindowController")
        openPanel.allowedContentTypes = [.data]
        openPanel.beginSheetModal(for: window!) { response in
            guard response == .OK else {
                return
            }
            guard let url = openPanel.url else {
                logger.debug("no file selected")
                return
            }
            Task.detached(priority: .background) { [self] in
                do {
                    try await qemuVM.changeMedium(drive, to: url)
                } catch {
                    Task { @MainActor in
                        showErrorAlert(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    func changeDriveImage(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for ejectDrive")
            return
        }
        openDriveImage(forDriveIndex: menu.tag)
    }
    
    @nonobjc private func label(for drive: UTMQemuConfigurationDrive) -> String {
        let imageURL = qemuVM.externalImageURL(for: drive) ?? drive.imageURL
        return String.localizedStringWithFormat(NSLocalizedString("%@ (%@): %@", comment: "VMDisplayQemuDisplayController"),
                                                drive.imageType.prettyValue,
                                                drive.interface.prettyValue,
                                                imageURL?.lastPathComponent ?? NSLocalizedString("none", comment: "VMDisplayQemuDisplayController"))
    }
    
    @MainActor private func installWindowsGuestTools(sender: AnyObject) {
        qemuVM.isGuestToolsInstallRequested = true
    }
}

// MARK: - Shared folders

extension VMDisplayQemuWindowController {
    @IBAction override func sharedFolderButtonPressed(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.title = NSLocalizedString("Select Shared Folder", comment: "VMDisplayWindowController")
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.beginSheetModal(for: window!) { response in
            guard response == .OK else {
                return
            }
            guard let url = openPanel.url else {
                logger.debug("no directory selected")
                return
            }
            Task.detached(priority: .background) { [self] in
                do {
                    try await self.qemuVM.changeSharedDirectory(to: url)
                } catch {
                    Task { @MainActor in
                        self.showErrorAlert(error.localizedDescription)
                    }
                }
            }
        }
    }
}

// MARK: - SPICE base implementation

extension VMDisplayQemuWindowController: UTMSpiceIODelegate {
    private func configIdForSerial(_ serial: CSPort) -> Int? {
        let prefix = "com.utmapp.terminal."
        guard serial.name?.hasPrefix(prefix) ?? false else {
            return nil
        }
        return Int(serial.name!.dropFirst(prefix.count))
    }
    
    func spiceDidCreateInput(_ input: CSInput) {
        for subwindow in secondaryWindows {
            (subwindow as! VMDisplayQemuWindowController).spiceDidCreateInput(input)
        }
    }
    
    func spiceDidDestroyInput(_ input: CSInput) {
        for subwindow in secondaryWindows {
            (subwindow as! VMDisplayQemuWindowController).spiceDidDestroyInput(input)
        }
    }
    
    func spiceDidCreateDisplay(_ display: CSDisplay) {
        guard !isSecondary else {
            return
        }
        Task { @MainActor in
            findWindow(for: display)
        }
    }
    
    func spiceDidUpdateDisplay(_ display: CSDisplay) {
        for subwindow in secondaryWindows {
            (subwindow as! VMDisplayQemuWindowController).spiceDidUpdateDisplay(display)
        }
    }
    
    func spiceDidDestroyDisplay(_ display: CSDisplay) {
        for subwindow in secondaryWindows {
            (subwindow as! VMDisplayQemuWindowController).spiceDidDestroyDisplay(display)
        }
    }
    
    func spiceDidChangeUsbManager(_ usbManager: CSUSBManager?) {
        if usbManager != vmUsbManager {
            connectedUsbDevices.removeAll()
            allUsbDevices.removeAll()
            vmUsbManager = usbManager
            if let usbManager = usbManager {
                usbManager.delegate = self
            }
        }
        for subwindow in secondaryWindows {
            (subwindow as! VMDisplayQemuWindowController).spiceDidChangeUsbManager(usbManager)
        }
    }
    
    func spiceDynamicResolutionSupportDidChange(_ supported: Bool) {
        for subwindow in secondaryWindows {
            (subwindow as! VMDisplayQemuWindowController).spiceDynamicResolutionSupportDidChange(supported)
        }
    }
    
    func spiceDidCreateSerial(_ serial: CSPort) {
        guard !isSecondary else {
            return
        }
        Task { @MainActor in
            findWindow(for: serial)
        }
    }
    
    func spiceDidDestroySerial(_ serial: CSPort) {
        for subwindow in secondaryWindows {
            (subwindow as! VMDisplayQemuWindowController).spiceDidDestroySerial(serial)
        }
    }
}

// MARK: - USB handling

extension VMDisplayQemuWindowController: CSUSBManagerDelegate {
    func spiceUsbManager(_ usbManager: CSUSBManager, deviceError error: String, for device: CSUSBDevice) {
        logger.debug("USB device error: (\(device)) \(error)")
        DispatchQueue.main.async {
            self.showErrorAlert(error)
        }
    }
    
    func spiceUsbManager(_ usbManager: CSUSBManager, deviceAttached device: CSUSBDevice) {
        logger.debug("USB device attached: \(device)")
        if !isNoUsbPrompt {
            DispatchQueue.main.async {
                if self.window!.isKeyWindow && self.vm.state == .vmStarted {
                    self.showConnectPrompt(for: device)
                }
            }
        }
    }
    
    func spiceUsbManager(_ usbManager: CSUSBManager, deviceRemoved device: CSUSBDevice) {
        logger.debug("USB device removed: \(device)")
        if let i = connectedUsbDevices.firstIndex(of: device) {
            connectedUsbDevices.remove(at: i)
        }
    }
    
    func showConnectPrompt(for usbDevice: CSUSBDevice) {
        guard let usbManager = vmUsbManager else {
            logger.error("cannot get usb manager")
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("USB Device", comment: "VMQemuDisplayMetalWindowController")
        alert.informativeText = String.localizedStringWithFormat(NSLocalizedString("Would you like to connect '%@' to this virtual machine?", comment: "VMQemuDisplayMetalWindowController"), usbDevice.name ?? usbDevice.description)
        alert.showsSuppressionButton = true
        alert.addButton(withTitle: NSLocalizedString("Confirm", comment: "VMQemuDisplayMetalWindowController"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "VMQemuDisplayMetalWindowController"))
        alert.beginSheetModal(for: window!) { response in
            if let suppressionButton = alert.suppressionButton,
               suppressionButton.state == .on {
                self.isNoUsbPrompt = true
            }
            guard response == .alertFirstButtonReturn else {
                return
            }
            DispatchQueue.global(qos: .background).async {
                usbManager.connectUsbDevice(usbDevice) { (result, message) in
                    DispatchQueue.main.async {
                        if let msg = message {
                            self.showErrorAlert(msg)
                        }
                        if result {
                            self.connectedUsbDevices.append(usbDevice)
                        }
                    }
                }
            }
        }
    }
}

/// These devices cannot be captured as enforced by macOS. Capturing results in an error. App Store Review requests that we block out the option.
let usbBlockList = [
    (0x05ac, 0x8102), // Apple Touch Bar Backlight
    (0x05ac, 0x8103), // Apple Headset
    (0x05ac, 0x8233), // Apple T2 Controller
    (0x05ac, 0x8262), // Apple Ambient Light Sensor
    (0x05ac, 0x8263),
    (0x05ac, 0x8302), // Apple Touch Bar Display
    (0x05ac, 0x8514), // Apple FaceTime HD Camera (Built-in)
    (0x05ac, 0x8600), // Apple iBridge
]

extension VMDisplayQemuWindowController {
    
    @IBAction override func usbButtonPressed(_ sender: Any) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let item = NSMenuItem()
        item.title = NSLocalizedString("Querying USB devices...", comment: "VMQemuDisplayMetalWindowController")
        item.isEnabled = false
        menu.addItem(item)
        DispatchQueue.global(qos: .userInitiated).async {
            let devices = self.vmUsbManager?.usbDevices ?? []
            DispatchQueue.main.async {
                self.updateUsbDevicesMenu(menu, devices: devices)
            }
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    func updateUsbDevicesMenu(_ menu: NSMenu, devices: [CSUSBDevice]) {
        allUsbDevices = devices
        menu.removeAllItems()
        if devices.count == 0 {
            let item = NSMenuItem()
            item.title = NSLocalizedString("No USB devices detected.", comment: "VMQemuDisplayMetalWindowController")
            item.isEnabled = false
            menu.addItem(item)
        }
        for (i, device) in devices.enumerated() {
            let item = NSMenuItem()
            let canRedirect = vmUsbManager?.canRedirectUsbDevice(device, errorMessage: nil) ?? false
            let isConnected = vmUsbManager?.isUsbDeviceConnected(device) ?? false
            let isConnectedToSelf = connectedUsbDevices.contains(device)
            item.title = device.name ?? device.description
            let blocked = usbBlockList.contains { (usbVid, usbPid) in usbVid == device.usbVendorId && usbPid == device.usbProductId }
            item.isEnabled = !blocked && canRedirect && (isConnectedToSelf || !isConnected)
            item.state = isConnectedToSelf ? .on : .off;
            item.tag = i
            item.target = self
            item.action = isConnectedToSelf ? #selector(disconnectUsbDevice) : #selector(connectUsbDevice)
            menu.addItem(item)
        }
        menu.update()
    }
    
    @objc func connectUsbDevice(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for connectUsbDevice")
            return
        }
        guard let usbManager = vmUsbManager else {
            logger.error("cannot get usb manager")
            return
        }
        let device = allUsbDevices[menu.tag]
        DispatchQueue.global(qos: .background).async {
            usbManager.connectUsbDevice(device) { (result, message) in
                DispatchQueue.main.async {
                    if let msg = message {
                        self.showErrorAlert(msg)
                    }
                    if result {
                        self.connectedUsbDevices.append(device)
                    }
                }
            }
        }
    }
    
    @objc func disconnectUsbDevice(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for disconnectUsbDevice")
            return
        }
        guard let usbManager = vmUsbManager else {
            logger.error("cannot get usb manager")
            return
        }
        let device = allUsbDevices[menu.tag]
        DispatchQueue.global(qos: .background).async {
            usbManager.disconnectUsbDevice(device) { (result, message) in
                DispatchQueue.main.async {
                    if let msg = message {
                        self.showErrorAlert(msg)
                    }
                    if result {
                        self.connectedUsbDevices.removeAll(where: { $0 == device })
                    }
                }
            }
        }
    }
}

// MARK: - Window management

extension VMDisplayQemuWindowController {
    @IBAction override func windowsButtonPressed(_ sender: Any) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for display in qemuVM.ioService!.displays {
            let id = display.monitorID
            guard id < vmQemuConfig.displays.count else {
                continue
            }
            let config = vmQemuConfig.displays[id]
            let item = NSMenuItem()
            let format = NSLocalizedString("Display %lld: %@", comment: "VMDisplayQemuDisplayController")
            let title = String.localizedStringWithFormat(format, id + 1, config.hardware.prettyValue)
            let isCurrent = self is VMDisplayQemuMetalWindowController && self.id == id
            item.title = title
            item.isEnabled = !isCurrent
            item.state = isCurrent ? .on : .off
            item.tag = id
            item.target = self
            item.action = #selector(showWindowFromDisplay)
            menu.addItem(item)
        }
        for serial in qemuVM.ioService!.serials {
            guard let id = configIdForSerial(serial) else {
                continue
            }
            let item = NSMenuItem()
            let format = NSLocalizedString("Serial %lld", comment: "VMDisplayQemuDisplayController")
            let title = String.localizedStringWithFormat(format, id + 1)
            let isCurrent = self is VMDisplayQemuTerminalWindowController && self.id == id
            item.title = title
            item.isEnabled = !isCurrent
            item.state = isCurrent ? .on : .off
            item.tag = id
            item.target = self
            item.action = #selector(showWindowFromSerial)
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc private func showWindowFromDisplay(sender: AnyObject) {
        let item = sender as! NSMenuItem
        let id = item.tag
        if self is VMDisplayQemuMetalWindowController && self.id == id {
            return
        }
        guard let display = qemuVM.ioService?.displays.first(where: { $0.monitorID == id}) else {
            return
        }
        if let window = findWindow(for: display) {
            window.showWindow(self)
        }
    }
    
    @objc private func showWindowFromSerial(sender: AnyObject) {
        let item = sender as! NSMenuItem
        let id = item.tag
        if self is VMDisplayQemuTerminalWindowController && self.id == id {
            return
        }
        guard let serial = qemuVM.ioService?.serials.first(where: { id == configIdForSerial($0) }) else {
            return
        }
        if let window = findWindow(for: serial) {
            window.showWindow(self)
        }
    }
    
    @MainActor private func findWindow(for display: CSDisplay) -> VMDisplayQemuWindowController? {
        let id = display.monitorID
        let secondaryWindows: [VMDisplayWindowController]
        if self is VMDisplayQemuMetalWindowController && self.id == id {
            return self
        }
        if let window = primaryWindow {
            if (window as? VMDisplayQemuMetalWindowController)?.id == id {
                return window as? VMDisplayQemuWindowController
            }
            secondaryWindows = window.secondaryWindows
        } else {
            secondaryWindows = self.secondaryWindows
        }
        for window in secondaryWindows {
            if let window = window as? VMDisplayQemuMetalWindowController {
                if window.id == id {
                    // found existing window
                    return window
                }
            }
        }
        if let newWindow = newWindow(from: display) {
            return newWindow
        } else {
            return nil
        }
    }
    
    @MainActor private func newWindow(from display: CSDisplay) -> VMDisplayQemuMetalWindowController? {
        let id = display.monitorID
        guard id < vmQemuConfig.displays.count else {
            return nil
        }
        guard let primary = (primaryWindow ?? self) as? VMDisplayQemuMetalWindowController else {
            return nil
        }
        let secondary = VMDisplayQemuMetalWindowController(secondaryFromDisplay: display, primary: primary, vm: qemuVM, id: id)
        registerSecondaryWindow(secondary)
        return secondary
    }
    
    @MainActor private func findWindow(for serial: CSPort) -> VMDisplayQemuWindowController? {
        let id = configIdForSerial(serial)!
        let secondaryWindows: [VMDisplayWindowController]
        if self is VMDisplayQemuTerminalWindowController && self.id == id {
            return self
        }
        if let window = primaryWindow {
            if (window as? VMDisplayQemuTerminalWindowController)?.id == id {
                return window as? VMDisplayQemuWindowController
            }
            secondaryWindows = window.secondaryWindows
        } else {
            secondaryWindows = self.secondaryWindows
        }
        for window in secondaryWindows {
            if let window = window as? VMDisplayQemuTerminalWindowController {
                if window.id == id {
                    // found existing window
                    return window
                }
            }
        }
        if let newWindow = newWindow(from: serial) {
            return newWindow
        } else {
            return nil
        }
    }
    
    @MainActor private func newWindow(from serial: CSPort) -> VMDisplayQemuTerminalWindowController? {
        guard let id = configIdForSerial(serial) else {
            return nil
        }
        guard id < vmQemuConfig.serials.count else {
            return nil
        }
        let secondary = VMDisplayQemuTerminalWindowController(secondaryFromSerialPort: serial, vm: qemuVM, id: id)
        registerSecondaryWindow(secondary)
        return secondary
    }
}
