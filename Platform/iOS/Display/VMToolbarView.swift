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

@available(iOS 14, *)
struct VMToolbarView: View {
    @AppStorage("ToolbarIsCollapsed") private var isCollapsed: Bool = true
    @AppStorage("ToolbarLocation") private var location: ToolbarLocation = .topRight
    @State private var shake: Bool = true
    @State private var isMoving: Bool = false
    @State private var dragPosition: CGPoint = .zero
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
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
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                Button {
                    
                } label: {
                    Label("Power Off", systemImage: "power")
                }.offset(x: isCollapsed ? 0 : -7*spacing)
                Button {
                    
                } label: {
                    Label("Pause", systemImage: "pause")
                }.offset(x: isCollapsed ? 0 : -6*spacing)
                Button {
                    
                } label: {
                    Label("Restart", systemImage: "restart")
                }.offset(x: isCollapsed ? 0 : -5*spacing)
                Button {
                    
                } label: {
                    Label("Zoom", systemImage: "arrow.down.right.and.arrow.up.left")
                }.offset(x: isCollapsed ? 0 : -4*spacing)
                Button {
                    
                } label: {
                    Label("Network", systemImage: "network")
                }.offset(x: isCollapsed ? 0 : -3*spacing)
                Button {
                    
                } label: {
                    Label("Disk", systemImage: "opticaldisc")
                }.offset(x: isCollapsed ? 0 : -2*spacing)
                Button {
                    
                } label: {
                    Label("Keyboard", systemImage: "keyboard")
                }.offset(x: isCollapsed ? 0 : -1*spacing)
            }.buttonStyle(ToolbarButtonStyle())
            .opacity(isCollapsed ? 0 : 1)
            .position(position(for: geometry))
            .transition(.slide)
            .animation(.default)
            Button {
                withOptionalAnimation {
                    isCollapsed.toggle()
                }
            } label: {
                Label("Hide", systemImage: isCollapsed ? nameOfHideIcon : nameOfShowIcon)
            }.buttonStyle(ToolbarButtonStyle())
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
                    }
            )
            .onAppear {
                withOptionalAnimation(.easeInOut(duration: 1)) {
                    shake.toggle()
                }
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
        let offset: CGFloat =
        (horizontalSizeClass == .compact || verticalSizeClass == .compact) ? 24 : 32
        guard !isMoving else {
            return dragPosition
        }
        switch location {
        case .topRight:
            return CGPoint(x: geometry.size.width - offset, y: offset)
        case .bottomRight:
            return CGPoint(x: geometry.size.width - offset, y: geometry.size.height - offset)
        case .topLeft:
            return CGPoint(x: offset, y: offset)
        case .bottomLeft:
            return CGPoint(x: offset, y: geometry.size.height - offset)
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
}

enum ToolbarLocation: Int {
    case topRight
    case bottomRight
    case topLeft
    case bottomLeft
}

@available(iOS 14, *)
struct ToolbarButtonStyle: ButtonStyle {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var size: CGFloat {
        (horizontalSizeClass == .compact || verticalSizeClass == .compact) ? 32 : 48
    }
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .foregroundColor(.gray)
                .opacity(configuration.isPressed ? 0.8 : 0.7)
                .blur(radius: 0.1)
            configuration.label
                .labelStyle(.iconOnly)
                .foregroundColor(configuration.isPressed ? .secondary : .white)
                .opacity(0.75)
        }.frame(width: size, height: size)
        .mask(Circle().frame(width: size-2, height: size-2))
        .scaleEffect(configuration.isPressed ? 1.2 : 1)
        .hoverEffect(.lift)
    }
}

// https://www.objc.io/blog/2019/10/01/swiftui-shake-animation/
@available(iOS 14, *)
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

@available(iOS 14, *)
struct VMToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        VMToolbarView()
    }
}
