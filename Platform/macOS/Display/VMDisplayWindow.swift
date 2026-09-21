//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

import AppKit

/// VM window which can fill the area beside the camera housing when in full screen.
///
/// A full screen window is normally kept below the camera housing by two separate mechanisms: AppKit insets the window
/// frame and the window server covers the inset area with an opaque menu bar. Both are undone here with private APIs,
/// all of which must be present or the window behaves like any other. None of them are used or hooked until the
/// option is enabled and a window enters full screen.
class VMDisplayWindow: NSWindow {
    /// Set when the content of this window is a display which should fill the area beside the camera housing.
    var isCameraHousingAreaAllowed: Bool = false

    /// Set from the start of the transition to full screen until the start of the transition out of it.
    private var isFullScreenFrameKept: Bool = false

    /// Set between entering and exiting full screen, the style mask is not enough as it changes before the space does.
    private var isInFullScreenSpace: Bool = false

    /// Set once we have been in the full screen space without covering the area beside the camera housing, such as when
    /// tiled. The window server does not let a window return to it, so we stop asking until full screen is entered again.
    private var isCameraHousingAreaLost: Bool = false

    /// Full screen space where the menu bar is currently hidden by us.
    private var menuBarHiddenSpaceID: UInt64?

    /// Presentation options of our full screen space, which let the menu bar be revealed.
    private var menuBarRevealablePresentationOptions: NSApplication.PresentationOptions?

    /// Set when the pointer has reached the top edge of the screen, until the menu bar it revealed is hidden again.
    ///
    /// The menu bar is otherwise revealed as soon as the pointer is over the area beside the camera housing, which would
    /// make it impossible to use that area of the display. The window server decides that on its own, so we keep the
    /// menu bar hidden with the presentation options until the pointer is at the very top.
    private var isMenuBarRevealAllowed: Bool = false {
        didSet {
            updatePresentationOptions()
        }
    }

    private var topEdgeEventMonitor: Any?

    /// Set while the presentation options of the application are ours rather than the ones of the full screen space.
    private var isPresentationOptionsForced: Bool = false

    /// AppKit applies the presentation options of the full screen space again when it changes spaces or menus.
    private var presentationOptionsObservation: NSKeyValueObservation?

    @Setting("FullScreenUseCameraHousingArea") private var isCameraHousingAreaEnabled: Bool = false

