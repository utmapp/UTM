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
import SwiftUI

extension UTMData {
    func run(vm: VMData, options: UTMVirtualMachineStartOptions = []) {
        #if WITH_SOLO_VM
        guard VMSessionState.allActiveSessions.count == 0 else {
            logger.error("Session already started")
            return
        }
        #endif
        guard let wrapped = vm.wrapped else {
            return
        }
        if let session = VMSessionState.allActiveSessions.values.first(where: { $0.vm.id == wrapped.id }) {
            session.showWindow()
        } else if vm.isStopped || vm.isTakeoverAllowed {
            let session = VMSessionState(for: wrapped as! (any UTMSpiceVirtualMachine))
            session.start(options: options)
        } else {
            showErrorAlert(message: NSLocalizedString("This virtual machine is already running. In order to run it from this device, you must stop it first.", comment: "UTMDataExtension"))
        }
    }
    
    func stop(vm: VMData) {
        guard let wrapped = vm.wrapped else {
            return
        }
        if wrapped.registryEntry.isSuspended {
            wrapped.requestVmDeleteState()
        }
        wrapped.requestVmStop()
    }
    
    func close(vm: VMData) {
        // do nothing
    }
}
