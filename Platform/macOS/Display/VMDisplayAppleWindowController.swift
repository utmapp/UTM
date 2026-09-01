//
// Copyright © 2021 osy. All rights reserved.
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

class VMDisplayAppleWindowController: VMDisplayWindowController {
    var mainView: NSView?

    var contentView: NSView? {
        nil
    }

    var isInstallSuccessful: Bool = false
    
    var appleVM: UTMAppleVirtualMachine! {
        vm as? UTMAppleVirtualMachine
    }
    
    var appleConfig: UTMAppleConfiguration! {
        appleVM?.config
    }
    
    var defaultTitle: String {
        appleConfig.information.name
    }
    
    var defaultSubtitle: String {
        ""
    }
    
    private var isSharePathAlertShownOnce = false
    
    // MARK: - User preferences
    
    @Setting("SharePathAlertShown") private var isSharePathAlertShownPersistent: Bool = false
    @Setting("NoUsbPrompt") private var isNoUsbPrompt: Bool = false
    
    override func windowDidLoad() {
        mainView!.translatesAutoresizingMaskIntoConstraints = false
        displayView.addSubview(mainView!)
        NSLayoutConstraint.activate(mainView!.constraintsForAnchoringTo(boundsOf: displayView))
        appleVM.screenshotDelegate = self
        window!.recalculateKeyViewLoop()
        if #available(macOS 12, *) {
            shouldAutoStartVM = appleConfig.system.boot.macRecoveryIpswURL == nil
        }
        super.windowDidLoad()
        if #available(macOS 12, *), let ipswUrl = appleConfig.system.boot.macRecoveryIpswURL {
            showConfirmAlert(NSLocalizedString("Would you like to install macOS? If an existing operating system is already installed on the primary drive of this VM, then it will be erased.", comment: "VMDisplayAppleWindowController")) {
                self.isInstallSuccessful = false
                self.appleVM.requestInstallVM(with: ipswUrl)
            }
        }
        if !isSecondary {
            // create remaining serial windows
            let primarySerialIndex = appleConfig.serials.firstIndex { $0.mode == .builtin }
            for i in appleConfig.serials.indices {
                if i == primarySerialIndex && self is VMDisplayAppleTerminalWindowController {
                    continue
                }
                if appleConfig.serials[i].mode != .builtin || appleConfig.serials[i].terminal == nil {
                    continue
                }
                let vc = VMDisplayAppleTerminalWindowController(secondaryForIndex: i, vm: appleVM)
                registerSecondaryWindow(vc)
            }
        }
    }
    
    override func enterLive() {
        window!.title = defaultTitle
        window!.subtitle = defaultSubtitle
        updateWindowFrame()
        super.enterLive()
        setControl([.drives, .usb, .resize, .keyboardShortcut], isEnabled: false)
        if #available(macOS 13, *) {
            setControl(.sharedFolder, isEnabled: true)
        } else if #available(macOS 12, *) {
            setControl(.sharedFolder, isEnabled: appleConfig.system.boot.operatingSystem == .linux)
        } else {
            // stop() not available on macOS 11 for some reason
            setControl([.restart, .sharedFolder], isEnabled: false)
        }
        if #available(macOS 15, *) {
            setControl(.drives, isEnabled: true)
        }
        if let usbManager = appleVM.usbManager, usbManager.isSupported {
            setControl(.usb, isEnabled: true)
            if !isSecondary, usbManager.isAvailable {
                usbManager.delegate = self
            }
        }
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if !isSecondary {
            appleVM.usbManager?.delegate = nil
        }
        super.enterSuspended(isBusy: busy)
    }
    
    override func virtualMachine(_ vm: any UTMVirtualMachine, didTransitionToState state: UTMVirtualMachineState) {
        super.virtualMachine(vm, didTransitionToState: state)
        if state == .stopped && !isSecondary {
            appleVM.usbManager?.delegate = nil
        }
        if state == .stopped && isInstallSuccessful {
            isInstallSuccessful = false
            vm.requestVmStart()
        }
    }
    
    func updateWindowFrame() {
        // implement in subclass
    }
    
    override func resizeConsoleButtonPressed(_ sender: Any) {
        // implement in subclass
    }
    
    @IBAction override func sharedFolderButtonPressed(_ sender: Any) {
        guard #available(macOS 12, *) else {
            return
        }
        guard appleConfig.system.boot.operatingSystem == .linux else {
            super.sharedFolderButtonPressed(sender)
            return
        }
        if !isSharePathAlertShownOnce && !isSharePathAlertShownPersistent {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Directory sharing", comment: "VMDisplayAppleWindowController")
            alert.informativeText = NSLocalizedString("To access the shared directory, the guest OS must have Virtiofs drivers installed. You can then run `sudo mount -t virtiofs share /path/to/share` to mount to the share path.", comment: "VMDisplayAppleWindowController")
            alert.showsSuppressionButton = true
            alert.beginSheetModal(for: window!) { _ in
                if alert.suppressionButton?.state ?? .off == .on {
                    self.isSharePathAlertShownPersistent = true
                }
                self.isSharePathAlertShownOnce = true
            }
        } else {
            super.sharedFolderButtonPressed(sender)
        }
    }
    
    // MARK: - Installation progress
    
    override func virtualMachine(_ vm: any UTMVirtualMachine, didCompleteInstallation success: Bool) {
        Task { @MainActor in
            self.window!.subtitle = ""
            if success {
                // delete IPSW setting
                self.enterSuspended(isBusy: true)
                self.appleConfig.system.boot.macRecoveryIpswURL = nil
                self.appleVM.registryEntry.macRecoveryIpsw = nil
                self.isInstallSuccessful = true
            }
        }
    }
    
    override func virtualMachine(_ vm: any UTMVirtualMachine, didUpdateInstallationProgress progress: Double) {
        Task { @MainActor in
            let installationFormat = NSLocalizedString("Installation: %@", comment: "VMDisplayAppleWindowController")
            let percentString = NumberFormatter.localizedString(from: progress as NSNumber, number: .percent)
            self.window!.subtitle = String.localizedStringWithFormat(installationFormat, percentString)
        }
    }
}