    private var isCameraHousingAreaUsable: Bool {
        guard #available(macOS 27, *) else {
            return false
        }
        guard isCameraHousingAreaAllowed && isCameraHousingAreaEnabled else {
            return false
        }
        // when the user wants the menu bar to always be visible, the area is never free
        guard !UserDefaults.standard.bool(forKey: "AppleMenuBarVisibleInFullscreen") else {
            return false
        }
        return FullScreenFrameHook.isInstalled && SkyLight.shared != nil && MenuBarReveal.isObserving
    }

    /// AppKit parks the auto hidden toolbar behind the menu bar, so it has to be hidden along with it.
    ///
    /// The alpha of this window is updated by AppKit on every step of the reveal animation, so its views are hidden instead.
    private var isFullScreenToolbarHidden: Bool = false {
        didSet {
            guard let contentView = fullScreenToolbarWindow?.contentView else {
                return
            }
            (contentView.superview ?? contentView).isHidden = isFullScreenToolbarHidden
            // while the menu bar cannot be revealed, AppKit parks the toolbar over our content
            fullScreenToolbarWindow?.ignoresMouseEvents = isFullScreenToolbarHidden
        }
    }

    private var fullScreenToolbarWindow: NSWindow? {
        guard let spaceID = menuBarHiddenSpaceID, let skyLight = SkyLight.shared else {
            return nil
        }
        return NSApp.windows.first { window in
            window !== self && window.className == "NSToolbarFullScreenWindow" && skyLight.spaceID(for: window) == spaceID
        }
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(willEnterFullScreen), name: NSWindow.willEnterFullScreenNotification, object: self)
        center.addObserver(self, selector: #selector(didEnterFullScreen), name: NSWindow.didEnterFullScreenNotification, object: self)
        center.addObserver(self, selector: #selector(updateMenuBarHidden), name: NSWindow.didResizeNotification, object: self)
        center.addObserver(self, selector: #selector(willLeaveFullScreen), name: NSWindow.willExitFullScreenNotification, object: self)
        center.addObserver(self, selector: #selector(willLeaveFullScreen), name: NSWindow.willCloseNotification, object: self)
        center.addObserver(self, selector: #selector(didExitFullScreen), name: NSWindow.didExitFullScreenNotification, object: self)
        center.addObserver(self, selector: #selector(menuBarRevealDidChange), name: MenuBarReveal.didChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(otherWindowDidChangeOcclusionState), name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        center.addObserver(self, selector: #selector(updatePresentationOptions), name: NSWindow.didBecomeKeyNotification, object: self)
    }

    override func toggleFullScreen(_ sender: Any?) {
        if !styleMask.contains(.fullScreen) {
            // installs our hooks before AppKit asks for the full screen frame
            _ = isCameraHousingAreaUsable
        }
        super.toggleFullScreen(sender)
    }

    /// Keeps the full screen frame once we have it.
    ///
    /// Our window controllers resize the window to fit the guest display, and AppKit constrains it to the safe area when
    /// it is ordered front again. The window server does not let a window return to the area beside the camera housing
    /// after it has left it, and even asking it for the frame we already have gets us moved out, so those are ignored.
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        if isFullScreenFrameKept, styleMask.contains(.fullScreen), isCameraHousingAreaUsable, !isCameraHousingAreaLost,
           let screen = screen, screen.safeAreaInsets.top > 0, frame == screen.frame,
           fullScreenFrame(forAppKitFrame: FullScreenFrameHook.appKitFrame(for: self)) == screen.frame {
            if flag {
                display()
            }
        } else {
            super.setFrame(frameRect, display: flag)
        }
    }

    /// Frame to use in full screen instead of the one AppKit would use.
    ///
    /// The window server only lets a window cover the area beside the camera housing if it does so from the moment it
    /// enters the full screen space, so every call during the transition must return the same answer.
    fileprivate func fullScreenFrame(forAppKitFrame frame: NSRect) -> NSRect {
        guard isCameraHousingAreaUsable, !isCameraHousingAreaLost, let screen = screen, screen.safeAreaInsets.top > 0 else {
            return frame
        }
        // a tiled window keeps its tile, only a window which has the screen to itself is extended
        guard FullScreenFrameHook.tileFrame(for: self) == screen.frame else {
            return frame
        }
        // the whole screen, which is the frame the window server accepts for a window that has it to itself
        return screen.frame
    }

    @objc private func willEnterFullScreen() {
        isFullScreenFrameKept = true
        _ = isCameraHousingAreaUsable
    }

    @objc private func didEnterFullScreen() {
        isInFullScreenSpace = true
        updateMenuBarHidden()
    }

    @objc private func willLeaveFullScreen() {
        isFullScreenFrameKept = false
        isInFullScreenSpace = false
        isCameraHousingAreaLost = false
        showMenuBar()
    }

    @objc private func didExitFullScreen() {
        guard #available(macOS 27, *) else {
            return
        }
        // the window server keeps Hot Corners disabled after the full screen space is gone, until the options change
        guard NSApp.presentationOptions.isEmpty else {
            return // another full screen window is in front and still wants them disabled
        }
        NSApp.presentationOptions = [.autoHideDock]
        NSApp.presentationOptions = []
    }

    /// Hides the menu bar of our full screen space if and only if we are covered by it.
    @objc private func updateMenuBarHidden() {
        if isInFullScreenSpace, let screen = screen, frame != screen.frame {
            isCameraHousingAreaLost = true
        }
        guard isInFullScreenSpace, isCameraHousingAreaUsable, !isCameraHousingAreaLost, let screen = screen,
              screen.safeAreaInsets.top > 0, frame == screen.frame,
              let skyLight = SkyLight.shared, let spaceID = skyLight.fullScreenSpaceID(for: self) else {
            showMenuBar()
            return
        }
        guard menuBarHiddenSpaceID != spaceID else {
            return
        }
        showMenuBar()
        logger.debug("hiding menu bar in full screen space \(spaceID)")
        menuBarHiddenSpaceID = spaceID
        menuBarRevealablePresentationOptions = NSApp.presentationOptions
        presentationOptionsObservation = NSApp.observe(\.currentSystemPresentationOptions) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updatePresentationOptions()
            }
        }
        topEdgeEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak self] event in
            self?.pointerDidMove()
            return event
        }
        isMenuBarRevealAllowed = false
        applyMenuBarReveal()
    }

    @objc private func showMenuBar() {
        guard let spaceID = menuBarHiddenSpaceID else {
            return
        }
        if let topEdgeEventMonitor = topEdgeEventMonitor {
            NSEvent.removeMonitor(topEdgeEventMonitor)
            self.topEdgeEventMonitor = nil
        }
        presentationOptionsObservation = nil
        // hands the presentation options of the space back to AppKit
        isMenuBarRevealAllowed = true
        menuBarRevealablePresentationOptions = nil
        isFullScreenToolbarHidden = false
        SkyLight.shared?.setMenuBarAlpha(1, inSpace: spaceID)
        menuBarHiddenSpaceID = nil
    }

    @objc private func updatePresentationOptions() {
        guard let revealableOptions = menuBarRevealablePresentationOptions else {
            return
        }
        // the menu bar is only kept hidden for the space we are in, but what we did must be undone in any case
        let options: NSApplication.PresentationOptions?
        if !isMenuBarRevealAllowed && isKeyWindow {
            var forcedOptions: NSApplication.PresentationOptions = [.fullScreen, .hideMenuBar, .hideDock]
            if #available(macOS 27, *) {
                forcedOptions.formUnion(revealableOptions.intersection(.disableScreenCornerInteractions))
            }
            options = forcedOptions
            isPresentationOptionsForced = true
        } else if isPresentationOptionsForced {
            options = revealableOptions
            isPresentationOptionsForced = false
        } else {
            options = nil
        }
        if let options = options, NSApp.presentationOptions != options {
            NSApp.presentationOptions = options
        }
    }

    private func pointerDidMove() {
        guard isKeyWindow, let spaceID = menuBarHiddenSpaceID, let screen = screen else {
            return
        }
        let location = NSEvent.mouseLocation
        if !isMenuBarRevealAllowed && location.y >= screen.frame.maxY - 1 {
            isMenuBarRevealAllowed = true
        } else if isMenuBarRevealAllowed && location.y < screen.frame.maxY - screen.safeAreaInsets.top && !MenuBarReveal.state(inSpace: spaceID).isMenuBarRevealed {
            // the pointer left the top without the menu bar being revealed
            isMenuBarRevealAllowed = false
        }
    }

    private func applyMenuBarReveal() {
        guard let spaceID = menuBarHiddenSpaceID else {
            return
        }
        let reveal = MenuBarReveal.state(inSpace: spaceID)
        SkyLight.shared?.setMenuBarAlpha(reveal.isMenuBarRevealed ? 1 : 0, inSpace: spaceID)
        isFullScreenToolbarHidden = !reveal.isToolbarRevealed
    }

    /// AppKit shows the full screen toolbar window some time after we have entered full screen.
    @objc private func otherWindowDidChangeOcclusionState(_ notification: Notification) {
        if menuBarHiddenSpaceID != nil, let window = notification.object as? NSWindow, window === fullScreenToolbarWindow {
            applyMenuBarReveal()
        }
    }

    @objc private func menuBarRevealDidChange(_ notification: Notification) {
        guard let spaceID = menuBarHiddenSpaceID,
              let userInfo = notification.userInfo,
              userInfo[MenuBarReveal.spaceIDKey] as? UInt64 == spaceID,
              let duration = userInfo[MenuBarReveal.durationKey] as? TimeInterval else {
            return
        }
        let reveal = MenuBarReveal.state(inSpace: spaceID)
        if reveal.isMenuBarRevealed || reveal.isToolbarRevealed {
            applyMenuBarReveal()
        }
        if !reveal.isMenuBarRevealed || !reveal.isToolbarRevealed {
            // they are animated out, do not show our content until they are gone
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self = self, self.menuBarHiddenSpaceID == spaceID else {
                    return
                }
                self.applyMenuBarReveal()
                if !MenuBarReveal.state(inSpace: spaceID).isMenuBarRevealed {
                    self.isMenuBarRevealAllowed = false
                }
            }
        }
    }
}

