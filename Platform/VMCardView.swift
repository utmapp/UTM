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

struct VMCardView<Title>: View where Title: View {
    var title: () -> Title
    var editAction: () -> Void
    var runAction: () -> Void
    #if os(macOS)
    @Binding var logo: NSImage?
    #else // iOS
    @Binding var logo: UIImage?
    #endif
    
    var body: some View {
        HStack() {
            Logo(logo: $logo)
            title()
                .font(.title)
            Spacer()
            Button(action: runAction) {
                Label("Run", systemImage: "play.fill")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                    .labelStyle(IconOnlyLabelStyle())
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: editAction) {
                Label("Edit", systemImage: "slider.horizontal.3")
            }
            Button {
                
            } label: {
                Label("Change Logo", systemImage: "photo")
            }
            Button(action: runAction) {
                Label("Run", systemImage: "play.fill")
            }
            Button {
                
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            Button {
                
            } label: {
                Label("Clone", systemImage: "doc.on.doc")
            }
            Button {
                
            } label: {
                Label("Delete", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
}

#if os(macOS)
struct Logo: View {
    @Binding var logo: NSImage?
    
    var body: some View {
        Group {
            if logo != nil {
                Image(nsImage: logo!)
                    .resizable()
                    .frame(width: 30.0, height: 30.0)
                    .padding()
            } else {
                defaultLogo
            }
        }
    }
}
#else // iOS
struct Logo: View {
    @Binding var logo: UIImage?
    
    var body: some View {
        Group {
            if logo != nil {
                Image(uiImage: logo!)
                    .resizable()
                    .frame(width: 30.0, height: 30.0)
                    .padding()
            } else {
                defaultLogo
            }
        }
    }
}
#endif

extension Logo {
    var defaultLogo: some View {
        Image(systemName: "desktopcomputer")
            .resizable()
            .frame(width: 30.0, height: 30.0)
            .padding()
    }
}

struct VMCardView_Previews: PreviewProvider {
    static var previews: some View {
        VMCardView(title: { Text("Virtual Machine") }, editAction: {}, runAction: {}, logo: .constant(nil))
    }
}
