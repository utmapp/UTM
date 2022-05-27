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
    private weak var vmUsbManager: CSUSBManager?
    private var allUsbDevices: [CSUSBDevice] = []
    private var connectedUsbDevices: [CSUSBDevice] = []
    @Setting("NoUsbPrompt") private var isNoUsbPrompt: Bool = false
    
    var qemuVM: UTMQemuVirtualMachine! {
        vm as? UTMQemuVirtualMachine
    }
    
    var vmQemuConfig: UTMQemuConfiguration! {
        vm?.config as? UTMQemuConfiguration
    }
    
    var defaultSubtitle: String {
        if qemuVM.isRunningAsSnapshot {
            return NSLocalizedString("Disposable Mode", comment: "VMDisplayQemuDisplayController")
        } else {
            return ""
        }
    }
    
    override var shouldSaveOnPause: Bool {
        !qemuVM.isRunningAsSnapshot
    }
    
    override func enterLive() {
        qemuVM.ioDelegate = self
        startPauseToolbarItem.isEnabled = true
        #if arch(x86_64)
        if vmQemuConfig.useHypervisor {
            // currently x86_64 HVF doesn't support suspending
            startPauseToolbarItem.isEnabled = false
        }
        #endif
        drivesToolbarItem.isEnabled = vmQemuConfig.countDrives > 0
        sharedFolderToolbarItem.isEnabled = qemuVM.hasShareDirectoryEnabled
        usbToolbarItem.isEnabled = qemuVM.hasUsbRedirection
        window!.title = vmQemuConfig.name
        window!.subtitle = defaultSubtitle
        super.enterLive()
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if vm.state == .vmStopped {
            connectedUsbDevices.removeAll()
            allUsbDevices.removeAll()
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
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = self.qemuVM.drives
            DispatchQueue.main.async {
                self.updateDrivesMenu(menu, drives: drives)
            }
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    func updateDrivesMenu(_ menu: NSMenu, drives: [UTMDrive]) {
        menu.removeAllItems()
        if drives.count == 0 {
            let item = NSMenuItem()
            item.title = NSLocalizedString("No drives connected.", comment: "VMDisplayWindowController")
            item.isEnabled = false
            menu.addItem(item)
        }
        for drive in drives {
            if drive.imageType != .disk && drive.imageType != .CD && drive.status == .fixed {
                continue // skip non-disks
            }
            let item = NSMenuItem()
            item.title = drive.label
            if drive.status == .fixed {
                item.isEnabled = false
            } else {
                let submenu = NSMenu()
                submenu.autoenablesItems = false
                let eject = NSMenuItem(title: NSLocalizedString("Eject", comment: "VMDisplayWindowController"),
                                       action: #selector(ejectDrive),
                                       keyEquivalent: "")
                eject.target = self
                eject.tag = drive.index
                eject.isEnabled = drive.status != .ejected
                submenu.addItem(eject)
                let change = NSMenuItem(title: NSLocalizedString("Change", comment: "VMDisplayWindowController"),
                                        action: #selector(changeDriveImage),
                                        keyEquivalent: "")
                change.target = self
                change.tag = drive.index
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
        let drive = qemuVM.drives[menu.tag]
        DispatchQueue.global(qos: .background).async {
            do {
                try self.qemuVM.ejectDrive(drive, force: false)
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(error.localizedDescription)
                }
            }
        }
    }
    
    func openDriveImage(forDrive drive: UTMDrive) {
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
            DispatchQueue.global(qos: .background).async {
                do {
                    try self.qemuVM.changeMedium(for: drive, url: url)
                } catch {
                    DispatchQueue.main.async {
                        self.showErrorAlert(error.localizedDescription)
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
        let drive = qemuVM.drives[menu.tag]
        openDriveImage(forDrive: drive)
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
            DispatchQueue.global(qos: .background).async {
                do {
                    try self.qemuVM.changeSharedDirectory(url)
                } catch {
                    DispatchQueue.main.async {
                        self.showErrorAlert(error.localizedDescription)
                    }
                }
            }
        }
    }
}

// MARK: - SPICE base implementation

extension VMDisplayQemuWindowController: UTMSpiceIODelegate {
    func spiceDidCreateInput(_ input: CSInput) {
        // Implemented in subclass
    }
    
    func spiceDidDestroyInput(_ input: CSInput) {
        // Implemented in subclass
    }
    
    func spiceDidCreateDisplay(_ display: CSDisplay) {
        // Implemented in subclass
    }
    
    func spiceDidChangeDisplay(_ display: CSDisplay) {
        // Implemented in subclass
    }
    
    func spiceDidDestroyDisplay(_ display: CSDisplay) {
        // Implemented in subclass
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
    }
    
    func spiceDynamicResolutionSupportDidChange(_ supported: Bool) {
        // Implemented in subclass
    }
    
    func spiceDidCreateSerial(_ serial: CSPort) {
        // Implemented in subclass
    }
    
    func spiceDidDestroySerial(_ serial: CSPort) {
        // Implemented in subclass
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
                if self.window!.isKeyWindow {
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
        alert.messageText = NSLocalizedString("USB Device", comment: "VMDisplayMetalWindowController")
        alert.informativeText = NSLocalizedString("Would you like to connect '\(usbDevice.name ?? usbDevice.description)' to this virtual machine?", comment: "VMDisplayMetalWindowController")
        alert.showsSuppressionButton = true
        alert.addButton(withTitle: NSLocalizedString("Confirm", comment: "VMDisplayMetalWindowController"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "VMDisplayMetalWindowController"))
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
        item.title = NSLocalizedString("Querying USB devices...", comment: "VMDisplayMetalWindowController")
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
            item.title = NSLocalizedString("No USB devices detected.", comment: "VMDisplayMetalWindowController")
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
