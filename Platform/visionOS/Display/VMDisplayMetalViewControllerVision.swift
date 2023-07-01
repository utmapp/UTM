//
// Copyright © 2023 osy. All rights reserved.
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

import UIKit
import CocoaSpice

class VMDisplayMetalViewController: VMDisplayViewController {
    @objc dynamic var vmDisplay: CSDisplay {
        didSet {
            if let renderer = renderer {
                oldValue.removeRenderer(renderer)
                vmDisplay.addRenderer(renderer)
            }
        }
    }
    
    var vmInput: CSInput?
    
    private var mtkView: CSMTKView!
    
    private var renderer: CSMetalRenderer!
    
    var serverModeCursor: Bool {
        vmInput?.serverModeCursor ?? false
    }
    
    init(display: CSDisplay, input: CSInput?) {
        self.vmInput = input
        self.vmDisplay = display
        super.init(nibName: nil, bundle: nil)
        addObserver(self, forKeyPath: "vmDisplay.displaySize", context: nil)
    }
    
    deinit {
        removeObserver(self, forKeyPath: "vmDisplay.displaySize")
    }
    
    required init?(coder: NSCoder) {
        fatalError("Unimplemented")
    }
    
    override func loadView() {
        super.loadView()
        mtkView = CSMTKView(frame: .zero)
        view.insertSubview(mtkView, at: 0)
        mtkView.bindFrameToSuperviewBounds()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view to use the default device
        mtkView.frame = view.bounds
        mtkView.device = MTLCreateSystemDefaultDevice()
        guard mtkView.device != nil else {
            logger.error("Metal is not supported on this device")
            return
        }
        
        renderer = CSMetalRenderer(metalKitView: mtkView)
        guard renderer != nil else {
            logger.error("Renderer failed initialization")
            return
        }
        
        // Initialize our renderer with the view size
        let drawableSize = view.bounds.size
        mtkView.drawableSize = drawableSize
        let preferredFramesPerSecond = integerForSetting("QEMURendererFPSLimit")
        if preferredFramesPerSecond > 0 {
            mtkView.preferredFramesPerSecond = preferredFramesPerSecond
        }
        
        renderer.changeUpscaler(delegate.qemuDisplayUpscaler, downscaler: delegate.qemuDisplayDownscaler)
        
        mtkView.delegate = renderer;
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prefersHomeIndicatorAutoHidden = true
        vmDisplay.addRenderer(renderer)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        vmDisplay.removeRenderer(renderer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        delegate.displayViewSize = mtkView.drawableSize
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.delegate.displayViewSize = self.mtkView.drawableSize
        }
        if delegate.qemuDisplayIsDynamicResolution {
            displayResize(size)
        }
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        super.enterSuspended(isBusy: busy)
        prefersPointerLocked = false
        view.window?.isIndirectPointerTouchIgnored = false
        if !busy && delegate.qemuHasClipboardSharing {
            UTMPasteboard.general.releasePollingMode(forObject: self)
        }
    }
    
    override func enterLive() {
        super.enterLive()
        prefersPointerLocked = true
        view.window?.isIndirectPointerTouchIgnored = true
        if delegate.qemuDisplayIsDynamicResolution {
            displayResize(view.bounds.size)
        }
        if delegate.qemuHasClipboardSharing {
            UTMPasteboard.general.requestPollingMode(forObject: self)
        }
    }
    
    func displayResize(_ size: CGSize) {
        logger.debug("resizing to (\(size.width), \(size.height))")
        let bounds = CGRect(origin: .zero, size: size)
        if delegate.qemuDisplayIsNativeResolution {
            // FIXME: scaling for Vision Pro
        }
        vmDisplay.requestResolution(bounds)
    }
    
    func setDisplayScaling(_ scaling: CGFloat, origin: CGPoint) {
        vmDisplay.viewportOrigin = origin
        if scaling != 0 {
            vmDisplay.viewportScale = scaling
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "vmDisplay.displaySize" {
            delegate.display(vmDisplay, didResizeTo: vmDisplay.displaySize)
            Task { @MainActor in
                self.view.window!.windowScene!.requestGeometryUpdate(.Reality(size: vmDisplay.displaySize, minimumSize: vmDisplay.displaySize, resizingRestrictions: .uniform)) { error in
                    logger.error("Error resizing: \(error)")
                }
            }
        }
    }
}
