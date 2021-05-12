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

import Carbon.HIToolbox

class VMDisplayMetalWindowController: VMDisplayWindowController {
    var metalView: VMMetalView!
    var renderer: UTMRenderer?
    
    @objc fileprivate weak var vmDisplay: CSDisplayMetal?
    @objc fileprivate weak var vmInput: CSInput?
    @objc fileprivate weak var vmUsbManager: CSUSBManager?
    
    private var displaySizeObserver: NSKeyValueObservation?
    private var displaySize: CGSize = .zero
    private var isDisplaySizeDynamic: Bool = false
    private var isFullScreen: Bool = false
    private let minDynamicSize = CGSize(width: 800, height: 600)
    
    private var localEventMonitor: Any? = nil
    private var ctrlKeyDown: Bool = false
    
    private var allUsbDevices: [CSUSBDevice] = []
    private var connectedUsbDevices: [CSUSBDevice] = []
    
    // MARK: - User preferences
    
    @Setting("NoCursorCaptureAlert") private var isCursorCaptureAlertShown: Bool = false
    @Setting("AlwaysNativeResolution") private var isAlwaysNativeResolution: Bool = false
    @Setting("DisplayFixed") private var isDisplayFixed: Bool = false
    @Setting("CtrlRightClick") private var isCtrlRightClick: Bool = false
    @Setting("NoUsbPrompt") private var isNoUsbPrompt: Bool = false
    private var settingObservations = [NSKeyValueObservation]()
    
    // MARK: - Init
    
    override func windowDidLoad() {
        super.windowDidLoad()
        metalView = VMMetalView(frame: displayView.bounds)
        metalView.autoresizingMask = [.width, .height]
        metalView.device = MTLCreateSystemDefaultDevice()
        guard let _ = metalView.device else {
            showErrorAlert(NSLocalizedString("Metal is not supported on this device. Cannot render display.", comment: "VMDisplayMetalWindowController"))
            logger.critical("Cannot find system default Metal device.")
            return
        }
        displayView.addSubview(metalView)
        renderer = UTMRenderer.init(metalKitView: metalView)
        guard let renderer = self.renderer else {
            showErrorAlert(NSLocalizedString("Internal error.", comment: "VMDisplayMetalWindowController"))
            logger.critical("Failed to create renderer.")
            return
        }
        renderer.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
        renderer.changeUpscaler(vmConfiguration?.displayUpscalerValue ?? .linear, downscaler: vmConfiguration?.displayDownscalerValue ?? .linear)
        metalView.delegate = renderer
        metalView.inputDelegate = self
        
        settingObservations.append(UserDefaults.standard.observe(\.AlwaysNativeResolution, options: .new) { (defaults, change) in
            self.displaySizeDidChange(size: self.displaySize)
        })
        settingObservations.append(UserDefaults.standard.observe(\.DisplayFixed, options: .new) { (defaults, change) in
            self.displaySizeDidChange(size: self.displaySize)
        })
        
        if vm.state == .vmStopped || vm.state == .vmSuspended {
            enterSuspended(isBusy: false)
            DispatchQueue.global(qos: .userInitiated).async {
                if self.vm.startVM() {
                    self.vm.ioDelegate = self
                }
            }
        } else {
            enterLive()
            vm.ioDelegate = self
        }
    }
    
    override func enterLive() {
        metalView.isHidden = false
        screenshotView.isHidden = true
        displaySizeObserver = observe(\.vmDisplay!.displaySize, options: [.initial, .new]) { (_, change) in
            guard let size = change.newValue else { return }
            self.displaySizeDidChange(size: size)
        }
        if vmConfiguration!.shareClipboardEnabled {
            UTMPasteboard.general.requestPollingMode(forHashable: self) // start clipboard polling
        }
        // monitor Cmd+Q and Cmd+W and capture them if needed
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            if !self.handleCaptureKeys(for: event) {
                return event
            } else {
                return nil
            }
        }
        super.enterLive()
        resizeConsoleToolbarItem.isEnabled = false // disable item
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if !busy {
            metalView.isHidden = true
            screenshotView.image = vm.screenshot?.image
            screenshotView.isHidden = false
        }
        if vmConfiguration!.shareClipboardEnabled {
            UTMPasteboard.general.releasePollingMode(forHashable: self) // stop clipboard polling
        }
        if vm.state == .vmStopped {
            connectedUsbDevices.removeAll()
            allUsbDevices.removeAll()
        }
        if let localEventMonitor = self.localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        super.enterSuspended(isBusy: busy)
    }
    
    override func captureMouseButtonPressed(_ sender: Any) {
        captureMouse()
    }
}

