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

import IOKit.pwr_mgt

class VMDisplayWindowController: NSWindowController, UTMVirtualMachineDelegate {
    
    @IBOutlet weak var displayView: NSView!
    @IBOutlet weak var screenshotView: NSImageView!
    @IBOutlet weak var overlayView: NSVisualEffectView!
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    @IBOutlet weak var startButton: NSButton!
    
    @IBOutlet weak var toolbar: NSToolbar!
    @IBOutlet weak var stopToolbarItem: NSMenuToolbarItem!
    @IBOutlet weak var startPauseToolbarItem: NSToolbarItem!
    @IBOutlet weak var restartToolbarItem: NSToolbarItem!
    @IBOutlet weak var captureMouseToolbarItem: NSToolbarItem!
    @IBOutlet weak var captureMouseToolbarButton: NSButton!
    @IBOutlet weak var usbToolbarItem: NSToolbarItem!
    @IBOutlet weak var drivesToolbarItem: NSToolbarItem!
    @IBOutlet weak var sharedFolderToolbarItem: NSToolbarItem!
    @IBOutlet weak var resizeConsoleToolbarItem: NSToolbarItem!
    @IBOutlet weak var windowsToolbarItem: NSToolbarItem!
    
    var shouldAutoStartVM: Bool = true
    var vm: (any UTMVirtualMachine)!
    var onClose: (() -> Void)?
    private(set) var secondaryWindows: [VMDisplayWindowController] = []
    private(set) weak var primaryWindow: VMDisplayWindowController?
    private var preventIdleSleepAssertion: IOPMAssertionID?
    private var hasSaveSnapshotFailed: Bool = false
    private var isFinalizing: Bool = false

    @Setting("PreventIdleSleep") private var isPreventIdleSleep: Bool = false
    @Setting("NoQuitConfirmation") private var isNoQuitConfirmation: Bool = false
    
    var isSecondary: Bool {
        primaryWindow != nil
    }
    
    override var windowNibName: NSNib.Name? {
        "VMDisplayWindow"
    }
    
    override weak var owner: AnyObject? {
        self
    }
    
