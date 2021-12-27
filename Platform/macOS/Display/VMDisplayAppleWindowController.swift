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
import Virtualization

@available(macOS 12, *)
class VMDisplayAppleWindowController: VMDisplayWindowController {
    var mainView: NSView?
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
        vmConfiguration as? UTMAppleConfiguration
    }
    
    private var cancellable: AnyCancellable?
    
    override func windowDidLoad() {
        if appleConfig.isConsoleDisplay {
            mainView = TerminalView()
            terminalView!.terminalDelegate = self
            cancellable = appleVM.$serialPort.sink { [weak self] serialPort in
                serialPort?.delegate = self
            }
        } else {
            mainView = VZVirtualMachineView()
            appleView!.capturesSystemKeys = true
        }
        mainView!.translatesAutoresizingMaskIntoConstraints = false
        displayView.addSubview(mainView!)
        NSLayoutConstraint.activate(mainView!.constraintsForAnchoringTo(boundsOf: displayView))
        window!.recalculateKeyViewLoop()
        shouldAutoStartVM = appleConfig.macRecoveryIpswURL == nil
        super.windowDidLoad()
        if let ipswUrl = appleConfig.macRecoveryIpswURL {
            showConfirmAlert(NSLocalizedString("Would you like to install macOS? If an existing operating system is already installed on the primary drive of this VM, then it will be erased.", comment: "VMDisplayAppleWindowController")) {
                self.isInstalling = true
                _ = self.appleVM.installVM(with: ipswUrl)
            }
        }
    }
    
    override func enterLive() {
        if let appleView = appleView {
            appleView.virtualMachine = appleVM.apple
        }
        isPowerForce = false
        captureMouseToolbarItem.isEnabled = false
        drivesToolbarItem.isEnabled = false
        usbToolbarItem.isEnabled = false
        restartToolbarItem.isEnabled = false // FIXME: enable this
        resizeConsoleToolbarItem.isEnabled = false
        sharedFolderToolbarItem.isEnabled = false
        window!.title = appleConfig.name
        updateWindowFrame()
        super.enterLive()
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if !busy, let appleView = appleView {
            appleView.virtualMachine = nil
        }
        isPowerForce = true
        super.enterSuspended(isBusy: busy)
    }
    
    override func virtualMachine(_ vm: UTMVirtualMachine, transitionTo state: UTMVMState) {
        super.virtualMachine(vm, transitionTo: state)
        if state == .vmStopped && isInstalling {
            didFinishInstallation()
        }
    }
    
    func updateWindowFrame() {
        guard let window = window else {
            return
        }
        if let terminalView = terminalView {
            if let fontSize = appleConfig.consoleFontSize?.intValue {
                //FIXME: support changing font
                let orig = terminalView.font
                let new = NSFont(descriptor: orig.fontDescriptor, size: CGFloat(fontSize)) ?? orig
                terminalView.font = new
            }
            terminalView.getTerminal().resize(cols: 80, rows: 24)
            let size = window.frameRect(forContentRect: terminalView.getOptimalFrameSize()).size
            let frame = CGRect(origin: window.frame.origin, size: size)
            window.minSize = size
            window.setFrame(frame, display: false, animate: true)
        } else {
            guard let primaryDisplay = appleConfig.displays.first else {
                return //FIXME: add multiple displays
            }
            let size = CGSize(width: primaryDisplay.widthInPixels, height: primaryDisplay.heightInPixels)
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
            if !appleVM.quitVM(force: false) {
                super.stopButtonPressed(sender)
            }
            isPowerForce = true
        }
    }
    
    override func resizeConsoleButtonPressed(_ sender: Any) {
        if let terminalView = terminalView {
            let cmd = appleConfig.consoleResizeCommand
            let cols = terminalView.getTerminal().cols
            let rows = terminalView.getTerminal().rows
            appleVM.serialPort?.writeResizeCommand(cmd, columns: cols, rows: rows)
        } else {
            updateWindowFrame()
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
            self.appleConfig.macRecoveryIpswURL = nil
            // start VM
            if self.vm.startVM() {
                self.didStartVirtualMachine(self.vm)
            }
        }
    }
    
    func virtualMachine(_ vm: UTMVirtualMachine, installationProgress completed: Double) {
        DispatchQueue.main.async {
            if completed >= 1 {
                self.window!.subtitle = ""
            } else {
                self.window!.subtitle = NSLocalizedString("Installation: \(Int(completed * 100))%", comment: "VMDisplayAppleWindowController")
            }
        }
    }
}

@available(macOS 12, *)
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