// MARK: - SPICE IO
extension VMDisplayMetalWindowController: UTMSpiceIODelegate {
    func spiceDidChange(_ input: CSInput) {
        vmInput = input
    }
    
    func spiceDidCreateDisplay(_ display: CSDisplayMetal) {
        if display.channelID == 0 && display.monitorID == 0 {
            vmDisplay = display
            renderer!.source = vmDisplay
        }
    }
    
    func spiceDidDestroyDisplay(_ display: CSDisplayMetal) {
        //TODO: implement something here
    }
    
    func spiceDidChange(_ usbManager: CSUSBManager) {
        if usbManager != vmUsbManager {
            connectedUsbDevices.removeAll()
            allUsbDevices.removeAll()
            vmUsbManager = usbManager
            usbManager.delegate = self
        }
    }
}
    
// MARK: - Screen management
extension VMDisplayMetalWindowController {
    fileprivate func displaySizeDidChange(size: CGSize) {
        guard size != .zero else {
            logger.debug("Ignoring zero size display")
            return
        }
        DispatchQueue.main.async {
            logger.debug("resizing to: (\(size.width), \(size.height))")
            guard let window = self.window else {
                logger.debug("Invalid window, ignoring size change")
                return
            }
            self.displaySize = size
            if self.isFullScreen {
                _ = self.updateHostScaling(for: window, frameSize: window.frame.size)
            } else {
                self.updateHostFrame(forGuestResolution: size)
            }
        }
    }
    
    func dynamicResolutionSupportDidChange(_ supported: Bool) {
        if isDisplaySizeDynamic != supported {
            displaySizeDidChange(size: displaySize)
        }
        isDisplaySizeDynamic = supported
    }
    
    func windowDidChangeScreen(_ notification: Notification) {
        logger.debug("screen changed")
        if let vmDisplay = self.vmDisplay {
            displaySizeDidChange(size: vmDisplay.displaySize)
        }
    }
    
    fileprivate func updateHostFrame(forGuestResolution size: CGSize) {
        guard let window = window else { return }
        guard let vmDisplay = vmDisplay else { return }
        let currentScreenScale = window.screen?.backingScaleFactor ?? 1.0
        let nativeScale = isAlwaysNativeResolution ? 1.0 : currentScreenScale
        // change optional scale if needed
        if isDisplaySizeDynamic || isDisplayFixed || (!isAlwaysNativeResolution && vmDisplay.viewportScale < currentScreenScale) {
            vmDisplay.viewportScale = nativeScale
        }
        let minScaledSize = CGSize(width: size.width * nativeScale / currentScreenScale, height: size.height * nativeScale / currentScreenScale)
        let fullContentWidth = size.width * vmDisplay.viewportScale / currentScreenScale
        let fullContentHeight = size.height * vmDisplay.viewportScale / currentScreenScale
        let contentRect = CGRect(x: window.frame.origin.x,
                                 y: 0,
                                 width: ceil(fullContentWidth),
                                 height: ceil(fullContentHeight))
        var windowRect = window.frameRect(forContentRect: contentRect)
        windowRect.origin.y = window.frame.origin.y + window.frame.height - windowRect.height
        if isDisplaySizeDynamic {
            window.contentMinSize = minDynamicSize
            window.contentResizeIncrements = NSSize(width: 1, height: 1)
            window.setFrame(windowRect, display: false, animate: false)
        } else {
            window.contentMinSize = minScaledSize
            window.contentAspectRatio = size
            window.setFrame(windowRect, display: false, animate: true)
        }
    }
    
