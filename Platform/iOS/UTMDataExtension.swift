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
        let qvm = vm as! UTMQemuVirtualMachine
        if qvm.qemuConfig.displayConsoleOnly {
            let vc = VMDisplayTerminalViewController()
            vc.vm = qvm
            vc.setupSubviews()
            vc.virtualMachine(vm, didTransitionTo: vm.state)
            return vc
        } else {
            let vc = VMDisplayMetalViewController()
            vc.vm = qvm
            vc.setupSubviews()
            vc.virtualMachine(vm, didTransitionTo: vm.state)
            return vc
        }
    }
    
    func run(vm: UTMVirtualMachine) {
        guard let window = UIApplication.shared.windows.filter({$0.isKeyWindow}).first else {
            logger.error("Cannot find key window")
            return
        }
        
        let vc = self.createDisplay(vm: vm)
        self.vmVC = vc
        window.rootViewController = vc
        window.makeKeyAndVisible()
        let options: UIView.AnimationOptions = .transitionCrossDissolve
        let duration: TimeInterval = 0.3

        UIView.transition(with: window, duration: duration, options: options, animations: {}, completion: nil)
    }
    
    func stop(vm: UTMVirtualMachine) throws {
        if vm.viewState.hasSaveState {
            vm.requestVmDeleteState()
        }
    }
    
    func close(vm: UTMVirtualMachine) {
        // do nothing
    }
    
    func tryClickAtPoint(point: CGPoint, button: CSInputButton) {
        if let vc = vmVC as? VMDisplayMetalViewController, let input = vc.vmInput {
            input.sendMouseButton(button, pressed: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                input.sendMouseButton(button, pressed: false)
            }
        }
    }
    
    func trySendTextSpice(_ text: String) {
        if let vc = vmVC as? VMDisplayMetalViewController {
            vc.keyboardView.insertText(text)
        }
    }
}
