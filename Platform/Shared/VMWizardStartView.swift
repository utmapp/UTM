//
// Copyright © 2021 osy. All rights reserved.
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
#if canImport(Virtualization)
import Virtualization
#endif

@available(iOS 14, macOS 11, *)
struct VMWizardStartView: View {
    @ObservedObject var wizardState: VMWizardState
    
    var isVirtualizationSupported: Bool {
        #if os(macOS)
        VZVirtualMachine.isSupported && !processIsTranslated()
        #else
        false
        #endif
    }
    
    var body: some View {
        VStack {
            Text("I want to...")
                .font(.largeTitle)
            Button {
                wizardState.useVirtualization = true
                wizardState.next()
            } label: {
                VStack {
                    Text("Virtualize")
                        .font(.title)
                    Text("Faster, but can only run the native CPU architecture.")
                        .font(.caption)
                }
            }.disabled(!isVirtualizationSupported)
            if !isVirtualizationSupported {
                Text("Virtualization is not supported on your system.")
                    .font(.footnote)
            }
            Button {
                wizardState.useVirtualization = false
                wizardState.next()
            } label: {
                VStack {
                    Text("Emulate")
                        .font(.title)
                    Text("Slower, but can run other CPU architectures.")
                        .font(.caption)
                }
            }
            Link("Download prebuilt from UTM Gallery...", destination: URL(string: "https://mac.getutm.app/gallery/")!)
                .buttonStyle(BorderlessButtonStyle())
        }.buttonStyle(BigButtonStyle(width: 320, height: 100))
    }
    
    private func processIsTranslated() -> Bool {
        let key = "sysctl.proc_translated"
        var ret = Int32(0)
        var size: Int = 0
        sysctlbyname(key, nil, &size, nil, 0)
        let result = sysctlbyname(key, &ret, &size, nil, 0)
        if result == -1 {
            return false
        }
        return ret != 0
    }
}

@available(iOS 14, macOS 11, *)
struct VMWizardStartView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardStartView(wizardState: wizardState)
    }
}