    fileprivate func updateHostScaling(for window: NSWindow, frameSize: NSSize) -> NSSize {
        guard displaySize != .zero else { return frameSize }
        guard let vmDisplay = self.vmDisplay else { return frameSize }
        let currentScreenScale = window.screen?.backingScaleFactor ?? 1.0
        let targetContentSize = window.contentRect(forFrameRect: CGRect(origin: .zero, size: frameSize)).size
        let targetScaleX = targetContentSize.width * currentScreenScale / displaySize.width
        let targetScaleY = targetContentSize.height * currentScreenScale / displaySize.height
        let targetScale = min(targetScaleX, targetScaleY)
        let scaledSize = CGSize(width: displaySize.width * targetScale / currentScreenScale, height: displaySize.height * targetScale / currentScreenScale)
        let targetFrameSize = window.frameRect(forContentRect: CGRect(origin: .zero, size: scaledSize)).size
        vmDisplay.viewportScale = targetScale
        logger.debug("changed scale \(targetScale)")
        return targetFrameSize
    }
    
    fileprivate func updateGuestResolution(for window: NSWindow, frameSize: NSSize) -> NSSize {
        guard let vmDisplay = self.vmDisplay else { return frameSize }
        let currentScreenScale = window.screen?.backingScaleFactor ?? 1.0
        let nativeScale = isAlwaysNativeResolution ? currentScreenScale : 1.0
        let targetSize = window.contentRect(forFrameRect: CGRect(origin: .zero, size: frameSize)).size
        let targetSizeScaled = isAlwaysNativeResolution ? targetSize.applying(CGAffineTransform(scaleX: nativeScale, y: nativeScale)) : targetSize
        logger.debug("Requesting resolution: (\(targetSizeScaled.width), \(targetSizeScaled.height))")
        let bounds = CGRect(origin: .zero, size: targetSizeScaled)
        vmDisplay.requestResolution(bounds)
        return frameSize
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard !self.isDisplaySizeDynamic else {
            return frameSize
        }
        guard !self.isDisplayFixed else {
            return frameSize
        }
        return updateHostScaling(for: sender, frameSize: frameSize)
    }
    
    func windowDidEndLiveResize(_ notification: Notification) {
        guard self.isDisplaySizeDynamic, let window = self.window else {
            return
        }
        _ = updateGuestResolution(for: window, frameSize: window.frame.size)
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        isFullScreen = true
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        isFullScreen = false
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        if let window = self.window {
            _ = window.makeFirstResponder(metalView)
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if let window = self.window {
            _ = window.makeFirstResponder(nil)
        }
    }
}

// MARK: - Input events
extension VMDisplayMetalWindowController: VMMetalViewInputDelegate {
    private func captureMouse() {
        let action = { () -> Void in
            self.vm.requestInputTablet(false)
            self.metalView?.captureMouse()
        }
        if isCursorCaptureAlertShown {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Captured mouse", comment: "VMDisplayMetalWindowController")
            alert.informativeText = NSLocalizedString("To release the mouse cursor, press ⌃+⌥ (Ctrl+Opt or Ctrl+Alt) at the same time.", comment: "VMDisplayMetalWindowController")
            alert.showsSuppressionButton = true
            alert.beginSheetModal(for: window!) { _ in
                if alert.suppressionButton?.state ?? .off == .on {
                    self.isCursorCaptureAlertShown = false
                }
                DispatchQueue.main.async(execute: action)
            }
        } else {
            action()
        }
    }
    
    private func releaseMouse() {
        vm.requestInputTablet(true)
        metalView?.releaseMouse()
    }
    
    func mouseMove(absolutePoint: CGPoint, button: CSInputButton) {
        guard let window = self.window else { return }
        let currentScreenScale = window.screen?.backingScaleFactor ?? 1.0
        let viewportScale = vmDisplay?.viewportScale ?? 1.0
        let frameSize = metalView.frame.size
        let newX = absolutePoint.x * currentScreenScale / viewportScale
        let newY = (frameSize.height - absolutePoint.y) * currentScreenScale / viewportScale
        let point = CGPoint(x: newX, y: newY)
        logger.debug("move cursor: cocoa (\(absolutePoint.x), \(absolutePoint.y)), native (\(newX), \(newY))")
        vmInput?.sendMouseMotion(button, point: point)
        vmDisplay?.forceCursorPosition(point) // required to show cursor on screen
    }
    
    func mouseMove(relativePoint: CGPoint, button: CSInputButton) {
        let translated = CGPoint(x: relativePoint.x, y: -relativePoint.y)
        vmInput?.sendMouseMotion(button, point: translated)
    }
    
