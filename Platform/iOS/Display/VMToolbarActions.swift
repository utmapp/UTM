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

import SwiftUI

@objc public class VMToolbarActions: NSObject {
    weak var viewController: VMDisplayViewController?
    
    init(with viewController: VMDisplayViewController) {
        self.viewController = viewController
    }
    
    @objc var hasLegacyToolbar: Bool {
        if #available(iOS 14, *) {
            return false
        } else {
            return true
        }
    }
    
    @objc private(set) var isLegacyToolbarVisible: Bool = false
    
    @objc var isViewportChanged: Bool = false {
        willSet {
            objectWillChange.send()
        }
    }
    
    private(set) var isBusy: Bool = false {
        willSet {
            objectWillChange.send()
        }
    }
    
    private(set) var isRunning: Bool = false {
        willSet {
            objectWillChange.send()
        }
    }
    
    var isUsbSupported: Bool = false {
        willSet {
            objectWillChange.send()
        }
    }
    
    private var longIdleTask: DispatchWorkItem?
    
    @objc var isUserInteracting: Bool = true {
        willSet {
            objectWillChange.send()
        }
    }
    
    private func setIsUserInteracting(_ value: Bool) {
        if !UIAccessibility.isReduceMotionEnabled {
            withAnimation {
                self.isUserInteracting = value
            }
        } else {
            self.isUserInteracting = value
        }
    }
    
    func assertUserInteraction() {
        if let task = longIdleTask {
            task.cancel()
        }
        setIsUserInteracting(true)
        longIdleTask = DispatchWorkItem {
            self.longIdleTask = nil
            self.setIsUserInteracting(false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: longIdleTask!)
    }
    
    @objc func enterSuspended(isBusy busy: Bool) {
        isBusy = busy
        isRunning = false
    }
    
    @objc func enterLive() {
        isBusy = false
        isRunning = true
    }
    
    @objc func changeDisplayZoomPressed() {
        guard let viewController = self.viewController as? VMDisplayMetalViewController else {
            return
        }
        if self.isViewportChanged {
            viewController.resetDisplay()
        } else {
            viewController.resizeDisplayToFit()
        }
        self.isViewportChanged = !self.isViewportChanged;
    }
    
    @objc func pauseResumePressed() {
        guard let viewController = self.viewController else {
            return
        }
        let shouldSaveState = !viewController.vm.isRunningAsSnapshot
        if viewController.vm.state == .vmStarted {
            viewController.enterSuspended(isBusy: true) // early indicator
            viewController.vm.requestVmPause(save: shouldSaveState)
        } else if viewController.vm.state == .vmPaused {
            viewController.enterSuspended(isBusy: true) // early indicator
            viewController.vm.requestVmResume()
        }
    }
    
    @objc func powerPressed() {
        guard let viewController = self.viewController else {
            return
        }
        if viewController.vm.state == .vmStarted {
            let yes = UIAlertAction(title: NSLocalizedString("Yes", comment: "VMDisplayViewController"), style: .destructive) { action in
                viewController.enterSuspended(isBusy: true) // early indicator
                viewController.vm.requestVmDeleteState()
                viewController.vm.vmStop { _ in
                    viewController.terminateApplication()
                }
            }
            let no = UIAlertAction(title: NSLocalizedString("No", comment: "VMDisplayViewController"), style: .cancel, handler: nil)
            viewController.showAlert(NSLocalizedString("Are you sure you want to stop this VM and exit? Any unsaved changes will be lost.", comment: "VMDisplayViewController"), actions: [yes, no], completion: nil)
        } else {
            let yes = UIAlertAction(title: NSLocalizedString("Yes", comment: "VMDisplayViewController"), style: .destructive) { action in
                viewController.terminateApplication()
            }
            let no = UIAlertAction(title: NSLocalizedString("No", comment: "VMDisplayViewController"), style: .cancel, handler: nil)
            viewController.showAlert(NSLocalizedString("Are you sure you want to exit UTM?", comment: "VMDisplayViewController"), actions: [yes, no], completion: nil)
        }
    }
    
    @objc func restartPressed() {
        guard let viewController = self.viewController else {
            return
        }
        let yes = UIAlertAction(title: NSLocalizedString("Yes", comment: "VMDisplayViewController"), style: .destructive) { action in
            DispatchQueue.global(qos: .background).async {
                viewController.vm.requestVmReset()
            }
        }
        let no = UIAlertAction(title: NSLocalizedString("No", comment: "VMDisplayViewController"), style: .cancel, handler: nil)
        viewController.showAlert(NSLocalizedString("Are you sure you want to reset this VM? Any unsaved changes will be lost.", comment: "VMDisplayViewController"), actions: [yes, no], completion: nil)
    }
    
    @objc func showKeyboardPressed() {
        guard let viewController = self.viewController else {
            return
        }
        viewController.keyboardVisible = !viewController.keyboardVisible
    }
    
    @objc func drivesPressed() {
        guard let viewController = self.viewController else {
            return
        }
        viewController.removableDrivesViewController.modalPresentationStyle = .pageSheet
        viewController.removableDrivesViewController.vm = viewController.vm
        viewController.present(viewController.removableDrivesViewController, animated: true, completion: nil)
    }
    
    @objc func usbPressed() {
        guard let viewController = self.viewController else {
            return
        }
        #if !WITH_QEMU_TCI
        viewController.usbDevicesViewController.modalPresentationStyle = .pageSheet
        viewController.present(viewController.usbDevicesViewController, animated: true, completion: nil)
        #endif
    }
}

extension VMToolbarActions: ObservableObject {
}