// MARK: - USB passthrough

extension VMDisplayAppleWindowController: UTMAppleUSBManagerDelegate {
    func usbManager(_ usbManager: UTMAppleUSBManager, didDiscover device: UTMAppleUSBDevice) {
        logger.debug("USB device discovered: \(device.name)")
        guard !isSecondary,
              !isNoUsbPrompt,
              window?.isKeyWindow == true,
              vm.state == .started,
              case .available = device.state else {
            return
        }
        showConnectPrompt(for: device, using: usbManager)
    }

    func usbManager(_ usbManager: UTMAppleUSBManager, didRemove device: UTMAppleUSBDevice) {
        logger.debug("USB device removed: \(device.name)")
    }

    private func showConnectPrompt(for device: UTMAppleUSBDevice, using usbManager: UTMAppleUSBManager) {
        guard !isSecondary, let window = window, window.isKeyWindow, vm.state == .started else {
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("USB Device", comment: "VMDisplayAppleWindowController")
        alert.informativeText = String.localizedStringWithFormat(NSLocalizedString("Would you like to connect '%@' to this virtual machine?", comment: "VMDisplayAppleWindowController"), device.name)
        alert.showsSuppressionButton = true
        alert.addButton(withTitle: NSLocalizedString("Connect", comment: "VMDisplayAppleWindowController"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "VMDisplayAppleWindowController"))
        alert.beginSheetModal(for: window) { response in
            if alert.suppressionButton?.state == .on {
                self.isNoUsbPrompt = true
            }
            guard response == .alertFirstButtonReturn, self.vm.state == .started else {
                return
            }
            self.withErrorAlert {
                try await usbManager.connect(device)
            }
        }
    }
}

extension VMDisplayAppleWindowController {
    override func updateUsbMenu(_ menu: NSMenu) {
        menu.autoenablesItems = false
        setUsbMenuMessage(NSLocalizedString("Querying USB devices...", comment: "VMDisplayAppleWindowController"), in: menu)
        guard let usbManager = appleVM.usbManager, usbManager.isSupported else {
            setUsbMenuMessage(NSLocalizedString("USB passthrough is unavailable.", comment: "VMDisplayAppleWindowController"), in: menu)
            return
        }
        if let unavailableReason = usbManager.unavailableReason {
            setUsbMenuMessage(unavailableReason, in: menu)
            return
        }
        Task { @MainActor [weak self] in
            guard let self = self else {
                return
            }
            do {
                let devices = try await usbManager.usbDevices()
                self.updateUsbDevicesMenu(menu, devices: devices)
            } catch {
                logger.debug("Failed to query USB devices: \(error.localizedDescription)")
                self.setUsbMenuMessage(NSLocalizedString("Unable to query USB devices.", comment: "VMDisplayAppleWindowController"),
                                       toolTip: error.localizedDescription,
                                       in: menu)
            }
        }
    }