    private func modifyMouseButton(_ button: CSInputButton) -> CSInputButton {
        let buttonMod: CSInputButton
        if button.contains(.left) && ctrlKeyDown && isCtrlRightClick {
            buttonMod = button.subtracting(.left).union(.right)
        } else {
            buttonMod = button
        }
        return buttonMod
    }
    
    func mouseDown(button: CSInputButton) {
        vmInput?.sendMouseButton(modifyMouseButton(button), pressed: true, point: .zero)
    }
    
    func mouseUp(button: CSInputButton) {
        vmInput?.sendMouseButton(modifyMouseButton(button), pressed: false, point: .zero)
    }
    
    func mouseScroll(dy: CGFloat, button: CSInputButton) {
        var scrollDy = dy
        if vmConfiguration?.inputScrollInvert ?? false {
            scrollDy = -scrollDy
        }
        vmInput?.sendMouseScroll(.smooth, button: button, dy: dy)
    }
    
    private func sendExtendedKey(_ button: CSInputKey, keyCode: Int) {
        if (keyCode & 0xFF00) == 0xE000 {
            vmInput?.send(button, code: Int32(0x100 | (keyCode & 0xFF)))
        } else if keyCode >= 0x100 {
            logger.warning("ignored invalid keycode \(keyCode)");
        } else {
            vmInput?.send(button, code: Int32(keyCode))
        }
    }
    
    func keyDown(keyCode: Int) {
        if (keyCode & 0xFF) == 0x1D { // Ctrl
            ctrlKeyDown = true
        }
        sendExtendedKey(.press, keyCode: keyCode)
    }
    
    func keyUp(keyCode: Int) {
        if (keyCode & 0xFF) == 0x1D { // Ctrl
            ctrlKeyDown = false
        }
        sendExtendedKey(.release, keyCode: keyCode)
    }
    
    func requestReleaseCapture() {
        releaseMouse()
    }
    
    private func handleCaptureKeys(for event: NSEvent) -> Bool {
        // if captured we route all keyevents to view, even Cmd+Q and Cmd+W
        if let metalView = metalView, metalView.isMouseCaptured {
            if event.type == .keyDown {
                metalView.keyDown(with: event)
            } else if event.type == .keyUp {
                metalView.keyUp(with: event)
            }
            return true
        }
        // otherwise, we confirm Cmd+Q and Cmd+W
        if event.modifierFlags.contains(.command) && event.type == .keyDown {
            if event.keyCode == kVK_ANSI_Q {
                showConfirmAlert(NSLocalizedString("Quitting UTM will kill all running VMs.", comment: "VMDisplayMetalWindowController")) {
                    NSApp.terminate(self)
                }
                return true
            } else if event.keyCode == kVK_ANSI_W {
                if vm.state == .vmStarted {
                    showConfirmAlert(NSLocalizedString("Closing this window will kill the VM.", comment: "VMDisplayMetalWindowController")) {
                        DispatchQueue.global(qos: .background).async {
                            self.vm.quitVM()
                        }
                    }
                } else if vm.state == .vmStopped || vm.state == .vmError {
                    return false // we can close the window
                } else {
                    return true // do not close window when in progress
                }
            }
        } else if event.modifierFlags.contains(.command) && event.type == .keyUp {
            // for some reason, macOS doesn't like to send Cmd+KeyUp
            metalView.keyUp(with: event)
            return true
        }
        return false
    }
}

// MARK: - USB handling

extension VMDisplayMetalWindowController: CSUSBManagerDelegate {
    func spiceUsbManager(_ usbManager: CSUSBManager, deviceError error: String, for device: CSUSBDevice) {
        logger.debug("USB device error: (\(device)) \(error)")
        DispatchQueue.main.async {
            self.showErrorAlert(error)
        }
    }
    
    func spiceUsbManager(_ usbManager: CSUSBManager, deviceAttached device: CSUSBDevice) {
        logger.debug("USB device attached: \(device)")
        if !isNoUsbPrompt {
            DispatchQueue.main.async {
                if self.window!.isKeyWindow {
                    self.showConnectPrompt(for: device)
                }
            }
        }
    }
    
    func spiceUsbManager(_ usbManager: CSUSBManager, deviceRemoved device: CSUSBDevice) {
        logger.debug("USB device removed: \(device)")
        if let i = connectedUsbDevices.firstIndex(of: device) {
            connectedUsbDevices.remove(at: i)
        }
    }
    
