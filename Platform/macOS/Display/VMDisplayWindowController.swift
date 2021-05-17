//
// Copyright © 2020 osy. All rights reserved.
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

class VMDisplayWindowController: NSWindowController {
    
    @IBOutlet weak var displayView: NSView!
    @IBOutlet weak var screenshotView: NSImageView!
    @IBOutlet weak var overlayView: NSVisualEffectView!
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    @IBOutlet weak var startButton: NSButton!
    
    @IBOutlet weak var toolbar: NSToolbar!
    @IBOutlet weak var stopToolbarItem: NSToolbarItem!
    @IBOutlet weak var startPauseToolbarItem: NSToolbarItem!
    @IBOutlet weak var restartToolbarItem: NSToolbarItem!
    @IBOutlet weak var captureMouseToolbarItem: NSToolbarItem!
    @IBOutlet weak var usbToolbarItem: NSToolbarItem!
    @IBOutlet weak var drivesToolbarItem: NSToolbarItem!
    @IBOutlet weak var sharedFolderToolbarItem: NSToolbarItem!
    @IBOutlet weak var resizeConsoleToolbarItem: NSToolbarItem!
    
    var vm: UTMVirtualMachine!
    var onClose: ((Notification) -> Void)?
    var vmMessage: String?
    var vmConfiguration: UTMConfiguration?
    var toolbarVisible: Bool = false // ignored
    var keyboardVisible: Bool = false // ignored
    
    @Setting("NoHypervisor") private var isNoHypervisor: Bool = false
    
    override var windowNibName: NSNib.Name? {
        "VMDisplayWindow"
    }
    
    override weak var owner: AnyObject? {
        self
    }
    
    convenience init(vm: UTMVirtualMachine, onClose: ((Notification) -> Void)?) {
        self.init(window: nil)
        self.vm = vm
        self.onClose = onClose
        vm.delegate = self
    }
    
    @IBAction func stopButtonPressed(_ sender: Any) {
        showConfirmAlert(NSLocalizedString("This may corrupt the VM and any unsaved changes will be lost. To quit safely, shut down from the guest.", comment: "VMDisplayWindowController")) {
            DispatchQueue.global(qos: .background).async {
                self.vm.quitVM()
            }
        }
    }
    
    @IBAction func startPauseButtonPressed(_ sender: Any) {
        if vm.state == .vmStarted {
            DispatchQueue.global(qos: .background).async {
                self.vm.pauseVM()
                guard self.vm.saveVM() else {
                    DispatchQueue.main.async {
                        self.showErrorAlert(NSLocalizedString("Failed to save VM state. Do you have at least one read-write drive attached that supports snapshots?", comment: "VMDisplayWindowController"))
                    }
                    return
                }
            }
        } else if vm.state == .vmPaused {
            DispatchQueue.global(qos: .background).async {
                self.vm.resumeVM()
            }
        } else if vm.state == .vmStopped {
            DispatchQueue.global(qos: .userInitiated).async {
                if self.vm.startVM() {
                    self.vm.ioDelegate = self
                }
            }
        } else {
            logger.error("Invalid state \(vm.state)")
        }
    }
    
    @IBAction func restartButtonPressed(_ sender: Any) {
        showConfirmAlert(NSLocalizedString("This will reset the VM and any unsaved state will be lost.", comment: "VMDisplayWindowController")) {
            DispatchQueue.global(qos: .background).async {
                self.vm.resetVM()
            }
        }
    }
    
    @IBAction dynamic func captureMouseButtonPressed(_ sender: Any) {
    }
    
    @IBAction dynamic func resizeConsoleButtonPressed(_ sender: Any) {
    }
    
    @IBAction dynamic func usbButtonPressed(_ sender: Any) {
    }
    
    // MARK: - UI states
    
    func enterLive() {
        overlayView.isHidden = true
        activityIndicator.stopAnimation(self)
        let pauseDescription = NSLocalizedString("Pause", comment: "VMDisplayWindowController")
        startPauseToolbarItem.image = NSImage(systemSymbolName: "pause", accessibilityDescription: pauseDescription)
        startPauseToolbarItem.label = pauseDescription
        if isNoHypervisor || !vmConfiguration!.isTargetArchitectureMatchHost {
            // currently HVF doesn't support suspending
            startPauseToolbarItem.isEnabled = true
        }
        stopToolbarItem.isEnabled = true
        captureMouseToolbarItem.isEnabled = true
        resizeConsoleToolbarItem.isEnabled = true
        drivesToolbarItem.isEnabled = vmConfiguration!.countDrives > 0
        sharedFolderToolbarItem.isEnabled = vm.hasShareDirectoryEnabled
        usbToolbarItem.isEnabled = vm.hasUsbRedirection
        window!.title = vmConfiguration!.name
    }
    