    convenience init(vm: any UTMVirtualMachine, onClose: (() -> Void)?) {
        self.init(window: nil)
        self.vm = vm
        self.onClose = onClose
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    private func stop(isKill: Bool = false) {
        showConfirmAlert(NSLocalizedString("This may corrupt the VM and any unsaved changes will be lost. To quit safely, shut down from the guest.", comment: "VMDisplayWindowController")) {
            self.enterSuspended(isBusy: true) // early indicator
            if self.vm.registryEntry.isSuspended {
                self.vm.requestVmDeleteState()
            }
            self.vm.requestVmStop(force: isKill)
        }
    }
    
    @IBAction func stopButtonPressed(_ sender: Any) {
        stop(isKill: false)
    }
    
    @IBAction func startPauseButtonPressed(_ sender: Any) {
        enterSuspended(isBusy: true) // early indicator
        if vm.state == .started {
            vm.requestVmPause()
        } else if vm.state == .paused {
            vm.requestVmResume()
        } else if vm.state == .stopped {
            vm.requestVmStart()
        } else {
            logger.error("Invalid state \(vm.state)")
        }
    }
    
    @IBAction func restartButtonPressed(_ sender: Any) {
        showConfirmAlert(NSLocalizedString("This will reset the VM and any unsaved state will be lost.", comment: "VMDisplayWindowController")) {
            self.vm.requestVmReset()
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
    
    @IBAction dynamic func windowsButtonPressed(_ sender: Any) {
    }
    
    // MARK: - UI states
    
    override func windowDidLoad() {
        window!.recalculateKeyViewLoop()
        setupStopButtonMenu()
        
        if vm.state == .stopped {
            enterSuspended(isBusy: false)
        } else {
            enterLive()
        }
        
        super.windowDidLoad()
    }
    
    public func requestAutoStart(options: UTMVirtualMachineStartOptions = []) {
        guard shouldAutoStartVM else {
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            if (self.vm.state == .stopped) {
                self.vm.requestVmStart(options: options)
            } else if (self.vm.state == .paused) {
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
        startPauseToolbarItem.isEnabled = true
        stopToolbarItem.isEnabled = true
        restartToolbarItem.isEnabled = true
        captureMouseToolbarItem.isEnabled = true
        resizeConsoleToolbarItem.isEnabled = true
        windowsToolbarItem.isEnabled = true
        window!.makeFirstResponder(displayView.subviews.first)
        if isPreventIdleSleep && !isSecondary {
            var preventIdleSleepAssertion: IOPMAssertionID = .zero
            let success = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,
                                                      IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                      "UTM Virtual Machine Running" as CFString,
                                                      &preventIdleSleepAssertion)
            if success == kIOReturnSuccess {
                self.preventIdleSleepAssertion = preventIdleSleepAssertion
            }
        }
    }
    
    func enterSuspended(isBusy busy: Bool) {
        overlayView.isHidden = false
        let playDescription = NSLocalizedString("Play", comment: "VMDisplayWindowController")
        let stopped = vm.state == .stopped
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
        windowsToolbarItem.isEnabled = false
        window!.makeFirstResponder(nil)
        if let preventIdleSleepAssertion = preventIdleSleepAssertion {
            IOPMAssertionRelease(preventIdleSleepAssertion)
        }
    }
    
    // MARK: - Alert
    
    @MainActor
    func showErrorAlert(_ message: String, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        window?.resignKey()
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString("Error", comment: "VMDisplayWindowController")
        alert.informativeText = message
        alert.beginSheetModal(for: window!, completionHandler: handler)
    }
    
    @MainActor
    func showConfirmAlert(_ message: String, confirmHandler handler: (() -> Void)? = nil) {
        window?.resignKey()
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
    
    // MARK: - Create a secondary window
    
    func registerSecondaryWindow(_ secondaryWindow: VMDisplayWindowController, at index: Int? = nil) {
        secondaryWindows.insert(secondaryWindow, at: index ?? secondaryWindows.endIndex)
        secondaryWindow.onClose = { [weak self] in
            self?.secondaryWindows.removeAll(where: { $0 == secondaryWindow })
        }
        secondaryWindow.primaryWindow = self
        secondaryWindow.showWindow(self)
        self.showWindow(self) // show primary window on top
        secondaryWindow.virtualMachine(vm, didTransitionToState: vm.state) // show correct starting state
    }
    
    // MARK: - Virtual machine delegate
    
    func virtualMachine(_ vm: any UTMVirtualMachine, didTransitionToState state: UTMVirtualMachineState) {
        Task { @MainActor in
            guard !isFinalizing else {
                return
            }
            switch state {
            case .stopped, .paused:
                enterSuspended(isBusy: false)
            case .pausing, .stopping, .starting, .resuming, .saving, .restoring:
                enterSuspended(isBusy: true)
            case .started:
                enterLive()
            }
            for subwindow in secondaryWindows {
                subwindow.virtualMachine(vm, didTransitionToState: state)
            }
        }
    }
    
    func virtualMachine(_ vm: any UTMVirtualMachine, didErrorWithMessage message: String) {
        Task { @MainActor in
            guard !isFinalizing else {
                return
            }
            showErrorAlert(message) { _ in
                if vm.state != .started && vm.state != .paused {
                    self.close()
                }
            }
        }
    }
    
    func virtualMachine(_ vm: any UTMVirtualMachine, didCompleteInstallation success: Bool) {
        
    }
    
    func virtualMachine(_ vm: any UTMVirtualMachine, didUpdateInstallationProgress progress: Double) {
        
    }
}

extension VMDisplayWindowController: NSWindowDelegate {
    func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
        return proposedOptions.union([.autoHideToolbar])
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isSecondary else {
            return true
        }
        guard !(vm.state == .stopped || (vm.state == .paused && vm.registryEntry.isSuspended)) else {
            return true
        }
        if let snapshotUnsupportedError = vm.snapshotUnsupportedError {
            return windowWillCloseAfterConfirmation(sender, error: snapshotUnsupportedError)
        } else if hasSaveSnapshotFailed {
            return windowWillCloseAfterConfirmation(sender)
        } else {
            return windowWillCloseAfterSaving(sender)
        }
    }
    
    private func windowWillCloseAfterConfirmation(_ sender: NSWindow, error: Error? = nil) -> Bool {
        guard !isNoQuitConfirmation else {
            return true
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        if error == nil {
            alert.messageText = NSLocalizedString("Confirmation", comment: "VMDisplayWindowController")
        } else {
            alert.messageText = NSLocalizedString("Failed to save suspend state", comment: "VMDisplayWindowController")
        }
        alert.informativeText = NSLocalizedString("Closing this window will kill the VM.", comment: "VMQemuDisplayMetalWindowController")
        if let error = error {
            alert.informativeText = error.localizedDescription + "\n" + alert.informativeText
        }
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "VMDisplayWindowController"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "VMDisplayWindowController"))
        alert.showsSuppressionButton = true
        alert.beginSheetModal(for: sender) { response in
            switch response {
            case .alertFirstButtonReturn:
                if alert.suppressionButton?.state == .on {
                    self.isNoQuitConfirmation = true
                }
                sender.close()
            default:
                return
            }
        }
        return false
    }
    
    private func windowWillCloseAfterSaving(_ sender: NSWindow) -> Bool {
        Task {
            do {
                try await vm.saveSnapshot(name: nil)
                vm.delegate = nil
                self.enterSuspended(isBusy: false)
                sender.close()
            } catch {
                hasSaveSnapshotFailed = true
                _ = windowWillCloseAfterConfirmation(sender, error: error)
            }
        }
        return false
    }
    
    func windowWillClose(_ notification: Notification) {
        if !isSecondary {
            self.vm.requestVmStop(force: true)
        }
        secondaryWindows.forEach { secondaryWindow in
            secondaryWindow.close()
        }
        if let preventIdleSleepAssertion = preventIdleSleepAssertion {
            IOPMAssertionRelease(preventIdleSleepAssertion)
        }
        isFinalizing = true
        onClose?()
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

// MARK: - Stop menu
extension VMDisplayWindowController {
    private func setupStopButtonMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let item1 = NSMenuItem()
        item1.title = NSLocalizedString("Request power down", comment: "VMDisplayWindowController")
        item1.toolTip = NSLocalizedString("Sends power down request to the guest. This simulates pressing the power button on a PC.", comment: "VMDisplayWindowController")
        item1.target = self
        item1.action = #selector(requestPowerDown)
        menu.addItem(item1)
        let item2 = NSMenuItem()
        item2.title = NSLocalizedString("Force shut down", comment: "VMDisplayWindowController")
        item2.toolTip = NSLocalizedString("Tells the VM process to shut down with risk of data corruption. This simulates holding down the power button on a PC.", comment: "VMDisplayWindowController")
        item2.target = self
        item2.action = #selector(forceShutDown)
        menu.addItem(item2)
        if type(of: vm).capabilities.supportsProcessKill {
            let item3 = NSMenuItem()
            item3.title = NSLocalizedString("Force kill", comment: "VMDisplayWindowController")
            item3.toolTip = NSLocalizedString("Force kill the VM process with high risk of data corruption.", comment: "VMDisplayWindowController")
            item3.target = self
            item3.action = #selector(forceKill)
            menu.addItem(item3)
        }
        stopToolbarItem.menu = menu
    }
    
    @MainActor @objc private func requestPowerDown(sender: AnyObject) {
        vm.requestGuestPowerDown()
    }
    
    @MainActor @objc private func forceShutDown(sender: AnyObject) {
        stop()
    }
    
    @MainActor @objc private func forceKill(sender: AnyObject) {
        stop(isKill: true)
    }
}

// MARK: - Computer wakeup
extension VMDisplayWindowController {
    @objc func didWake(_ notification: NSNotification) {
        // do something in subclass
    }
}
