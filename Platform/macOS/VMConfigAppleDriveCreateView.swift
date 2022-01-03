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

@available(macOS 12, *)
struct VMConfigAppleDriveCreateView: View {
    private let mibToGib = 1024
    let minSizeMib = 1
    
    @Binding var driveSize: Int
    @State private var isGiB: Bool = true
    
    var body: some View {
        Form {
            HStack {
                NumberTextField("Size", number: Binding<NSNumber?>(get: {
                    NSNumber(value: convertToDisplay(fromSizeMib: driveSize))
                }, set: {
                    driveSize = convertToMib(fromSize: $0?.intValue ?? 0)
                }), onEditingChanged: validateSize)
                    .multilineTextAlignment(.trailing)
                Button(action: { isGiB.toggle() }, label: {
                    Text(isGiB ? "GB" : "MB")
                        .foregroundColor(.blue)
                }).buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func validateSize(editing: Bool) {
        guard !editing else {
            return
        }
        if driveSize < minSizeMib {
            driveSize = minSizeMib
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

@available(macOS 12, *)
struct VMConfigAppleDriveCreateView_Previews: PreviewProvider {
    static var previews: some View {
        VMConfigAppleDriveCreateView(driveSize: .constant(100))
    }
}
