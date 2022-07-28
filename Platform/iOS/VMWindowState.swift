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
    enum Device: Equatable {
        case display(CSDisplay, Int)
        case serial(CSPort, Int)
        
        var configIndex: Int {
            switch self {
            case .display(_, let index): return index
            case .serial(_, let index): return index
            }
        }
    }
    
    let id = UUID()
    
    var device: Device?
    
    private var shouldViewportChange: Bool {
        !(displayScale == 1.0 && displayOriginX == 0.0 && displayOriginY == 0.0)
    }
    
    var displayScale: Float = 1.0 {
        didSet {
            isViewportChanged = shouldViewportChange
        }
    }
    
    var displayOriginX: Float = 0.0 {
        didSet {
            isViewportChanged = shouldViewportChange
        }
    }
    
    var displayOriginY: Float = 0.0 {
        didSet {
            isViewportChanged = shouldViewportChange
        }
    }
    
    var displayViewSize: CGSize = .zero
    
    var isKeyboardRequested: Bool = false
    
    var isKeyboardShown: Bool = false
    
    var isViewportChanged: Bool = false
    
    var isUserInteracting: Bool = false
    
    var isBusy: Bool = false
    
    var isRunning: Bool = false
    
    var alert: Alert?
    
    var isInteractive: Bool = true
}

// MARK: - VM action alerts

extension VMWindowState {
    enum Alert: Identifiable {
        var id: Int {
            switch self {
            case .powerDown: return 0
            case .terminateApp: return 1
            case .restart: return 2
            case .deviceConnected(_): return 3
            case .nonfatalError(_): return 4
            case .fatalError(_): return 5
            }
        }
        
        case powerDown
        case terminateApp
        case restart
        #if !WITH_QEMU_TCI
        case deviceConnected(CSUSBDevice)
        #else
        case deviceConnected(Any?)
        #endif
        case nonfatalError(String)
        case fatalError(String)
    }
}

// MARK: - Resizing display

extension VMWindowState {
    private var kVMDefaultResizeCmd: String {
        "stty cols $COLS rows $ROWS\\n"
    }
    
    private mutating func resizeDisplayToFit(_ display: CSDisplay) {
        let viewSize = displayViewSize
        let displaySize = display.displaySize
        let scaled = CGSize(width: viewSize.width / displaySize.width, height: viewSize.height / displaySize.height)
        let viewportScale = min(scaled.width, scaled.height)
        display.viewportScale = viewportScale
        display.viewportOrigin = .zero
        // persist this change in viewState
        displayScale = Float(viewportScale)
        displayOriginX = 0;
        displayOriginY = 0;
    }
    
    private mutating func resetDisplay(_ display: CSDisplay) {
        display.viewportScale = 1.0
        display.viewportOrigin = .zero
        // persist this change in viewState
        displayScale = 1.0
        displayOriginX = 0
        displayOriginY = 0
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
                resetDisplay(display)
            } else {
                resizeDisplayToFit(display)
            }
        } else if case let .serial(serial, _) = device {
            resetConsole(serial)
            isViewportChanged = false
        }
    }
}
