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

struct UTMPlaceholderVMView<Content>: View where Content: View {
    let title: String
    let subtitle: String
    let progress: CGFloat?
    let imageOverlaySystemName: String
    let popover: () -> Content
    let onRemove: () -> Void
    
    @State private var showingDetails = false
#if os(macOS)
    @State private var showRemoveButton = false
#endif
    
    var body: some View {
        HStack(alignment: .center) {
            /// Computer with download symbol on its screen
            Image(systemName: "desktopcomputer")
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .aspectRatio(contentMode: .fit)
                .overlay(
                    Image(systemName: imageOverlaySystemName)
                        .font(Font.caption.weight(Font.Weight.medium))
                        .offset(y: -5)
                )
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                if let progress = progress {
                    MinimalProgressView(fractionCompleted: progress)
                }
                Text(subtitle)
                    .font(.caption)
            }
            .foregroundColor(.gray)
            
#if os(macOS)
            Spacer()
            /// macOS gets an on-hover cancel button
            Button(action: onRemove, label: {
                Image(systemName: "xmark.circle")
                    .accessibility(label: Text("Remove"))
            })
                .clipShape(Circle())
                .disabled(!showRemoveButton)
                .opacity(showRemoveButton ? 1 : 0)
#endif
        }.padding([.top, .bottom], 10)
        .onTapGesture(perform: toggleDetailsPopup)
        .popover(isPresented: $showingDetails, content: popover)
        .onDisappear {
            showingDetails = false
        }
#if os(macOS)
        .onHover(perform: { hovering in
            self.showRemoveButton = hovering
        })
#endif
    }
    
    private func toggleDetailsPopup() {
        showingDetails.toggle()
    }
}

struct MinimalProgressView: View {
    let fractionCompleted: CGFloat
    
    private var accessibilityLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.allowsFloats = false
        let label = formatter.string(from: fractionCompleted as NSNumber) ?? ""
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

struct UTMPlaceholderVMView_Previews: PreviewProvider {
    static var previews: some View {
        UTMPlaceholderVMView(title: "Title", subtitle: "Subtitle", progress: nil, imageOverlaySystemName: "arrow.down.circle.fill", popover: {
            EmptyView()
        }, onRemove: {
            
        }).frame(width: 350, height: 100)
    }
}
