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

import Combine
import SwiftUI

struct VMDisplayHostedView: UIViewControllerRepresentable {
    internal class Coordinator: VMDisplayViewControllerDelegate {
        let vm: UTMQemuVirtualMachine
        let device: VMWindowState.Device
        @Binding var state: VMWindowState
        var vmStateCancellable: AnyCancellable?
        
        var vmState: UTMVMState {
            vm.state
        }
        
        var vmConfig: UTMQemuConfiguration! {
            vm.config.qemuConfig
        }
        
        @MainActor var qemuInputLegacy: Bool {
            vmConfig.input.usbBusSupport == .disabled
        }
        
        @MainActor var qemuDisplayUpscaler: MTLSamplerMinMagFilter {
            vmConfig.displays[state.device!.configIndex].upscalingFilter.metalSamplerMinMagFilter
        }
        
        @MainActor var qemuDisplayDownscaler: MTLSamplerMinMagFilter {
            vmConfig.displays[state.device!.configIndex].downscalingFilter.metalSamplerMinMagFilter
        }
        
        @MainActor var qemuDisplayIsDynamicResolution: Bool {
            vmConfig.displays[state.device!.configIndex].isDynamicResolution
        }
        
        @MainActor var qemuDisplayIsNativeResolution: Bool {
            vmConfig.displays[state.device!.configIndex].isNativeResolution
        }
        
        @MainActor var qemuHasClipboardSharing: Bool {
            vmConfig.sharing.hasClipboardSharing
        }
        
        @MainActor var qemuConsoleResizeCommand: String? {
            vmConfig.serials[state.device!.configIndex].terminal?.resizeCommand
        }
        
        var isViewportChanged: Bool {
            get {
                state.isViewportChanged
            }
            
            set {
                state.isViewportChanged = newValue
            }
        }
        
        var displayOrigin: CGPoint {
            get {
                state.displayOrigin
            }
            
            set {
                state.displayOrigin = newValue
            }
        }
        
        var displayScale: CGFloat {
            get {
                state.displayScale
            }
            
            set {
                state.displayScale = newValue
            }
        }
        
        var displayViewSize: CGSize {
            get {
                state.displayViewSize
            }
            
            set {
                state.displayViewSize = newValue
            }
        }
        
        init(with vm: UTMQemuVirtualMachine, device: VMWindowState.Device, state: Binding<VMWindowState>) {
            self.vm = vm
            self.device = device
            self._state = state
        }
        
        func displayDidAssertUserInteraction() {
            state.isUserInteracting.toggle()
        }
        
        func displayDidAppear() {
            if vm.state == .vmStopped {
                vm.requestVmStart()
            }
        }
        
        func display(_ display: CSDisplay, didResizeTo size: CGSize) {
            if state.isDisplayZoomLocked {
                state.resizeDisplayToFit(display, size: size)
            }
        }
        
        func serialDidError(_ error: String) {
            state.alert = .nonfatalError(error)
        }
        
        func requestInputTablet(_ tablet: Bool) {
            vm.requestInputTablet(tablet)
        }
    }
    
    let vm: UTMQemuVirtualMachine
    let device: VMWindowState.Device
    
    @Binding var state: VMWindowState
    
    @EnvironmentObject private var session: VMSessionState
    
    func makeUIViewController(context: Context) -> VMDisplayViewController {
        let vc: VMDisplayViewController
        switch device {
        case .display(let display, _):
            let mvc = VMDisplayMetalViewController(display: display, input: session.primaryInput)
            mvc.delegate = context.coordinator
            mvc.setDisplayScaling(state.displayScale, origin: state.displayOrigin)
            vc = mvc
        case .serial(let serial, let id):
            let style = vm.qemuConfig.serials[id].terminal
            vc = VMDisplayTerminalViewController(port: serial, style: style)
            vc.delegate = context.coordinator
        }
        context.coordinator.vmStateCancellable = session.$vmState.sink { vmState in
            switch vmState {
            case .vmStopped, .vmPaused:
                vc.enterSuspended(isBusy: false)
            case .vmPausing, .vmStopping, .vmStarting, .vmResuming:
                vc.enterSuspended(isBusy: true)
            case .vmStarted:
                vc.enterLive()
            @unknown default:
                break
            }
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: VMDisplayViewController, context: Context) {
        if let vc = uiViewController as? VMDisplayMetalViewController {
            vc.vmInput = session.primaryInput
        }
        if state.isKeyboardShown != state.isKeyboardRequested {
            DispatchQueue.main.async {
                if state.isKeyboardRequested {
                    uiViewController.showKeyboard()
                } else {
                    uiViewController.hideKeyboard()
                }
            }
        }
        switch state.device {
        case .display(let display, _):
            if let vc = uiViewController as? VMDisplayMetalViewController {
                if vc.vmDisplay != display {
                    vc.vmDisplay = display
                    // some obscure SwiftUI error means we cannot refer to Coordinator's state binding
                    vc.setDisplayScaling(state.displayScale, origin: state.displayOrigin)
                }
            }
        case .serial(let serial, _):
            if let vc = uiViewController as? VMDisplayTerminalViewController {
                if vc.vmSerialPort != serial {
                    vc.vmSerialPort = serial
                }
            }
        default:
            break
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(with: vm, device: device, state: $state)
    }
}
