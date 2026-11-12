//
// Copyright © 2022 osy. All rights reserved.
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

import Foundation
import Virtualization
import Carbon.HIToolbox

class VMDisplayAppleDisplayWindowController: VMDisplayAppleWindowController {
    var appleView: VZVirtualMachineView! {
        mainView as? VZVirtualMachineView
    }

    override var contentView: NSView? {
        appleView
    }

    var supportsReconfiguration: Bool {
        guard #available(macOS 14, *) else {
            return false
        }
        guard let display = appleVM.apple?.graphicsDevices.first?.displays.first else {
            return false
        }
        return display.value(forKey: "_supportsReconfiguration") as? Bool ?? false
    }

    var isDynamicResolution: Bool {
        appleConfig.displays.first!.isDynamicResolution
    }

    private let checkSupportsReconfigurationTimeoutPeriod: Double = 1
    private var checkSupportsReconfigurationTimeoutAttempts: Int = 60
    private var aspectRatioLocked: Bool = false
    private var screenChangedToken: Any?
    private var isFullscreen: Bool = false
    private var cancelCheckSupportsReconfiguration: DispatchWorkItem?
    private var isReadyToSaveResolution: Bool = false

    @Setting("FullScreenAutoCapture") private var isFullScreenAutoCapture: Bool = false
    /// Modifier keys held down by scripted input, by key code
    private var scriptedModifierKeys: Set<UInt16> = []
    
    override func windowDidLoad() {
        mainView = VZVirtualMachineView()
        captureMouseToolbarButton.image = captureMouseToolbarButton.alternateImage // show capture keyboard image
        (window as? VMDisplayWindow)?.isCameraHousingAreaAllowed = true
        screenChangedToken = NotificationCenter.default.addObserver(forName: NSWindow.didChangeScreenNotification, object: nil, queue: .main) { [weak self] _ in
            // update minSize when we change screens
            if let self = self,
               let window = window,
               let primaryDisplay = appleConfig.displays.first,
               !supportsReconfiguration || !isDynamicResolution {
                window.contentMinSize = contentMinSize(in: window, for: windowSize(for: primaryDisplay))
            }
        }
        super.windowDidLoad()
    }

    override func windowWillClose(_ notification: Notification) {
        if let screenChangedToken = screenChangedToken {
            NotificationCenter.default.removeObserver(screenChangedToken)
        }
        screenChangedToken = nil
        stopPollingForSupportsReconfiguration()
        super.windowWillClose(notification)
    }

    override func enterLive() {
        appleView.isHidden = false
        appleView.virtualMachine = appleVM.apple
        appleVM.inputDelegate = self
        screenshotView.isHidden = true
        if #available(macOS 14, *) {
            appleView.automaticallyReconfiguresDisplay = isDynamicResolution
            startPollingForSupportsReconfiguration()
        }
        super.enterLive()
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if !busy {
            appleView.virtualMachine = nil
            appleView.isHidden = true
            screenshotView.image = vm.screenshot?.image
            screenshotView.isHidden = false
        }
        captureMouseToolbarButton.state = .off
        captureMouseButtonPressed(self)
        stopPollingForSupportsReconfiguration()
        super.enterSuspended(isBusy: busy)
    }
    
    private func windowSize(for display: UTMAppleConfigurationDisplay) -> CGSize {
        let currentScreenScale = window?.screen?.backingScaleFactor ?? 1.0
        let useHidpi = display.pixelsPerInch >= 226
        let scale = useHidpi ? currentScreenScale : 1.0
        return CGSize(width: CGFloat(display.widthInPixels) / scale, height: CGFloat(display.heightInPixels) / scale)
    }
    
    override func updateWindowFrame() {
        guard let window = window else {
            return
        }
        guard let primaryDisplay = appleConfig.displays.first else {
            return //FIXME: add multiple displays
        }
        let size = windowSize(for: primaryDisplay)
        let frame = window.frameRect(forContentRect: CGRect(origin: window.frame.origin, size: size))
        window.contentAspectRatio = size
        aspectRatioLocked = true
        let dynamicResolution = supportsReconfiguration && isDynamicResolution
        if dynamicResolution {
            window.minSize = NSSize(width: 400, height: 400)
        } else {
            window.minSize = contentMinSize(in: window, for: size)
        }
        if !dynamicResolution || !restoreDynamicResolution(for: window) {
            window.setFrame(frame, display: false, animate: true)
        }
        super.updateWindowFrame()
    }
    
    override func resizeConsoleButtonPressed(_ sender: Any) {
        updateWindowFrame()
    }
    
    override func captureMouseButtonPressed(_ sender: Any) {
        appleView!.capturesSystemKeys = captureMouseToolbarButton.state == .on
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        isFullscreen = true
        if isFullScreenAutoCapture {
            captureMouseToolbarButton.state = .on
            captureMouseButtonPressed(self)
        }
        saveDynamicResolution()
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        isFullscreen = false
        if isFullScreenAutoCapture {
            captureMouseToolbarButton.state = .off
            captureMouseButtonPressed(self)
        }
        saveDynamicResolution()
    }
    
    func windowDidResize(_ notification: Notification) {
        if supportsReconfiguration && isDynamicResolution {
            if aspectRatioLocked {
                window!.resizeIncrements = NSSize(width: 1.0, height: 1.0)
                window!.minSize = NSSize(width: 400, height: 400)
                aspectRatioLocked = false
            }
            saveDynamicResolution()
        }
    }

    private func contentMinSize(in window: NSWindow, for scaledSize: CGSize) -> CGSize {
        guard let screenSize = window.screen?.visibleFrame.size else {
            return scaledSize
        }
        let excessSize = window.frameRect(forContentRect: .zero).size
        // if the window is larger than our host screen, shrink the min size allowed
        let widthScale = (screenSize.width - excessSize.width) / scaledSize.width
        let heightScale = (screenSize.height - excessSize.height) / scaledSize.height
        let scale = min(min(widthScale, heightScale), 1.0)
        return CGSize(width: scaledSize.width * scale, height: scaledSize.height * scale)
    }
}

