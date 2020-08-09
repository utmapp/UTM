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

class VMDisplayMetalWindowController: VMDisplayWindowController, UTMSpiceIODelegate {
    var metalView: VMMetalView!
    var renderer: UTMRenderer?
    
    @objc dynamic var vmDisplay: CSDisplayMetal?
    @objc dynamic var vmInput: CSInput?
    
    private var displaySizeObserver: NSKeyValueObservation?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        metalView = VMMetalView(frame: displayView.bounds)
        metalView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
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
        
        if vm.state == .vmStopped || vm.state == .vmSuspended {
            enterSuspended(isBusy: false)
            vm.startVM()
        } else {
            enterLive()
        }
        
        guard let spiceIO = vm.ioService as? UTMSpiceIO else {
            showErrorAlert(NSLocalizedString("Internal error.", comment: "VMDisplayMetalWindowController"))
            logger.critical("VM ioService must be UTMSpiceIO, but is: \(String(describing: vm.ioService))")
            return
        }
        spiceIO.delegate = self
    }
    
    override func enterLive() {
        metalView.isHidden = false
        screenshotView.isHidden = true
        renderer!.sourceScreen = vmDisplay
        renderer!.sourceCursor = vmInput
        displaySizeObserver = observe(\.vmDisplay!.displaySize, options: [.initial, .new]) { (_, change) in
            guard let size = change.newValue else { return }
            self.displaySizeDidChange(size: size)
        }
        metalView.becomeFirstResponder()
        super.enterLive()
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if !busy {
            metalView.isHidden = true
            screenshotView.image = vm.screenshot.image
            screenshotView.isHidden = false
        }
        metalView.resignFirstResponder()
        super.enterSuspended(isBusy: busy)
    }
    
    // MARK: - Screen management
    
    func displaySizeDidChange(size: CGSize) {
        if size == .zero {
            logger.debug("Ignoring zero size display")
            return
        }
        logger.debug("resizing to: (\(size.width), \(size.height))")
        DispatchQueue.main.async {
            guard let window = self.window else { return }
            guard let vmDisplay = self.vmDisplay else { return }
            let currentScreenScale = window.screen?.backingScaleFactor ?? 1.0
            let scaledSize = CGSize(width: size.width / currentScreenScale, height: size.height / currentScreenScale)
            let contentRect = CGRect(x: window.frame.origin.x, y: 0, width: scaledSize.width * vmDisplay.viewportScale, height: scaledSize.height * vmDisplay.viewportScale)
            var windowRect = window.frameRect(forContentRect: contentRect)
            windowRect.origin.y = window.frame.origin.y + window.frame.height - windowRect.height
            window.contentMinSize = scaledSize
            window.contentAspectRatio = size
            window.setFrame(windowRect, display: false, animate: true)
            self.metalView.setFrameSize(contentRect.size)
        }
    }
    
    func windowDidChangeScreen(_ notification: Notification) {
        logger.debug("screen changed")
        if let vmDisplay = self.vmDisplay {
            displaySizeDidChange(size: vmDisplay.displaySize)
        }
    }
}

// MARK: - Input events
extension VMDisplayMetalWindowController: VMMetalViewInputDelegate {
    func mouseMove(absolutePoint: CGPoint, button: CSInputButton) {
        guard let window = self.window else { return }
        let currentScreenScale = window.screen?.backingScaleFactor ?? 1.0
        let viewportScale = vmDisplay?.viewportScale ?? 1.0
        let frameSize = metalView.frame.size
        let newX = absolutePoint.x * currentScreenScale / viewportScale
        let newY = (frameSize.height - absolutePoint.y) * currentScreenScale / viewportScale
        logger.debug("move cursor: cocoa (\(absolutePoint.x), \(absolutePoint.y)), native (\(newX), \(newY))")
        vmInput?.sendMouseMotion(button, point: CGPoint(x: newX, y: newY))
    }
    
    func mouseMove(relativePoint: CGPoint, button: CSInputButton) {
    }
    
    func mouseDown(button: CSInputButton) {
        vmInput?.sendMouseButton(button, pressed: true, point: .zero)
    }
    
    func mouseUp(button: CSInputButton) {
        vmInput?.sendMouseButton(button, pressed: false, point: .zero)
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
        sendExtendedKey(.press, keyCode: keyCode)
    }
    
    func keyUp(keyCode: Int) {
        sendExtendedKey(.release, keyCode: keyCode)
    }
    
}
