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
        #if os(macOS)
        Text("Start")
            .font(.largeTitle)
        #endif
        List {
            Section {
                Button {
                    wizardState.useVirtualization = true
                    wizardState.next()
                } label: {
                    HStack {
                        Image(systemName: "hare")
                            .font(.title)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Virtualize")
                                .font(.title)
                            Text("Faster, but can only run the native CPU architecture.")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .padding()
                }
                .disabled(!isVirtualizationSupported)
                .buttonStyle(InListButtonStyle())
                
                Button {
                    wizardState.useVirtualization = false
                    wizardState.next()
                } label: {
                    HStack {
                        Image(systemName: "tortoise")
                            .font(.title)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Emulate")
                                .font(.title)
                            Text("Slower, but can run other CPU architectures.")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(InListButtonStyle())
                
            } header: {
                Text("Custom")
            } footer: {
                if !isVirtualizationSupported {
                    Text("Virtualization is not supported on your system.")
                }
            }
            Section {
                Link(destination: URL(string: "https://mac.getutm.app/gallery/")!) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Download prebuilt from UTM Gallery...")
                    }
                }
            } header: {
                Text("Prebuilt")
            }

        }
        .navigationTitle(Text("Start"))
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
