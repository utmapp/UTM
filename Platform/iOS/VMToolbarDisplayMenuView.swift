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

struct VMToolbarDisplayMenuView: View {
    @Binding var state: VMWindowState
    @EnvironmentObject private var session: VMSessionState
    #if os(visionOS)
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openWindow) private var openWindow
    #else
    private var supportsMultipleWindows: Bool {
        UIApplication.shared.supportsMultipleScenes
    }
    #endif

    var body: some View {
        Menu {
            Menu {
                Picker("", selection: $state.device) {
                    MenuLabel("None", systemImage: "rectangle.dashed").tag(nil as VMWindowState.Device?)
                    ForEach(session.devices) { device in
                        switch device {
                        case .serial(_, let index):
                            MenuLabel("Serial \(index): \(session.qemuConfig.serials[index].target.prettyValue)", systemImage: "rectangle.connected.to.line.below").tag(device as VMWindowState.Device?)
                        case .display(_, let index):
                            MenuLabel("Display \(index): \(session.qemuConfig.displays[index].hardware.prettyValue)", systemImage: "display").tag(device as VMWindowState.Device?)
                        }
                    }
                }
            } label: {
                MenuLabel("Current Window", systemImage: "rectangle.inset.filled.on.rectangle")
            }
            if let externalWindowBinding = session.externalWindowBinding {
                Menu {
                    Button {
                        externalWindowBinding.wrappedValue.toggleDisplayResize()
                    } label: {
                        MenuLabel("Zoom/Reset", systemImage: externalWindowBinding.isViewportChanged.wrappedValue ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }
                    Picker("", selection: externalWindowBinding.device) {
                        MenuLabel("None", systemImage: "rectangle.dashed").tag(nil as VMWindowState.Device?)
                        ForEach(session.devices) { device in
                            switch device {
                            case .serial(_, let index):
                                MenuLabel("Serial \(index): \(session.qemuConfig.serials[index].target.prettyValue)", systemImage: "rectangle.connected.to.line.below").tag(device as VMWindowState.Device?)
                            case .display(_, let index):
                                MenuLabel("Display \(index): \(session.qemuConfig.displays[index].hardware.prettyValue)", systemImage: "display").tag(device as VMWindowState.Device?)
                            }
                        }
                    }
                } label: {
                    MenuLabel("External Monitor", systemImage: "rectangle.on.rectangle")
                }
            }
            if supportsMultipleWindows {
                Divider()
                Button {
                    #if os(visionOS)
                    openWindow(value: session.newWindow())
                    #else
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil, errorHandler: nil)
                    #endif
                } label: {
                    MenuLabel("New Window…", systemImage: "plus.rectangle.on.rectangle")
                }
            }

        } label: {
            Label("Display", systemImage: "rectangle.on.rectangle")
        }.overlay(Badge(count: session.devices.count), alignment: .topTrailing)
    }
}

private struct Badge: View {
    let count: Int
    
    var body: some View {
        if count > 1 {
            ZStack(alignment: .center) {
                Circle().fill(.white)
                Image(systemName: count <= 50 ? "\(count).circle.fill" : "infinity.circle.fill")
                    .foregroundColor(.red)
            }.frame(width: 16, height: 16)
            .allowsHitTesting(false)
        } else {
            EmptyView()
        }
    }
}
