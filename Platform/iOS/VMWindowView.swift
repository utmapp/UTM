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
import SwiftUIVisualEffects
#if os(visionOS)
import VisionKeyboardKit
#endif

struct VMWindowView: View {
    let id: VMSessionState.WindowID

    @State var isInteractive = true
    @State private var state: VMWindowState
    @EnvironmentObject private var session: VMSessionState
    @Environment(\.scenePhase) private var scenePhase
    #if os(visionOS)
    @Environment(\.dismissWindow) private var dismissWindow
    #endif

    private let keyboardDidShowNotification = NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)
    private let keyboardDidHideNotification = NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)
    private let didReceiveMemoryWarningNotification = NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)

    init(id: VMSessionState.WindowID, isInteractive: Bool = true) {
        self.id = id
        self._isInteractive = State<Bool>(initialValue: isInteractive)
        self._state = State<VMWindowState>(initialValue: VMWindowState(id: id))
    }

    private func withOptionalAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
        if UIAccessibility.isReduceMotionEnabled {
            return try body()
        } else {
            return try withAnimation(animation, body)
        }
    }
    
    var body: some View {
        ZStack {
            ZStack {
                if let device = state.device {
                    switch device {
                    case .display(_, _):
                        VMDisplayHostedView(vm: session.vm, device: device, state: $state)
                            .prefersPersistentSystemOverlaysHidden()
                            .defersSystemGesturesOnAllEdges()
                    case .serial(_, _):
                        VMDisplayHostedView(vm: session.vm, device: device, state: $state)
                            .prefersPersistentSystemOverlaysHidden()
                    }
                } else if !state.isBusy && state.isRunning {
                    // headless
                    HeadlessView()
                }
                if state.isBusy || !state.isRunning {
                    BlurEffect().blurEffectStyle(.light)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            if state.isBusy {
                                Spinner(size: .large)
                            } else if session.vmState == .paused {
                                Button {
                                    session.vm.requestVmResume()
                                } label: {
                                    if #available(iOS 16, *) {
                                        Label("Resume", systemImage: "playpause.circle.fill")
                                    } else {
                                        Label("Resume", systemImage: "play.circle.fill")
                                    }
                                }
                            } else {
                                Button {
                                    session.vm.requestVmStart()
                                } label: {
                                    Label("Start", systemImage: "play.circle.fill")
                                }
                            }
                            Spacer()
                        }
                        Spacer()
                    }.labelStyle(.iconOnly)
                        .font(.system(size: 128))
                        .vibrancyEffect()
                        .vibrancyEffectStyle(.label)
                        .clearOfReservedDivisions()
                }
            }.background(Color.black)
            .modifier(InputDeckModifier(state: $state))
            .ignoresSafeArea()
            #if !os(visionOS)
            if isInteractive && state.isRunning {
                VMToolbarView(state: $state)
            }
            #endif
        }
        .modifier(VMToolbarOrnamentModifier(state: $state))
        .modifier(VMWindowCloseConfirmationModifier(isInteractive: isInteractive))
        .statusBarHidden(true)
        .alert(item: $state.alert, content: { type in
            switch type {
            case .powerDown:
                return Alert(title: Text("Are you sure you want to stop this VM and exit? Any unsaved changes will be lost."), primaryButton: .destructive(Text("Yes")) {
                    session.powerDown()
                }, secondaryButton: .cancel(Text("No")))
            case .terminateApp:
                return Alert(title: Text("Are you sure you want to exit UTM?"), primaryButton: .destructive(Text("Yes")) {
                    session.powerDown(isKill: true)
                }, secondaryButton: .cancel(Text("No")))
            case .restart:
                return Alert(title: Text("Are you sure you want to reset this VM? Any unsaved changes will be lost."), primaryButton: .destructive(Text("Yes")) {
                    session.reset()
                }, secondaryButton: .cancel(Text("No")))
            #if WITH_USB
            case .deviceConnected(let device):
                return Alert(title: Text("Would you like to connect '\(device.name ?? device.description)' to this virtual machine?"), primaryButton: .default(Text("Yes")) {
                    session.mostRecentConnectedDevice = nil
                    session.connectDevice(device)
                }, secondaryButton: .cancel(Text("No")) {
                    session.mostRecentConnectedDevice = nil
                })
            #endif
            case .nonfatalError(let message), .fatalError(let message):
                return Alert(title: Text(message), dismissButton: .cancel(Text("OK")) {
                    if case .fatalError(_) = type {
                        session.stop()
                    } else if session.vmState == .stopped {
                        session.stop()
                    } else {
                        session.nonfatalError = nil
                    }
                })
            case .memoryWarning:
                return Alert(title: Text("Running low on memory! UTM might soon be killed by iOS. You can prevent this by decreasing the amount of memory and/or JIT cache assigned to this VM"), dismissButton: .cancel(Text("OK")) {
                    session.didReceiveMemoryWarning()
                })
            }
        })
        .onChange(of: session.windowDeviceMap) { windowDeviceMap in
            if let device = windowDeviceMap[state.id] {
                state.device = device
            } else {
                state.device = nil
            }
        }
        .onChange(of: state.device) { [oldDevice = state.device] newDevice in
            if session.windowDeviceMap[state.id] != newDevice {
                session.windowDeviceMap[state.id] = newDevice
            }
            state.saveWindow(to: session.vm.registryEntry, device: oldDevice)
            state.restoreWindow(from: session.vm.registryEntry, device: newDevice)
        }
        #if WITH_USB
        .onChange(of: session.mostRecentConnectedDevice) { newValue in
            if session.activeWindow == state.id, let device = newValue {
                state.alert = .deviceConnected(device)
            }
        }
        #endif
        .onChange(of: session.nonfatalError) { newValue in
            if session.activeWindow == state.id, let message = newValue {
                state.alert = .nonfatalError(message)
            }
        }
        .onChange(of: session.fatalError) { newValue in
            if session.activeWindow == state.id, let message = newValue {
                state.alert = .fatalError(message)
            }
        }
        .onChange(of: session.vmState) { [oldValue = session.vmState] newValue in
            vmStateUpdated(from: oldValue, to: newValue)
        }
        .onChange(of: session.isDynamicResolutionSupported) { newValue in
            state.isDynamicResolutionSupported = newValue
        }
        .onReceive(keyboardDidShowNotification) { notification in
            // a keyboard placed off the screen, which the system does while moving it between the
            // panels of a folding device, is not one the user can type on
            guard notification.isKeyboardOnScreen else {
                return
            }
            state.isKeyboardShown = true
            state.isKeyboardRequested = true
        }
        .onReceive(keyboardDidHideNotification) { _ in
            state.isKeyboardShown = false
            state.isKeyboardRequested = false
        }
        .onReceive(didReceiveMemoryWarningNotification) { _ in
            if session.activeWindow == state.id && !session.hasShownMemoryWarning {
                session.hasShownMemoryWarning = true
                state.alert = .memoryWarning
            }
        }
        .onChange(of: scenePhase) { newValue in
            guard session.activeWindow == state.id else {
                return
            }
            if newValue == .background {
                saveWindow()
                session.didEnterBackground()
            } else if newValue == .active {
                session.didEnterForeground()
            }
        }
        .onAppear {
            vmStateUpdated(from: nil, to: session.vmState)
            session.registerWindow(state.id, isExternal: !isInteractive)
            if !isInteractive {
                session.externalWindowBinding = $state
            }
            state.isDynamicResolutionSupported = session.isDynamicResolutionSupported
            // in case an alert appeared before we created the view
            if session.activeWindow == state.id {
                #if WITH_USB
                if let device = session.mostRecentConnectedDevice {
                    state.alert = .deviceConnected(device)
                }
                #endif
                if let nonfatalError = session.nonfatalError {
                    state.alert = .nonfatalError(nonfatalError)
                }
                if let fatalError = session.fatalError {
                    state.alert = .fatalError(fatalError)
                }
            }
        }
        .onDisappear {
            session.removeWindow(state.id)
            if !isInteractive {
                session.externalWindowBinding = nil
            }
            #if os(visionOS)
            dismissWindow(keyboardFor: state.id)
            #endif
        }
    }
    
    private func vmStateUpdated(from oldState: UTMVirtualMachineState?, to vmState: UTMVirtualMachineState) {
        if oldState == .started {
            saveWindow()
        }
        switch vmState {
        case .stopped, .paused:
            withOptionalAnimation {
                state.isBusy = false
                state.isRunning = false
            }
            // do not close if we have a popup open
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                if session.nonfatalError == nil && session.fatalError == nil {
                    if session.vmState == .stopped {
                        session.stop()
                    }
                }
            }
        case .pausing, .stopping, .starting, .resuming, .saving, .restoring:
            withOptionalAnimation {
                state.isBusy = true
                state.isRunning = false
            }
        case .started:
            withOptionalAnimation {
                state.isBusy = false
                state.isRunning = true
            }
        }
    }
    
    private func saveWindow() {
        state.saveWindow(to: session.vm.registryEntry, device: state.device)
    }
}

