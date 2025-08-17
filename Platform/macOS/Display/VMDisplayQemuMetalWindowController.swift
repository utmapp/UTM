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
import Carbon.HIToolbox
import SwiftUI

class VMDisplayQemuMetalWindowController: VMDisplayQemuWindowController {
    var metalView: VMMetalView!
    var renderer: CSMetalRenderer?
    
    private var vmDisplay: CSDisplay? {
        didSet {
            if let renderer = renderer {
                oldValue?.removeRenderer(renderer)
                vmDisplay?.addRenderer(renderer)
            }
        }
    }
    private var vmInput: CSInput?
    
    private var displaySize: CGSize = .zero
    private var isDisplaySizeDynamic: Bool = false
    private var isFullScreen: Bool = false
    private let minDynamicSize = CGSize(width: 800, height: 600)
    private let resizeDebounceSecs: Double = 1
    private let resizeTimeoutSecs: Double = 5
    private var debounceResize: DispatchWorkItem?
    private var cancelResize: DispatchWorkItem?
    
    private var localEventMonitor: Any? = nil
    private var globalEventMonitor: Any? = nil
    private var ctrlKeyDown: Bool = false
    private var screenChangedToken: Any?

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
    @Setting("NoFullscreenCursorCaptureAlert") private var isFullscreenCursorCaptureAlertShown: Bool = false
    @Setting("FullScreenAutoCapture") private var isFullScreenAutoCapture: Bool = false
    @Setting("WindowFocusAutoCapture") private var isWindowFocusAutoCapture: Bool = false
    @Setting("CtrlRightClick") private var isCtrlRightClick: Bool = false
    @Setting("AlternativeCaptureKey") private var isAlternativeCaptureKey: Bool = false
    @Setting("IsCapsLockKey") private var isCapsLockKey: Bool = false
    @Setting("IsNumLockForced") private var isNumLockForced: Bool = false
    @Setting("InvertScroll") private var isInvertScroll: Bool = false
    @Setting("QEMURendererFPSLimit") private var rendererFpsLimit: Int = 0
    
    // MARK: - Init
    
    convenience init(secondaryFromDisplay display: CSDisplay, primary: VMDisplayQemuMetalWindowController, vm: UTMQemuVirtualMachine, id: Int) {
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
        renderer = CSMetalRenderer.init(metalKitView: metalView)
        guard let renderer = self.renderer else {
            showErrorAlert(NSLocalizedString("Internal error.", comment: "VMDisplayMetalWindowController"))
            logger.critical("Failed to create renderer.")
            return
        }
        if rendererFpsLimit > 0 {
            metalView.preferredFramesPerSecond = rendererFpsLimit
        }
        renderer.changeUpscaler(displayConfig?.upscalingFilter.metalSamplerMinMagFilter ?? .linear, downscaler: displayConfig?.downscalingFilter.metalSamplerMinMagFilter ?? .linear)
        vmDisplay?.addRenderer(renderer) // can be nil if primary
        metalView.delegate = renderer
        metalView.inputDelegate = self

        screenChangedToken = NotificationCenter.default.addObserver(forName: NSWindow.didChangeScreenNotification, object: nil, queue: .main) { [weak self] _ in
            // update minSize when we change screens
            if let self = self,
               let window = window,
               displaySize != .zero,
               !isDisplaySizeDynamic {
                window.contentMinSize = contentMinSize(in: window, for: displaySize)
            }
        }

        if isSecondary && isDisplaySizeDynamic, let window = window {
            restoreDynamicResolution(for: window)
        }

        super.windowDidLoad()
    }
    
    override func windowWillClose(_ notification: Notification) {
        vmDisplay?.removeRenderer(renderer!)
        stopAllCapture()
        if let screenChangedToken = screenChangedToken {
            NotificationCenter.default.removeObserver(screenChangedToken)
        }
        screenChangedToken = nil
        super.windowWillClose(notification)
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
        setControl(.resize, isEnabled: false) // disable item
        if isWindowFocusAutoCapture {
            captureMouse()
        }
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if !busy {
            metalView.isHidden = true
            screenshotView.image = vm.screenshot?.image
            screenshotView.isHidden = false
        }
        if vm.state == .stopped {
            vmDisplay = nil
            vmInput = nil
            displaySize = .zero
        }
        stopAllCapture()
        super.enterSuspended(isBusy: busy)
    }

    private func stopAllCapture() {
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
    }

    override func captureMouseButtonPressed(_ sender: Any) {
        captureMouse()
    }
}

// MARK: - SPICE IO
extension VMDisplayQemuMetalWindowController {
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
            }
        } else {
            super.spiceDidDestroyDisplay(display)
        }
    }
    
    override func spiceDidUpdateDisplay(_ display: CSDisplay) {
        if vmDisplay == display {
            if display.displaySize != self.displaySize {
                displaySizeDidChange(size: display.displaySize)
            }
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
            displaySizeDidChange(size: displaySize, shouldSaveResolution: false)
            DispatchQueue.main.async {
                if supported, let window = self.window {
                    self.restoreDynamicResolution(for: window)
                }
            }
        }
        isDisplaySizeDynamic = supported
        super.spiceDynamicResolutionSupportDidChange(supported)
    }
}
    
