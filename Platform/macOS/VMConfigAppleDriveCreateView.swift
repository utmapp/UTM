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

struct VMConfigAppleDriveCreateView: View {
    private let mibToGib = 1024
    let minSizeMib = 1
    
    @Binding var config: UTMAppleConfigurationDrive
    @State private var isGiB: Bool = true
    
    var body: some View {
        Form {
            VStack {
                Toggle(isOn: $config.isExternal.animation(), label: {
                    Text("Removable")
                }).help("If checked, the drive image will be stored with the VM.")
                .onChange(of: config.isExternal) { newValue in
                    if newValue {
                        config.sizeMib = 0
                    } else {
                        config.sizeMib = 10240
                    }
                }
                if !config.isExternal {
                    SizeTextField($config.sizeMib)
                }
            }
        }
    }
    
    private func validateSize(editing: Bool) {
        guard !editing else {
            return
        }
        if config.sizeMib < minSizeMib {
            config.sizeMib = minSizeMib
        }
    }
    
    private func convertToMib(fromSize size: Int) -> Int {
        if isGiB {
            return size * mibToGib
        } else {
            return size
        }
    }
    
    private func convertToDisplay(fromSizeMib sizeMib: Int) -> Int {
        if isGiB {
            return sizeMib / mibToGib
        } else {
            return sizeMib
        }
    }
}

struct VMConfigAppleDriveCreateView_Previews: PreviewProvider {
    static var previews: some View {
        VMConfigAppleDriveCreateView(config: .constant(.init(newSize: 1024)))
    }
}
