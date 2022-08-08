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
    
    var isInstalling: Bool = false
    
    var appleVM: UTMAppleVirtualMachine! {
        vm as? UTMAppleVirtualMachine
    }
    
    var appleConfig: UTMAppleConfiguration! {
        vm?.config.appleConfig
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
                self.isInstalling = true
                self.appleVM.requestInstallVM(with: ipswUrl)
            }
        }
        if !isSecondary {
            // create remaining serial windows
            for i in appleConfig.serials.indices {
                if i == 0 && self is VMDisplayAppleTerminalWindowController {
                    continue
                }
                if appleConfig.serials[i].mode != .builtin || appleConfig.serials[i].terminal == nil {
                    continue
                }
                let vc = VMDisplayAppleTerminalWindowController(secondaryForIndex: i, vm: appleVM)
                showSecondaryWindow(vc)
            }
        }
    }
    
    override func enterLive() {
        window!.title = defaultTitle
        window!.subtitle = defaultSubtitle
        updateWindowFrame()
        super.enterLive()
        captureMouseToolbarItem.isEnabled = false
        drivesToolbarItem.isEnabled = false
        usbToolbarItem.isEnabled = false
        startPauseToolbarItem.isEnabled = true
        if #available(macOS 12, *) {
            isPowerForce = false
            sharedFolderToolbarItem.isEnabled = appleConfig.system.boot.operatingSystem == .linux
        } else {
            // stop() not available on macOS 11 for some reason
            restartToolbarItem.isEnabled = false
            sharedFolderToolbarItem.isEnabled = false
            isPowerForce = true
        }
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        isPowerForce = true
        super.enterSuspended(isBusy: busy)
    }
    
    override func virtualMachine(_ vm: UTMVirtualMachine, didTransitionTo state: UTMVMState) {
        super.virtualMachine(vm, didTransitionTo: state)
        if #available(macOS 12, *), state == .vmStopped && isInstalling {
            didFinishInstallation()
        }
    }
    
    func updateWindowFrame() {
        // implement in subclass
    }
    
    override func stopButtonPressed(_ sender: Any) {
        if isPowerForce {
            super.stopButtonPressed(sender)
        } else {
            appleVM.requestVmStop(force: false)
            isPowerForce = true
        }
    }
    
    override func resizeConsoleButtonPressed(_ sender: Any) {
        // implement in subclass
    }
    
    @IBAction override func sharedFolderButtonPressed(_ sender: Any) {
        guard #available(macOS 12, *) else {
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
            openShareMenu(sender)
        }
    }
}

@available(macOS 12, *)
extension VMDisplayAppleWindowController {
    func openShareMenu(_ sender: Any) {
        let menu = NSMenu()
        for i in appleConfig.sharedDirectories.indices {
            let item = NSMenuItem()
            let sharedDirectory = appleConfig.sharedDirectories[i]
            guard let name = sharedDirectory.directoryURL?.lastPathComponent else {
                continue
            }
            item.title = name
            let submenu = NSMenu()
            let ro = NSMenuItem(title: NSLocalizedString("Read Only", comment: "VMDisplayAppleController"),
                                   action: #selector(flipReadOnlyShare),
                                   keyEquivalent: "")
            ro.target = self
            ro.tag = i
            ro.state = sharedDirectory.isReadOnly ? .on : .off
            submenu.addItem(ro)
            let change = NSMenuItem(title: NSLocalizedString("Change…", comment: "VMDisplayAppleController"),
                                   action: #selector(changeShare),
                                   keyEquivalent: "")
            change.target = self
            change.tag = i
            submenu.addItem(change)
            let remove = NSMenuItem(title: NSLocalizedString("Remove…", comment: "VMDisplayAppleController"),
                                   action: #selector(removeShare),
                                   keyEquivalent: "")
            remove.target = self
            remove.tag = i
            submenu.addItem(remove)
            item.submenu = submenu
            menu.addItem(item)
        }
        let add = NSMenuItem(title: NSLocalizedString("Add…", comment: "VMDisplayAppleController"),
                               action: #selector(addShare),
                               keyEquivalent: "")
        add.target = self
        menu.addItem(add)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc func addShare(sender: AnyObject) {
        pickShare { url in
            let sharedDirectory = UTMAppleConfigurationSharedDirectory(directoryURL: url)
            self.appleConfig.sharedDirectories.append(sharedDirectory)
        }
    }
    
    @objc func changeShare(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for changeShare")
            return
        }
        let i = menu.tag
        let isReadOnly = appleConfig.sharedDirectories[i].isReadOnly
        pickShare { url in
            let sharedDirectory = UTMAppleConfigurationSharedDirectory(directoryURL: url, isReadOnly: isReadOnly)
            self.appleConfig.sharedDirectories[i] = sharedDirectory
        }
    }
    
    @objc func flipReadOnlyShare(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for changeShare")
            return
        }
        let i = menu.tag
        let isReadOnly = appleConfig.sharedDirectories[i].isReadOnly
        appleConfig.sharedDirectories[i].isReadOnly = !isReadOnly
    }
    
    @objc func removeShare(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for removeShare")
            return
        }
        let i = menu.tag
        appleConfig.sharedDirectories.remove(at: i)
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

extension VMDisplayAppleWindowController {
    func didFinishInstallation() {
        DispatchQueue.main.async {
            self.isInstalling = false
            // delete IPSW setting
            self.enterSuspended(isBusy: true)
            self.appleConfig.system.boot.macRecoveryIpswURL = nil
            // start VM
            self.vm.requestVmStart()
        }
    }
    
    func virtualMachine(_ vm: UTMVirtualMachine, didUpdateInstallationProgress progress: Double) {
        DispatchQueue.main.async {
            if progress >= 1 {
                self.window!.subtitle = ""
            } else {
                let installationFormat = NSLocalizedString("Installation: %@", comment: "VMDisplayAppleWindowController")
                let percentString = NumberFormatter.localizedString(from: progress as NSNumber, number: .percent)
                self.window!.subtitle = String.localizedStringWithFormat(installationFormat, percentString)
            }
        }
    }
}

extension VMDisplayAppleWindowController: UTMScreenshotProvider {
    var screenshot: CSScreenshot? {
        if let image = mainView?.image() {
            return CSScreenshot(image: image)
        } else {
            return nil
        }
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