    private func updateUsbDevicesMenu(_ menu: NSMenu, devices: [UTMAppleUSBDevice]) {
        guard !devices.isEmpty else {
            setUsbMenuMessage(NSLocalizedString("No USB devices assigned to UTM.", comment: "VMDisplayAppleWindowController"),
                              toolTip: NSLocalizedString("Use the USB Accessories menu in the menu bar to allow a device.", comment: "VMDisplayAppleWindowController"),
                              in: menu)
            return
        }
        menu.removeAllItems()
        for device in devices {
            let item = NSMenuItem()
            item.title = device.name
            item.representedObject = device

            let actionItem = NSMenuItem()
            actionItem.representedObject = device
            actionItem.target = self
            switch device.state {
            case .available:
                item.isEnabled = true
                item.state = .off
                actionItem.title = NSLocalizedString("Connect…", comment: "VMDisplayAppleWindowController")
                actionItem.isEnabled = true
                actionItem.action = #selector(connectUsbDevice(_:))
            case .connected:
                item.isEnabled = true
                item.state = .on
                actionItem.title = NSLocalizedString("Disconnect…", comment: "VMDisplayAppleWindowController")
                actionItem.isEnabled = true
                actionItem.action = #selector(disconnectUsbDevice(_:))
            case .inUse:
                item.isEnabled = false
                item.state = .off
                item.toolTip = NSLocalizedString("This device is connected to another virtual machine.", comment: "VMDisplayAppleWindowController")
                actionItem.title = NSLocalizedString("Connect…", comment: "VMDisplayAppleWindowController")
                actionItem.isEnabled = false
                actionItem.action = #selector(connectUsbDevice(_:))
            }

            let submenu = NSMenu()
            submenu.autoenablesItems = false
            submenu.addItem(actionItem)
            item.submenu = submenu
            menu.addItem(item)
        }
        menu.update()
    }

    private func setUsbMenuMessage(_ message: String, toolTip: String? = nil, in menu: NSMenu) {
        menu.removeAllItems()
        let item = NSMenuItem()
        item.title = message
        item.toolTip = toolTip
        item.isEnabled = false
        menu.addItem(item)
        menu.update()
    }

    @objc private func connectUsbDevice(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? UTMAppleUSBDevice else {
            logger.debug("Missing USB device for connect action")
            return
        }
        guard let usbManager = appleVM.usbManager else {
            logger.debug("USB manager is missing for connect action")
            return
        }
        withErrorAlert {
            try await usbManager.connect(device)
        }
    }

    @objc private func disconnectUsbDevice(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? UTMAppleUSBDevice else {
            logger.debug("Missing USB device for disconnect action")
            return
        }
        guard let usbManager = appleVM.usbManager else {
            logger.debug("USB manager is missing for disconnect action")
            return
        }
        withErrorAlert {
            try await usbManager.disconnect(device)
        }
    }
}

extension VMDisplayAppleWindowController {
    override func updateSharedFolderMenu(_ menu: NSMenu) {
        let entry = appleVM.registryEntry
        for i in entry.sharedDirectories.indices {
            let item = NSMenuItem()
            let sharedDirectory = entry.sharedDirectories[i]
            let name = sharedDirectory.url.lastPathComponent
            item.title = name
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            let ro = NSMenuItem(title: NSLocalizedString("Read Only", comment: "VMDisplayAppleController"),
                                   action: #selector(flipReadOnlyShare),
                                   keyEquivalent: "")
            ro.target = self
            ro.tag = i
            ro.state = sharedDirectory.isReadOnly ? .on : .off
            // we cannot toggle read-only state if we originally obtained the bookmark as read-only
            ro.isEnabled = !appleConfig.sharedDirectories[i].isReadOnly
            submenu.addItem(ro)
            let change = NSMenuItem(title: NSLocalizedString("Change…", comment: "VMDisplayAppleController"),
                                   action: #selector(changeShare),
                                   keyEquivalent: "")
            change.target = self
            change.tag = i
            change.isEnabled = true
            submenu.addItem(change)
            let remove = NSMenuItem(title: NSLocalizedString("Remove…", comment: "VMDisplayAppleController"),
                                   action: #selector(removeShare),
                                   keyEquivalent: "")
            remove.target = self
            remove.tag = i
            remove.isEnabled = true
            submenu.addItem(remove)
            item.submenu = submenu
            menu.addItem(item)
        }
        let add = NSMenuItem(title: NSLocalizedString("Add…", comment: "VMDisplayAppleController"),
                               action: #selector(addShare),
                               keyEquivalent: "")
        add.target = self
        menu.addItem(add)
    }

