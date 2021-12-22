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

import Virtualization

@available(macOS 12, *)
class VMDisplayAppleWindowController: VMDisplayWindowController {
    var appleView: VZVirtualMachineView!
    
    var appleVM: UTMAppleVirtualMachine! {
        vm as? UTMAppleVirtualMachine
    }
    
    var appleConfig: UTMAppleConfiguration! {
        vmConfiguration as? UTMAppleConfiguration
    }
    
    override func windowDidLoad() {
        appleView = VZVirtualMachineView()
        appleView.virtualMachine = appleVM.apple
        displayView.addSubview(appleView)
        NSLayoutConstraint.activate(appleView.constraintsForAnchoringTo(boundsOf: displayView))
        window!.recalculateKeyViewLoop()
        super.windowDidLoad()
    }
    
    override func enterLive() {
        drivesToolbarItem.isEnabled = false
        usbToolbarItem.isEnabled = false
        restartToolbarItem.isEnabled = false // FIXME: enable this
        resizeConsoleToolbarItem.isEnabled = false
        sharedFolderToolbarItem.isEnabled = false
        updateWindowFrame()
        super.enterLive()
    }
    
    func updateWindowFrame() {
        guard let window = window else {
            return
        }
        guard let primaryDisplay = appleConfig.displays.first else {
            return //FIXME: add multiple displays
        }
        let size = CGSize(width: primaryDisplay.widthInPixels, height: primaryDisplay.heightInPixels)
        let frame = window.frameRect(forContentRect: CGRect(origin: .zero, size: size))
        window.contentAspectRatio = size
        window.minSize = NSSize(width: 400, height: 400)
        window.setFrame(frame, display: false, animate: true)
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
