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
    
    var isPowerForce: Bool = false
    var shouldAutoStartVM: Bool = true
    var vm: UTMVirtualMachine!
    var onClose: ((Notification) -> Void)?
    
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
            self.enterSuspended(isBusy: true) // early indicator
            self.vm.requestVmDeleteState()
            self.vm.requestVmStop(force: self.isPowerForce)
        }
    }
    
    @IBAction func startPauseButtonPressed(_ sender: Any) {
        enterSuspended(isBusy: true) // early indicator
        if vm.state == .vmStarted {
            vm.requestVmPause(save: true)
        } else if vm.state == .vmPaused {
            vm.requestVmResume()
        } else if vm.state == .vmStopped {
            vm.requestVmStart()
        } else {
            logger.error("Invalid state \(vm.state)")
        }
    }
    
    @IBAction func restartButtonPressed(_ sender: Any) {
        showConfirmAlert(NSLocalizedString("This will reset the VM and any unsaved state will be lost.", comment: "VMDisplayWindowController")) {
            DispatchQueue.global(qos: .background).async {
                self.vm.requestVmReset()
            }
        }
    }
    
    @IBAction dynamic func captureMouseButtonPressed(_ sender: Any) {
    }
    
    @IBAction dynamic func resizeConsoleButtonPressed(_ sender: Any) {
    }
    
    @IBAction dynamic func usbButtonPressed(_ sender: Any) {
    }
    
    @IBAction dynamic func drivesButtonPressed(_ sender: Any) {
    }
    
    @IBAction dynamic func sharedFolderButtonPressed(_ sender: Any) {
    }
    
    // MARK: - UI states
    
    override func windowDidLoad() {
        window!.recalculateKeyViewLoop()
        
        if vm.state == .vmStopped {
            enterSuspended(isBusy: false)
        } else {
            enterLive()
        }
        
        super.windowDidLoad()
    }
    
    public func requestAutoStart() {
        guard shouldAutoStartVM else {
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            if (self.vm.state == .vmStopped) {
                self.vm.requestVmStart()
            } else if (self.vm.state == .vmPaused) {
                self.vm.requestVmResume()
            }
        }
    }
    
    func enterLive() {
        overlayView.isHidden = true
        activityIndicator.stopAnimation(self)
        let pauseDescription = NSLocalizedString("Pause", comment: "VMDisplayWindowController")
        startPauseToolbarItem.image = NSImage(systemSymbolName: "pause", accessibilityDescription: pauseDescription)
        startPauseToolbarItem.label = pauseDescription
        stopToolbarItem.isEnabled = true
        restartToolbarItem.isEnabled = true
        captureMouseToolbarItem.isEnabled = true
        resizeConsoleToolbarItem.isEnabled = true
        window!.makeFirstResponder(displayView.subviews.first)
    }
    
    func enterSuspended(isBusy busy: Bool) {
        overlayView.isHidden = false
        let playDescription = NSLocalizedString("Play", comment: "VMDisplayWindowController")
        let stopped = vm.state == .vmStopped
        startPauseToolbarItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: playDescription)
        startPauseToolbarItem.label = playDescription
        if busy {
            activityIndicator.startAnimation(self)
            startPauseToolbarItem.isEnabled = false
            stopToolbarItem.isEnabled = false
            restartToolbarItem.isEnabled = false
            startButton.isHidden = true
        } else {
            activityIndicator.stopAnimation(self)
            startPauseToolbarItem.isEnabled = true
            startButton.isHidden = false
            stopToolbarItem.isEnabled = !stopped
            restartToolbarItem.isEnabled = !stopped
        }
        captureMouseToolbarItem.isEnabled = false
        resizeConsoleToolbarItem.isEnabled = false
        drivesToolbarItem.isEnabled = false
        sharedFolderToolbarItem.isEnabled = false
        usbToolbarItem.isEnabled = false
        window!.makeFirstResponder(nil)
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
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !(vm.state == .vmStopped || (vm.state == .vmPaused && vm.hasSaveState)) else {
            return true
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Confirmation", comment: "VMDisplayWindowController")
        alert.informativeText = NSLocalizedString("Closing this window will kill the VM.", comment: "VMDisplayMetalWindowController")
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "VMDisplayWindowController"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "VMDisplayWindowController"))
        alert.beginSheetModal(for: sender) { response in
            switch response {
            case .alertFirstButtonReturn:
                sender.close()
            default:
                return
            }
        }
        return false
    }
    
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.global(qos: .background).async {
            self.vm.requestVmStop(force: true)
        }
        onClose?(notification)
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        if let window = self.window {
            _ = window.makeFirstResponder(displayView.subviews.first)
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if let window = self.window {
            _ = window.makeFirstResponder(nil)
        }
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
    func virtualMachine(_ vm: UTMVirtualMachine, didTransitionTo state: UTMVMState) {
        switch state {
        case .vmStopped, .vmPaused:
            enterSuspended(isBusy: false)
        case .vmPausing, .vmStopping, .vmStarting, .vmResuming:
            enterSuspended(isBusy: true)
        case .vmStarted:
            enterLive()
        @unknown default:
            break
        }
    }
    
    func virtualMachine(_ vm: UTMVirtualMachine, didErrorWithMessage message: String) {
        showErrorAlert(message) { _ in
            if vm.state != .vmStarted && vm.state != .vmPaused {
                self.close()
            }
        }
    }
}