// MARK: - Save and restore resolution
@MainActor extension VMDisplayAppleDisplayWindowController {
    func saveDynamicResolution() {
        guard supportsReconfiguration && isDynamicResolution && isReadyToSaveResolution else {
            return
        }
        var resolution = UTMRegistryEntry.Resolution()
        resolution.isFullscreen = isFullscreen
        resolution.size = window!.contentRect(forFrameRect: window!.frame).size
        vm.registryEntry.resolutionSettings[0] = resolution
    }

    @discardableResult
    func restoreDynamicResolution(for window: NSWindow) -> Bool {
        isReadyToSaveResolution = true
        guard let resolution = vm.registryEntry.resolutionSettings[0] else {
            return false
        }
        if resolution.isFullscreen && !isFullscreen {
            window.toggleFullScreen(self)
        } else if resolution.size != .zero {
            let frame = window.frameRect(forContentRect: CGRect(origin: window.frame.origin, size: resolution.size))
            window.setFrame(frame, display: false, animate: true)
        }
        return true
    }

    func startPollingForSupportsReconfiguration() {
        cancelCheckSupportsReconfiguration?.cancel()
        cancelCheckSupportsReconfiguration = DispatchWorkItem { [weak self] in
            guard let self = self else {
                return
            }
            if supportsReconfiguration, let window = window {
                restoreDynamicResolution(for: window)
                checkSupportsReconfigurationTimeoutAttempts = 0
                cancelCheckSupportsReconfiguration = nil
            } else if checkSupportsReconfigurationTimeoutAttempts > 0 {
                checkSupportsReconfigurationTimeoutAttempts -= 1
                DispatchQueue.main.asyncAfter(deadline: .now() + checkSupportsReconfigurationTimeoutPeriod, execute: cancelCheckSupportsReconfiguration!)
            } else {
                cancelCheckSupportsReconfiguration = nil
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + checkSupportsReconfigurationTimeoutPeriod, execute: cancelCheckSupportsReconfiguration!)
    }

    func stopPollingForSupportsReconfiguration() {
        cancelCheckSupportsReconfiguration?.cancel()
        cancelCheckSupportsReconfiguration = nil
        isReadyToSaveResolution = false
    }
}

// MARK: - Scripted input

extension VMDisplayAppleDisplayWindowController: UTMAppleInputProvider {
    /// Each modifier key's flag, with the device-dependent bit (NX_DEVICE*KEYMASK) a real keyboard
    /// sets for it: the guest keyboard tells left from right keys by those bits, and ignores a
    /// flag without one.
    private static let modifierFlags: [Int: NSEvent.ModifierFlags] = [
        kVK_Control: [.control, .init(rawValue: 0x0001)],
        kVK_Shift: [.shift, .init(rawValue: 0x0002)],
        kVK_RightShift: [.shift, .init(rawValue: 0x0004)],
        kVK_Command: [.command, .init(rawValue: 0x0008)],
        kVK_RightCommand: [.command, .init(rawValue: 0x0010)],
        kVK_Option: [.option, .init(rawValue: 0x0020)],
        kVK_RightOption: [.option, .init(rawValue: 0x0040)],
        kVK_RightControl: [.control, .init(rawValue: 0x2000)],
        kVK_CapsLock: .capsLock,
        kVK_Function: .function,
    ]

