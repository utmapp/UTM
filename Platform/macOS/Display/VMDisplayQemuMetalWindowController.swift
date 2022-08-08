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

import CocoaSpiceRenderer

class VMQemuDisplayMetalWindowController: VMDisplayQemuWindowController {
    var metalView: VMMetalView!
    var renderer: CSRenderer?
    
    private var vmDisplay: CSDisplay?
    private var vmInput: CSInput?
    
    private var displaySize: CGSize = .zero
    private var isDisplaySizeDynamic: Bool = false
    private var isFullScreen: Bool = false
    private let minDynamicSize = CGSize(width: 800, height: 600)
    private let resizeTimeoutSecs: Double = 5
    private var cancelResize: DispatchWorkItem?
    
    private var localEventMonitor: Any? = nil
    private var globalEventMonitor: Any? = nil
    private var ctrlKeyDown: Bool = false
    
    private var displayConfig: UTMQemuConfigurationDisplay? {
        vmQemuConfig?.displays[id]
    }
    
    override var defaultTitle: String {
        if isSecondary {
            return String.localizedStringWithFormat(NSLocalizedString("%@ (Display %lld)", comment: "VMDisplayMetalWindowController"), vmQemuConfig.information.name, id + 1)
        } else {
            return super.defaultTitle
        }
    }
    
    // MARK: - User preferences
    
    @Setting("NoCursorCaptureAlert") private var isCursorCaptureAlertShown: Bool = false
    @Setting("DisplayFixed") private var isDisplayFixed: Bool = false
    @Setting("CtrlRightClick") private var isCtrlRightClick: Bool = false
    @Setting("AlternativeCaptureKey") private var isAlternativeCaptureKey: Bool = false
    @Setting("IsCapsLockKey") private var isCapsLockKey: Bool = false
    @Setting("InvertScroll") private var isInvertScroll: Bool = false
    private var settingObservations = [NSKeyValueObservation]()
    
    // MARK: - Init
    
    convenience init(secondaryFromDisplay display: CSDisplay, primary: VMQemuDisplayMetalWindowController, vm: UTMQemuVirtualMachine, id: Int) {
        self.init(vm: vm, id: id)
        self.vmDisplay = display
        self.vmInput = primary.vmInput
        self.isDisplaySizeDynamic = primary.isDisplaySizeDynamic
    }
    
    override func windowDidLoad() {
        metalView = VMMetalView(frame: displayView.bounds)
        metalView.autoresizingMask = [.width, .height]
        metalView.device = MTLCreateSystemDefaultDevice()
        guard let _ = metalView.device else {
            showErrorAlert(NSLocalizedString("Metal is not supported on this device. Cannot render display.", comment: "VMDisplayMetalWindowController"))
            logger.critical("Cannot find system default Metal device.")
            return
        }
        displayView.addSubview(metalView)
        renderer = CSRenderer.init(metalKitView: metalView)
        guard let renderer = self.renderer else {
            showErrorAlert(NSLocalizedString("Internal error.", comment: "VMDisplayMetalWindowController"))
            logger.critical("Failed to create renderer.")
            return
        }
        renderer.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
        renderer.changeUpscaler(displayConfig?.upscalingFilter.metalSamplerMinMagFilter ?? .linear, downscaler: displayConfig?.downscalingFilter.metalSamplerMinMagFilter ?? .linear)
        renderer.source = vmDisplay // can be nil if primary
        metalView.delegate = renderer
        metalView.inputDelegate = self
        
        settingObservations.append(UserDefaults.standard.observe(\.DisplayFixed, options: .new) { (defaults, change) in
            self.displaySizeDidChange(size: self.displaySize)
        })
        
        super.windowDidLoad()
    }
    
    override func enterLive() {
        metalView.isHidden = false
        screenshotView.isHidden = true
        if vmQemuConfig!.sharing.hasClipboardSharing {
            UTMPasteboard.general.requestPollingMode(forHashable: self) // start clipboard polling
        }
        // monitor Cmd+Q and Cmd+W and capture them if needed
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            if let self = self, !self.handleCaptureKeys(for: event) {
                return event
            } else {
                return nil
            }
        }
        // monitor caps lock
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            if let self = self {
                // sync caps lock while window is outside focus
                self.syncCapsLock(with: event.modifierFlags)
            }
        }
        // resize if we already have a vmDisplay
        if let vmDisplay = vmDisplay {
            displaySizeDidChange(size: vmDisplay.displaySize)
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
        if vm.state == .vmStopped {
            vmDisplay = nil
            vmInput = nil
        }
        if vmQemuConfig!.sharing.hasClipboardSharing {
            UTMPasteboard.general.releasePollingMode(forHashable: self) // stop clipboard polling
        }
        if let localEventMonitor = self.localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let globalEventMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        releaseMouse()
        super.enterSuspended(isBusy: busy)
    }
    
    override func captureMouseButtonPressed(_ sender: Any) {
        captureMouse()
    }
}

