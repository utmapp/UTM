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

private var memoryAlertOnce = false

@objc public extension VMDisplayViewController {
    var largeScreen: Bool {
        traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular
    }
    
    var autosaveBackground: Bool {
        bool(forSetting: "AutosaveBackground")
    }
    
    var autosaveLowMemory: Bool {
        bool(forSetting: "AutosaveLowMemory")
    }
    
    var runInBackground: Bool {
        bool(forSetting: "RunInBackground")
    }
    
    var disableIdleTimer: Bool {
        bool(forSetting: "DisableIdleTimer")
    }
}

// MARK: - View Loading
public extension VMDisplayViewController {
    func loadDisplayViewFromNib() {
        let nib = UINib(nibName: "VMDisplayView", bundle: nil)
        _ = nib.instantiate(withOwner: self, options: nil)
        assert(self.displayView != nil, "Failed to load main view from VMDisplayView nib")
        assert(self.inputAccessoryView != nil, "Failed to load input view from VMDisplayView nib")
        displayView.frame = view.bounds
        displayView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(displayView)
        
        // set up other nibs
        removableDrivesViewController = VMRemovableDrivesViewController(nibName: "VMRemovableDrivesView", bundle: nil)
        #if !WITH_QEMU_TCI
        usbDevicesViewController = VMUSBDevicesViewController(nibName: "VMUSBDevicesView", bundle: nil)
        #endif
    }
    
