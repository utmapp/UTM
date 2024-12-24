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

@available(macOS 12, *)
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
    
    override func windowDidLoad() {
        mainView = VZVirtualMachineView()
        captureMouseToolbarButton.image = captureMouseToolbarButton.alternateImage // show capture keyboard image
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
    
    @available(macOS 12, *)
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
@available(macOS 12, *)
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