    private var scriptedModifiers: NSEvent.ModifierFlags {
        scriptedModifierKeys.reduce(into: []) { flags, keyCode in
            flags.formUnion(Self.modifierFlags[Int(keyCode)] ?? [])
        }
    }

    func sendKey(_ keyCode: UInt16, isDown: Bool) -> Bool {
        guard let view = appleView, view.virtualMachine != nil, let window = window else {
            return false
        }
        let type: NSEvent.EventType
        if Self.modifierFlags[Int(keyCode)] != nil {
            if isDown {
                scriptedModifierKeys.insert(keyCode)
            } else {
                scriptedModifierKeys.remove(keyCode)
            }
            type = .flagsChanged
        } else {
            type = isDown ? .keyDown : .keyUp
        }
        guard let event = NSEvent.keyEvent(with: type,
                                           location: .zero,
                                           modifierFlags: scriptedModifiers,
                                           timestamp: ProcessInfo.processInfo.systemUptime,
                                           windowNumber: window.windowNumber,
                                           context: nil,
                                           characters: "",
                                           charactersIgnoringModifiers: "",
                                           isARepeat: false,
                                           keyCode: keyCode) else {
            return false
        }
        switch type {
        case .flagsChanged: view.flagsChanged(with: event)
        case .keyDown: view.keyDown(with: event)
        default: view.keyUp(with: event)
        }
        return true
    }

    func sendMouseClick(at point: CGPoint, button: Int) -> Bool {
        guard let view = appleView, view.virtualMachine != nil, let window = window else {
            return false
        }
        // the screenshot is in backing pixels of the view, with the origin at the top left
        let scale = window.backingScaleFactor
        let bounds = view.bounds
        let local = CGPoint(x: min(max(point.x / scale, 0), bounds.width - 1),
                            y: view.isFlipped ? min(max(point.y / scale, 0), bounds.height - 1)
                                              : bounds.height - 1 - min(max(point.y / scale, 0), bounds.height - 1))
        let location = view.convert(local, to: nil)
        let (downType, upType): (NSEvent.EventType, NSEvent.EventType)
        switch button {
        case 1: (downType, upType) = (.rightMouseDown, .rightMouseUp)
        case 2: (downType, upType) = (.otherMouseDown, .otherMouseUp)
        default: (downType, upType) = (.leftMouseDown, .leftMouseUp)
        }
        func event(_ type: NSEvent.EventType) -> NSEvent? {
            NSEvent.mouseEvent(with: type,
                               location: location,
                               modifierFlags: scriptedModifiers,
                               timestamp: ProcessInfo.processInfo.systemUptime,
                               windowNumber: window.windowNumber,
                               context: nil,
                               eventNumber: 0,
                               clickCount: type == .mouseMoved ? 0 : 1,
                               pressure: type == downType ? 1 : 0)
        }
        guard let moved = event(.mouseMoved), let down = event(downType), let up = event(upType) else {
            return false
        }
        view.mouseMoved(with: moved)
        switch button {
        case 1:
            view.rightMouseDown(with: down)
            view.rightMouseUp(with: up)
        case 2:
            view.otherMouseDown(with: down)
            view.otherMouseUp(with: up)
        default:
            view.mouseDown(with: down)
            view.mouseUp(with: up)
        }
        return true
    }
}