/// Replaces the frame AppKit uses for a window in full screen, installed the first time it is needed.
private enum FullScreenFrameHook {
    private typealias FrameFunction = @convention(c) (NSWindow, Selector) -> NSRect
    private typealias FrameBlock = @convention(block) (VMDisplayWindow) -> NSRect

    private static let frameTypeEncoding = "{CGRect={CGPoint=dd}{CGSize=dd}}16@0:8"
    private static let frameForFullScreenModeSelector = NSSelectorFromString("_frameForFullScreenMode")
    private static let tileFrameForFullScreenSelector = NSSelectorFromString("_tileFrameForFullScreen")

    private static var frameForFullScreenMode: FrameFunction?
    private static var tileFrameForFullScreen: FrameFunction?

    static let isInstalled: Bool = {
        func frameFunction(for selector: Selector) -> FrameFunction? {
            guard let method = class_getInstanceMethod(NSWindow.self, selector),
                  let types = method_getTypeEncoding(method), String(cString: types) == frameTypeEncoding else {
                logger.debug("cannot use \(NSStringFromSelector(selector))")
                return nil
            }
            return unsafeBitCast(method_getImplementation(method), to: FrameFunction.self)
        }
        guard let appKitFrameForFullScreenMode = frameFunction(for: frameForFullScreenModeSelector),
              let appKitTileFrameForFullScreen = frameFunction(for: tileFrameForFullScreenSelector) else {
            return false
        }
        let selector = frameForFullScreenModeSelector
        let block: FrameBlock = { window in
            window.fullScreenFrame(forAppKitFrame: appKitFrameForFullScreenMode(window, selector))
        }
        guard class_addMethod(VMDisplayWindow.self, selector, imp_implementationWithBlock(block), frameTypeEncoding) else {
            return false
        }
        frameForFullScreenMode = appKitFrameForFullScreenMode
        tileFrameForFullScreen = appKitTileFrameForFullScreen
        return true
    }()