// MARK: - SPICE IO
extension VMQemuDisplayMetalWindowController {
    override func spiceDidCreateInput(_ input: CSInput) {
        if vmInput == nil {
            vmInput = input
        }
        super.spiceDidCreateInput(input)
    }
    
    override func spiceDidDestroyInput(_ input: CSInput) {
        if vmInput == input {
            vmInput = nil
        }
        super.spiceDidDestroyInput(input)
    }
    
    override func spiceDidCreateDisplay(_ display: CSDisplay) {
        if !isSecondary && vmDisplay == nil && display.isPrimaryDisplay {
            vmDisplay = display
            renderer!.source = display
            displaySizeDidChange(size: display.displaySize)
        } else {
            super.spiceDidCreateDisplay(display)
        }
    }
    
    override func spiceDidDestroyDisplay(_ display: CSDisplay) {
        if vmDisplay == display {
            if isSecondary {
                DispatchQueue.main.async {
                    self.close()
                }
            } else {
                vmDisplay = nil
                renderer!.source = nil
            }
        } else {
            super.spiceDidDestroyDisplay(display)
        }
    }
    
    override func spiceDidUpdateDisplay(_ display: CSDisplay) {
        if vmDisplay == display {
            displaySizeDidChange(size: display.displaySize)
        } else {
            super.spiceDidUpdateDisplay(display)
        }
    }
    
    override func spiceDynamicResolutionSupportDidChange(_ supported: Bool) {
        guard displayConfig!.isDynamicResolution else {
            super.spiceDynamicResolutionSupportDidChange(supported)
            return
        }
        if isDisplaySizeDynamic != supported {
            displaySizeDidChange(size: displaySize)
            DispatchQueue.main.async {
                if supported, let window = self.window {
                    _ = self.updateGuestResolution(for: window, frameSize: window.frame.size)
                }
            }
        }
        isDisplaySizeDynamic = supported
        super.spiceDynamicResolutionSupportDidChange(supported)
    }
}
    
