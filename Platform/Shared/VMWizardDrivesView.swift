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

struct VMWizardDrivesView: View {
    @ObservedObject var wizardState: VMWizardState
    
    var body: some View {
        VMWizardContent("Storage") {
            Section {
                HStack {
                    Text("Specify the size of the drive where data will be stored into.")
                    Spacer()
                    NumberTextField("", number: $wizardState.storageSizeGib)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 50)
                    Text("GiB")
                }
            } header: {
                Text("Size")
            }
            
        }
    }
}

struct VMWizardDrivesView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardDrivesView(wizardState: wizardState)
    }
}
