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

#if os(macOS)
import Foundation
import GameController
#if !WITH_USB
import CocoaSpiceNoUsb
#else
import CocoaSpice
#endif

/// Feeds the host's game controller to the guest's `poweremu-gamepad` USB device
/// (from ppc-osx-vgpu), over the `com.utmapp.gamepad.0` SPICE port.
///
/// Mac OS X 10.4/10.5 have no driver for modern Xbox or PlayStation pads, so the
/// guest sees a plain USB gamepad instead and this sends it 9-byte readings:
///
///     0-3  left X, left Y, right X, right Y   (128 centred, Y grows downwards)
///     4-5  left trigger, right trigger         (0 released)
///     6    direction pad                       (0 up, clockwise in eighths, 15 none)
///     7    buttons 1-8: A B X Y, LB RB, LT RT (triggers past half way)
///     8    buttons 9-16: View, Menu, L3, R3, then the direction pad up, down, left, right
@MainActor
final class UTMGamepadBridge {
    private static let neutral: [UInt8] = [128, 128, 128, 128, 0, 0, 15, 0, 0]

    private weak var ioService: UTMSpiceIO?
    private var portObservation: NSKeyValueObservation?
    private var notificationObservers: [NSObjectProtocol] = []
    private weak var controller: GCController?
    private var lastSent: [UInt8]?

    init(ioService: UTMSpiceIO) {
        self.ioService = ioService
    }

    func start() {
        if #available(macOS 11.3, *) {
            // The guest window may not be key while a game runs full screen in it.
            GCController.shouldMonitorBackgroundEvents = true
        }
        let center = NotificationCenter.default
        notificationObservers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.selectController() }
        })
        notificationObservers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.selectController() }
        })
        // the port opens once SPICE has connected; give it the current state then
        portObservation = ioService?.observe(\.gamepadPort, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.lastSent = nil
                self?.send()
            }
        }
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
        selectController()
    }

    func stop() {
        GCController.stopWirelessControllerDiscovery()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers = []
        portObservation = nil
        controller?.extendedGamepad?.valueChangedHandler = nil
        controller = nil
    }

    private func selectController() {
        let next = GCController.controllers().first { $0.extendedGamepad != nil }
        if next !== controller {
            controller?.extendedGamepad?.valueChangedHandler = nil
            controller = next
            controller?.extendedGamepad?.valueChangedHandler = { [weak self] _, _ in
                Task { @MainActor in self?.send() }
            }
            if let name = next?.vendorName {
                logger.debug("Game controller for the guest: \(name)")
            }
        }
        send()
    }

    private func send() {
        guard let port = ioService?.gamepadPort else {
            return
        }
        let report = controller?.extendedGamepad.map(Self.report(for:)) ?? Self.neutral
        if report != lastSent {
            port.write(Data(report))
            lastSent = report
        }
    }

    private static func axis(_ value: Float, inverted: Bool = false) -> UInt8 {
        let v = inverted ? -value : value
        return UInt8(max(0, min(255, ((v + 1) * 127.5).rounded())))
    }

    private static func trigger(_ value: Float) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }

    private static func report(for pad: GCExtendedGamepad) -> [UInt8] {
        let dpad = pad.dpad
        let up = dpad.up.isPressed, down = dpad.down.isPressed
        let left = dpad.left.isPressed, right = dpad.right.isPressed
        let hat: UInt8
        switch (up, right, down, left) {
        case (true, false, false, false): hat = 0
        case (true, true, false, false): hat = 1
        case (false, true, false, false): hat = 2
        case (false, true, true, false): hat = 3
        case (false, false, true, false): hat = 4
        case (false, false, true, true): hat = 5
        case (false, false, false, true): hat = 6
        case (true, false, false, true): hat = 7
        default: hat = 15
        }
        let low: [Bool] = [pad.buttonA.isPressed, pad.buttonB.isPressed,
                           pad.buttonX.isPressed, pad.buttonY.isPressed,
                           pad.leftShoulder.isPressed, pad.rightShoulder.isPressed,
                           pad.leftTrigger.value > 0.5, pad.rightTrigger.value > 0.5]
        let high: [Bool] = [pad.buttonOptions?.isPressed ?? false, pad.buttonMenu.isPressed,
                            pad.leftThumbstickButton?.isPressed ?? false,
                            pad.rightThumbstickButton?.isPressed ?? false,
                            up, down, left, right]
        func bits(_ buttons: [Bool]) -> UInt8 {
            buttons.enumerated().reduce(0) { $1.element ? $0 | UInt8(1 << $1.offset) : $0 }
        }
        return [axis(pad.leftThumbstick.xAxis.value),
                axis(pad.leftThumbstick.yAxis.value, inverted: true),
                axis(pad.rightThumbstick.xAxis.value),
                axis(pad.rightThumbstick.yAxis.value, inverted: true),
                trigger(pad.leftTrigger.value),
                trigger(pad.rightTrigger.value),
                hat, bits(low), bits(high)]
    }
}
#endif