// MARK: - Screen management
extension VMQemuDisplayMetalWindowController {
    fileprivate func displaySizeDidChange(size: CGSize) {
        // cancel any pending resize
        cancelResize?.cancel()
        cancelResize = nil
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
        let nativeScale = displayConfig!.isNativeResolution ? 1.0 : currentScreenScale
        // change optional scale if needed
        if isDisplaySizeDynamic || isDisplayFixed || (!displayConfig!.isNativeResolution && vmDisplay.viewportScale < currentScreenScale) {
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
        let nativeScale = displayConfig!.isNativeResolution ? currentScreenScale : 1.0
        let targetSize = window.contentRect(forFrameRect: CGRect(origin: .zero, size: frameSize)).size
        let targetSizeScaled = displayConfig!.isNativeResolution ? targetSize.applying(CGAffineTransform(scaleX: nativeScale, y: nativeScale)) : targetSize
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
        let newSize = updateHostScaling(for: sender, frameSize: frameSize)
        if isFullScreen {
            return frameSize
        } else {
            return newSize
        }
    }
    
    func windowDidEndLiveResize(_ notification: Notification) {
        guard self.isDisplaySizeDynamic, let window = self.window else {
            return
        }
        _ = updateGuestResolution(for: window, frameSize: window.frame.size)
        cancelResize = DispatchWorkItem {
            if let vmDisplay = self.vmDisplay {
                self.displaySizeDidChange(size: vmDisplay.displaySize)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + resizeTimeoutSecs, execute: cancelResize!)
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        isFullScreen = true
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        isFullScreen = false
    }
    
    override func windowDidResignKey(_ notification: Notification) {
        releaseMouse()
        super.windowDidResignKey(notification)
    }
}

// MARK: - Input events
extension VMQemuDisplayMetalWindowController: VMMetalViewInputDelegate {
    var shouldUseCmdOptForCapture: Bool {
        isAlternativeCaptureKey || NSWorkspace.shared.isVoiceOverEnabled
    }
    
    func captureMouse() {
        let action = { () -> Void in
            self.qemuVM.requestInputTablet(false)
            self.metalView?.captureMouse()
            self.window?.subtitle = String.localizedStringWithFormat(NSLocalizedString("Press %@ to release cursor", comment: "VMQemuDisplayMetalWindowController"), self.shouldUseCmdOptForCapture ? "⌘+⌥" : "⌃+⌥")
            self.window?.makeFirstResponder(self.metalView)
            self.syncCapsLock()
        }
        if isCursorCaptureAlertShown {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Captured mouse", comment: "VMQemuDisplayMetalWindowController")
            alert.informativeText = String.localizedStringWithFormat(NSLocalizedString("To release the mouse cursor, press %@ at the same time.", comment: "VMQemuDisplayMetalWindowController"), self.shouldUseCmdOptForCapture ? "⌘+⌥ (Cmd+Opt)" : "⌃+⌥ (Ctrl+Opt)")
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
    
    func releaseMouse() {
        syncCapsLock()
        qemuVM.requestInputTablet(true)
        metalView?.releaseMouse()
        self.window?.subtitle = defaultSubtitle
    }
    
    func mouseMove(absolutePoint: CGPoint, button: CSInputButton) {
        guard let window = self.window else { return }
        guard let vmInput = vmInput, !vmInput.serverModeCursor else {
            logger.trace("requesting client mode cursor")
            qemuVM.requestInputTablet(true)
            return
        }
        let currentScreenScale = window.screen?.backingScaleFactor ?? 1.0
        let viewportScale = vmDisplay?.viewportScale ?? 1.0
        let frameSize = metalView.frame.size
        let newX = absolutePoint.x * currentScreenScale / viewportScale
        let newY = (frameSize.height - absolutePoint.y) * currentScreenScale / viewportScale
        let point = CGPoint(x: newX, y: newY)
        logger.trace("move cursor: cocoa (\(absolutePoint.x), \(absolutePoint.y)), native (\(newX), \(newY))")
        vmInput.sendMousePosition(button, absolutePoint: point, forMonitorID: vmDisplay?.monitorID ?? 0)
        vmDisplay?.cursor?.move(to: point) // required to show cursor on screen
    }
    
    func mouseMove(relativePoint: CGPoint, button: CSInputButton) {
        guard let vmInput = vmInput, vmInput.serverModeCursor else {
            logger.trace("requesting server mode cursor")
            qemuVM.requestInputTablet(false)
            return
        }
        let translated = CGPoint(x: relativePoint.x, y: -relativePoint.y)
        vmInput.sendMouseMotion(button, relativePoint: translated, forMonitorID: vmDisplay?.monitorID ?? 0)
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
        vmInput?.sendMouseButton(modifyMouseButton(button), pressed: true)
    }
    
    func mouseUp(button: CSInputButton) {
        vmInput?.sendMouseButton(modifyMouseButton(button), pressed: false)
    }
    
    func mouseScroll(dy: CGFloat, button: CSInputButton) {
        let scrollDy = isInvertScroll ? -dy : dy
        vmInput?.sendMouseScroll(.smooth, button: button, dy: scrollDy)
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
    
    func keyDown(scanCode: Int) {
        if (scanCode & 0xFF) == 0x1D { // Ctrl
            ctrlKeyDown = true
        }
        if !isCapsLockKey && (scanCode & 0xFF) == 0x3A { // Caps Lock
            return
        }
        sendExtendedKey(.press, keyCode: scanCode)
    }
    
    func keyUp(scanCode: Int) {
        if (scanCode & 0xFF) == 0x1D { // Ctrl
            ctrlKeyDown = false
        }
        if !isCapsLockKey && (scanCode & 0xFF) == 0x3A { // Caps Lock
            return
        }
        sendExtendedKey(.release, keyCode: scanCode)
    }
    
    private func handleCaptureKeys(for event: NSEvent) -> Bool {
        // if captured we route all keyevents to view
        if let metalView = metalView, metalView.isMouseCaptured {
            if event.type == .keyDown {
                metalView.keyDown(with: event)
            } else if event.type == .keyUp {
                metalView.keyUp(with: event)
            }
            return true
        }
        
        if event.modifierFlags.contains(.command) && event.type == .keyUp {
            // for some reason, macOS doesn't like to send Cmd+KeyUp
            metalView.keyUp(with: event)
            return false
        }
        return false
    }
    
    /// Syncs the host caps lock state with the guest
    /// - Parameter modifier: An NSEvent modifier, or nil to get the current system state
    func syncCapsLock(with modifier: NSEvent.ModifierFlags? = nil) {
        guard !isCapsLockKey else {
            // ignore sync if user disabled it
            return
        }
        guard let vmInput = vmInput else {
            return
        }
        let capsLock: Bool
        if let modifier = modifier {
            capsLock = modifier.contains(.capsLock)
        } else {
            let status = CGEventSource.flagsState(.hidSystemState)
            capsLock = status.contains(.maskAlphaShift)
        }
        var locks = vmInput.keyLock
        if capsLock {
            locks.update(with: .caps)
        } else {
            locks.subtract(.caps)
        }
        vmInput.keyLock = locks
    }
}
