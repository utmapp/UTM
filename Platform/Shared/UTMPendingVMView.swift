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

@available(iOS 14, macOS 11, *)
struct UTMPendingVMView: View {
    @ObservedObject var vm: UTMPendingVirtualMachine
    #if os(macOS)
    @State private var showCancelButton = false
    #endif
    
    var body: some View {
        HStack(alignment: .center) {
            /// Computer with download symbol on its screen
            Image(systemName: "desktopcomputer")
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .aspectRatio(contentMode: .fit)
                .overlay(
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption.weight(.medium))
                        .offset(y: -5)
                )
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text(vm.name)
                    .font(.headline)
                Text(" ") /// to create a seamless layout with the ProgressView like a next line of text
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        MinimalProgressView(fractionCompleted: vm.downloadProgress)
                    )
            }
            .frame(maxHeight: 30)
            .foregroundColor(.gray)
        }
        .overlay(
            HStack {
                Spacer()
                #if os(macOS)
                if showCancelButton {
                    Button(action: {
                        vm.cancel()
                    }, label: {
                        Image(systemName: "xmark.circle")
                            .accessibility(label: Text("Cancel download"))
                    })
                    .clipShape(Circle())
                }
                #endif
            }
        )
        .onHover(perform: { hovering in
            #if os(macOS)
            self.showCancelButton = hovering
            #endif
        })
    }
}

@available(iOS 14, macOS 11, *)
struct MinimalProgressView: View {
    let fractionCompleted: CGFloat
    
    var body: some View {
        ZStack {
            GeometryReader { frame in
                RoundedRectangle(cornerRadius: frame.size.height/5)
                    .fill(Color.accentColor)
                    .frame(width: frame.size.width * fractionCompleted, height: frame.size.height/3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(1)
    }
}

#if DEBUG
@available(iOS 14, macOS 11, *)
struct UTMProgressView_Previews: PreviewProvider {
    static var previews: some View {
        UTMPendingVMView(vm: UTMPendingVirtualMachine(name: ""))
            .frame(width: 350, height: 100)
    }
}
#endif