private struct HeadlessView: View {
    var body: some View {
        ZStack {
            BlurEffect().blurEffectStyle(.dark)
            VStack {
                Image(systemName: "rectangle.dashed")
                    .font(.title)
                Text("No output device is selected for this window.")
                    .foregroundColor(.white)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }.padding()
                .frame(width: 200, height: 200, alignment: .center)
                .foregroundColor(.white)
                .background(Color.gray.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
                .vibrancyEffect()
                .vibrancyEffectStyle(.label)
                .clearOfReservedDivisions()
        }
    }
}

// MARK: - Folding devices

/// Gives the bottom half of a device folded like a laptop to the keyboard or touchpad.
///
/// The trigger is the fold itself, reported as an active horizontal division, since Apple keeps the
/// hinge angle for effects and the reserved regions for layout.
private struct InputDeckModifier: ViewModifier {
    @Binding var state: VMWindowState
    @State private var hingeGeneration = 0
    @State private var hingeSettling = HingeSettling()
    @State private var keyboardRequest = DeferredWork()

    private func requestDeckKeyboard() {
        keyboardRequest.schedule(after: [0.8, 2.5]) {
            if state.wantsDeckKeyboard {
                state.isKeyboardRequested = true
            }
        }
    }

    func body(content: Content) -> some View {
        #if !os(visionOS) && canImport(SwiftUI, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            content.background(GeometryReader { proxy in
                let deck = proxy.inputDeck(hingeGeneration: hingeGeneration)
                Color.clear
                    .onAppear {
                        state.setInputDeck(deck)
                        requestDeckKeyboard()
                    }
                    .onChange(of: deck) { oldValue, newValue in
                        state.setInputDeck(newValue)
                        // only a fresh fold asks for the keyboard, so that one the user dismissed stays away
                        if oldValue == nil && newValue != nil {
                            requestDeckKeyboard()
                        }
                    }
                    .onChange(of: state.isKeyboardShown) { _, isShown in
                        // once the keyboard has shown, dismissing it is the user's choice
                        if isShown {
                            keyboardRequest.cancel()
                        }
                    }
            })
            .environment(\.hingeGeneration, hingeGeneration)
            .onHingeChange { _, _ in
                hingeSettling.refresh($hingeGeneration)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Work scheduled for later that can still be called off.
private final class DeferredWork {
    private var pending: [DispatchWorkItem] = []

    func schedule(after delays: [TimeInterval], _ work: @escaping () -> Void) {
        cancel()
        pending = delays.map { delay in
            let item = DispatchWorkItem(block: work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    }

    func cancel() {
        pending.forEach { $0.cancel() }
        pending = []
    }
}

/// Re-evaluates the region readers after a hinge change.
///
/// A fold becoming active does not change the window's size, and it becomes active a moment
/// after the last hinge event, so the readers are asked again a few times after the hinge stops.
/// The window's input deck owns the timers and passes the count down to the other readers.
private final class HingeSettling {
    private static let delays: [TimeInterval] = [0, 0.5, 1.5, 3]
    private var pending: [DispatchWorkItem] = []

    func refresh(_ generation: Binding<Int>) {
        pending.forEach { $0.cancel() }
        pending = Self.delays.map { delay in
            let item = DispatchWorkItem {
                generation.wrappedValue += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    }
}

#if !os(visionOS) && canImport(SwiftUI, _version: 8.0.85)
@available(iOS 27.1, *)
extension GeometryProxy {
    /// The part below a horizontal fold, where a device folded like a laptop lies flat.
    ///
    /// The readers pass a value that changes as the hinge settles so they are evaluated again.
    func inputDeck(hingeGeneration: Int) -> VMWindowState.InputDeckLayout? {
        let fold = reservedRegions(kind: .division).first { $0.isActive && $0.frame.width > $0.frame.height }
        guard let fold = fold else {
            return nil
        }
        // layout passes differ in the last bits, which must not read as a new deck every time
        let foldFrame = fold.frame.roundedToQuarterPoints
        let frame = CGRect(x: 0, y: foldFrame.maxY, width: size.width, height: max(0, size.height - foldFrame.maxY)).roundedToQuarterPoints
        return VMWindowState.InputDeckLayout(frame: frame, fold: foldFrame)
    }

    /// The largest part of the view that no active fold runs through, or all of it.
    func frameClearOfDivisions(hingeGeneration: Int) -> CGRect {
        var frame = CGRect(origin: .zero, size: size)
        for region in reservedRegions(kind: .division) where region.isActive {
            let division = region.frame
            let parts = [
                frame.part(maxY: division.minY),
                frame.part(minY: division.maxY),
                frame.part(maxX: division.minX),
                frame.part(minX: division.maxX),
            ]
            frame = parts.max { $0.width * $0.height < $1.width * $1.height }!
        }
        return frame
    }
}

private extension CGRect {
    var roundedToQuarterPoints: CGRect {
        func round(_ value: CGFloat) -> CGFloat {
            (value * 4).rounded() / 4
        }
        return CGRect(x: round(minX), y: round(minY), width: round(width), height: round(height))
    }

    /// The rectangle cut down to the given edges, empty when nothing is left.
    func part(minX: CGFloat? = nil, minY: CGFloat? = nil, maxX: CGFloat? = nil, maxY: CGFloat? = nil) -> CGRect {
        let left = max(self.minX, minX ?? self.minX)
        let top = max(self.minY, minY ?? self.minY)
        let right = min(self.maxX, maxX ?? self.maxX)
        let bottom = min(self.maxY, maxY ?? self.maxY)
        return CGRect(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
    }
}
#endif

/// Keeps centred interactive content out of the fold of a partially folded device.
///
/// Alerts, menus and sheets move out of the fold by themselves; a control centred in the
/// window does not.
private struct ClearOfReservedDivisionsModifier: ViewModifier {
    @Environment(\.hingeGeneration) private var hingeGeneration

    func body(content: Content) -> some View {
        #if !os(visionOS) && canImport(SwiftUI, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            GeometryReader { proxy in
                let frame = proxy.frameClearOfDivisions(hingeGeneration: hingeGeneration)
                content
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct HingeGenerationKey: EnvironmentKey {
    static let defaultValue = 0
}

private extension EnvironmentValues {
    /// Changes while the hinge of a folding device settles, so that readers of reserved regions are evaluated again.
    var hingeGeneration: Int {
        get { self[HingeGenerationKey.self] }
        set { self[HingeGenerationKey.self] = newValue }
    }
}

private extension View {
    func clearOfReservedDivisions() -> some View {
        modifier(ClearOfReservedDivisionsModifier())
    }
}

#if !os(visionOS)
/// Stub for non-Vision platforms
fileprivate struct VMToolbarOrnamentModifier: ViewModifier {
    @Binding var state: VMWindowState
    func body(content: Content) -> some View {
        content
    }
}
#endif

#if !os(visionOS)
private extension Notification {
    /// Whether the keyboard in a keyboard notification ends up on the screen it was posted for.
    var isKeyboardOnScreen: Bool {
        guard let frame = userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return true
        }
        guard let screen = object as? UIScreen else {
            return true
        }
        return frame.intersection(screen.bounds).height > 0
    }
}
#else
private extension Notification {
    var isKeyboardOnScreen: Bool {
        true
    }
}
#endif

private extension View {
    /// A touch that starts at a screen edge is otherwise held back for the system and never reaches the guest
    func defersSystemGesturesOnAllEdges() -> some View {
        #if os(visionOS)
        return self
        #else
        if #available(iOS 16, *) {
            return self.defersSystemGestures(on: .all)
        } else {
            return self
        }
        #endif
    }

    func prefersPersistentSystemOverlaysHidden() -> some View {
        if #available(iOS 16, *) {
            return self.persistentSystemOverlays(.hidden)
        } else {
            return self
        }
    }
}

/// Asks before the system closes the last window of a running VM, which would end it without saving.
private struct VMWindowCloseConfirmationModifier: ViewModifier {
    let isInteractive: Bool

    @EnvironmentObject private var session: VMSessionState

    private var isLastWindowOfRunningVM: Bool {
        let externalWindows = session.externalWindowBinding == nil ? 0 : 1
        // a VM that is still pausing or saving would lose its state as well
        let isSafeToClose = session.vmState == .stopped || (session.vmState == .paused && session.vm.registryEntry.isSuspended)
        return isInteractive && !isSafeToClose && session.windows.count - externalWindows <= 1
    }

    func body(content: Content) -> some View {
        #if os(visionOS) || WITH_REMOTE
        content
        #else
        if #available(iOS 27, *) {
            content.dismissalConfirmationDialog("This virtual machine is still running.", shouldPresent: isLastWindowOfRunningVM) {
                Button("Stop", role: .destructive) {
                    session.powerDown()
                }
            } message: {
                Text("Closing the window stops the virtual machine. Any unsaved changes will be lost.")
            }
        } else {
            content
        }
        #endif
    }
}

