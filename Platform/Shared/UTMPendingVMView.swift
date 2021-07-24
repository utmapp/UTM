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
    let vm: UTMPendingVirtualMachine
    
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
            
            VStack(alignment: .leading) {
                Text(vm.name)
                    .font(.headline)
                Text(" ") /// to create a seamless layout with the ProgressView like a next line of text
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        ProgressView(vm.downloadProgress)
                            .progressViewStyle(MinimalProgressViewStyle())
                    )
            }
            .frame(maxHeight: 30)
        }
        .foregroundColor(.gray)
    }
}

@available(iOS 14, macOS 11, *)
struct MinimalProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        let fractionCompleted = CGFloat(configuration.fractionCompleted ?? 0)
        
        return ZStack {
            GeometryReader { frame in
                RoundedRectangle(cornerRadius: frame.size.height/5)
                    .fill(Color.accentColor)
                    .frame(width: frame.size.width * fractionCompleted, height: frame.size.height/3)
            }
        }
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
