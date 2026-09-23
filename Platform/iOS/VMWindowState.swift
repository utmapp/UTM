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

/// Represents the UI state for a single window
struct VMWindowState: Identifiable {
    enum Device: Identifiable, Hashable {
        case display(CSDisplay, Int)
        case serial(CSPort, Int)
        
        var configIndex: Int {
            switch self {
            case .display(_, let index): return index
            case .serial(_, let index): return index
            }
        }
        
        var id: Self {
            self
        }
    }
    
    let id: VMSessionState.WindowID
    
    var device: Device?
    
    private var shouldViewportChange: Bool {
        !(displayScale == 1.0 && displayOrigin == .zero)
    }
    
    var displayScale: CGFloat = 1.0 {
        didSet {
            isViewportChanged = shouldViewportChange
        }
    }
    
    var displayOrigin: CGPoint = CGPoint(x: 0, y: 0) {
        didSet {
            isViewportChanged = shouldViewportChange
        }
    }
    
    var displayViewSize: CGSize = .zero
    
    var isDisplayZoomLocked: Bool = false
    
    var isKeyboardRequested: Bool = false
    
    var isKeyboardShown: Bool = false
    
    var isViewportChanged: Bool = false
    
    var isUserInteracting: Bool = false
    
    var isBusy: Bool = false
    
    var isRunning: Bool = false
    
    var alert: Alert?

    var isDynamicResolutionSupported: Bool = false

    // MARK: Toolbar

    /// Only the show/hide button is visible.
    ///
    /// Read from the defaults once so the window keeps its own state while the choice persists.
    var isToolbarCollapsed: Bool = UserDefaults.standard.bool(forKey: "ToolbarIsCollapsed")

    // MARK: Input deck

    struct InputDeckLayout: Equatable {
        /// The part below the fold, in window coordinates.
        var frame: CGRect
        /// The fold itself, which neither half uses for controls.
        var fold: CGRect
    }

    /// The bottom half of a device folded like a laptop, while it is folded so.
    var inputDeckLayout: InputDeckLayout?

    var inputDeckFrame: CGRect? {
        inputDeckLayout?.frame
    }

    /// What the bottom half shows, remembered for the next time the device is folded.
    var inputDeck: VMInputDeck = .keyboard

    /// The zoom lock from before the device was folded, restored when it is opened again.
    var zoomLockBeforeDeck: Bool?

    /// Whether the keyboard was shown before the device was folded, which is what the window remembers.
    var keyboardVisibleBeforeDeck: Bool?

    /// Height reserved for the accessory row at the bottom of the display half while folded.
    var deckAccessoryHeight: CGFloat = 0

    /// How far a toolbar ending at the given window position must move up to clear the fold and accessory row.
    ///
    /// The keyboard is left to the system, which keeps the toolbar above it.
    func toolbarBottomInset(toolbarBottom: CGFloat) -> CGFloat {
        guard let layout = inputDeckLayout else {
            return 0
        }
        return max(0, toolbarBottom - (layout.fold.minY - deckAccessoryHeight))
    }

    /// Only the guest display has a touchpad, so other devices keep the keyboard in the deck.
    var showsTouchpadDeck: Bool {
        guard inputDeckLayout != nil, inputDeck == .touchpad, case .display = device else {
            return false
        }
        return true
    }
}

// MARK: - Toolbar

extension VMWindowState {
    mutating func toggleToolbarCollapsed() {
        setToolbarCollapsed(!isToolbarCollapsed)
    }

    mutating func setToolbarCollapsed(_ collapsed: Bool) {
        isToolbarCollapsed = collapsed
        UserDefaults.standard.set(collapsed, forKey: "ToolbarIsCollapsed")
    }
}

// MARK: - Input deck

extension VMWindowState {
    /// Called when the device is folded like a laptop or opened up again.
    mutating func setInputDeck(_ layout: InputDeckLayout?) {
        guard layout != inputDeckLayout else {
            return
        }
        inputDeckLayout = layout
        if layout != nil {
            // the display half is small, so it always shows the whole guest display
            if zoomLockBeforeDeck == nil {
                zoomLockBeforeDeck = isDisplayZoomLocked
            }
            if keyboardVisibleBeforeDeck == nil {
                keyboardVisibleBeforeDeck = isKeyboardShown
            }
            isDisplayZoomLocked = true
        } else {
            if let zoomLock = zoomLockBeforeDeck {
                isDisplayZoomLocked = zoomLock
            }
            if let keyboardVisible = keyboardVisibleBeforeDeck {
                isKeyboardRequested = keyboardVisible
            }
            zoomLockBeforeDeck = nil
            keyboardVisibleBeforeDeck = nil
        }
    }

