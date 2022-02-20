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
    
    private(set) var lastDisplayChangeResize: Bool = false {
        willSet {
            optionalObjectWillChange()
        }
        
        didSet {
            guard let viewController = self.viewController as? VMDisplayMetalViewController else {
                return
            }
            guard hasLegacyToolbar else {
                return
            }
            if (lastDisplayChangeResize) {
                viewController.zoomButton.setImage(UIImage(named: "Toolbar Minimize"), for: .normal)
            } else {
                viewController.zoomButton.setImage(UIImage(named: "Toolbar Maximize"), for: .normal)
            }
        }
    }
    
    private(set) var isBusy: Bool = false {
        willSet {
            optionalObjectWillChange()
        }
    }
    
    private(set) var isRunning: Bool = false {
        willSet {
            optionalObjectWillChange()
        }
    }
    
    var isUsbSupported: Bool = false {
        willSet {
            optionalObjectWillChange()
        }
        
        didSet {
            guard hasLegacyToolbar else {
                return
            }
            guard let viewController = self.viewController else {
                return
            }
            viewController.usbButton.isHidden = !isUsbSupported
        }
    }
    
    private var longIdleTask: DispatchWorkItem?
    
    @objc var isUserInteracting: Bool = true {
        willSet {
            optionalObjectWillChange()
        }
    }
    
    private func optionalObjectWillChange() {
        if #available(iOS 14, *) {
            self.objectWillChange.send()
        }
    }
    
    @objc func hide() {
        guard hasLegacyToolbar else {
            return
        }
        guard let viewController = self.viewController else {
            return
        }
        UIView.transition(with: viewController.view, duration: 0.3, options: .transitionCrossDissolve) {
            viewController.toolbarAccessoryView.isHidden = true
            viewController.prefersStatusBarHidden = true
        } completion: { _ in
        }
        if !viewController.bool(forSetting: "HasShownHideToolbarAlert") {
            viewController.showAlert(NSLocalizedString("Hint: To show the toolbar again, use a three-finger swipe down on the screen.", comment: "VMDisplayViewController"), actions: nil) { action in
                UserDefaults.standard.set(true, forKey: "HasShownHideToolbarAlert")
            }
        }
    }
    
    @objc func show() {
        guard hasLegacyToolbar else {
            return
        }
        guard let viewController = self.viewController else {
            return
        }
        UIView.transition(with: viewController.view, duration: 0.3, options: .transitionCrossDissolve) {
            viewController.toolbarAccessoryView.isHidden = false
            if !viewController.largeScreen {
                viewController.prefersStatusBarHidden = false
            }
        } completion: { _ in
        }
    }
    
    private func setIsUserInteracting(_ value: Bool) {
        if #available(iOS 14, *), !UIAccessibility.isReduceMotionEnabled {
            withAnimation {
                self.isUserInteracting = value
            }
        } else {
            self.isUserInteracting = value
        }
    }
    
    func assertUserInteraction() {
        guard !hasLegacyToolbar else {
            return
        }
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
        guard hasLegacyToolbar else {
            return
        }
        guard let viewController = self.viewController else {
            return
        }
        if busy {
            viewController.pauseResumeButton.isEnabled = false
            viewController.powerExitButton.setImage(UIImage(named: "Toolbar Exit")!, for: .normal)
        } else {
            viewController.toolbarVisible = true
            viewController.pauseResumeButton.isEnabled = true
            viewController.pauseResumeButton.setImage(UIImage(named: "Toolbar Start")!, for: .normal)
            viewController.powerExitButton.setImage(UIImage(named: "Toolbar Exit")!, for: .normal)
        }
        viewController.restartButton.isEnabled = false
        viewController.zoomButton.isEnabled = false
        viewController.keyboardButton.isEnabled = false
        viewController.drivesButton.isEnabled = false
        viewController.usbButton.isEnabled = false
    }
    
    @objc func enterLive() {
        isBusy = false
        isRunning = true
        guard hasLegacyToolbar else {
            return
        }
        guard let viewController = self.viewController else {
            return
        }
        viewController.pauseResumeButton.isEnabled = true
        viewController.restartButton.isEnabled = true
        viewController.zoomButton.isEnabled = true
        viewController.keyboardButton.isEnabled = true
        viewController.drivesButton.isEnabled = true
        viewController.usbButton.isEnabled = viewController.vm.hasUsbRedirection
        viewController.pauseResumeButton.setImage(UIImage(named: "Toolbar Pause")!, for: .normal)
        viewController.powerExitButton.setImage(UIImage(named: "Toolbar Power")!, for: .normal)
    }
    
    @objc func changeDisplayZoomPressed() {
        guard let viewController = self.viewController as? VMDisplayMetalViewController else {
            return
        }
        if self.lastDisplayChangeResize {
            viewController.resetDisplay()
        } else {
            viewController.resizeDisplayToFit()
        }
        self.lastDisplayChangeResize = !self.lastDisplayChangeResize;
    }
    
    @objc func pauseResumePressed() {
        guard let viewController = self.viewController else {
            return
        }
        DispatchQueue.global(qos: .background).async {
            if viewController.vm.state == .vmStarted {
                viewController.vm.pauseVM()
                viewController.vm.saveVM()
            } else if viewController.vm.state == .vmPaused {
                viewController.vm.resumeVM()
            }
        }
    }
    
    @objc func powerPressed() {
        guard let viewController = self.viewController else {
            return
        }
        if viewController.vm.state == .vmStarted {
            let yes = UIAlertAction(title: NSLocalizedString("Yes", comment: "VMDisplayViewController"), style: .destructive) { action in
                DispatchQueue.global(qos: .background).async {
                    viewController.vm.deleteSaveVM()
                    viewController.vm.quitVM()
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
                viewController.vm.resetVM()
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
    
    @objc func hideToolbarPressed() {
        guard let viewController = self.viewController else {
            return
        }
        viewController.toolbarVisible = false
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

@available(iOS 14, *)
extension VMToolbarActions: ObservableObject {
}
