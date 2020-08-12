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
    
    @IBOutlet weak var stopToolbarItem: NSToolbarItem!
    @IBOutlet weak var startPauseToolbarItem: NSToolbarItem!
    @IBOutlet weak var restartToolbarItem: NSToolbarItem!
    @IBOutlet weak var captureMouseToolbarItem: NSToolbarItem!
    @IBOutlet weak var drivesToolbarItem: NSToolbarItem!
    @IBOutlet weak var networkToolbarItem: NSToolbarItem!
    
    var vm: UTMVirtualMachine!
    var vmMessage: String?
    var vmConfiguration: UTMConfiguration?
    var toolbarVisible: Bool = false // ignored
    var keyboardVisible: Bool = false // ignored
    
    var isMouseCaptued: Bool = false
    
    override var windowNibName: NSNib.Name? {
        "VMDisplayWindow"
    }
    
    override weak var owner: AnyObject? {
        self
    }
    
    convenience init(vm: UTMVirtualMachine) {
        self.init(window: nil)
        self.vm = vm
        vm.delegate = self
    }
    
    @IBAction func stopButtonPressed(_ sender: Any) {
    }
    
    @IBAction func startPauseButtonPressed(_ sender: Any) {
    }
    
    @IBAction func restartButtonPressed(_ sender: Any) {
    }
    
    @IBAction func captureMouseButtonPressed(_ sender: Any) {
        isMouseCaptued.toggle()
    }
    
    @IBAction func drivesButtonPressed(_ sender: Any) {
    }
    
    @IBAction func networkButtonPressed(_ sender: Any) {
    }
    
    // MARK: - UI states
    
    func enterLive() {
        overlayView.isHidden = true
        activityIndicator.stopAnimation(self)
        let pauseDescription = NSLocalizedString("Pause", comment: "VMDisplayWindowController")
        startPauseToolbarItem.image = NSImage(systemSymbolName: "pause", accessibilityDescription: pauseDescription)
        startPauseToolbarItem.label = pauseDescription
        startPauseToolbarItem.isEnabled = true
        stopToolbarItem.isEnabled = true
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
    }
    
    // MARK: - Alert
    
    func showErrorAlert(_ message: String, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString("Error", comment: "VMDisplayWindowController")
        alert.informativeText = message
        alert.beginSheetModal(for: window!, completionHandler: handler)
    }
}

extension VMDisplayWindowController: NSWindowDelegate {
    func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
        return [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
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
            let message = vmMessage ?? NSLocalizedString("An internal error has occured. UTM will terminate.", comment: "VMDisplayWindowController")
            showErrorAlert(message)
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
