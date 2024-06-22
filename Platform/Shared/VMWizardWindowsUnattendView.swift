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

struct VMWizardWindowsUnattendView: View {
    @ObservedObject var wizardState: VMWizardState
    var body: some View {
        VMWizardContent("Unattended Installation") {
            Section {
                Form {
                    TextField("Language", text: $wizardState.unattendLanguage)
                        .keyboardType(.asciiCapable)
                        .lineLimit(1)
                    TextField("Username", text: $wizardState.unattendUsername)
                        .keyboardType(.asciiCapable)
                        .lineLimit(1)
                    SecureField("Password", text: $wizardState.unattendPassword)
                        .keyboardType(.asciiCapable)
                        .lineLimit(1)
                }
            } header: {
                Text("Configuration")
            }
        }
    }
}

struct VMWizardWindowsUnattendView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()

    static var previews: some View {
        VMWizardWindowsUnattendView(wizardState: wizardState)
    }
}
