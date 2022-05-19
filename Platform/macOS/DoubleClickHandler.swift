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

import SwiftUI

// from https://gist.github.com/joelekstrom/91dad79ebdba409556dce663d28e8297
extension View {
    /// Adds a double click handler this view (macOS only)
    ///
    /// Example
    /// ```
    /// Text("Hello")
    ///     .onDoubleClick { print("Double click detected") }
    /// ```
    /// - Parameters:
    ///   - handler: Block invoked when a double click is detected
    func onDoubleClick(handler: @escaping () -> Void) -> some View {
        modifier(DoubleClickHandler(handler: handler))
    }
}

struct DoubleClickHandler: ViewModifier {
    let handler: () -> Void
    func body(content: Content) -> some View {
        content.overlay(DoubleClickListeningViewRepresentable(handler: handler))
    }
}

struct DoubleClickListeningViewRepresentable: NSViewRepresentable {
    let handler: () -> Void
    func makeNSView(context: Context) -> DoubleClickListeningView {
        DoubleClickListeningView(handler: handler)
    }
    func updateNSView(_ nsView: DoubleClickListeningView, context: Context) {}
}

class DoubleClickListeningView: NSView {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        self.isHidden = true
        if event.modifierFlags.contains(.control) {
            let rightEvent = NSEvent.mouseEvent(with: .rightMouseDown,
                                                location: event.locationInWindow,
                                                modifierFlags: event.modifierFlags.subtracting(.control),
                                                timestamp: event.timestamp,
                                                windowNumber: event.windowNumber,
                                                context: nil,
                                                eventNumber: event.eventNumber,
                                                clickCount: event.clickCount,
                                                pressure: event.pressure)!
            super.rightMouseDown(with: rightEvent)
        } else {
            super.mouseDown(with: event)
        }
        self.isHidden = false
        if event.clickCount == 2 {
            handler()
        }
    }
}
