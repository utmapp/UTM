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

struct UTMUnavailableVMView: View {
    @ObservedObject var vm: VMData
    @EnvironmentObject private var data: UTMData
    
    var body: some View {
        UTMPlaceholderVMView(title: vm.detailsTitleLabel,
                             subtitle: vm.detailsSubtitleLabel,
                             progress: nil,
                             imageOverlaySystemName: "questionmark.circle.fill",
                             popover: {
                             #if WITH_REMOTE
                                 UnsupportedVMDetailsView(vm: vm)
                             #else
                                 WrappedVMDetailsView(path: vm.pathUrl.path, onRemove: remove)
                             #endif
                             },
                             onRemove: remove)
    }
    
    private func remove() {
        data.listRemove(vm: vm)
    }
}

fileprivate struct WrappedVMDetailsView: View {
    let path: String
    let onRemove: () -> Void
    
    /// Check if the path in this wrapped VM is accessible
    var isAccessible: Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    var body: some View {
        VStack(alignment: .center) {
            Text(isAccessible ? "This virtual machine must be re-added to UTM by opening it with Finder. You can find it at the path: \(path)"
                 : "This virtual machine cannot be found at: \(path)")
                .lineLimit(nil)
                .padding()
            
            if #available(iOS 15, macOS 12.0, *) {
                Button(role: .cancel, action: onRemove) {
                    Label("Remove", systemImage: "xmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding([.bottom, .leading, .trailing])
            } else {
                Button(action: onRemove) {
                    Label("Remove", systemImage: "xmark.circle")
                }
                .foregroundColor(.red)
                .padding([.bottom, .leading, .trailing])
            }
        }
        #if os(macOS)
        .frame(width: 230)
        #else
        .padding()
        #endif
    }
}

#if WITH_REMOTE
fileprivate struct UnsupportedVMDetailsView: View {
    @ObservedObject var vm: VMData

    var body: some View {
        VStack(alignment: .center) {
            if let remotevm = vm as? VMRemoteData, let reason = remotevm.unavailableReason {
                Text(reason)
                    .lineLimit(nil)
            } else {
                Text("This VM is unavailable.")
            }
        }
        #if os(macOS)
        .frame(width: 230)
        #else
        .padding()
        #endif
    }
}
#endif

struct UTMUnavailableVMView_Previews: PreviewProvider {
    static var previews: some View {
        UTMUnavailableVMView(vm: VMData(from: UTMRegistryEntry.empty))
    }
}