    @objc func createToolbar(in view: UIView) {
        toolbar = VMToolbarActions(with: self)
        guard floatingToolbarViewController == nil else {
            return
        }
        if #available(iOS 14, *) {
            // create new toolbar
            floatingToolbarViewController = UIHostingController(rootView: VMToolbarView(state: self.toolbar))
            let childView = floatingToolbarViewController.view!
            childView.backgroundColor = .clear
            view.addSubview(childView)
            childView.bindFrameToSuperviewBounds()
            addChild(floatingToolbarViewController)
            floatingToolbarViewController.didMove(toParent: self)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadDisplayViewFromNib()
        
        // view state and observers
        toolbarVisible = true
        
        if largeScreen {
            prefersStatusBarHidden = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        // remove legacy toolbar
        if !toolbar.hasLegacyToolbar {
            // remove legacy toolbar
            toolbarAccessoryView.removeFromSuperview()
        }
        
        // hide USB icon if not supported
        toolbar.isUsbSupported = vm.hasUsbRedirection
        
        let nc = NotificationCenter.default
        weak var _self = self
        notifications = NSMutableArray()
        notifications.add(nc.addObserver(forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { _ in
            _self?.keyboardDidShow()
        })
        notifications.add(nc.addObserver(forName: UIResponder.keyboardDidHideNotification, object: nil, queue: .main) { _ in
            _self?.keyboardDidHide()
        })
        notifications.add(nc.addObserver(forName: UIResponder.keyboardDidChangeFrameNotification, object: nil, queue: .main) { _ in
            _self?.keyboardDidChangeFrame()
        })
        notifications.add(nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            _self?.handleEnteredBackground()
        })
        notifications.add(nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            _self?.handleEnteredForeground()
        })
        notifications.add(nc.addObserver(forName: .UTMImport, object: nil, queue: .main) { _ in
            _self?.handleImportUTM()
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for notification in notifications {
            NotificationCenter.default.removeObserver(notification)
        }
        notifications.removeAllObjects()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if runInBackground {
            logger.info("Start location tracking to enable running in background")
            UTMLocationManager.sharedInstance().startUpdatingLocation()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        if autosaveLowMemory {
            logger.info("Saving VM state on low memory warning.")
            DispatchQueue.global(qos: .background).async {
                self.vm.requestVmSaveState()
            }
        }
        
        if !memoryAlertOnce {
            memoryAlertOnce = true
            showAlert(NSLocalizedString("Running low on memory! UTM might soon be killed by iOS. You can prevent this by decreasing the amount of memory and/or JIT cache assigned to this VM", comment: "VMDisplayViewController"), actions: nil, completion: nil)
        }
    }
}

@objc extension VMDisplayViewController {
    func enterSuspended(isBusy busy: Bool) {
        if busy {
            resumeBigButton.isHidden = true
            placeholderView.isHidden = false
            placeholderIndicator.startAnimating()
        } else {
            UIView.transition(with: view, duration: 0.5, options: .transitionCrossDissolve) {
                self.placeholderView.isHidden = false
                if self.vm.state == .vmPaused {
                    self.resumeBigButton.isHidden = false
                }
            } completion: { _ in
            }
            placeholderIndicator.stopAnimating()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        toolbar.enterSuspended(isBusy: busy)
    }
    
    func enterLive() {
        UIView.transition(with: view, duration: 0.5, options: .transitionCrossDissolve) {
            self.placeholderView.isHidden = true
            self.resumeBigButton.isHidden = true
        } completion: { _ in
        }
        placeholderIndicator.stopAnimating()
        UIApplication.shared.isIdleTimerDisabled = disableIdleTimer
        toolbar.enterLive()
    }
    
    private func suspend() {
        // dummy function for selector
    }
    
    func terminateApplication() {
        DispatchQueue.main.async { [self] in
            // animate to home screen
            let app = UIApplication.shared
            app.performSelector(onMainThread: #selector(suspend), with: nil, waitUntilDone: true)
            
            // wait 2 seconds while app is going background
            Thread.sleep(forTimeInterval: 2)
            
            // exit app when app is in background
            exit(0);
        }
    }
}

// MARK: - Toolbar actions
@objc extension VMDisplayViewController {
    @IBAction func changeDisplayZoom(_ sender: UIButton) {
        toolbar.changeDisplayZoomPressed()
    }
    
    @IBAction func pauseResumePressed(_ sender: UIButton) {
        toolbar.pauseResumePressed()
    }
    
    @IBAction func powerPressed(_ sender: UIButton) {
        toolbar.powerPressed()
    }
    
    @IBAction func restartPressed(_ sender: UIButton) {
        toolbar.restartPressed()
    }
    
    @IBAction func showKeyboardButton(_ sender: UIButton) {
        toolbar.showKeyboardPressed()
    }
    
    @IBAction func hideToolbarButton(_ sender: UIButton) {
        toolbar.hideToolbarPressed()
    }
    
    @IBAction func drivesPressed(_ sender: UIButton) {
        toolbar.drivesPressed()
    }
    
    @IBAction func usbPressed(_ sender: UIButton) {
        toolbar.usbPressed()
    }
}

// MARK: Toolbar hiding
public extension VMDisplayViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch.type == .direct {
                toolbar.assertUserInteraction()
                break
            }
        }
        super.touchesBegan(touches, with: event)
    }
}

// MARK: Notification handling
extension VMDisplayViewController {
    func handleEnteredBackground() {
        logger.info("Entering background")
        if autosaveBackground && vm.state == .vmStarted {
            logger.info("Saving snapshot")
            var task: UIBackgroundTaskIdentifier = .invalid
            task = UIApplication.shared.beginBackgroundTask {
                logger.info("Background task end")
                UIApplication.shared.endBackgroundTask(task)
                task = .invalid
            }
            DispatchQueue.global(qos: .default).async {
                self.vm.requestVmSaveState()
                self.hasAutoSave = true
                logger.info("Save snapshot complete")
                UIApplication.shared.endBackgroundTask(task)
                task = .invalid
            }
        }
    }
    
    func handleEnteredForeground() {
        logger.info("Entering foreground!")
        if (hasAutoSave && vm.state == .vmStarted) {
            logger.info("Deleting snapshot")
            DispatchQueue.global(qos: .background).async {
                self.vm.requestVmDeleteState()
            }
        }
    }
    
    func keyboardDidShow() {
        keyboardVisible = true
    }
    
    func keyboardDidHide() {
        // workaround for notification when hw keyboard connected
        keyboardVisible = inputViewIsFirstResponder()
    }
    
    func keyboardDidChangeFrame() {
        updateKeyboardAccessoryFrame()
    }
    
    func handleImportUTM() {
        showAlert(NSLocalizedString("You must terminate the running VM before you can import a new VM.", comment: "VMDisplayViewController"), actions: nil, completion: nil)
    }
}
