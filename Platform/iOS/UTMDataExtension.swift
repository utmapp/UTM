//
// Copyright © 2020 osy. All rights reserved.
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

import Foundation

@available(iOS 14, *)
extension UTMData {
    private func createDisplay(vm: UTMVirtualMachine) -> VMDisplayViewController {
        if vm.configuration.displayConsoleOnly {
            let vc = VMDisplayTerminalViewController()
            let webView = WKWebView()
            webView.isOpaque = false
            vm.delegate = vc
            vc.vm = vm
            vc.webView = webView
            vc.view.insertSubview(webView, at: 0)
            webView.bindFrameToSuperviewBounds()
            vc.virtualMachine(vm, transitionTo: vm.state)
            return vc
        } else {
            let vc = VMDisplayMetalViewController()
            let keyboardView = VMKeyboardView(frame: .zero)
            let placeholder = UIImageView()
            let metal = MTKView()
            vm.delegate = vc
            vc.vm = vm
            vc.keyboardView = keyboardView
            vc.placeholderImageView = placeholder
            vc.mtkView = metal
            keyboardView.delegate = vc
            vc.view.insertSubview(keyboardView, at: 0)
            vc.view.insertSubview(placeholder, at: 1)
            placeholder.bindFrameToSuperviewBounds()
            vc.view.insertSubview(metal, at: 2)
            metal.bindFrameToSuperviewBounds()
            vc.virtualMachine(vm, transitionTo: vm.state)
            return vc
        }
    }
    
    func run(vm: UTMVirtualMachine) {
        guard let window = UIApplication.shared.windows.filter({$0.isKeyWindow}).first else {
            logger.error("Cannot find key window")
            return
        }
        
        let vc = self.createDisplay(vm: vm)
        window.rootViewController = vc
        window.makeKeyAndVisible()
        let options: UIView.AnimationOptions = .transitionCrossDissolve
        let duration: TimeInterval = 0.3

        UIView.transition(with: window, duration: duration, options: options, animations: {}, completion: nil)
    }
    
    func stop(vm: UTMVirtualMachine) throws {
        if vm.viewState.suspended {
            guard vm.deleteSaveVM() else {
                throw NSLocalizedString("Failed to delete saved state.", comment: "UTMDataExtension")
            }
        }
    }
}