    static func appKitFrame(for window: NSWindow) -> NSRect {
        frameForFullScreenMode?(window, frameForFullScreenModeSelector) ?? window.frame
    }

    static func tileFrame(for window: NSWindow) -> NSRect? {
        tileFrameForFullScreen?(window, tileFrameForFullScreenSelector)
    }
}

/// Private window server functions, resolved at runtime.
private struct SkyLight {
    private typealias MainConnectionIDFunction = @convention(c) () -> Int32
    private typealias CopySpacesForWindowsFunction = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias SpaceGetTypeFunction = @convention(c) (Int32, UInt64) -> Int32
    private typealias TransactionCreateFunction = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?
    private typealias TransactionSetMenuBarSystemOverrideAlphaFunction = @convention(c) (CFTypeRef, UInt64, Float) -> Void
    private typealias TransactionCommitFunction = @convention(c) (CFTypeRef, Int32) -> Int32

    private let mainConnectionID: MainConnectionIDFunction
    private let copySpacesForWindows: CopySpacesForWindowsFunction
    private let spaceGetType: SpaceGetTypeFunction
    private let transactionCreate: TransactionCreateFunction
    private let transactionSetMenuBarSystemOverrideAlpha: TransactionSetMenuBarSystemOverrideAlphaFunction
    private let transactionCommit: TransactionCommitFunction

