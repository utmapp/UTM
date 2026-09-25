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
    /// Where the toolbar goes when it is laid out along a side of the window.
    enum Layout: Equatable {
        /// The corner of the window, which the user can drag the toolbar between.
        case corner(ToolbarLocation)
        /// Top-aligned along one side, next to the system's own vertical controls.
        case vertical(HorizontalEdge)

        var isVertical: Bool {
            if case .vertical = self {
                return true
            } else {
                return false
            }
        }
    }

    @AppStorage("ToolbarLocation") private var location: ToolbarLocation = .topRight
    @State private var verticalBarRegion: CGRect?
    @State private var shake: Bool = true
    @State private var isMoving: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var isKeyShortcutsShown: Bool = false
    @StateObject private var idle = ToolbarIdleState()
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var session: VMSessionState
    
    @Binding var state: VMWindowState
    
    @Namespace private var namespace
    
    private var spacing: CGFloat {
        if horizontalSizeClass == .compact || verticalSizeClass == .compact {
            return 8
        } else {
            return 16
        }
    }
    
    /// The chevron points where the buttons unfold to or fold away towards.
    private func showHideIcon(for layout: Layout) -> String {
        switch layout {
        case .corner(let location):
            let isLeft = location == .topLeft || location == .bottomLeft
            return state.isToolbarCollapsed == isLeft ? "chevron.right" : "chevron.left"
        case .vertical:
            return state.isToolbarCollapsed ? "chevron.down" : "chevron.up"
        }
    }
    
    private var toolbarToggleOpacity: Double {
        if state.device != nil && !state.isBusy && state.isRunning && state.isToolbarCollapsed && !isMoving {
            if idle.isHidden {
                return 0
            } else if idle.isDimmed {
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
        toolbarContainer { geometry, layout in
            if layout.isVertical {
                showHideButton(geometry: geometry, layout: layout)
                if !state.isToolbarCollapsed {
                    buttons
                }
            } else {
                if !state.isToolbarCollapsed {
                    buttons
                }
                showHideButton(geometry: geometry, layout: layout)
            }
        }
        .onAppear {
            resetIdle()
            assertUserInteraction()
            if state.isToolbarCollapsed {
                withOptionalAnimation(.easeInOut(duration: 1)) {
                    shake.toggle()
                }
            }
        }
        .onChange(of: state.isUserInteracting) { newValue in
            assertUserInteraction()
            session.activeWindow = state.id
        }
    }
    
    @ViewBuilder
    private var buttons: some View {
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
                if state.inputDeckFrame != nil {
                    state.cycleInputDeck()
                } else {
                    state.isKeyboardRequested = !state.isKeyboardShown
                }
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
    
    /// The vertical layout is pinned next to the system's controls, so only the corner layout can be dragged.
    private func showHideButton(geometry: GeometryProxy, layout: Layout) -> some View {
        Button {
            resetIdle()
            assertUserInteraction()
            withOptionalAnimation {
                state.toggleToolbarCollapsed()
            }
        } label: {
            Label("Hide", systemImage: showHideIcon(for: layout))
        }.toolbarButtonStyle(horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass)
        .animationUniqueID("hide", in: namespace)
        .modifier(HideToolbarTipModifier(isCollapsed: state.isToolbarCollapsed, layout: layout))
        .opacity(toolbarToggleOpacity)
        .modifier(Shake(shake: shake))
        .offset(dragOffset)
        .highPriorityGesture(
            DragGesture(coordinateSpace: .named("Window"))
                .onChanged { value in
                    withOptionalAnimation {
                        state.setToolbarCollapsed(true)
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
                    assertUserInteraction()
                },
            including: layout.isVertical ? .subviews : .all
        )
    }
    
    /// The closed iPhone Duo reserves a vertical strip on one side of the window for the status bar and
    /// camera, and Apple puts controls in a column next to it. Other phones inset both sides equally in
    /// landscape and neither in portrait, so an inset on one side only is what tells the strip apart.
    ///
    /// The reader stays inside the safe area, which is what makes it report the insets around it.
    private func layout(for geometry: GeometryProxy) -> Layout {
        let insets = geometry.safeAreaInsets
        guard horizontalSizeClass == .compact, abs(insets.leading - insets.trailing) >= 44 else {
            return .corner(location)
        }
        return .vertical(insets.trailing > insets.leading ? .trailing : .leading)
    }
    
    @ViewBuilder
    private func toolbarContainer<Content: View>(@ViewBuilder body: @escaping (GeometryProxy, Layout) -> Content) -> some View {
        GeometryReader { geometry in
            let layout = layout(for: geometry)
            Group {
                switch layout {
                case .vertical(let edge):
                    if let region = verticalBarRegion {
                        // inside the strip, where the system puts its own bars
                        VStack(alignment: .center, spacing: spacing) {
                            body(geometry, layout)
                            Spacer()
                        }.frame(width: region.width, height: region.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .offset(x: region.minX - geometry.safeAreaInsets.leading, y: region.minY - geometry.safeAreaInsets.top)
                    } else {
                        HStack(alignment: .top) {
                            if edge == .trailing {
                                Spacer()
                            }
                            VStack(alignment: .center, spacing: spacing) {
                                body(geometry, layout)
                                Spacer()
                            }.padding(.top)
                            if edge == .leading {
                                Spacer()
                            }
                        }.padding(edge == .trailing ? .trailing : .leading)
                    }
                case .corner(.topRight):
                    VStack(alignment: .trailing) {
                        HStack(alignment: .top, spacing: spacing) {
                            Spacer()
                            body(geometry, layout)
                        }.padding(.trailing)
                        Spacer()
                    }.padding(.top)
                case .corner(.bottomRight):
                    VStack(alignment: .trailing) {
                        Spacer()
                        HStack(alignment: .bottom, spacing: spacing) {
                            Spacer()
                            body(geometry, layout)
                        }.padding(.trailing)
                    }.padding(.bottom)
                    .padding(.bottom, bottomInset(for: geometry))
                case .corner(.topLeft):
                    VStack(alignment: .leading) {
                        HStack(alignment: .top, spacing: spacing) {
                            body(geometry, layout)
                            Spacer()
                        }.padding(.leading)
                        Spacer()
                    }.padding(.top)
                case .corner(.bottomLeft):
                    VStack(alignment: .leading) {
                        Spacer()
                        HStack(alignment: .bottom, spacing: spacing) {
                            body(geometry, layout)
                            Spacer()
                        }.padding(.leading)
                    }.padding(.bottom)
                    .padding(.bottom, bottomInset(for: geometry))
                }
            }
            .background(verticalBarRegionReader(for: layout))
        }.coordinateSpace(name: "Window")
    }
    
    /// Keeps a bottom corner above the input deck.
    ///
    /// The padding is applied inside the reader so that it does not become a minimum height of the
    /// window: SwiftUI measures the window against the part above the keyboard, and a window that
    /// does not fit there is centred over it.
    private func bottomInset(for geometry: GeometryProxy) -> CGFloat {
        state.toolbarBottomInset(toolbarBottom: geometry.frame(in: .global).maxY)
    }

    /// Reads the region from the window, since the strip lies outside the safe area the toolbar is laid out in.
    @ViewBuilder
    private func verticalBarRegionReader(for layout: Layout) -> some View {
        #if canImport(SwiftUI, _version: 8.0.85)
        if #available(iOS 27.1, *), case .vertical(let edge) = layout {
            VerticalBarRegionReader(edge: edge, extent: 44, region: $verticalBarRegion)
                .ignoresSafeArea()
        }
        #endif
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
        idle.resetDimming()
    }
    
    private func assertUserInteraction() {
        idle.resetHiding()
    }
}

/// Animates unless the user has asked for reduced motion.
private func withOptionalAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    if UIAccessibility.isReduceMotionEnabled {
        return try body()
    } else {
        return try withAnimation(animation, body)
    }
}

/// Idle timers of the toolbar, kept apart from the window state so that they do not update the whole window.
@MainActor private final class ToolbarIdleState: ObservableObject {
    /// The show/hide button is dimmed after a short time without interaction.
    @Published private(set) var isDimmed: Bool = false

    /// The collapsed toolbar is faded out after a long time without interaction, until the next touch.
    @Published private(set) var isHidden: Bool = false

    private var dimTask: DispatchWorkItem?
    private var hideTask: DispatchWorkItem?

    func resetDimming() {
        dimTask?.cancel()
        isDimmed = false
        dimTask = schedule(after: 5) { $0.isDimmed = true }
    }

    func resetHiding() {
        hideTask?.cancel()
        withOptionalAnimation {
            isHidden = false
        }
        hideTask = schedule(after: 15) { $0.isHidden = true }
    }

    private func schedule(after seconds: TimeInterval, _ change: @escaping (ToolbarIdleState) -> Void) -> DispatchWorkItem {
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else {
                return
            }
            withOptionalAnimation {
                change(self)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
        return task
    }
}

#if canImport(SwiftUI, _version: 8.0.85)
/// Where the system would lay out a vertical bar of the given width on an edge of the window.
///
/// On the closed iPhone Duo that is a column inside the strip, below the camera.
@available(iOS 27.1, *)
private struct VerticalBarRegionReader: UIViewRepresentable {
    let edge: HorizontalEdge
    let extent: CGFloat
    @Binding var region: CGRect?

    final class RegionView: UIView {
        var edge: NSDirectionalRectEdge = .trailing
        var extent: CGFloat = 44
        var onChange: ((CGRect) -> Void)?
        private var lastFrame: CGRect?

        override func layoutSubviews() {
            super.layoutSubviews()
            let frame = layoutGuide(for: .bar(onEdge: edge, extent: extent)).layoutFrame
            if frame != lastFrame {
                lastFrame = frame
                onChange?(frame)
            }
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            setNeedsLayout()
        }
    }

    func makeUIView(context: Context) -> RegionView {
        let view = RegionView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: RegionView, context: Context) {
        view.edge = edge == .trailing ? .trailing : .leading
        view.extent = extent
        view.onChange = { frame in
            DispatchQueue.main.async {
                if region != frame {
                    region = frame
                }
            }
        }
        view.setNeedsLayout()
    }
}
#endif

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
    var size: CGFloat {
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

/// Liquid Glass variant of `ToolbarButtonStyle`.
///
/// Sizes the button explicitly instead of relying on `.buttonStyle(.glass)`:
/// the system style sizes each circle from its label on iOS 27, which makes
/// the buttons uneven and removes the gap between them. The neutral tint keeps
/// the buttons readable over both dark and light guest content, since glass
/// otherwise adapts to whatever the VM is displaying underneath.
@available(iOS 26, *)
struct ToolbarGlassButtonStyle: ButtonStyle, ToolbarButtonBaseStyle {
    typealias Label = Configuration.Label

    @Environment(\.isEnabled) private var isEnabled

    var horizontalSizeClass: UserInterfaceSizeClass?
    var verticalSizeClass: UserInterfaceSizeClass?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .contentShape(Circle())
            .glassEffect(.regular.tint(.gray.opacity(0.5)).interactive(), in: .circle)
            .opacity(isEnabled ? 1 : 0.5)
            .hoverEffect(.lift)
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
                .buttonStyle(ToolbarGlassButtonStyle(horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass))
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

private struct HideToolbarTipModifier: ViewModifier {
    let isCollapsed: Bool
    let layout: VMToolbarView.Layout
    private let _hideToolbarTip: Any?

    /// Keeps the tip on the side of the toolbar facing the middle of the screen.
    ///
    /// From iOS 26 a single arrow edge is only a preference, and when the toolbar spans most of
    /// the width the system attaches the tip beside the button instead, covering the toolbar.
    private var arrowEdges: Edge.Set {
        switch layout {
        case .corner(.topLeft), .corner(.topRight): return .top
        case .corner(.bottomLeft), .corner(.bottomRight): return .bottom
        case .vertical(.leading): return .leading
        case .vertical(.trailing): return .trailing
        }
    }

    @available(iOS 17, *)
    private var hideToolbarTip: UTMTipHideToolbar {
        _hideToolbarTip as! UTMTipHideToolbar
    }

    init(isCollapsed: Bool, layout: VMToolbarView.Layout) {
        self.isCollapsed = isCollapsed
        self.layout = layout
        if #available(iOS 17, *) {
            _hideToolbarTip = UTMTipHideToolbar()
        } else {
            _hideToolbarTip = nil
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .popoverTip(hideToolbarTip, arrowEdges: arrowEdges)
                .onAppear {
                    UTMTipHideToolbar.didHideToolbar = isCollapsed
                }
        } else if #available(iOS 17, *) {
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