    /// The keyboard for a freshly folded device is asked for once the pose has settled, since a
    /// keyboard shown while the hinge is still moving is dismissed again by the system.
    var wantsDeckKeyboard: Bool {
        inputDeckLayout != nil && !showsTouchpadDeck && !isKeyboardShown
    }

    mutating func requestInputDeck(_ deck: VMInputDeck) {
        inputDeck = deck
        isKeyboardRequested = deck == .keyboard
    }

    /// The keyboard button steps from the keyboard to the touchpad and back while the device is folded.
    mutating func cycleInputDeck() {
        guard case .display = device else {
            isKeyboardRequested = !isKeyboardShown
            return
        }
        switch inputDeck {
        case .keyboard where isKeyboardShown:
            requestInputDeck(.touchpad)
        case .keyboard:
            isKeyboardRequested = true
        case .touchpad:
            requestInputDeck(.keyboard)
        }
    }
}

// MARK: - VM action alerts

extension VMWindowState {
    enum Alert: Identifiable {
        var id: Int {
            switch self {
            case .powerDown: return 0
            case .terminateApp: return 1
            case .restart: return 2
            #if WITH_USB
            case .deviceConnected(_): return 3
            #endif
            case .nonfatalError(_): return 4
            case .fatalError(_): return 5
            case .memoryWarning: return 6
            }
        }
        
        case powerDown
        case terminateApp
        case restart
        #if WITH_USB
        case deviceConnected(CSUSBDevice)
        #endif
        case nonfatalError(String)
        case fatalError(String)
        case memoryWarning
    }
}

// MARK: - Resizing display

extension VMWindowState {
    private var kVMDefaultResizeCmd: String {
        "stty cols $COLS rows $ROWS\\n"
    }
    
    mutating func resizeDisplayToFit(_ display: CSDisplay, size: CGSize = .zero) {
        let viewSize = displayViewSize
        let displaySize = size == .zero ? display.displaySize : size
        let scaled = CGSize(width: viewSize.width / displaySize.width, height: viewSize.height / displaySize.height)
        let viewportScale = min(scaled.width, scaled.height)
        // persist this change in viewState
        displayScale = viewportScale
        displayOrigin = .zero
    }
    
    private mutating func resetDisplay(_ display: CSDisplay) {
        // persist this change in viewState
        displayScale = 1.0
        displayOrigin = .zero
    }
    
    private mutating func resetConsole(_ serial: CSPort, command: String? = nil) {
        let cols = Int(displayViewSize.width)
        let rows = Int(displayViewSize.height)
        let template = command ?? kVMDefaultResizeCmd
        let cmd = template
            .replacingOccurrences(of: "$COLS", with: String(cols))
            .replacingOccurrences(of: "$ROWS", with: String(rows))
            .replacingOccurrences(of: "\\n", with: "\n")
        serial.write(cmd.data(using: .nonLossyASCII)!)
    }
    
    mutating func toggleDisplayResize(command: String? = nil) {
        if case let .display(display, _) = device {
            if isViewportChanged {
                isDisplayZoomLocked = false
                resetDisplay(display)
            } else {
                isDisplayZoomLocked = true
                resizeDisplayToFit(display)
            }
        } else if case let .serial(serial, _) = device {
            resetConsole(serial)
            isViewportChanged = false
            isDisplayZoomLocked = false
        }
    }
}

// MARK: - Persist changes

@MainActor extension VMWindowState {
    func saveWindow(to registryEntry: UTMRegistryEntry, device: Device?) {
        guard case let .display(_, id) = device else {
            return
        }
        var window = UTMRegistryEntry.Window()
        window.scale = displayScale
        #if !os(visionOS)
        window.origin = displayOrigin
        window.isDisplayZoomLocked = zoomLockBeforeDeck ?? isDisplayZoomLocked
        #endif
        window.isKeyboardVisible = keyboardVisibleBeforeDeck ?? isKeyboardShown
        registryEntry.windowSettings[id] = window
    }
    
    mutating func restoreWindow(from registryEntry: UTMRegistryEntry, device: Device?) {
        guard case let .display(display, id) = device else {
            return
        }
        let window = registryEntry.windowSettings[id] ?? UTMRegistryEntry.Window()
        displayScale = window.scale
        #if os(visionOS)
        isDisplayZoomLocked = true
        #else
        displayOrigin = window.origin
        if inputDeckLayout != nil {
            // the forced fit and keyboard stay while folded and the window's own choices apply once opened
            zoomLockBeforeDeck = window.isDisplayZoomLocked
            keyboardVisibleBeforeDeck = window.isKeyboardVisible
            isDisplayZoomLocked = true
            isKeyboardRequested = !showsTouchpadDeck
        } else {
            isDisplayZoomLocked = window.isDisplayZoomLocked
            isKeyboardRequested = window.isKeyboardVisible
        }
        #endif
        if isDisplayZoomLocked {
            resizeDisplayToFit(display)
        }
    }
}
