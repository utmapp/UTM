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
        let vm: any UTMSpiceVirtualMachine
        let device: VMWindowState.Device
        @Binding var state: VMWindowState
        var vmStateCancellable: AnyCancellable?
        
        var vmState: UTMVirtualMachineState {
            vm.state
        }
        
        var vmConfig: UTMQemuConfiguration {
            vm.config
        }
        
        @MainActor var qemuInputLegacy: Bool {
            vmConfig.input.usbBusSupport == .disabled
        }
        
        @MainActor var qemuDisplayUpscaler: MTLSamplerMinMagFilter {
            vmConfig.displays[device.configIndex].upscalingFilter.metalSamplerMinMagFilter
        }
        
        @MainActor var qemuDisplayDownscaler: MTLSamplerMinMagFilter {
            vmConfig.displays[device.configIndex].downscalingFilter.metalSamplerMinMagFilter
        }
        
        @MainActor var qemuDisplayIsDynamicResolution: Bool {
            vmConfig.displays[device.configIndex].isDynamicResolution
        }
        
        @MainActor var qemuDisplayIsNativeResolution: Bool {
            vmConfig.displays[device.configIndex].isNativeResolution
        }
        
        @MainActor var qemuHasClipboardSharing: Bool {
            vmConfig.sharing.hasClipboardSharing
        }
        
        @MainActor var qemuConsoleResizeCommand: String? {
            vmConfig.serials[device.configIndex].terminal?.resizeCommand
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
        
        init(with vm: any UTMSpiceVirtualMachine, device: VMWindowState.Device, state: Binding<VMWindowState>) {
            self.vm = vm
            self.device = device
            self._state = state
        }
        
        func displayDidAssertUserInteraction() {
            state.isUserInteracting.toggle()
        }
        
        func displayDidAppear() {
            if vm.state == .stopped {
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
    
    let vm: any UTMSpiceVirtualMachine
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
            let style = vm.config.serials[id].terminal
            vc = VMDisplayTerminalViewController(port: serial, style: style)
            vc.delegate = context.coordinator
        }
        context.coordinator.vmStateCancellable = session.$vmState.sink { vmState in
            switch vmState {
            case .stopped, .paused:
                vc.enterSuspended(isBusy: false)
            case .pausing, .stopping, .starting, .resuming, .saving, .restoring:
                vc.enterSuspended(isBusy: true)
            case .started:
                vc.enterLive()
            }
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: VMDisplayViewController, context: Context) {
        if let vc = uiViewController as? VMDisplayMetalViewController {
            vc.vmInput = session.primaryInput
        }
        #if os(visionOS)
        let useSystemOsk = !(uiViewController is VMDisplayMetalViewController)
        #else
        let useSystemOsk = true
        #endif
        if useSystemOsk && state.isKeyboardShown != state.isKeyboardRequested {
            DispatchQueue.main.async {
                if state.isKeyboardRequested {
                    uiViewController.showKeyboard()
                } else {
                    uiViewController.hideKeyboard()
                }
                #if os(visionOS)
                // UIKeyboardDidShowNotification is never posted on visionOS
                // so we cannot determine the keyboard state
                state.isKeyboardRequested = false
                #endif
            }
        }
        switch state.device {
        case .display(let display, _):
            if let vc = uiViewController as? VMDisplayMetalViewController {
                if vc.vmDisplay != display {
                    vc.vmDisplay = display
                }
                // some obscure SwiftUI error means we cannot refer to Coordinator's state binding
                vc.setDisplayScaling(state.displayScale, origin: state.displayOrigin)
                vc.isDynamicResolutionSupported = state.isDynamicResolutionSupported
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