    func enterSuspended(isBusy busy: Bool) {
        overlayView.isHidden = false
        let playDescription = NSLocalizedString("Play", comment: "VMDisplayWindowController")
        startPauseToolbarItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: playDescription)
        startPauseToolbarItem.label = playDescription
        if busy {
            activityIndicator.startAnimation(self)
            startPauseToolbarItem.isEnabled = false
            stopToolbarItem.isEnabled = false
            startButton.isHidden = true
        } else {
            activityIndicator.stopAnimation(self)
            startPauseToolbarItem.isEnabled = true
            stopToolbarItem.isEnabled = true
            startButton.isHidden = false
        }
        captureMouseToolbarItem.isEnabled = false
        resizeConsoleToolbarItem.isEnabled = false
        drivesToolbarItem.isEnabled = false
        sharedFolderToolbarItem.isEnabled = false
        usbToolbarItem.isEnabled = false
    }
    
    // MARK: - Alert
    
    func showErrorAlert(_ message: String, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString("Error", comment: "VMDisplayWindowController")
        alert.informativeText = message
        alert.beginSheetModal(for: window!, completionHandler: handler)
    }
    
    func showConfirmAlert(_ message: String, confirmHandler handler: (() -> Void)? = nil) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Confirmation", comment: "VMDisplayWindowController")
        alert.informativeText = message
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "VMDisplayWindowController"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "VMDisplayWindowController"))
        alert.beginSheetModal(for: window!) { response in
            if response == .alertFirstButtonReturn {
                handler?()
            }
        }
    }
}

extension VMDisplayWindowController: NSWindowDelegate {
    func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
        return [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
    }
    
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.global(qos: .background).async {
            self.vm.quitVM(force: true)
        }
        onClose?(notification)
    }
}

// MARK: - Toolbar

extension VMDisplayWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        return true
    }
}

// MARK: - VM Delegate

extension VMDisplayWindowController: UTMVirtualMachineDelegate {
    func virtualMachine(_ vm: UTMVirtualMachine, transitionTo state: UTMVMState) {
        switch state {
        case .vmError:
            let message = vmMessage ?? NSLocalizedString("An internal error has occured.", comment: "VMDisplayWindowController")
            showErrorAlert(message) { _ in
                self.close()
            }
        case .vmStopped, .vmPaused, .vmSuspended:
            enterSuspended(isBusy: false)
        case .vmPausing, .vmStopping, .vmStarting, .vmResuming:
            enterSuspended(isBusy: true)
        case .vmStarted:
            enterLive()
        @unknown default:
            break
        }
    }
}

// MARK: - Removable drives

@objc extension VMDisplayWindowController {
    @IBAction func drivesButtonPressed(_ sender: Any) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let item = NSMenuItem()
        item.title = NSLocalizedString("Querying drives status...", comment: "VMDisplayWindowController")
        item.isEnabled = false
        menu.addItem(item)
        DispatchQueue.global(qos: .userInitiated).async {
            let drives = self.vm.drives
            DispatchQueue.main.async {
                self.updateDrivesMenu(menu, drives: drives)
            }
        }
        if let event = NSApplication.shared.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: sender as! NSView)
        }
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
        let drive = vm.drives[menu.tag]
        DispatchQueue.global(qos: .background).async {
            do {
                try self.vm.ejectDrive(drive, force: false)
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
                    try self.vm.changeMedium(for: drive, url: url)
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
        let drive = vm.drives[menu.tag]
        openDriveImage(forDrive: drive)
    }
}

// MARK: - Shared folders

extension VMDisplayWindowController {
    @IBAction func sharedFolderButtonPressed(_ sender: Any) {
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
                    try self.vm.changeSharedDirectory(url)
                } catch {
                    DispatchQueue.main.async {
                        self.showErrorAlert(error.localizedDescription)
                    }
                }
            }
        }
    }
}
