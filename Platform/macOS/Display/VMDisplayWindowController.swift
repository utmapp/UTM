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
    
    var shouldAutoStartVM: Bool = true
    var vm: UTMVirtualMachine!
    var onClose: ((Notification) -> Void)?
    var vmMessage: String?
    var vmConfiguration: UTMConfigurable?
    var toolbarVisible: Bool = false // ignored
    var keyboardVisible: Bool = false // ignored
    
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
                    self.virtualMachineHasStarted(self.vm)
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
    
    @IBAction dynamic func drivesButtonPressed(_ sender: Any) {
    }
    
    @IBAction dynamic func sharedFolderButtonPressed(_ sender: Any) {
    }
    
    // MARK: - UI states
    
    override func windowDidLoad() {
        window!.recalculateKeyViewLoop()
        
        if vm.state == .vmStopped || vm.state == .vmSuspended {
            enterSuspended(isBusy: false)
            if shouldAutoStartVM {
                DispatchQueue.global(qos: .userInitiated).async {
                    if self.vm.startVM() {
                        self.virtualMachineHasStarted(self.vm)
                    }
                }
            }
        } else {
            enterLive()
            virtualMachineHasStarted(vm)
        }
        
        super.windowDidLoad()
    }
    
    func enterLive() {
        overlayView.isHidden = true
        activityIndicator.stopAnimation(self)
        let pauseDescription = NSLocalizedString("Pause", comment: "VMDisplayWindowController")
        startPauseToolbarItem.image = NSImage(systemSymbolName: "pause", accessibilityDescription: pauseDescription)
        startPauseToolbarItem.label = pauseDescription
        stopToolbarItem.isEnabled = true
        captureMouseToolbarItem.isEnabled = true
        resizeConsoleToolbarItem.isEnabled = true
        window!.makeFirstResponder(displayView.subviews.first)
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
    
    internal func virtualMachineHasStarted(_ vm: UTMVirtualMachine) {
        
    }
}

extension VMDisplayWindowController: NSWindowDelegate {
    func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
        return [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard vm.state != .vmStopped && vm.state != .vmSuspended && vm.state != .vmError else {
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
            self.vm.quitVM(force: true)
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
