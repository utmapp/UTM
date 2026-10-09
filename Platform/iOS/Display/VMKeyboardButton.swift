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

// Classic key colors taken from iSH: https://github.com/tbodt/ish/blob/master/app/BarButton.m
//  Created by Theodore Dubois on 9/22/18.
//  Licensed under GNU General Public License 3.0

import UIKit

/// A key on the keyboard accessory, drawn to match the keys of the system keyboard.
@objc final class VMKeyboardButton: UIButton {
    enum Style {
        /// Shadowed keys of the iOS 18 and earlier keyboard.
        case classic
        /// Flat rounded keys of the iOS 26 Liquid Glass keyboard.
        case glass

        var cornerRadius: CGFloat {
            switch self {
            case .classic: return 5
            case .glass: return 8.5
            }
        }
    }

    /// PS/2 scan code sent to the guest, prefixed with 0xE0 for extended keys.
    @objc let scanCode: Int32

    /// Modifier keys stay held after a tap until the next key is pressed.
    @objc let isToggleable: Bool

    @objc var isToggled = false {
        didSet { updateColors() }
    }

    override var isHighlighted: Bool {
        didSet { updateColors(isReleased: !isHighlighted) }
    }

    private let style: Style

    init(title: String, scanCode: Int32, isToggleable: Bool = false, style: Style) {
        self.scanCode = scanCode
        self.isToggleable = isToggleable
        self.style = style
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        layer.cornerRadius = style.cornerRadius
        switch style {
        case .classic:
            layer.shadowOffset = CGSize(width: 0, height: 1)
            layer.shadowOpacity = 0.4
            layer.shadowRadius = 0
        case .glass:
            layer.cornerCurve = .continuous
        }
        accessibilityTraits.insert(.keyboardKey)
        if isToggleable, #available(iOS 17, *) {
            accessibilityTraits.insert(.toggleButton)
        }
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        updateMetrics()
        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var accessibilityValue: String? {
        get { isToggleable ? (isToggled ? "1" : "0") : nil }
        set { }
    }

    // MARK: - Metrics

    /// Keys grow to the size of the iPad keyboard's keys when it is shown full width.
    private var isLarge: Bool {
        traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular
    }

    private var minimumSize: CGSize {
        switch (style, isLarge) {
        case (.classic, false): return CGSize(width: 30, height: 36)
        case (.classic, true): return CGSize(width: 60, height: 60)
        case (.glass, false): return CGSize(width: 34, height: 38)
        case (.glass, true): return CGSize(width: 54, height: 54)
        }
    }

    /// Symbols are drawn like the keyboard's letters and words like its "return" key.
    private var isSymbol: Bool {
        currentTitle?.count == 1
    }

    override var intrinsicContentSize: CGSize {
        var size = minimumSize
        if !isSymbol, let titleLabel {
            size.width = max(size.width, titleLabel.intrinsicContentSize.width + 16)
        }
        return size
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateMetrics()
    }

    private func updateMetrics() {
        let pointSize: CGFloat = isSymbol ? (isLarge ? 24 : 20) : (isLarge ? 18 : 15)
        titleLabel?.font = .systemFont(ofSize: pointSize)
        invalidateIntrinsicContentSize()
    }

    // MARK: - Colors

    private func updateColors(isReleased: Bool = false) {
        let isActive = isHighlighted || isToggled
        let fill: UIColor
        let text: UIColor
        switch style {
        case .classic:
            // modifiers are drawn like the shift key and swap colors with regular keys when active
            fill = isToggleable != isActive ? .classicDarkKey : .classicLightKey
            text = .label
        case .glass:
            fill = isToggled ? .glassToggledKey : isHighlighted ? .glassPressedKey : .glassKey
            text = isToggled ? .glassToggledText : .label
        }
        let apply = {
            self.backgroundColor = fill
            self.setTitleColor(text, for: .normal)
        }
        if isReleased && !isActive {
            // keep the pressed state visible for quick taps
            UIView.animate(withDuration: 0, delay: 0.1, options: .allowUserInteraction, animations: apply)
        } else {
            apply()
        }
    }
}

private extension UIColor {
    convenience init(light: UIColor, dark: UIColor) {
        self.init { $0.userInterfaceStyle == .dark ? dark : light }
    }

    static let classicLightKey = UIColor(light: .white,
                                         dark: UIColor(white: 1, alpha: 77/255))
    static let classicDarkKey = UIColor(light: UIColor(red: 172/255, green: 180/255, blue: 190/255, alpha: 1),
                                        dark: UIColor(white: 147/255, alpha: 66/255))
    static let glassKey = UIColor(light: UIColor(white: 1, alpha: 0.8),
                                  dark: UIColor(white: 1, alpha: 0.16))
    static let glassToggledKey = UIColor(light: .black, dark: .white)
    static let glassToggledText = UIColor(light: .white, dark: .black)
    static let glassPressedKey = UIColor(light: UIColor(white: 1, alpha: 0.4),
                                         dark: UIColor(white: 1, alpha: 0.32))
}
