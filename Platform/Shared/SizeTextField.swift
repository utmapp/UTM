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

struct SizeTextField: View {
    @Binding var sizeMib: Int
    @State private var isGiB: Bool = true
    
    private let mibToGib = 1024
    let minSizeMib: Int
    
    init(_ sizeMib: Binding<Int>, minSizeMib: Int = 1) {
        _sizeMib = sizeMib
        self.minSizeMib = minSizeMib
    }
    
    var body: some View {
        HStack {
            NumberTextField("Size", number: Binding<Int>(get: {
                convertToDisplay(fromSizeMib: sizeMib)
            }, set: {
                sizeMib = convertToMib(fromSize: $0)
            }), onEditingChanged: validateSize)
                .multilineTextAlignment(.trailing)
                .help("The amount of storage to allocate for this image. Ignored if importing an image. If this is a raw image, then an empty file of this size will be stored with the VM. Otherwise, the disk image will dynamically expand up to this size.")
            Button(action: { isGiB.toggle() }, label: {
                Group {
                    if isGiB {
                        Text("GiB")
                    } else {
                        Text("MiB")
                    }
                }.foregroundColor(.blue)
            }).buttonStyle(.plain)
        }
    }
    
    private func validateSize(editing: Bool) {
        guard !editing else {
            return
        }
        if sizeMib < minSizeMib {
            sizeMib = minSizeMib
        }
    }
    
    private func convertToMib(fromSize size: Int) -> Int {
        if isGiB {
            return size * mibToGib
        } else {
            return size
        }
    }
    
    private func convertToDisplay(fromSizeMib sizeMib: Int) -> Int {
        if isGiB {
            return sizeMib / mibToGib
        } else {
            return sizeMib
        }
    }
}

struct SizeTextField_Previews: PreviewProvider {
    static var previews: some View {
        SizeTextField(.constant(100))
    }
}
