//
// Copyright © 2022 osy. All rights reserved.
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
struct UTMPendingVMDetailsView: View {
    @ObservedObject var vm: UTMPendingVirtualMachine
    
    var body: some View {
        VStack(alignment: .leading) {
            if let estimatedSize = vm.estimatedDownloadSize {
                HStack(spacing: 0) {
                    Text("Total Download Size: ")
                    Text(estimatedSize)
                }
            }
            if let estimatedSpeed = vm.estimatedDownloadSpeed {
                HStack(spacing: 0) {
                    Text("Download Speed: ")
                    Text(estimatedSpeed)
                }
            }
            VStack(alignment: .center) {
                if #available(iOS 15, macOS 12.0, *) {
                    Button(role: .cancel, action: vm.cancel) {
                        Label("Cancel Download", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button(action: vm.cancel) {
                        Label("Cancel Download", systemImage: "xmark.circle")
                    }
                    .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

#if DEBUG
struct UTMPendingVMDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        UTMPendingVMDetailsView(vm: UTMPendingVirtualMachine(name: "My Pending VM"))
    }
}
#endif
