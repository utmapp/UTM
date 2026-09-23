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
    @State private var externalDevice: VMWindowState.Device?
    #if os(visionOS)
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openWindow) private var openWindow
    #endif

    /// Two views of one display would both request its resolution, so a window only offers what no
    /// other window shows, and what it shows itself so that its selection is always in the list.
    private func availableDevices(for windowID: VMSessionState.WindowID?, current: VMWindowState.Device?) -> [VMWindowState.Device] {
        session.devices.filter { device in
            device == current || !session.windowDeviceMap.contains { $0.key != windowID && $0.value == device }
        }
    }

    var body: some View {
        Menu {
            Menu {
                Picker("", selection: $state.device) {
                    MenuLabel("None", systemImage: "rectangle.dashed").tag(nil as VMWindowState.Device?)
                    ForEach(availableDevices(for: state.id, current: state.device)) { device in
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
                    Picker("", selection: $externalDevice) {
                        MenuLabel("None", systemImage: "rectangle.dashed").tag(nil as VMWindowState.Device?)
                        ForEach(availableDevices(for: externalWindowBinding.wrappedValue.id, current: externalWindowBinding.wrappedValue.device)) { device in
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
            #if os(visionOS)
            if supportsMultipleWindows {
                Divider()
                Button {
                    openWindow(value: session.newWindow())
                } label: {
                    NewWindowLabel()
                }
            }
            #else
            if #available(iOS 16, *) {
                NewWindowMenuItem()
            } else if UIApplication.shared.supportsMultipleScenes {
                Divider()
                Button {
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil) { error in
                        state.alert = .nonfatalError(error.localizedDescription)
                    }
                } label: {
                    NewWindowLabel()
                }
            }
            #endif
        } label: {
            Label("Display", systemImage: "rectangle.on.rectangle")
        }.overlay(Badge(count: session.devices.count), alignment: .topTrailing)
        .onChange(of: externalDevice) { newValue in
            session.externalWindowBinding?.device.wrappedValue = newValue
        }
    }
}

private struct NewWindowLabel: View {
    var body: some View {
        MenuLabel("New Window…", systemImage: "plus.rectangle.on.rectangle")
    }
}

#if !os(visionOS)
/// Opens another scene through SwiftUI, which also knows when the system will not allow one.
///
/// `UIApplication.supportsMultipleScenes` stays true on iPhone Duo even though new scenes can
/// only be created on the inner display, so the item hides itself from the environment instead.
@available(iOS 16, *)
private struct NewWindowMenuItem: View {
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if supportsMultipleWindows {
            Divider()
            Button {
                openWindow(id: UTMApp.windowID)
            } label: {
                NewWindowLabel()
            }
        }
    }
}
#endif

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
