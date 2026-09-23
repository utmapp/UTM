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

import SwiftUI

/// A bezeled, multi-line text field that grows with its contents.
///
/// `TextEditor` has no bezel and `TextField(axis: .vertical)` submits on Return,
/// so this wraps an `NSTextField` and lets AppKit draw the same bezel and focus
/// ring as a single-line `TextField`.
struct MultilineTextField: NSViewRepresentable {
    @Binding var text: String
    var minHeight: CGFloat = 0

    func makeNSView(context: Context) -> WrappingTextField {
        let field = WrappingTextField()
        field.minHeight = minHeight
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: WrappingTextField, context: Context) {
        context.coordinator.parent = self
        field.disableAutocorrection = context.environment.disableAutocorrection
        if field.minHeight != minHeight {
            field.minHeight = minHeight
            field.invalidateIntrinsicContentSize()
        }
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    @available(macOS 13, *)
    func sizeThatFits(_ proposal: ProposedViewSize, nsView field: WrappingTextField, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, let cell = field.cell else {
            return nil
        }
        guard width > 0 else {
            return CGSize(width: 0, height: minHeight)
        }
        let bounds = NSRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude)
        return CGSize(width: width, height: max(cell.cellSize(forBounds: bounds).height, minHeight))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MultilineTextField

        init(_ parent: MultilineTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else {
                return
            }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                textView.insertNewlineIgnoringFieldEditor(nil)
                return true
            }
            return false
        }
    }

    /// Wraps at the current width so the intrinsic height follows the text on macOS 12,
    /// where SwiftUI sizes the view from `intrinsicContentSize`.
    class WrappingTextField: NSTextField {
        var minHeight: CGFloat = 0
        /// SwiftUI's `disableAutocorrection` does not reach the field editor, so it is applied by hand.
        var disableAutocorrection: Bool?

        override var intrinsicContentSize: NSSize {
            var size = super.intrinsicContentSize
            size.height = max(size.height, minHeight)
            return size
        }

        override func becomeFirstResponder() -> Bool {
            let result = super.becomeFirstResponder()
            if result, let textView = currentEditor() as? NSTextView {
                // the field editor is shared by the window, so always set it
                textView.isAutomaticSpellingCorrectionEnabled = disableAutocorrection != true && NSSpellChecker.isAutomaticSpellingCorrectionEnabled
            }
            return result
        }

        override func layout() {
            if preferredMaxLayoutWidth != bounds.width {
                preferredMaxLayoutWidth = bounds.width
                invalidateIntrinsicContentSize()
            }
            super.layout()
        }
    }
}