// MARK: - Screen management
extension VMDisplayQemuMetalWindowController {
    fileprivate func displaySizeDidChange(size: CGSize, shouldSaveResolution: Bool = true) {
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
            if shouldSaveResolution {
                self.saveDynamicResolution()
            }
        }
    }
    
    func windowDidChangeScreen(_ notification: Notification) {
        logger.debug("screen changed")
        if let vmDisplay = self.vmDisplay {
            displaySizeDidChange(size: vmDisplay.displaySize)
        }
    }

    private func contentMinSize(in window: NSWindow, for displaySize: CGSize) -> CGSize {
        let currentScreenScale = window.screen?.backingScaleFactor ?? 1.0
        let nativeScale = displayConfig!.isNativeResolution ? 1.0 : currentScreenScale
        let minScaledSize = CGSize(width: displaySize.width * nativeScale / currentScreenScale, height: displaySize.height * nativeScale / currentScreenScale)
        guard let screenSize = window.screen?.visibleFrame.size else {
            return minScaledSize
        }
        let excessSize = window.frameRect(forContentRect: .zero).size
        // if the window is larger than our host screen, shrink the min size allowed
        let widthScale = (screenSize.width - excessSize.width) / displaySize.width
        let heightScale = (screenSize.height - excessSize.height) / displaySize.height
        let scale = min(min(widthScale, heightScale), 1.0)
        return CGSize(width: displaySize.width * scale, height: displaySize.height * scale)
    }

    fileprivate func updateHostFrame(forGuestResolution size: CGSize) {
        guard let window = window else { return }
        guard let vmDisplay = vmDisplay else { return }
        let currentScreenScale = window.screen?.backingScaleFactor ?? 1.0
        let nativeScale = displayConfig!.isNativeResolution ? 1.0 : currentScreenScale
        // change optional scale if needed
        if isDisplaySizeDynamic || (!displayConfig!.isNativeResolution && vmDisplay.viewportScale < currentScreenScale) {
            vmDisplay.viewportScale = nativeScale
        }
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
            window.contentMinSize = contentMinSize(in: window, for: size)
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
        let newSize = updateHostScaling(for: sender, frameSize: frameSize)
        if isFullScreen {
            return frameSize
        } else {
            return newSize
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        guard self.isDisplaySizeDynamic, let window = self.window else {
            return
        }
        debounceResize?.cancel()
        debounceResize = DispatchWorkItem {
            self._handleResizeEnd(for: window)
        }
        // when resizing with a mouse drag, we get flooded with this notification
        // when using accessibility APIs, we do not get a `windowDidEndLiveResize` notification
        DispatchQueue.main.asyncAfter(deadline: .now() + resizeDebounceSecs, execute: debounceResize!)
    }
    
    func windowDidEndLiveResize(_ notification: Notification) {
        guard self.isDisplaySizeDynamic, let window = self.window else {
            return
        }
        _handleResizeEnd(for: window)
    }
    
    private func _handleResizeEnd(for window: NSWindow) {
        debounceResize?.cancel()
        debounceResize = nil
        _ = updateGuestResolution(for: window, frameSize: window.frame.size)
        cancelResize?.cancel()
        cancelResize = DispatchWorkItem {
            if let vmDisplay = self.vmDisplay {
                self.displaySizeDidChange(size: vmDisplay.displaySize)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + resizeTimeoutSecs, execute: cancelResize!)
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        isFullScreen = true
        if isFullScreenAutoCapture {
            captureMouse()
        }
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        isFullScreen = false
        if isFullScreenAutoCapture {
            releaseMouse()
        }
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        // Do not capture mouse if user did not clicked inside the metalView because the window will be draged if user hold the mouse button.
        guard let window = window,
              window.mouseLocationOutsideOfEventStream.y < metalView.frame.height,
              captureMouseToolbarButton.state == .off,
              isWindowFocusAutoCapture else {
            return
        }
        captureMouse()
    }
    
    func windowDidResignMain(_ notification: Notification) {
        releaseMouse()
    }
    
    override func windowDidBecomeKey(_ notification: Notification) {
        if isFullScreen && isFullScreenAutoCapture {
            captureMouse()
        }
        super.windowDidBecomeKey(notification)
    }
    
    override func windowDidResignKey(_ notification: Notification) {
        releaseMouse()
        super.windowDidResignKey(notification)
    }
}

// MARK: - Save and restore resolution
@MainActor extension VMDisplayQemuMetalWindowController {
    func saveDynamicResolution() {
        guard isDisplaySizeDynamic else {
            return
        }
        var resolution = UTMRegistryEntry.Resolution()
        resolution.isFullscreen = isFullScreen
        resolution.size = displaySize
        vm.registryEntry.resolutionSettings[id] = resolution
    }

    func restoreDynamicResolution(for window: NSWindow) {
        guard let resolution = vm.registryEntry.resolutionSettings[id] else {
            return
        }
        if resolution.isFullscreen && !isFullScreen {
            window.toggleFullScreen(self)
        } else if let vmDisplay = vmDisplay, resolution.size != .zero {
            vmDisplay.requestResolution(CGRect(origin: .zero, size: resolution.size))
        } else {
            _ = self.updateGuestResolution(for: window, frameSize: window.frame.size)
        }
    }
}

// MARK: - Input events
extension VMDisplayQemuMetalWindowController: VMMetalViewInputDelegate {
    var shouldUseCmdOptForCapture: Bool {
        isAlternativeCaptureKey || NSWorkspace.shared.isVoiceOverEnabled
    }

    func captureMouse() {
        guard NSApp.modalWindow == nil && window?.attachedSheet == nil else {
            return // don't capture if modal is shown
        }
        let action = { () -> Void in
            self.qemuVM.requestInputTablet(false)
            self.metalView?.captureMouse()
            
            self.captureMouseToolbarButton.state = .on
            
            let format = NSLocalizedString("Press %@ to release cursor", comment: "VMDisplayQemuMetalWindowController")
            let keys = NSLocalizedString(self.shouldUseCmdOptForCapture ? "⌘+⌥" : "⌃+⌥", comment: "VMDisplayQemuMetalWindowController")
            self.window?.subtitle = String.localizedStringWithFormat(format, keys)
            
            self.window?.makeFirstResponder(self.metalView)
            self.syncCapsLock()
        }
        if !isCursorCaptureAlertShown || (isFullScreen && !isFullscreenCursorCaptureAlertShown) {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Captured mouse", comment: "VMDisplayQemuMetalWindowController")
            
            let format = NSLocalizedString("To release the mouse cursor, press %@ at the same time.", comment: "VMDisplayQemuMetalWindowController")
            let keys = NSLocalizedString(self.shouldUseCmdOptForCapture ? "⌘+⌥ (Cmd+Opt)" : "⌃+⌥ (Ctrl+Opt)", comment: "VMDisplayQemuMetalWindowController")
            alert.informativeText = String.localizedStringWithFormat(format, keys)
            
            alert.showsSuppressionButton = true
            alert.beginSheetModal(for: window!) { _ in
                if alert.suppressionButton?.state ?? .off == .on {
                    self.isCursorCaptureAlertShown = true
                    if self.isFullScreen {
                        self.isFullscreenCursorCaptureAlertShown = true
                    }
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
        self.captureMouseToolbarButton.state = .off
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
        if event.type == .keyDown && (event.keyCode == kVK_JIS_Eisu || event.keyCode == kVK_JIS_Kana) {
            // Eisu and Kana keydown events are swallowed and sent directly to IME
            metalView.keyDown(with: event)
            return true
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
    
    /// Update virtual num lock status if we force num pad to on
    func didUseNumericPad() {
        guard isNumLockForced else {
            return // nothing to do
        }
        guard let vmInput = vmInput else {
            return
        }
        if !vmInput.keyLock.contains(.num) {
            vmInput.keyLock.insert(.num)
        }
    }
}

// MARK: - Keyboard shortcuts menu
extension VMDisplayQemuMetalWindowController {
    override func updateKeyboardShortcutMenu(_ menu: NSMenu) {
        let keyboardShortcuts = UTMKeyboardShortcuts.shared.loadKeyboardShortcuts()
        for (index, keyboardShortcut) in keyboardShortcuts.enumerated() {
            let item = NSMenuItem()
            item.title = keyboardShortcut.title
            item.target = self
            item.action = #selector(keyboardShortcutHandler)
            item.tag = index
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let item = NSMenuItem()
        item.title = NSLocalizedString("Edit…", comment: "VMDisplayQemuMetalWindowController")
        item.target = self
        item.action = #selector(keyboardShortcutEdit)
        menu.addItem(item)
    }
    
    @MainActor @objc private func keyboardShortcutHandler(sender: AnyObject) {
        let keyboardShortcuts = UTMKeyboardShortcuts.shared.loadKeyboardShortcuts()
        let item = sender as! NSMenuItem
        let index = item.tag
        guard index < keyboardShortcuts.count else {
            return
        }
        let keys = keyboardShortcuts[index]
        withErrorAlert {
            try await self.qemuVM.monitor?.sendKeys(keys)
        }
    }
    
    @MainActor @objc private func keyboardShortcutEdit(sender: AnyObject) {
        guard let window = window else {
            return
        }
        let content = NSHostingController(rootView: VMKeyboardShortcutsView {
            if let sheet = window.attachedSheet {
                window.endSheet(sheet)
            }
        }.padding())
        var fittingSize = content.view.fittingSize
        fittingSize.width = 400
        let sheetWindow = NSWindow(contentViewController: content)
        sheetWindow.setContentSize(fittingSize)
        window.beginSheet(sheetWindow)
    }
}
