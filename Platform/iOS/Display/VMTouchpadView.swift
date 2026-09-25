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

#if !os(visionOS)
import UIKit

/// A trackpad for the bottom half of a device folded like a laptop, drawn like the keyboard it replaces.
///
/// One finger moves the pointer, a tap clicks, a two finger tap right-clicks, two fingers scroll and a
/// finger held down for a moment drags. Clicks come with a haptic tap like a physical trackpad.
///
/// The view needs the glass of iOS 26; the fold that brings it up is only reported from iOS 27.1.
@available(iOS 26, *)
@objc final class VMTouchpadView: UIView {
    private weak var target: VMDisplayMetalViewController?
    private let surface = UIView()
    private let clickFeedback = UIImpactFeedbackGenerator(style: .rigid)
    private let releaseFeedback = UIImpactFeedbackGenerator(style: .light)
    private var lastLocation: CGPoint = .zero
    private var isHolding = false

    @objc init(target: VMDisplayMetalViewController) {
        self.target = target
        super.init(frame: .zero)

        let panel = UIVisualEffectView(effect: UIGlassEffect(style: .clear))
        panel.cornerConfiguration = .corners(radius: 14.5)
        panel.contentView.cornerConfiguration = panel.cornerConfiguration
        panel.contentView.clipsToBounds = true
        panel.contentView.backgroundColor = .glassKeyboardBackdrop
        addSubview(panel)
        VMKeyboardAccessoryView.pin(panel, to: safeAreaLayoutGuide, insets: .init(top: 8, left: 8, bottom: 6, right: 8))

        surface.backgroundColor = .glassKey
        surface.layer.cornerRadius = VMKeyboardButton.Style.glass.cornerRadius
        surface.layer.cornerCurve = .continuous
        surface.isAccessibilityElement = true
        surface.accessibilityLabel = NSLocalizedString("Touchpad", comment: "VMTouchpadView")
        panel.contentView.addSubview(surface)
        VMKeyboardAccessoryView.pin(surface, to: panel.contentView, insets: .init(top: 6, left: 6, bottom: 6, right: 6))

        let keyboardButton = VMKeyboardAccessoryView.makeActionButton(image: UIImage(systemName: "keyboard"),
                                                                       accessibilityLabel: NSLocalizedString("Show Keyboard", comment: "VMTouchpadView"))
        keyboardButton.tintColor = .label
        keyboardButton.addTarget(target, action: #selector(VMDisplayMetalViewController.touchpadKeyboardPressed(_:)), for: .touchUpInside)
        keyboardButton.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(keyboardButton)
        NSLayoutConstraint.activate([
            keyboardButton.topAnchor.constraint(equalTo: surface.topAnchor, constant: 8),
            keyboardButton.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -8),
        ])

        let move = UIPanGestureRecognizer(target: self, action: #selector(handleMove(_:)))
        move.maximumNumberOfTouches = 1
        move.delegate = self
        let scroll = UIPanGestureRecognizer(target: self, action: #selector(handleScroll(_:)))
        scroll.minimumNumberOfTouches = 2
        scroll.maximumNumberOfTouches = 2
        let click = UITapGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        let rightClick = UITapGestureRecognizer(target: self, action: #selector(handleRightClick(_:)))
        rightClick.numberOfTouchesRequired = 2
        click.require(toFail: rightClick)
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleHold(_:)))
        hold.minimumPressDuration = 0.3
        hold.delegate = self
        for recognizer in [move, scroll, click, rightClick, hold] {
            surface.addGestureRecognizer(recognizer)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        clickFeedback.prepare()
        super.touchesBegan(touches, with: event)
    }

    // MARK: - Gestures

    @objc private func handleMove(_ sender: UIPanGestureRecognizer) {
        let location = sender.location(in: self)
        if sender.state == .changed {
            target?.touchpadMove(by: CGPoint(x: location.x - lastLocation.x, y: location.y - lastLocation.y))
        }
        lastLocation = location
    }

    @objc private func handleScroll(_ sender: UIPanGestureRecognizer) {
        target?.scroll(withInertia: sender)
    }

    @objc private func handleClick(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            sendClick(.left)
        }
    }

    @objc private func handleRightClick(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            sendClick(.right)
        }
    }

    /// A held finger keeps the button down so the pointer drags along with it.
    @objc private func handleHold(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            isHolding = true
            clickFeedback.impactOccurred()
            target?.touchpadPress(.left, pressed: true)
        case .ended, .cancelled, .failed:
            guard isHolding else {
                break
            }
            isHolding = false
            releaseFeedback.impactOccurred()
            target?.touchpadPress(.left, pressed: false)
        default:
            break
        }
    }

    private func sendClick(_ button: CSInputButton) {
        clickFeedback.impactOccurred()
        target?.touchpadPress(button, pressed: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.target?.touchpadPress(button, pressed: false)
        }
    }

}

@available(iOS 26, *)
extension VMTouchpadView: UIGestureRecognizerDelegate {
    /// The pointer keeps moving while a held finger drags.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UILongPressGestureRecognizer) ||
        (gestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer)
    }
}
#endif