    func showConnectPrompt(for usbDevice: CSUSBDevice) {
        guard let usbManager = vmUsbManager else {
            logger.error("cannot get usb manager")
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("USB Device", comment: "VMDisplayMetalWindowController")
        alert.informativeText = NSLocalizedString("Would you like to connect '\(usbDevice.name ?? usbDevice.description)' to this virtual machine?", comment: "VMDisplayMetalWindowController")
        alert.showsSuppressionButton = true
        alert.addButton(withTitle: NSLocalizedString("Confirm", comment: "VMDisplayMetalWindowController"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "VMDisplayMetalWindowController"))
        alert.beginSheetModal(for: window!) { response in
            if let suppressionButton = alert.suppressionButton,
               suppressionButton.state == .on {
                self.isNoUsbPrompt = true
            }
            guard response == .alertFirstButtonReturn else {
                return
            }
            DispatchQueue.global(qos: .background).async {
                usbManager.connectUsbDevice(usbDevice) { (result, message) in
                    DispatchQueue.main.async {
                        if let msg = message {
                            self.showErrorAlert(msg)
                        }
                        if result {
                            self.connectedUsbDevices.append(usbDevice)
                        }
                    }
                }
            }
        }
    }
}

extension VMDisplayMetalWindowController {
    @IBAction override func usbButtonPressed(_ sender: Any) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let item = NSMenuItem()
        item.title = NSLocalizedString("Querying USB devices...", comment: "VMDisplayMetalWindowController")
        item.isEnabled = false
        menu.addItem(item)
        DispatchQueue.global(qos: .userInitiated).async {
            let devices = self.vmUsbManager?.usbDevices ?? []
            DispatchQueue.main.async {
                self.updateUsbDevicesMenu(menu, devices: devices)
            }
        }
        if let event = NSApplication.shared.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: sender as! NSView)
        }
    }
    
    func updateUsbDevicesMenu(_ menu: NSMenu, devices: [CSUSBDevice]) {
        allUsbDevices = devices
        menu.removeAllItems()
        if devices.count == 0 {
            let item = NSMenuItem()
            item.title = NSLocalizedString("No USB devices detected.", comment: "VMDisplayMetalWindowController")
            item.isEnabled = false
            menu.addItem(item)
        }
        for (i, device) in devices.enumerated() {
            let item = NSMenuItem()
            let canRedirect = vmUsbManager?.canRedirectUsbDevice(device, errorMessage: nil) ?? false
            let isConnected = vmUsbManager?.isUsbDeviceConnected(device) ?? false
            let isConnectedToSelf = connectedUsbDevices.contains(device)
            item.title = device.name ?? device.description
            item.isEnabled = canRedirect && (isConnectedToSelf || !isConnected);
            item.state = isConnectedToSelf ? .on : .off;
            item.tag = i
            item.target = self
            item.action = isConnectedToSelf ? #selector(disconnectUsbDevice) : #selector(connectUsbDevice)
            menu.addItem(item)
        }
        menu.update()
    }
    
    @objc func connectUsbDevice(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for connectUsbDevice")
            return
        }
        guard let usbManager = vmUsbManager else {
            logger.error("cannot get usb manager")
            return
        }
        let device = allUsbDevices[menu.tag]
        DispatchQueue.global(qos: .background).async {
            usbManager.connectUsbDevice(device) { (result, message) in
                DispatchQueue.main.async {
                    if let msg = message {
                        self.showErrorAlert(msg)
                    }
                    if result {
                        self.connectedUsbDevices.append(device)
                    }
                }
            }
        }
    }
    
    @objc func disconnectUsbDevice(sender: AnyObject) {
        guard let menu = sender as? NSMenuItem else {
            logger.error("wrong sender for disconnectUsbDevice")
            return
        }
        guard let usbManager = vmUsbManager else {
            logger.error("cannot get usb manager")
            return
        }
        let device = allUsbDevices[menu.tag]
        DispatchQueue.global(qos: .background).async {
            usbManager.disconnectUsbDevice(device) { (result, message) in
                DispatchQueue.main.async {
                    if let msg = message {
                        self.showErrorAlert(msg)
                    }
                    if result {
                        self.connectedUsbDevices.removeAll(where: { $0 == device })
                    }
                }
            }
        }
    }
}
