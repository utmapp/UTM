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
    @State private var showingDetails = false
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
                        .font(Font.caption.weight(Font.Weight.medium))
                        .offset(y: -5)
                )
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text(vm.name)
                    .font(.headline)
                MinimalProgressView(fractionCompleted: vm.downloadProgress)
                Text(vm.estimatedTimeRemaining ?? " ")
                    .font(.caption)
            }
            .foregroundColor(.gray)
            
#if os(macOS)
            /// macOS gets an on-hover cancel button
            Button(action: {
                vm.cancel()
            }, label: {
                Image(systemName: "xmark.circle")
                    .accessibility(label: Text("Cancel download"))
            })
                .clipShape(Circle())
                .disabled(!showCancelButton)
                .opacity(showCancelButton ? 1 : 0)
#endif
        }
        .onTapGesture(perform: toggleDetailsPopup)
        .popover(isPresented: $showingDetails) {
            UTMPendingVMDetailsView(vm: vm)
        }
#if os(macOS)
        .onHover(perform: { hovering in
            self.showCancelButton = hovering
        })
#endif
    }
    
    private func toggleDetailsPopup() {
        showingDetails.toggle()
    }
}

@available(iOS 14, macOS 11, *)
struct MinimalProgressView: View {
    let fractionCompleted: CGFloat
    
    private var accessibilityLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.allowsFloats = false
        let label = formatter.string(from: NSNumber(value: fractionCompleted)) ?? ""
        return label
    }
    
    var body: some View {
        Text(" ") /// to create a seamless layout with the rest of the text
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .overlay(
                GeometryReader { frame in
                    RoundedRectangle(cornerRadius: frame.size.height/5)
                        .fill(Color.secondary)
                        .frame(width: frame.size.width, height: frame.size.height/3)
                        .offset(y: frame.size.height/3)
                    RoundedRectangle(cornerRadius: frame.size.height/5)
                        .fill(Color.accentColor)
                        .frame(width: frame.size.width * fractionCompleted, height: frame.size.height/3)
                        .offset(y: frame.size.height/3)
                }
            )
            .accessibilityLabel(accessibilityLabel)
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
