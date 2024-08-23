//
// Copyright © 2021 osy. All rights reserved.
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
import TipKit

struct VMToolbarView: View {
    @AppStorage("ToolbarIsCollapsed") private var isCollapsed: Bool = false
    @AppStorage("ToolbarLocation") private var location: ToolbarLocation = .topRight
    @State private var shake: Bool = true
    @State private var isMoving: Bool = false
    @State private var isIdle: Bool = false
    @State private var dragPosition: CGPoint = .zero
    @State private var shortIdleTask: DispatchWorkItem?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var session: VMSessionState
    @StateObject private var longIdleTimeout = LongIdleTimeout()
    
    @Binding var state: VMWindowState
    
    private var spacing: CGFloat {
        let direction: CGFloat
        let distance: CGFloat
        if location == .topLeft || location == .bottomLeft {
            direction = -1
        } else {
            direction = 1
        }
        if horizontalSizeClass == .compact || verticalSizeClass == .compact {
            distance = 40
        } else {
            distance = 56
        }
        return direction * distance
    }
    
    private var nameOfHideIcon: String {
        if location == .topLeft || location == .bottomLeft {
            return "chevron.right"
        } else {
            return "chevron.left"
        }
    }
    
    private var nameOfShowIcon: String {
        if location == .topLeft || location == .bottomLeft {
            return "chevron.left"
        } else {
            return "chevron.right"
        }
    }
    
