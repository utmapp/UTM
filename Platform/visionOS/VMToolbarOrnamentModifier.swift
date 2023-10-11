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
    
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .bottomOrnament) {
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
            }
            ToolbarItem(placement: .bottomOrnament) {
                Button {
                    session.pauseResume()
                } label: {
                    Label(state.isRunning ? "Pause" : "Play", systemImage: state.isRunning ? "pause" : "play")
                }
                .disabled(state.isBusy)
            }
            ToolbarItem(placement: .bottomOrnament) {
                Button {
                    state.alert = .restart
                } label: {
                    Label("Restart", systemImage: "restart")
                }
                .disabled(state.isBusy)
            }
            ToolbarItem(placement: .bottomOrnament) {
                Divider()
            }
            if case .serial(_, _) = state.device {
                ToolbarItem(placement: .bottomOrnament) {
                    Button {
                        let template = session.qemuConfig.serials[state.device!.configIndex].terminal?.resizeCommand
                        state.toggleDisplayResize(command: template)
                    } label: {
                        Label("Zoom", systemImage: state.isViewportChanged ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }
                    .disabled(state.isBusy)
                }
            }
            #if !WITH_QEMU_TCI
            ToolbarItem(placement: .bottomOrnament) {
                if session.vm.hasUsbRedirection {
                    VMToolbarUSBMenuView()
                        .disabled(state.isBusy)
                }
            }
            #endif
            ToolbarItem(placement: .bottomOrnament) {
                VMToolbarDriveMenuView(config: session.qemuConfig)
                    .disabled(state.isBusy)
            }
            ToolbarItem(placement: .bottomOrnament) {
                VMToolbarDisplayMenuView(state: $state)
                    .disabled(state.isBusy)
            }
            ToolbarItem(placement: .bottomOrnament) {
                Button {
                    state.isKeyboardRequested = true
                } label: {
                    Label("Keyboard", systemImage: "keyboard")
                }
                .disabled(state.isBusy)
            }
        }
    }
}
