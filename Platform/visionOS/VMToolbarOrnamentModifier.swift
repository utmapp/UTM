//
// Copyright © 2023 osy. All rights reserved.
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

struct VMToolbarOrnamentModifier: ViewModifier {
    @Binding var state: VMWindowState
    @EnvironmentObject private var session: VMSessionState
    @AppStorage("ToolbarIsCollapsed") private var isCollapsed: Bool = false

    func body(content: Content) -> some View {
        content.ornament(visibility: isCollapsed ? .hidden : .visible, attachmentAnchor: .scene(.top)) {
            HStack {
                Button {
                    if session.vm.state == .started {
                        state.alert = .powerDown
                    } else {
                        state.alert = .terminateApp
                    }
                } label: {
                    Label(state.isRunning ? "Power Off" : "Quit", systemImage: state.isRunning ? "power" : "xmark")
                }
                .disabled(state.isBusy)
                Button {
                    session.pauseResume()
                } label: {
                    Label(state.isRunning ? "Pause" : "Play", systemImage: state.isRunning ? "pause" : "play")
                }
                .disabled(state.isBusy)
                Button {
                    state.alert = .restart
                } label: {
                    Label("Restart", systemImage: "restart")
                }
                .disabled(state.isBusy)
                Divider()
                if case .serial(_, _) = state.device {
                    Button {
                        let template = session.qemuConfig.serials[state.device!.configIndex].terminal?.resizeCommand
                        state.toggleDisplayResize(command: template)
                    } label: {
                        Label("Zoom", systemImage: state.isViewportChanged ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }
                    .disabled(state.isBusy)
                }
                #if WITH_USB
                if session.vm.hasUsbRedirection {
                    VMToolbarUSBMenuView()
                        .disabled(state.isBusy)
                }
                #endif
                VMToolbarDriveMenuView(config: session.qemuConfig)
                    .disabled(state.isBusy)
                VMToolbarDisplayMenuView(state: $state)
                    .disabled(state.isBusy)
                Button {
                    state.isKeyboardRequested = true
                } label: {
                    Label("Keyboard", systemImage: "keyboard")
                }
                .disabled(state.isBusy)
                Divider()
                Button {
                    isCollapsed = true
                } label: {
                    Label("Hide Controls", systemImage: "chevron.right")
                }
            }
            .modifier(ToolbarOrnamentViewModifier())
        }
        .ornament(visibility: isCollapsed ? .visible : .hidden, attachmentAnchor: .scene(.topTrailing)) {
                Button {
                    isCollapsed = false
                } label: {
                    Label("Show Controls", systemImage: "chevron.left")
                }
                .modifier(ToolbarOrnamentViewModifier())
        }
    }
}

// the following was suggested by Apple via Feedback to look close to .toolbar() with .bottomOrnament
private struct ToolbarOrnamentViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonBorderShape(.capsule)
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .padding(12)
            .glassBackgroundEffect()
    }
}