    static let shared: SkyLight? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else {
            logger.debug("SkyLight is not available")
            return nil
        }
        return SkyLight(handle: handle)
    }()

    private init?(handle: UnsafeMutableRawPointer) {
        func symbol<T>(_ name: String) -> T? {
            guard let symbol = dlsym(handle, name) else {
                logger.debug("SkyLight is missing \(name)")
                return nil
            }
            return unsafeBitCast(symbol, to: T.self)
        }
        guard let mainConnectionID: MainConnectionIDFunction = symbol("SLSMainConnectionID"),
              let copySpacesForWindows: CopySpacesForWindowsFunction = symbol("SLSCopySpacesForWindows"),
              let spaceGetType: SpaceGetTypeFunction = symbol("SLSSpaceGetType"),
              let transactionCreate: TransactionCreateFunction = symbol("SLSTransactionCreate"),
              let transactionSetMenuBarSystemOverrideAlpha: TransactionSetMenuBarSystemOverrideAlphaFunction = symbol("SLSTransactionSetMenuBarSystemOverrideAlpha"),
              let transactionCommit: TransactionCommitFunction = symbol("SLSTransactionCommit") else {
            return nil
        }
        self.mainConnectionID = mainConnectionID
        self.copySpacesForWindows = copySpacesForWindows
        self.spaceGetType = spaceGetType
        self.transactionCreate = transactionCreate
        self.transactionSetMenuBarSystemOverrideAlpha = transactionSetMenuBarSystemOverrideAlpha
        self.transactionCommit = transactionCommit
    }

    /// - Returns: Space that the window is in, if it is in exactly one
    func spaceID(for window: NSWindow) -> UInt64? {
        let allSpacesMask: Int32 = 7
        let windows = [NSNumber(value: window.windowNumber)] as CFArray
        guard let spaces = copySpacesForWindows(mainConnectionID(), allSpacesMask, windows)?.takeRetainedValue() as? [NSNumber],
              spaces.count == 1 else {
            return nil
        }
        return spaces[0].uint64Value
    }

    /// - Returns: Space that the window is in, if that is a full screen space
    func fullScreenSpaceID(for window: NSWindow) -> UInt64? {
        let fullScreenSpaceType: Int32 = 4
        guard let spaceID = spaceID(for: window), spaceGetType(mainConnectionID(), spaceID) == fullScreenSpaceType else {
            return nil
        }
        return spaceID
    }

    /// The override only exists for the lifetime of the space, which for full screen is until the window leaves it.
    func setMenuBarAlpha(_ alpha: Float, inSpace spaceID: UInt64) {
        guard let transaction = transactionCreate(mainConnectionID())?.takeRetainedValue() else {
            return
        }
        transactionSetMenuBarSystemOverrideAlpha(transaction, spaceID, alpha)
        _ = transactionCommit(transaction, 1)
    }
}

/// Observes AppKit being told to reveal or hide the menu bar in a full screen space.
private enum MenuBarReveal {
    static let didChangeNotification = Notification.Name("VMDisplayWindowMenuBarRevealDidChange")
    static let spaceIDKey = "SpaceID"
    static let durationKey = "Duration"

    private typealias DispatchRevealChangedFunction = @convention(c) (AnyClass, Selector, UInt64, Double, Double, Double) -> Void
    private typealias DispatchRevealChangedBlock = @convention(block) (AnyClass, UInt64, Double, Double, Double) -> Void

    struct State {
        var isMenuBarRevealed: Bool = false
        var isToolbarRevealed: Bool = false
    }

    private static var states = [UInt64: State]()

    static let isObserving: Bool = {
        let selector = NSSelectorFromString("_dispatchAgentRevealChangedForSpaceID:menuBarRevealTarget:toolbarRevealTarget:duration:")
        guard let method = class_getClassMethod(NSMenu.self, selector),
              let types = method_getTypeEncoding(method), String(cString: types) == "v48@0:8q16d24d32d40" else {
            logger.debug("cannot observe menu bar reveal")
            return false
        }
        let original = unsafeBitCast(method_getImplementation(method), to: DispatchRevealChangedFunction.self)
        let block: DispatchRevealChangedBlock = { cls, spaceID, menuBarRevealTarget, toolbarRevealTarget, duration in
            original(cls, selector, spaceID, menuBarRevealTarget, toolbarRevealTarget, duration)
            let update = {
                let state = State(isMenuBarRevealed: menuBarRevealTarget > 0, isToolbarRevealed: toolbarRevealTarget > 0)
                states[spaceID] = state.isMenuBarRevealed || state.isToolbarRevealed ? state : nil
                NotificationCenter.default.post(name: didChangeNotification, object: nil, userInfo: [spaceIDKey: spaceID, durationKey: duration])
            }
            if Thread.isMainThread {
                update()
            } else {
                DispatchQueue.main.async(execute: update)
            }
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
        return true
    }()

    static func state(inSpace spaceID: UInt64) -> State {
        states[spaceID] ?? State()
    }
}
