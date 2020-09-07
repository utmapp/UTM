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

import SwiftUI

@available(iOS 14, macOS 11, *)
struct VMConfigInputView: View {
    @ObservedObject var config: UTMConfiguration
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Legacy"), footer: Text("PS/2 has higher compatibility with older operating systems but does not support custom cursor settings.").padding(.bottom)) {
                    Toggle(isOn: $config.inputLegacy, label: {
                        Text("Legacy (PS/2) Mode")
                    })
                }
                
                Section(header: Text("Mouse Wheel"), footer: EmptyView().padding(.bottom)) {
                    Toggle(isOn: $config.inputScrollInvert, label: {
                        Text("Invert Mouse Scroll")
                    })
                }
                
                GestureSettingsSection()
            }
        }
    }
}

#if os(macOS)
@available(macOS 11, *)
struct GestureSettingsSection: View {
    var body: some View {
        EmptyView()
    }
}
#else
@available(iOS 14, *)
struct GestureSettingsSection: View {
    var body: some View {
        Section(header: Text("Additional Settings"), footer: EmptyView().padding(.bottom)) {
            Button(action: {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
            }, label: {
                Text("Gesture and Cursor Settings")
            })
        }
    }
}
#endif

@available(iOS 14, macOS 11, *)
struct VMConfigInputView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMConfigInputView(config: config)
    }
}
