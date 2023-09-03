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

struct VMWizardOSView: View {
    @ObservedObject var wizardState: VMWizardState
    var body: some View {
        VMWizardContent("Operating System") {
            Section {
                #if os(macOS) && arch(arm64)
                if #available(macOS 12, *), wizardState.useVirtualization {
                    Button {
                        wizardState.operatingSystem = .macOS
                        wizardState.useAppleVirtualization = true
                        wizardState.isGuestToolsInstallRequested = false
                        wizardState.next()
                    } label: {
                        OperatingSystem(imageName: "mac", name: "macOS 12+")
                    }
                }
                #endif
                Button {
                    wizardState.operatingSystem = .Windows
                    wizardState.useAppleVirtualization = false
                    wizardState.isGuestToolsInstallRequested = true
                    wizardState.next()
                } label: {
                    OperatingSystem(imageName: "windows", name: "Windows")
                }
                Button {
                    wizardState.operatingSystem = .Linux
                    wizardState.isGuestToolsInstallRequested = false
                    wizardState.next()
                } label: {
                    OperatingSystem(imageName: "linux", name: "Linux")
                }
            } header: {
                Text("Preconfigured")
            }
            Section {
                Button {
                    wizardState.operatingSystem = .Other
                    wizardState.useAppleVirtualization = false
                    wizardState.isGuestToolsInstallRequested = false
                    wizardState.next()
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                            .resizable()
                            .frame(width: 30.0, height: 30.0)
                            .aspectRatio(contentMode: .fit)
                        Text("Other")
                            .font(.title)
                    }
                    .padding()
                }
            } header: {
                Text("Custom")
            }

        }
        .buttonStyle(.inList)
    }
}

struct OperatingSystem: View {
    let imageName: String
    let name: LocalizedStringKey
    
    private var imageURL: URL {
        let path = Bundle.main.path(forResource: imageName, ofType: "png", inDirectory: "Icons")!
        return URL(fileURLWithPath: path)
    }
    
#if os(macOS)
    private var icon: Image {
        Image(nsImage: NSImage(byReferencing: imageURL))
    }
#else
    private var icon: Image {
        Image(uiImage: UIImage(contentsOfURL: imageURL)!)
    }
#endif
    
    var body: some View {
        HStack {
            icon
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .aspectRatio(contentMode: .fit)
            Text(name)
                .font(.title)
        }
        .padding()
    }
}

struct VMWizardOSView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardOSView(wizardState: wizardState)
    }
}
