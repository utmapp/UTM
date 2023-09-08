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

import Foundation
import CocoaSpiceRenderer

class VMDisplayMetalViewController: VMDisplayViewController {
    var renderer: CSMetalRenderer?
    var windowScaling: CGFloat
    var windowOrigin: CGPoint
    
    @IBOutlet var inputAccessoryView: UIInputView?
    @IBOutlet var customKeyModifierButtons: [VMKeyboardButton]
    
    @IBOutlet var mtkView: CSMTKView?
    @IBOutlet var keyboardView: VMKeyboardView?
    
    var vmInput: CSInput?
    var vmDisplay: CSDisplay
    
    var serverModeCursor: Bool {
        return vmInput!.serverModeCursor
    }
    
    var mutableKeyCommands: [UIKeyCommand]
    
    init(_ display: CSDisplay, input: CSInput) {
        super.init(nibName: nil, bundle: nil)
        vmDisplay = display
        vmInput = input
        windowScaling = 1.0
        windowOrigin = CGPointZero
        self.addObserver(self, forKeyPath: "vmDisplay.displaySize", context: nil)
    }
    
    public func loadView() {
        super.loadView()
        keyboardView = VMKeyboardView(frame: CGRectZero)
        mtkView = CSMTKView(frame: CGRectZero)
        keyboardView!.delegate = self
        view.insertSubview(keyboardView!, at: 0)
        view.insertSubview(mtkView!, at: 1)
        mtkView!.bindFrameToSuperviewBounds()
        loadInputAccessory()
    }
    
    public func loadInputAccessory() {
        var nib = UINib(nibName: "VMDisplayMetalViewInputAccessory", bundle: nil)
        nib.instantiate(withOwner: self)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up software keyboard
        keyboardView!.inputAccessoryView = inputAccessoryView!
        
        // Set the view to use the default device
        mtkView!.frame = view.bounds
        mtkView!.device = MTLCreateSystemDefaultDevice()
        if mtkView!.device == nil {
            logger.error("Metal is not supported on this device")
            return
        }
        
        renderer = CSMetalRenderer(metalKitView: mtkView!)
        if renderer == nil {
            logger.error("Renderer failed initialization")
            return
        }
        
        if integerForSetting("QEMURendererFPSLimit") > 0 {
            mtkView!.preferredFramesPerSecond = integerForSetting("QEMURendererFPSLimit")
        }
        
        renderer!.changeUpscaler(delegate.qemuDisplayUpscaler, downscaler: delegate.qemuDisplayDownscaler)
        
        mtkView!.delegate = renderer
        
        init(touch: ())
        init(gamepad: ())
        // Pointing device support on iPadOS 13.4 GM or later
        if #available(iOS 13.4, *) {
            // Betas of iPadOS 13.4 did not include this API, that's why I check if the class exists
            if NSClassFromString("UIPointerInteraction") != nil {
                init(pointerInteraction: ())
            }
        }
        #if !os(visionOS)
        if #available(iOS 12.1, *) {
            init(pencilInteraction: ())
        }
        #endif
    }
             
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prefersHomeIndicatorAutoHidden = true
        startGCMouse()
        vmDisplay.addRenderer(renderer!)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopGCMouse()
        vmDisplay.removeRenderer(renderer!)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        delegate.displayViewSize = convertSizeToNative(view.bounds.size)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil, completion: { _ in
            self.delegate.displayViewSize = self.convertSizeToNative(size)
            self.delegate.display(self.vmDisplay, didResizeTo: self.vmDisplay.displaySize)
        })
        if delegate.qemuDisplayIsDynamicResolution {
            displayResize(size)
        }
    }
    
    public override func enterSuspended(isBusy busy: Bool) {
        super.enterSuspended(isBusy: busy)
        prefersPointerLocked = false
        view.window?.isIndirectPointerTouchIgnored = false
        if !busy {
            if delegate.qemuHasClipboardSharing {
                UTMPasteboard.general.releasePollingMode(forObject: self)
            }
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
    
    public override func showKeyboard() {
        super.showKeyboard()
        keyboardView!.becomeFirstResponder()
    }
    
    override func hideKeyboard() {
        super.hideKeyboard()
        keyboardView!.resignFirstResponder()
    }
    
    public func sendExtendedKey(_ type: CSInputKey, code: Int) {
        var code = code
        if (code & 0xFF00) == 0xE000 {
            code = 0x100 | (code & 0xFF)
        } else if (code >= 0x100) {
            logger.warning("Ignored invalid keycode 0x\(code)")
        }
        self.vmInput!.send(type, code: Int32(code))
    }
    
    public func convertSizeToNative(_ size: CGSize) -> CGSize {
        var size = size
        if delegate.qemuDisplayIsNativeResolution {
            size.width = CGPointToPixel(size.width)
            size.height = CGPointToPixel(size.height)
        }
        return size
    }
    
    public func displayResize(_ size: CGSize) {
        var size = size
        logger.info("Resizing to (\(size.width), \(size.height))")
        size = self.convertSizeToNative(size)
        var bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        vmDisplay.requestResolution(bounds)
    }
    
    public func setVmDisplay(_ display: CSDisplay) {
        if let renderer = renderer {
            vmDisplay.removeRenderer(renderer)
            vmDisplay = display
            display.addRenderer(renderer)
        }
    }
    
    public func setDisplayScaling(_ scaling: CGFloat, origin: CGPoint) {
        var scaling = scaling
        if scaling == windowScaling && CGPointEqualToPoint(origin, windowOrigin) {
            return
        }
        vmDisplay.viewportOrigin = origin
        windowScaling = scaling
        windowOrigin = origin
        if !delegate.qemuDisplayIsNativeResolution {
            scaling = CGPointToPixel(scaling)
        }
        if scaling != 0 {
            vmDisplay.viewportScale = scaling
        }
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "vmDisplay.displaySize" {
            #if os(visionOS)
            DispatchQueue.main.async {
                var minSize = vmDisplay.displaySize
                if delegate.qemuDisplayIsNativeResolution {
                    minSize.width = CGPixelToPoint(minSize.width)
                    minSize.height = CGPixelToPoint(minSize.height)
                }
                var displaySize = CGSize(width: minSize.width * windowScaling, height: minSize.height * windowScaling)
                var maxSize = CGSize(width: UIProposedSceneSizeNoPreference, height: UIProposedSceneSizeNoPreference)
                var geoPref = UIWindowSceneGeometryPreferences.Vision(size: displaySize)
                geoPref.__minimumSize = minSize
                geoPref.__maximumSize = maxSize
                geoPref.__resizingRestrictions = .uniform
                view.window!.windowScene?.requestGeometryUpdate(geoPref)
            }
            #else
            delegate.display(vmDisplay, didResizeTo: vmDisplay.displaySize)
            #endif
        }
    }
}
