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

import UIKit

/// Row of keys missing from the software keyboard, shown above it.
///
/// Modifiers stay pinned on the leading side and the paste and hide buttons on the trailing side
/// while the remaining keys scroll in between.
@objc final class VMKeyboardAccessoryView: UIInputView {
    private struct Key {
        let title: String
        let scanCode: Int32
        let accessibilityLabel: String?

        func makeButton(style: VMKeyboardButton.Style, isToggleable: Bool = false) -> VMKeyboardButton {
            let button = VMKeyboardButton(title: title, scanCode: scanCode, isToggleable: isToggleable, style: style)
            button.accessibilityLabel = accessibilityLabel
            return button
        }
    }

    private static let modifierKeys = [
        Key(title: "⌃", scanCode: 0x1D, accessibilityLabel: NSLocalizedString("Control", comment: "VMKeyboardAccessoryView")),
        Key(title: "⌥", scanCode: 0x38, accessibilityLabel: NSLocalizedString("Option", comment: "VMKeyboardAccessoryView")),
        Key(title: "⌘", scanCode: 0xE05B, accessibilityLabel: NSLocalizedString("Command", comment: "VMKeyboardAccessoryView")),
        Key(title: "⇧", scanCode: 0x2A, accessibilityLabel: NSLocalizedString("Shift", comment: "VMKeyboardAccessoryView")),
    ]

    private static let keys = [
        Key(title: "⇥", scanCode: 0x0F, accessibilityLabel: NSLocalizedString("Tab", comment: "VMKeyboardAccessoryView")),
        Key(title: "⎋", scanCode: 0x01, accessibilityLabel: NSLocalizedString("Escape", comment: "VMKeyboardAccessoryView")),
        Key(title: "↑", scanCode: 0xE048, accessibilityLabel: NSLocalizedString("Up", comment: "VMKeyboardAccessoryView")),
        Key(title: "↓", scanCode: 0xE050, accessibilityLabel: NSLocalizedString("Down", comment: "VMKeyboardAccessoryView")),
        Key(title: "←", scanCode: 0xE04B, accessibilityLabel: NSLocalizedString("Left", comment: "VMKeyboardAccessoryView")),
        Key(title: "→", scanCode: 0xE04D, accessibilityLabel: NSLocalizedString("Right", comment: "VMKeyboardAccessoryView")),
        Key(title: "Del", scanCode: 0xE053, accessibilityLabel: NSLocalizedString("Forward Delete", comment: "VMKeyboardAccessoryView")),
    ] + zip(1...12, [0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40, 0x41, 0x42, 0x43, 0x44, 0x57, 0x58]).map {
        Key(title: "F\($0)", scanCode: $1, accessibilityLabel: nil)
    } + [
        Key(title: "Caps", scanCode: 0x3A, accessibilityLabel: NSLocalizedString("Caps Lock", comment: "VMKeyboardAccessoryView")),
        Key(title: "Scroll", scanCode: 0x46, accessibilityLabel: NSLocalizedString("Scroll Lock", comment: "VMKeyboardAccessoryView")),
        Key(title: "Num", scanCode: 0x45, accessibilityLabel: NSLocalizedString("Num Lock", comment: "VMKeyboardAccessoryView")),
        Key(title: "Pr Scr", scanCode: 0xE037, accessibilityLabel: NSLocalizedString("Print Screen", comment: "VMKeyboardAccessoryView")),
        Key(title: "Ins", scanCode: 0xE052, accessibilityLabel: NSLocalizedString("Insert", comment: "VMKeyboardAccessoryView")),
        Key(title: "Home", scanCode: 0xE047, accessibilityLabel: NSLocalizedString("Home", comment: "VMKeyboardAccessoryView")),
        Key(title: "End", scanCode: 0xE04F, accessibilityLabel: NSLocalizedString("End", comment: "VMKeyboardAccessoryView")),
        Key(title: "Pg Up", scanCode: 0xE049, accessibilityLabel: NSLocalizedString("Page Up", comment: "VMKeyboardAccessoryView")),
        Key(title: "Pg Dn", scanCode: 0xE051, accessibilityLabel: NSLocalizedString("Page Down", comment: "VMKeyboardAccessoryView")),
    ]