    @objc func addShare(sender: AnyObject) {
        pickShare { url in
            if let sharedDirectory = try? UTMRegistryEntry.File(url: url) {
                self.appleVM.registryEntry.sharedDirectories.append(sharedDirectory)
            }
        }
    }
    
    @objc func changeShare(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for changeShare")
            return
        }
        let i = menu.tag
        let isReadOnly = appleVM.registryEntry.sharedDirectories[i].isReadOnly
        pickShare { url in
            if let sharedDirectory = try? UTMRegistryEntry.File(url: url, isReadOnly: isReadOnly) {
                self.appleVM.registryEntry.sharedDirectories[i] = sharedDirectory
            }
        }
    }
    
    @objc func flipReadOnlyShare(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for changeShare")
            return
        }
        let i = menu.tag
        let isReadOnly = appleVM.registryEntry.sharedDirectories[i].isReadOnly
        appleVM.registryEntry.sharedDirectories[i].isReadOnly = !isReadOnly
    }
    
    @objc func removeShare(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for removeShare")
            return
        }
        let i = menu.tag
        appleVM.registryEntry.sharedDirectories.remove(at: i)
    }
    
    func pickShare(_ onComplete: @escaping (URL) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.title = NSLocalizedString("Select Shared Folder", comment: "VMDisplayAppleWindowController")
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
            onComplete(url)
        }
    }
}

@objc extension VMDisplayAppleWindowController {
    override func updateDrivesMenu(_ menu: NSMenu) {
        menu.autoenablesItems = false
        let item = NSMenuItem()
        item.title = NSLocalizedString("Querying drives status...", comment: "VMDisplayWindowController")
        item.isEnabled = false
        menu.addItem(item)
        updateDrivesMenu(menu, drives: appleConfig.drives)
    }

    @nonobjc func updateDrivesMenu(_ menu: NSMenu, drives: [UTMAppleConfigurationDrive]) {
        menu.removeAllItems()
        if drives.count == 0 {
            let item = NSMenuItem()
            item.title = NSLocalizedString("No drives connected.", comment: "VMDisplayWindowController")
            item.isEnabled = false
            menu.addItem(item)
        }
        if #available(macOS 15, *), appleConfig.system.boot.operatingSystem == .macOS {
            let item = NSMenuItem()
            item.title = NSLocalizedString("Install Guest Tools…", comment: "VMDisplayAppleWindowController")
            item.isEnabled = true
            item.state = appleVM.hasGuestToolsAttached ? .on : .off
            item.target = self
            item.action = #selector(installGuestTools)
            menu.addItem(item)
        }
        for i in drives.indices {
            let drive = drives[i]
            if !drive.isExternal {
                continue // skip non-disks
            }
            let item = NSMenuItem()
            item.title = label(for: drive)
            if !drive.isExternal {
                item.isEnabled = false
            } else if #available(macOS 15, *) {
                let submenu = NSMenu()
                submenu.autoenablesItems = false
                let eject = NSMenuItem(title: NSLocalizedString("Eject", comment: "VMDisplayWindowController"),
                                       action: #selector(ejectDrive),
                                       keyEquivalent: "")
                eject.target = self
                eject.tag = i
                eject.isEnabled = drive.imageURL != nil
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

    @available(macOS 15, *)
    func ejectDrive(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for ejectDrive")
            return
        }
        let drive = appleConfig.drives[menu.tag]
        withErrorAlert {
            try await self.appleVM.eject(drive)
        }
    }

