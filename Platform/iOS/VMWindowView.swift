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

struct VMWindowView: View {
    @State private var state = VMWindowState()
    @EnvironmentObject private var session: VMSessionState
    
    private let keyboardDidShowNotification = NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)
    private let keyboardDidHideNotification = NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)
    
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
                    case .serial(_, _):
                        VMDisplayHostedView(vm: session.vm, device: device, state: $state)
                    }
                } else if !state.isBusy && state.isRunning {
                    // headless
                    BusyIndicator()
                }
                if state.isBusy || !state.isRunning {
                    BlurEffect().blurEffectStyle(.light)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            if state.isBusy {
                                Spinner(size: .large)
                            } else if session.vmState == .vmPaused {
                                Button {
                                    session.vm.requestVmResume()
                                } label: {
                                    Label("Resume", systemImage: "playpause.circle.fill")
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
                }
            }.background(Color.black)
            .ignoresSafeArea()
            if state.isInteractive {
                VMToolbarView(state: $state)
            }
        }
        .alert(item: $state.alert, content: { type in
            switch type {
            case .powerDown:
                return Alert(title: Text("Are you sure you want to stop this VM and exit? Any unsaved changes will be lost."), primaryButton: .cancel(Text("No")), secondaryButton: .destructive(Text("Yes")) {
                    session.powerDown()
                })
            case .terminateApp:
                return Alert(title: Text("Are you sure you want to exit UTM?"), primaryButton: .cancel(Text("No")), secondaryButton: .destructive(Text("Yes")) {
                    session.terminateApplication()
                })
            case .restart:
                return Alert(title: Text("Are you sure you want to reset this VM? Any unsaved changes will be lost."), primaryButton: .cancel(Text("No")), secondaryButton: .destructive(Text("Yes")) {
                    session.reset()
                })
            case .deviceConnected(let device):
                return Alert(title: Text("Would you like to connect '\(device.name ?? device.description)' to this virtual machine?"), primaryButton: .cancel(Text("No")) {
                    session.mostRecentConnectedDevice = nil
                }, secondaryButton: .default(Text("Yes")) {
                    session.mostRecentConnectedDevice = nil
                    #if !WITH_QEMU_TCI
                    session.connectDevice(device)
                    #endif
                })
            case .nonfatalError(let message), .fatalError(let message):
                return Alert(title: Text(message), dismissButton: .cancel(Text("OK")) {
                    if case .fatalError(_) = type {
                        session.terminateApplication()
                    } else {
                        session.nonfatalError = nil
                    }
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
        .onChange(of: session.mostRecentConnectedDevice) { newValue in
            if session.activeWindow == state.id, let device = newValue {
                state.alert = .deviceConnected(device)
            }
        }
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
        .onChange(of: session.vmState) { newValue in
            switch newValue {
            case .vmStopped, .vmPaused:
                withOptionalAnimation {
                    state.isBusy = false
                    state.isRunning = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    if session.vmState == .vmStopped && session.fatalError == nil {
                        session.terminateApplication()
                    }
                }
            case .vmPausing, .vmStopping, .vmStarting, .vmResuming:
                withOptionalAnimation {
                    state.isBusy = true
                    state.isRunning = false
                }
            case .vmStarted:
                withOptionalAnimation {
                    state.isBusy = false
                    state.isRunning = true
                }
            @unknown default:
                break
            }
        }
        .onReceive(keyboardDidShowNotification) { _ in
            state.isKeyboardShown = true
            state.isKeyboardRequested = true
        }
        .onReceive(keyboardDidHideNotification) { _ in
            state.isKeyboardShown = false
            state.isKeyboardRequested = false
        }
        .onAppear {
            session.registerWindow(state.id)
        }
        .onDisappear {
            session.removeWindow(state.id)
        }
    }
}

struct VMWindowView_Previews: PreviewProvider {
    static var previews: some View {
        VMWindowView()
    }
}