    private var toolbarToggleOpacity: Double {
        if state.device != nil && !state.isBusy && state.isRunning && isCollapsed && !isMoving {
            if !longIdleTimeout.isUserInteracting {
                return 0
            } else if isIdle {
                return 0.4
            } else {
                return 1
            }
        } else {
            return 1
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                Button {
                    if state.isRunning {
                        state.alert = .powerDown
                    } else {
                        state.alert = .terminateApp
                    }
                } label: {
                    if state.isRunning {
                        Label("Power Off", systemImage: "power")
                    } else {
                        Label("Force Kill", systemImage: "xmark")
                    }
                }.offset(offset(for: 8))
                Button {
                    session.pauseResume()
                } label: {
                    Label(state.isRunning ? "Pause" : "Play", systemImage: state.isRunning ? "pause" : "play")
                }.offset(offset(for: 7))
                Button {
                    state.alert = .restart
                } label: {
                    Label("Restart", systemImage: "restart")
                }.offset(offset(for: 6))
                Button {
                    if case .serial(_, _) = state.device {
                        let template = session.qemuConfig.serials[state.device!.configIndex].terminal?.resizeCommand
                        state.toggleDisplayResize(command: template)
                    } else {
                        state.toggleDisplayResize()
                    }
                } label: {
                    Label("Zoom", systemImage: state.isViewportChanged ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }.offset(offset(for: 5))
                #if WITH_USB
                if session.vm.hasUsbRedirection {
                    VMToolbarUSBMenuView()
                    .offset(offset(for: 4))
                }
                #endif
                VMToolbarDriveMenuView(config: session.qemuConfig)
                .offset(offset(for: 3))
                VMToolbarDisplayMenuView(state: $state)
                .offset(offset(for: 2))
                Button {
                    state.isKeyboardRequested = !state.isKeyboardShown
                } label: {
                    Label("Keyboard", systemImage: "keyboard")
                }.offset(offset(for: 1))
            }.buttonStyle(.toolbar(horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass))
            .menuStyle(.toolbar)
            .disabled(state.isBusy)
            .opacity(isCollapsed ? 0 : 1)
            .position(position(for: geometry))
            .transition(.slide)
            .animation(.default)
            Button {
                resetIdle()
                longIdleTimeout.assertUserInteraction()
                withOptionalAnimation {
                    isCollapsed.toggle()
                }
            } label: {
                Label("Hide", systemImage: isCollapsed ? nameOfHideIcon : nameOfShowIcon)
            }.buttonStyle(.toolbar(horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass))
            .modifier(HideToolbarTipModifier(isCollapsed: $isCollapsed))
            .opacity(toolbarToggleOpacity)
            .modifier(Shake(shake: shake))
            .position(position(for: geometry))
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        withOptionalAnimation {
                            isCollapsed = true
                        }
                        isMoving = true
                        dragPosition = value.location
                    }
                    .onEnded { value in
                        withOptionalAnimation {
                            location = closestLocation(to: value.location, for: geometry)
                            isMoving = false
                            dragPosition = position(for: geometry)
                        }
                        resetIdle()
                        longIdleTimeout.assertUserInteraction()
                    }
            )
            .onAppear {
                resetIdle()
                longIdleTimeout.assertUserInteraction()
                if isCollapsed {
                    withOptionalAnimation(.easeInOut(duration: 1)) {
                        shake.toggle()
                    }
                }
            }
            .onChange(of: state.isUserInteracting) { newValue in
                longIdleTimeout.assertUserInteraction()
                session.activeWindow = state.id
            }
        }
    }
    
    private func withOptionalAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
        if UIAccessibility.isReduceMotionEnabled {
            return try body()
        } else {
            return try withAnimation(animation, body)
        }
    }
    
    private func position(for geometry: GeometryProxy) -> CGPoint {
        let yoffset: CGFloat = 48
        var xoffset: CGFloat = 48
        guard !isMoving else {
            return dragPosition
        }
        if session.vm.hasUsbRedirection && !isCollapsed {
            xoffset -= 12
        }
        switch location {
        case .topRight:
            return CGPoint(x: geometry.size.width - xoffset, y: yoffset)
        case .bottomRight:
            return CGPoint(x: geometry.size.width - xoffset, y: geometry.size.height - yoffset)
        case .topLeft:
            return CGPoint(x: xoffset, y: yoffset)
        case .bottomLeft:
            return CGPoint(x: xoffset, y: geometry.size.height - yoffset)
        }
    }
    
    private func closestLocation(to point: CGPoint, for geometry: GeometryProxy) -> ToolbarLocation {
        if point.x < geometry.size.width/2 && point.y < geometry.size.height/2 {
            return .topLeft
        } else if point.x < geometry.size.width/2 && point.y > geometry.size.height/2 {
            return .bottomLeft
        } else if point.x > geometry.size.width/2 && point.y > geometry.size.height/2 {
            return .bottomRight
        } else {
            return .topRight
        }
    }
    
    private func offset(for index: Int) -> CGSize {
        var sub = 0
        if !session.vm.hasUsbRedirection && index >= 4 {
            sub = 1
        }
        let x = isCollapsed ? 0 : -CGFloat(index-sub)*spacing
        return CGSize(width: x, height: 0)
    }
    
    private func resetIdle() {
        if let task = shortIdleTask {
            task.cancel()
        }
        self.isIdle = false
        shortIdleTask = DispatchWorkItem {
            self.shortIdleTask = nil
            withOptionalAnimation {
                self.isIdle = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: shortIdleTask!)
    }
}

enum ToolbarLocation: Int {
    case topRight
    case bottomRight
    case topLeft
    case bottomLeft
}

protocol ToolbarButtonBaseStyle<Label, Content> {
    associatedtype Label: View
    associatedtype Content: View
    
    var horizontalSizeClass: UserInterfaceSizeClass? { get }
    var verticalSizeClass: UserInterfaceSizeClass? { get }
    
    func makeBodyBase(label: Label, isPressed: Bool) -> Content
}

extension ToolbarButtonBaseStyle {
    private var size: CGFloat {
        (horizontalSizeClass == .compact || verticalSizeClass == .compact) ? 32 : 48
    }
    
    func makeBodyBase(label: Label, isPressed: Bool) -> some View {
        ZStack {
            Circle()
                .foregroundColor(.gray)
                .opacity(isPressed ? 0.8 : 0.7)
                .blur(radius: 0.1)
            label
                .labelStyle(.iconOnly)
                .foregroundColor(isPressed ? .secondary : .white)
                .opacity(0.75)
        }.frame(width: size, height: size)
        .mask(Circle().frame(width: size-2, height: size-2))
        .scaleEffect(isPressed ? 1.2 : 1)
        .hoverEffect(.lift)
    }
}