    private static var style: VMKeyboardButton.Style {
        #if !os(visionOS)
        if #available(iOS 26, *) {
            return .glass
        }
        #endif
        return .classic
    }

    /// Toggleable keys which the target releases after another key is pressed.
    @objc let modifierButtons: [VMKeyboardButton]

    @objc init(target: VMDisplayMetalViewController) {
        let style = Self.style
        modifierButtons = Self.modifierKeys.map { $0.makeButton(style: style, isToggleable: true) }
        let keyButtons = Self.keys.map { $0.makeButton(style: style) }
        super.init(frame: .zero, inputViewStyle: .keyboard)
        allowsSelfSizing = true
        translatesAutoresizingMaskIntoConstraints = false

        for button in modifierButtons + keyButtons {
            button.addTarget(target, action: #selector(VMDisplayMetalViewController.customKeyTouchDown(_:)), for: .touchDown)
            button.addTarget(target, action: #selector(VMDisplayMetalViewController.customKeyTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        }
        let pasteButton = Self.makeActionButton(imageName: "Keyboard Paste",
                                                accessibilityLabel: NSLocalizedString("Paste", comment: "VMKeyboardAccessoryView"))
        pasteButton.addTarget(target, action: #selector(VMDisplayMetalViewController.keyboardPastePressed(_:)), for: .touchUpInside)
        let hideButton = Self.makeActionButton(imageName: "Keyboard Hide",
                                               accessibilityLabel: NSLocalizedString("Hide Keyboard", comment: "VMKeyboardAccessoryView"))
        hideButton.addTarget(target, action: #selector(VMDisplayMetalViewController.keyboardDonePressed(_:)), for: .touchUpInside)

        let keySpacing: CGFloat = style == .classic ? 8 : 6
        let modifierStack = UIStackView(arrangedSubviews: modifierButtons)
        modifierStack.spacing = keySpacing
        let keyStack = UIStackView(arrangedSubviews: keyButtons)
        keyStack.spacing = keySpacing
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.addSubview(keyStack)
        Self.pin(keyStack, to: scrollView.contentLayoutGuide)
        keyStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor).isActive = true
        let contentStack = UIStackView(arrangedSubviews: [modifierStack, scrollView, pasteButton, hideButton])
        contentStack.spacing = 8
        contentStack.alignment = .center

        switch style {
        case .classic:
            // the input view draws the keyboard's backdrop
            tintColor = .secondaryLabel
            // leave room for the key shadows inside the scroll view's clipping bounds
            keyStack.layoutMargins = .init(top: 1, left: 0, bottom: 1, right: 0)
            keyStack.isLayoutMarginsRelativeArrangement = true
            addSubview(contentStack)
            Self.pin(contentStack, to: safeAreaLayoutGuide, top: topAnchor, insets: .init(top: 3, left: 8, bottom: 3, right: 8))
        case .glass:
            #if !os(visionOS)
            guard #available(iOS 26, *) else { break }
            // The keyboard floats on its own glass panel so the keys get a matching one. Glass
            // takes its brightness from the guest display behind it and not from the keyboard's
            // appearance, so clear glass is filled with the keyboard's color to look the same.
            let bar = UIVisualEffectView(effect: UIGlassEffect(style: .clear))
            bar.cornerConfiguration = .corners(radius: 14.5)
            bar.contentView.cornerConfiguration = bar.cornerConfiguration
            bar.contentView.clipsToBounds = true
            bar.contentView.backgroundColor = .glassKeyboardBackdrop
            tintColor = .label
            // keys cut off by scrolling keep their rounded shape
            scrollView.layer.cornerRadius = style.cornerRadius
            scrollView.layer.cornerCurve = .continuous
            bar.contentView.addSubview(contentStack)
            addSubview(bar)
            Self.pin(contentStack, to: bar.contentView, insets: .init(top: 6, left: 6, bottom: 6, right: 6))
            Self.pin(bar, to: safeAreaLayoutGuide, top: topAnchor, insets: .init(top: 4, left: 8, bottom: 6, right: 8))
            #endif
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeActionButton(imageName: String, accessibilityLabel: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: imageName), for: .normal)
        button.accessibilityLabel = accessibilityLabel
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return button
    }

    /// - Parameter top: Overrides the top of `guide` when only its other edges should be respected.
    private static func pin(_ view: UIView, to guide: LayoutAnchorProviding, top: NSLayoutYAxisAnchor? = nil, insets: UIEdgeInsets = .zero) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: top ?? guide.topAnchor, constant: insets.top),
            view.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -insets.bottom),
            view.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -insets.right),
        ])
    }
}

private protocol LayoutAnchorProviding {
    var topAnchor: NSLayoutYAxisAnchor { get }
    var bottomAnchor: NSLayoutYAxisAnchor { get }
    var leadingAnchor: NSLayoutXAxisAnchor { get }
    var trailingAnchor: NSLayoutXAxisAnchor { get }
}

extension UIView: LayoutAnchorProviding {}
extension UILayoutGuide: LayoutAnchorProviding {}

private extension UIColor {
    /// Sits between the backdrops of the iOS 26 and iOS 27 keyboards, which differ slightly.
    static let glassKeyboardBackdrop = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 30/255, alpha: 0.85) : UIColor(red: 216/255, green: 218/255, blue: 222/255, alpha: 0.83)
    }
}
