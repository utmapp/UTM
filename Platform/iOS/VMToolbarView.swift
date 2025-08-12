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
    @State private var dragOffset: CGSize = .zero
    @State private var shortIdleTask: DispatchWorkItem?
    @State private var isKeyShortcutsShown: Bool = false
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var session: VMSessionState
    @StateObject private var longIdleTimeout = LongIdleTimeout()
    
    @Binding var state: VMWindowState
    
    @Namespace private var namespace
    
    private var spacing: CGFloat {
        let add: CGFloat
        if #available(iOS 26, *) {
            add = 0
        } else {
            add = 8
        }
        if horizontalSizeClass == .compact || verticalSizeClass == .compact {
            return add + 0
        } else {
            return add + 8
        }
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
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                toolbarBody
            }
        } else {
            toolbarBody
        }
    }
    
    @ViewBuilder
    var toolbarBody: some View {
        toolbarContainer { geometry in
            if !isCollapsed {
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
                    }.animationUniqueID("power", in: namespace)
                    Button {
                        session.pauseResume()
                    } label: {
                        Label(state.isRunning ? "Pause" : "Play", systemImage: state.isRunning ? "pause" : "play")
                    }.animationUniqueID("pause", in: namespace)
                    Button {
                        state.alert = .restart
                    } label: {
                        Label("Restart", systemImage: "restart")
                    }.animationUniqueID("restart", in: namespace)
                    Button {
                        if case .serial(_, _) = state.device {
                            let template = session.qemuConfig.serials[state.device!.configIndex].terminal?.resizeCommand
                            state.toggleDisplayResize(command: template)
                        } else {
                            state.toggleDisplayResize()
                        }
                    } label: {
                        Label("Zoom", systemImage: state.isViewportChanged ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }.animationUniqueID("resize", in: namespace)
                    #if WITH_USB
                    if session.vm.hasUsbRedirection {
                        VMToolbarUSBMenuView()
                            .animationUniqueID("usb", in: namespace)
                    }
                    #endif
                    VMToolbarDriveMenuView(config: session.qemuConfig)
                        .animationUniqueID("drive", in: namespace)
                    VMToolbarDisplayMenuView(state: $state)
                        .animationUniqueID("display", in: namespace)
                    Button {
                        // ignore if we are showing shortcuts
                        guard !isKeyShortcutsShown else {
                            return
                        }
                        state.isKeyboardRequested = !state.isKeyboardShown
                    } label: {
                        Label("Keyboard", systemImage: "keyboard")
                    }.animationUniqueID("keyboard", in: namespace)
                    #if !WITH_REMOTE
                    .simultaneousGesture(
                        LongPressGesture().onEnded { _ in
                            isKeyShortcutsShown.toggle()
                        }
                    )
                    .sheet(isPresented: $isKeyShortcutsShown) {
                        VMKeyboardShortcutsView { keys in
                            session.sendKeys(keys: keys)
                        }
                    }
                    #endif
                }.toolbarButtonStyle(horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass)
                .disabled(state.isBusy)
            }
            Button {
                resetIdle()
                longIdleTimeout.assertUserInteraction()
                withOptionalAnimation {
                    isCollapsed.toggle()
                }
            } label: {
                Label("Hide", systemImage: isCollapsed ? nameOfHideIcon : nameOfShowIcon)
            }.toolbarButtonStyle(horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass)
            .animationUniqueID("hide", in: namespace)
            .modifier(HideToolbarTipModifier(isCollapsed: $isCollapsed))
            .opacity(toolbarToggleOpacity)
            .modifier(Shake(shake: shake))
            .offset(dragOffset)
            .highPriorityGesture(
                DragGesture(coordinateSpace: .named("Window"))
                    .onChanged { value in
                        withOptionalAnimation {
                            isCollapsed = true
                            isMoving = true
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        withOptionalAnimation {
                            location = closestLocation(to: value.location, for: geometry)
                            isMoving = false
                            dragOffset = .zero
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
    
    @ViewBuilder
    private func toolbarContainer<Content: View>(@ViewBuilder body: @escaping (GeometryProxy) -> Content) -> some View {
        GeometryReader { geometry in
            switch location {
            case .topRight:
                VStack(alignment: .trailing) {
                    HStack(alignment: .top, spacing: spacing) {
                        Spacer()
                        body(geometry)
                    }.padding(.trailing)
                    Spacer()
                }.padding(.top)
            case .bottomRight:
                VStack(alignment: .trailing) {
                    Spacer()
                    HStack(alignment: .bottom, spacing: spacing) {
                        Spacer()
                        body(geometry)
                    }.padding(.trailing)
                }.padding(.bottom)
            case .topLeft:
                VStack(alignment: .leading) {
                    HStack(alignment: .top, spacing: spacing) {
                        body(geometry)
                        Spacer()
                    }.padding(.leading)
                    Spacer()
                }.padding(.top)
            case .bottomLeft:
                VStack(alignment: .leading) {
                    Spacer()
                    HStack(alignment: .bottom, spacing: spacing) {
                        body(geometry)
                        Spacer()
                    }.padding(.leading)
                }.padding(.bottom)
            }
        }.coordinateSpace(name: "Window")
    }
    
    private func withOptionalAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
        if UIAccessibility.isReduceMotionEnabled {
            return try body()
        } else {
            return try withAnimation(animation, body)
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

private extension View {
    @ViewBuilder
    func toolbarButtonStyle(horizontalSizeClass: UserInterfaceSizeClass? = nil, verticalSizeClass: UserInterfaceSizeClass? = nil) -> some View {
        if #available(iOS 26, *) {
            self
                .menuStyle(.button)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .labelStyle(.iconOnly)
                .foregroundStyle(.primary)
                .controlSize(forHorizontalSizeClass: horizontalSizeClass)
        } else {
            self
                .buttonStyle(.toolbar(horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass))
                .menuStyle(.toolbar)
        }
    }
    
    @ViewBuilder
    func animationUniqueID(_ id: (some Hashable & Sendable)?, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26, *) {
            self
                .glassEffectID(id, in: namespace)
                .matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
                .matchedGeometryEffect(id: id, in: namespace)
        }
    }
    
    @available(iOS 15, *)
    @ViewBuilder
    func controlSize(forHorizontalSizeClass horizontalSizeClass: UserInterfaceSizeClass?) -> some View {
        if horizontalSizeClass == .regular {
            self.controlSize(.large)
        } else {
            self
        }
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
