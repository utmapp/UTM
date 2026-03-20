//
// Copyright © 2026 osy. All rights reserved.
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
import Logging

class VMDisplayWindow: NSWindow {
    // Minimum window size to prevent UI issues and crashes
    // Issue #7650: Setting bounds to {0, 0, 0, 0} causes crash.
    // We enforce a safe minimum size to prevent layout engines from failing.
    private let kMinWindowWidth: CGFloat = 400
    private let kMinWindowHeight: CGFloat = 300
    
    private func sanitizeFrame(_ frameRect: NSRect) -> NSRect {
        var frame = frameRect
        
        // Check for invalid or too small dimensions
        if frame.size.width < kMinWindowWidth {
            // Log warning only if it's significantly invalid (e.g. 0 or negative)
            if frame.size.width <= 0 {
                logger.warning("Attempted to set invalid window width: \(frame.size.width). Clamping to \(kMinWindowWidth).")
            }
            frame.size.width = kMinWindowWidth
        }
        
        if frame.size.height < kMinWindowHeight {
             if frame.size.height <= 0 {
                logger.warning("Attempted to set invalid window height: \(frame.size.height). Clamping to \(kMinWindowHeight).")
            }
            frame.size.height = kMinWindowHeight
        }
        
        return frame
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        let validFrame = sanitizeFrame(frameRect)
        super.setFrame(validFrame, display: flag)
    }
    
    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        let validFrame = sanitizeFrame(frameRect)
        super.setFrame(validFrame, display: displayFlag, animate: animateFlag)
    }
    
    override var minSize: NSSize {
        get {
            return NSSize(width: kMinWindowWidth, height: kMinWindowHeight)
        }
        set {
            super.minSize = newValue
        }
    }
}
