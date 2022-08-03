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

import Combine
import SwiftTerm
import SwiftUI
import Virtualization

@available(macOS 11, *)
class VMDisplayAppleWindowController: VMDisplayWindowController {
    var mainView: NSView?
    
    @available(macOS 12, *)
    var appleView: VZVirtualMachineView? {
        mainView as? VZVirtualMachineView
    }
    
    var terminalView: TerminalView? {
        mainView as? TerminalView
    }
    var isInstalling: Bool = false
    
    var appleVM: UTMAppleVirtualMachine! {
        vm as? UTMAppleVirtualMachine
    }
    
    var appleConfig: UTMAppleConfiguration! {
        vm?.config.appleConfig
    }
    
    private var cancellable: AnyCancellable?
    
    private var isSharePathAlertShownOnce = false
    
    // MARK: - User preferences
    
    @Setting("SharePathAlertShown") private var isSharePathAlertShownPersistent: Bool = false
    
    override func windowDidLoad() {
        if !appleConfig.serials.isEmpty {
            mainView = TerminalView()
            terminalView!.terminalDelegate = self
            cancellable = appleVM.$serialPort.sink { [weak self] serialPort in
                serialPort?.delegate = self
            }
        } else if #available(macOS 12, *) {
            mainView = VZVirtualMachineView()
            appleView!.capturesSystemKeys = true
        } else {
            mainView = NSView()
            showErrorAlert(NSLocalizedString("This version of macOS does not support running this virtual machine.", comment: "VMDisplayAppleController"))
        }
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
    }
    
    override func enterLive() {
        if #available(macOS 12, *), let appleView = appleView {
            appleView.virtualMachine = appleVM.apple
        }
        window!.title = appleConfig.information.name
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
        if !busy, #available(macOS 12, *), let appleView = appleView {
            appleView.virtualMachine = nil
        }
        isPowerForce = true
        super.enterSuspended(isBusy: busy)
    }
    
    override func virtualMachine(_ vm: UTMVirtualMachine, didTransitionTo state: UTMVMState) {
        super.virtualMachine(vm, didTransitionTo: state)
        if #available(macOS 12, *), state == .vmStopped && isInstalling {
            didFinishInstallation()
        }
    }
    
    @available(macOS 12, *)
    private func windowSize(for display: UTMAppleConfigurationDisplay) -> CGSize {
        let currentScreenScale = window?.screen?.backingScaleFactor ?? 1.0
        let useHidpi = display.pixelsPerInch >= 226
        let scale = useHidpi ? currentScreenScale : 1.0
        return CGSize(width: CGFloat(display.widthInPixels) / scale, height: CGFloat(display.heightInPixels) / scale)
    }
    
    func updateWindowFrame() {
        guard let window = window else {
            return
        }
        if let terminalView = terminalView {
            let fontSize = appleConfig.serials.first!.terminal!.fontSize
            let fontName = appleConfig.serials.first!.terminal!.font.rawValue
            if fontName != "" {
                let orig = terminalView.font
                let new = NSFont(name: fontName, size: CGFloat(fontSize)) ?? orig
                terminalView.font = new
            } else {
                let orig = terminalView.font
                let new = NSFont(descriptor: orig.fontDescriptor, size: CGFloat(fontSize)) ?? orig
                terminalView.font = new
            }
            if let consoleTextColor = appleConfig.serials.first!.terminal!.foregroundColor,
               let textColor = Color(hexString: consoleTextColor),
               let consoleBackgroundColor = appleConfig.serials.first!.terminal!.backgroundColor,
               let backgroundColor = Color(hexString: consoleBackgroundColor) {
                terminalView.nativeForegroundColor = NSColor(textColor)
                terminalView.nativeBackgroundColor = NSColor(backgroundColor)
            }
            terminalView.getTerminal().resize(cols: 80, rows: 24)
            let size = window.frameRect(forContentRect: terminalView.getOptimalFrameSize()).size
            let frame = CGRect(origin: window.frame.origin, size: size)
            window.minSize = size
            window.setFrame(frame, display: false, animate: true)
        } else if #available(macOS 12, *) {
            guard let primaryDisplay = appleConfig.displays.first else {
                return //FIXME: add multiple displays
            }
            let size = windowSize(for: primaryDisplay)
            let frame = window.frameRect(forContentRect: CGRect(origin: window.frame.origin, size: size))
            window.contentAspectRatio = size
            window.minSize = NSSize(width: 400, height: 400)
            window.setFrame(frame, display: false, animate: true)
        }
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
        if let terminalView = terminalView {
            let cmd = appleConfig.serials.first!.terminal!.resizeCommand
            let cols = terminalView.getTerminal().cols
            let rows = terminalView.getTerminal().rows
            appleVM.serialPort?.writeResizeCommand(cmd, columns: cols, rows: rows)
        } else {
            updateWindowFrame()
        }
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

@available(macOS 12, *)
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
                self.window!.subtitle = NSLocalizedString("Installation: \(Int(progress * 100))%", comment: "VMDisplayAppleWindowController")
            }
        }
    }
}

@available(macOS 11, *)
extension VMDisplayAppleWindowController: TerminalViewDelegate, UTMSerialPortDelegate {
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
    }
    
    func setTerminalTitle(source: TerminalView, title: String) {
        window!.subtitle = title
    }
    
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
    }
    
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        if let serialPort = appleVM.serialPort {
            serialPort.write(data: Data(data))
        }
    }
    
    func scrolled(source: TerminalView, position: Double) {
    }
    
    func serialPort(_ serialPort: UTMSerialPort, didRecieveData data: Data) {
        if let terminalView = terminalView {
            let arr = [UInt8](data)[...]
            DispatchQueue.main.async {
                terminalView.feed(byteArray: arr)
            }
        }
    }
}

@available(macOS 11, *)
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