struct ToolbarButtonStyle: ButtonStyle, ToolbarButtonBaseStyle {
    typealias Label = Configuration.Label
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClassEnvironment
    @Environment(\.verticalSizeClass) private var verticalSizeClassEnvironment
    
    var horizontalSizeClass: UserInterfaceSizeClass?
    var verticalSizeClass: UserInterfaceSizeClass?
    
    init(horizontalSizeClass: UserInterfaceSizeClass? = nil, verticalSizeClass: UserInterfaceSizeClass? = nil) {
        if horizontalSizeClass != nil {
            self.horizontalSizeClass = horizontalSizeClass
        } else {
            self.horizontalSizeClass = horizontalSizeClassEnvironment
        }
        if verticalSizeClass != nil {
            self.verticalSizeClass = verticalSizeClass
        } else {
            self.verticalSizeClass = verticalSizeClassEnvironment
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        return makeBodyBase(label: configuration.label, isPressed: configuration.isPressed)
    }
}

struct ToolbarMenuStyle: MenuStyle, ToolbarButtonBaseStyle {
    typealias Label = Menu<Configuration.Label, Configuration.Content>
    
    @Environment(\.horizontalSizeClass) internal var horizontalSizeClass
    @Environment(\.verticalSizeClass) internal var verticalSizeClass
    
    func makeBody(configuration: Configuration) -> some View {
        return makeBodyBase(label: Menu(configuration), isPressed: false)
    }
}

// https://www.objc.io/blog/2019/10/01/swiftui-shake-animation/
struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    init(shake: Bool) {
        animatableData = shake ? 1.0 : 0.0
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

extension ButtonStyle where Self == ToolbarButtonStyle {
    static var toolbar: ToolbarButtonStyle {
        ToolbarButtonStyle()
    }
    
    // this is needed to workaround a SwiftUI bug on < iOS 15
    static func toolbar(horizontalSizeClass: UserInterfaceSizeClass?, verticalSizeClass: UserInterfaceSizeClass?) -> ToolbarButtonStyle {
        ToolbarButtonStyle(horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass)
    }
}

extension MenuStyle where Self == ToolbarMenuStyle {
    static var toolbar: ToolbarMenuStyle {
        ToolbarMenuStyle()
    }
}

@MainActor private class LongIdleTimeout: ObservableObject {
    private var longIdleTask: DispatchWorkItem?
    
    @Published var isUserInteracting: Bool = true
    
    private func setIsUserInteracting(_ value: Bool) {
        if !UIAccessibility.isReduceMotionEnabled {
            withAnimation {
                self.isUserInteracting = value
            }
        } else {
            self.isUserInteracting = value
        }
    }
    
    func assertUserInteraction() {
        if let task = longIdleTask {
            task.cancel()
        }
        setIsUserInteracting(true)
        longIdleTask = DispatchWorkItem {
            self.longIdleTask = nil
            self.setIsUserInteracting(false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: longIdleTask!)
    }
}

private struct HideToolbarTipModifier: ViewModifier {
    @Binding var isCollapsed: Bool
    private let _hideToolbarTip: Any?

    @available(iOS 17, *)
    private var hideToolbarTip: UTMTipHideToolbar {
        _hideToolbarTip as! UTMTipHideToolbar
    }

    init(isCollapsed: Binding<Bool>) {
        _isCollapsed = isCollapsed
        if #available(iOS 17, *) {
            _hideToolbarTip = UTMTipHideToolbar()
        } else {
            _hideToolbarTip = nil
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content
                .popoverTip(hideToolbarTip, arrowEdge: .top)
                .onAppear {
                    UTMTipHideToolbar.didHideToolbar = isCollapsed
                }
        } else {
            content
        }
    }
}
