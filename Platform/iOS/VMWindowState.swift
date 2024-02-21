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
        window.isDisplayZoomLocked = isDisplayZoomLocked
        #endif
        window.isKeyboardVisible = isKeyboardShown
        registryEntry.windowSettings[id] = window
    }
    
    mutating func restoreWindow(from registryEntry: UTMRegistryEntry, device: Device?) {
        guard case let .display(_, id) = device else {
            return
        }
        let window = registryEntry.windowSettings[id] ?? UTMRegistryEntry.Window()
        displayScale = window.scale
        #if os(visionOS)
        isDisplayZoomLocked = true
        #else
        displayOrigin = window.origin
        isDisplayZoomLocked = window.isDisplayZoomLocked
        isKeyboardRequested = window.isKeyboardVisible
        #endif
    }
}
