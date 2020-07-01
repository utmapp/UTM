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

struct ContentView: View {
    @State private var editMode = false
    @State private var isSettingsPresented = false
    @State private var examples = ["Windows", "Ubuntu", "Generic"]
    
    var body: some View {
        NavigationView {
            List(examples, id: \.self) { example in
                NavigationLink(
                    destination: VMDetailsView(config: UTMConfiguration(name: example), screenshot: UIImage(named: "\(example)-Screen")),
                    label: {
                        VMCardView(title: { Text(example) }, editAction: {}, runAction: {}, logo: .constant(UIImage(named: example)) )
                    })
            }.listStyle(SidebarListStyle())
            .navigationTitle("UTM")
            VMPlaceholderView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
