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
        
        // hide USB icon if not supported
        usbButton.isHidden = !vm.hasUsbRedirection
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
                self.vm.saveVM()
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
            pauseResumeButton.isEnabled = false
            placeholderView.isHidden = false
            placeholderIndicator.startAnimating()
            powerExitButton.setImage(UIImage(named: "Toolbar Exit")!, for: .normal)
        } else {
            UIView.transition(with: view, duration: 0.5, options: .transitionCrossDissolve) {
                self.placeholderView.isHidden = false
                if self.vm.state == .vmPaused {
                    self.resumeBigButton.isHidden = false
                }
            } completion: { _ in
            }
            placeholderIndicator.stopAnimating()
            toolbarVisible = true
            pauseResumeButton.isEnabled = true
            pauseResumeButton.setImage(UIImage(named: "Toolbar Start")!, for: .normal)
            powerExitButton.setImage(UIImage(named: "Toolbar Exit")!, for: .normal)
            UIApplication.shared.isIdleTimerDisabled = false
        }
        restartButton.isEnabled = false
        zoomButton.isEnabled = false
        keyboardButton.isEnabled = false
        drivesButton.isEnabled = false
        usbButton.isEnabled = false
    }
    
    func enterLive() {
        UIView.transition(with: view, duration: 0.5, options: .transitionCrossDissolve) {
            self.placeholderView.isHidden = true
            self.resumeBigButton.isHidden = true
        } completion: { _ in
        }
        placeholderIndicator.stopAnimating()
        pauseResumeButton.isEnabled = true
        restartButton.isEnabled = true
        zoomButton.isEnabled = true
        keyboardButton.isEnabled = true
        drivesButton.isEnabled = true
        usbButton.isEnabled = vm.hasUsbRedirection
        pauseResumeButton.setImage(UIImage(named: "Toolbar Pause")!, for: .normal)
        powerExitButton.setImage(UIImage(named: "Toolbar Power")!, for: .normal)
        UIApplication.shared.isIdleTimerDisabled = disableIdleTimer
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
    func hideToolbar() {
        UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
            self.toolbarAccessoryView.isHidden = true
            self.prefersStatusBarHidden = true
        } completion: { _ in
        }
        if !bool(forSetting: "HasShownHideToolbarAlert") {
            showAlert(NSLocalizedString("Hint: To show the toolbar again, use a three-finger swipe down on the screen.", comment: "VMDisplayViewController"), actions: nil) { action in
                UserDefaults.standard.set(true, forKey: "HasShownHideToolbarAlert")
            }
        }
    }
    
    func showToolbar() {
        UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
            self.toolbarAccessoryView.isHidden = false
            if !self.largeScreen {
                self.prefersStatusBarHidden = false
            }
        } completion: { _ in
        }
    }
    
    @IBAction func changeDisplayZoom(_ sender: UIButton) {
        
    }
    
    @IBAction func pauseResumePressed(_ sender: UIButton) {
        DispatchQueue.global(qos: .background).async {
            if self.vm.state == .vmStarted {
                self.vm.pauseVM()
                if !self.vm.saveVM() {
                    DispatchQueue.main.async {
                        self.showAlert(NSLocalizedString("Failed to save VM state. Do you have at least one read-write drive attached that supports snapshots?", comment: "VMDisplayViewController"), actions: nil, completion: nil)
                    }
                }
            } else if self.vm.state == .vmPaused {
                self.vm.resumeVM()
            }
        }
    }
    
    @IBAction func powerPressed(_ sender: UIButton) {
        if vm.state == .vmStarted {
            let yes = UIAlertAction(title: NSLocalizedString("Yes", comment: "VMDisplayViewController"), style: .destructive) { action in
                DispatchQueue.global(qos: .background).async {
                    self.vm.quitVM()
                    self.terminateApplication()
                }
            }
            let no = UIAlertAction(title: NSLocalizedString("No", comment: "VMDisplayViewController"), style: .cancel, handler: nil)
            self.showAlert(NSLocalizedString("Are you sure you want to stop this VM and exit? Any unsaved changes will be lost.", comment: "VMDisplayViewController"), actions: [yes, no], completion: nil)
        } else {
            let yes = UIAlertAction(title: NSLocalizedString("Yes", comment: "VMDisplayViewController"), style: .destructive) { action in
                self.terminateApplication()
            }
            let no = UIAlertAction(title: NSLocalizedString("No", comment: "VMDisplayViewController"), style: .cancel, handler: nil)
            self.showAlert(NSLocalizedString("Are you sure you want to exit UTM?", comment: "VMDisplayViewController"), actions: [yes, no], completion: nil)
        }
    }
    
    @IBAction func restartPressed(_ sender: UIButton) {
        let yes = UIAlertAction(title: NSLocalizedString("Yes", comment: "VMDisplayViewController"), style: .destructive) { action in
            DispatchQueue.global(qos: .background).async {
                self.vm.resetVM()
            }
        }
        let no = UIAlertAction(title: NSLocalizedString("No", comment: "VMDisplayViewController"), style: .cancel, handler: nil)
        self.showAlert(NSLocalizedString("Are you sure you want to reset this VM? Any unsaved changes will be lost.", comment: "VMDisplayViewController"), actions: [yes, no], completion: nil)
    }
    
    @IBAction func showKeyboardButton(_ sender: UIButton) {
        keyboardVisible = !keyboardVisible
    }
    
    @IBAction func hideToolbarButton(_ sender: UIButton) {
        toolbarVisible = false
    }
    
    @IBAction func drivesPressed(_ sender: UIButton) {
        removableDrivesViewController.modalPresentationStyle = .pageSheet
        removableDrivesViewController.vm = vm
        present(removableDrivesViewController, animated: true, completion: nil)
    }
    
    @IBAction func usbPressed(_ sender: UIButton) {
        #if !WITH_QEMU_TCI
        usbDevicesViewController.modalPresentationStyle = .pageSheet
        present(usbDevicesViewController, animated: true, completion: nil)
        #endif
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
                self.vm.saveVM()
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
                self.vm.deleteSaveVM()
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