    @available(macOS 15, *)
    func openDriveImage(forDriveIndex index: Int) {
        let drive = appleConfig.drives[index]
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
            self.withErrorAlert {
                try await self.appleVM.changeMedium(drive, to: url)
            }
        }
    }

    @available(macOS 15, *)
    func changeDriveImage(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for ejectDrive")
            return
        }
        openDriveImage(forDriveIndex: menu.tag)
    }

    @nonobjc private func label(for drive: UTMAppleConfigurationDrive) -> String {
        let imageURL = drive.imageURL
        return String.localizedStringWithFormat(NSLocalizedString("USB Mass Storage: %@", comment: "VMDisplayAppleDisplayController"),
                                                imageURL?.lastPathComponent ?? NSLocalizedString("none", comment: "VMDisplayAppleDisplayController"))
    }

    @available(macOS 15, *)
    @MainActor private func installGuestTools(sender: AnyObject) {
        if appleVM.hasGuestToolsAttached {
            withErrorAlert {
                try await self.appleVM.detachGuestTools()
            }
        } else {
            showConfirmAlert(NSLocalizedString("An USB device containing the installer will be mounted in the virtual machine. Only macOS Sequoia (15.0) and newer guests are supported.", comment: "VMDisplayAppleDisplayController")) {
                NotificationCenter.default.post(name: NSNotification.InstallGuestTools, object: self.appleVM)
            }
        }
    }
}

extension VMDisplayAppleWindowController: UTMScreenshotProvider {
    var screenshot: UTMVirtualMachineScreenshot? {
        if let image = contentView?.image() {
            return UTMVirtualMachineScreenshot(wrapping: image)
        } else {
            return nil
        }
    }
}

extension VMDisplayAppleWindowController {
    override func updateWindowsMenu(_ menu: NSMenu) {
        menu.autoenablesItems = false
        if #available(macOS 12, *), !appleConfig.displays.isEmpty {
            let item = NSMenuItem()
            let title = NSLocalizedString("Display", comment: "VMDisplayAppleWindowController")
            let isCurrent = self is VMDisplayAppleDisplayWindowController
            item.title = title
            item.isEnabled = !isCurrent
            item.state = isCurrent ? .on : .off
            item.target = self
            item.action = #selector(showWindowFromDisplay)
            menu.addItem(item)
        }
        for i in appleConfig.serials.indices {
            if appleConfig.serials[i].mode != .builtin || appleConfig.serials[i].terminal == nil {
                continue
            }
            let item = NSMenuItem()
            let format = NSLocalizedString("Serial %lld", comment: "VMDisplayAppleWindowController")
            let title = String.localizedStringWithFormat(format, i + 1)
            let isCurrent = (self as? VMDisplayAppleTerminalWindowController)?.index == i
            item.title = title
            item.isEnabled = !isCurrent
            item.state = isCurrent ? .on : .off
            item.tag = i
            item.target = self
            item.action = #selector(showWindowFromSerial)
            menu.addItem(item)
        }
    }
    
    @available(macOS 12, *)
    @objc private func showWindowFromDisplay(sender: AnyObject) {
        if self is VMDisplayAppleDisplayWindowController {
            return
        }
        if let window = primaryWindow, window is VMDisplayAppleDisplayWindowController {
            window.showWindow(self)
        }
    }
    
    @objc private func showWindowFromSerial(sender: AnyObject) {
        let item = sender as! NSMenuItem
        let id = item.tag
        let secondaryWindows: [VMDisplayWindowController]
        if let primaryWindow = primaryWindow {
            if (primaryWindow as? VMDisplayAppleTerminalWindowController)?.index == id {
                primaryWindow.showWindow(self)
                return
            }
            secondaryWindows = primaryWindow.secondaryWindows
        } else {
            secondaryWindows = self.secondaryWindows
        }
        for window in secondaryWindows {
            if (window as? VMDisplayAppleTerminalWindowController)?.index == id {
                window.showWindow(self)
                return
            }
        }
        // create new serial window
        let vc = VMDisplayAppleTerminalWindowController(secondaryForIndex: id, vm: appleVM)
        registerSecondaryWindow(vc)
        vc.showWindow(self)
    }
}

// https://www.avanderlee.com/swift/auto-layout-programmatically/
fileprivate extension NSView {
    /// Returns a collection of constraints to anchor the bounds of the current view to the given view.
    ///
    /// - Parameter view: The view to anchor to.
    /// - Returns: The layout constraints needed for this constraint.
    func constraintsForAnchoringTo(boundsOf view: NSView) -> [NSLayoutConstraint] {
        return [
            topAnchor.constraint(equalTo: view.topAnchor),
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ]
    }
}

// https://stackoverflow.com/a/41387514/13914748
fileprivate extension NSView {
    /// Get `NSImage` representation of the view.
    ///
    /// - Returns: `NSImage` of view
    func image() -> NSImage {
        let imageRepresentation = bitmapImageRepForCachingDisplay(in: bounds)!
        cacheDisplay(in: bounds, to: imageRepresentation)
        return NSImage(cgImage: imageRepresentation.cgImage!, size: bounds.size)
    }
}
