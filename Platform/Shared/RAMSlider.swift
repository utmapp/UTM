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

struct RAMSlider: View {
    let validMemoryValues = [32, 64, 128, 256, 512, 768, 1024, 1536, 2048, 3072, 4096, 6144, 8192, 10240, 12288, 14336, 16384, 32768]
    
    let validateMemorySize: (Bool) -> Void
    @Binding var systemMemory: NSNumber?
    @State private var memorySizeIndex: Float = 0
    
    var memorySizeIndexObserver: Binding<Float> {
        Binding<Float>(
            get: {
                return memorySizePickerIndex(size: systemMemory)
            },
            set: {
                systemMemory = memorySize(pickerIndex: $0)
            }
        )
    }
    
    init(systemMemory: Binding<NSNumber?>, onValidate: @escaping (Bool) -> Void = { _ in }) {
        validateMemorySize = onValidate
        _systemMemory = systemMemory
    }
    
    init<T: FixedWidthInteger>(systemMemory: Binding<T>, onValidate: @escaping (Bool) -> Void = { _ in }) {
        validateMemorySize = onValidate
        _systemMemory = Binding<NSNumber?>(get: {
            UInt64(systemMemory.wrappedValue) as NSNumber
        }, set: { newValue in
            systemMemory.wrappedValue = T(newValue?.uint64Value ?? 0)
        })
    }
    
    var body: some View {
        GeometryReader { geo in
            HStack {
                Slider(value: memorySizeIndexObserver, in: 0...Float(validMemoryValues.count-1), step: 1) { start in
                    if !start {
                        validateMemorySize(false)
                    }
                } label: {
                    Text("")
                }
                NumberTextField("", number: $systemMemory, prompt: "Size", onEditingChanged: validateMemorySize)
                    .frame(width: 80)
                Text("MB")
            }
        }.frame(height: 30)
    }
    
    func memorySizePickerIndex(size: NSNumber?) -> Float {
        guard let sizeUnwrap = size else {
            return 0
        }
        for (i, s) in validMemoryValues.enumerated() {
            if s >= Int(truncating: sizeUnwrap) {
                return Float(i)
            }
        }
        return Float(validMemoryValues.count - 1)
    }
    
    func memorySize(pickerIndex: Float) -> NSNumber {
        let i = Int(pickerIndex)
        guard i >= 0 && i < validMemoryValues.count else {
            return 0
        }
        return validMemoryValues[i] as NSNumber
    }
}

struct RAMSlider_Previews: PreviewProvider {
    static var previews: some View {
        RAMSlider(systemMemory: .constant(1024)) { _ in
            
        }
    }
}
