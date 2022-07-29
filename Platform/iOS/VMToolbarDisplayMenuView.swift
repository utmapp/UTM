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
    
    var body: some View {
        Menu {
            Menu {
                Picker("", selection: $state.device) {
                    ForEach(session.devices) { device in
                        switch device {
                        case .serial(_, let index):
                            Label("Serial \(index): \(session.qemuConfig.serials[index].target.prettyValue)", systemImage: "cable.connector").tag(device as VMWindowState.Device?)
                        case .display(_, let index):
                            Label("Display \(index): \(session.qemuConfig.displays[index].hardware.prettyValue)", systemImage: "display").tag(device as VMWindowState.Device?)
                        }
                    }
                }
            } label: {
                Label("Current Window", systemImage: "rectangle.inset.filled.on.rectangle")
            }
            if let externalWindowBinding = session.externalWindowBinding {
                Menu {
                    Button {
                        externalWindowBinding.wrappedValue.toggleDisplayResize()
                    } label: {
                        Label("Zoom/Reset", systemImage: externalWindowBinding.isViewportChanged.wrappedValue ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }
                    Picker("", selection: externalWindowBinding.device) {
                        ForEach(session.devices) { device in
                            switch device {
                            case .serial(_, let index):
                                Label("Serial \(index): \(session.qemuConfig.serials[index].target.prettyValue)", systemImage: "cable.connector").tag(device as VMWindowState.Device?)
                            case .display(_, let index):
                                Label("Display \(index): \(session.qemuConfig.displays[index].hardware.prettyValue)", systemImage: "display").tag(device as VMWindowState.Device?)
                            }
                        }
                    }
                } label: {
                    Label("External Monitor", systemImage: "rectangle.on.rectangle")
                }
            }
            Divider()
            Button {
                UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil, errorHandler: nil)
            } label: {
                Label("New Window…", systemImage: "plus.rectangle.on.rectangle")
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

struct VMToolbarDisplayMenuView_Previews: PreviewProvider {
    @State private static var state = VMWindowState()
    static var previews: some View {
        VMToolbarDisplayMenuView(state: $state)
    }
}
