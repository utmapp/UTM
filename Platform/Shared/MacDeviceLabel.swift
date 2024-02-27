//
// Copyright © 2024 osy. All rights reserved.
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
import UniformTypeIdentifiers

struct MacDeviceLabel<Title>: View where Title : StringProtocol {
    let title: Title
    let device: MacDevice

    init(_ title: Title, device macDevice: MacDevice) {
        self.title = title
        self.device = macDevice
    }

    var body: some View {
        Label(title, systemImage: device.symbolName)
    }
}

// credits: https://adamdemasi.com/2023/04/15/mac-device-icon-by-device-class.html

private extension UTTagClass {
    static let deviceModelCode = UTTagClass(rawValue: "com.apple.device-model-code")
}

private extension UTType {
    static let macBook          = UTType("com.apple.mac.laptop")
    static let macBookWithNotch = UTType("com.apple.mac.notched-laptop")
    static let macMini          = UTType("com.apple.macmini")
    static let macStudio        = UTType("com.apple.macstudio")
    static let iMac             = UTType("com.apple.imac")
    static let macPro           = UTType("com.apple.macpro")
    static let macPro2013       = UTType("com.apple.macpro-cylinder")
    static let macPro2019       = UTType("com.apple.macpro-2019")
}

struct MacDevice {
    let model: String
    let symbolName: String

    #if os(macOS)
    static let current: Self = {
        let key = "hw.model"
        var size = size_t()
        sysctlbyname(key, nil, &size, nil, 0)
        let value = malloc(size)
        defer {
            value?.deallocate()
        }
        sysctlbyname(key, value, &size, nil, 0)
        guard let cChar = value?.bindMemory(to: CChar.self, capacity: size) else {
            return Self(model: "Unknown")
        }
        return Self(model: String(cString: cChar))
    }()
    #endif

    init(model: String?) {
        self.model = model ?? "Unknown"
        self.symbolName = Self.symbolName(from: self.model)
    }

    private static func checkModel(_ model: String, conformsTo type: UTType?) -> Bool {
        guard let type else {
            return false
        }
        return UTType(tag: model, tagClass: .deviceModelCode, conformingTo: nil)?.conforms(to: type) ?? false
    }

    private static func symbolName(from model: String) -> String {
        if checkModel(model, conformsTo: .macBookWithNotch),
            #available(macOS 14, iOS 17, macCatalyst 17, tvOS 17, watchOS 10, *) {
            // macbook.gen2 was added with SF Symbols 5.0 (macOS Sonoma, 2023), but MacBooks with a notch
            // were released in 2021!
            return "macbook.gen2"
        } else if checkModel(model, conformsTo: .macBook) {
            return "laptopcomputer"
        } else if checkModel(model, conformsTo: .macMini) {
            return "macmini"
        } else if checkModel(model, conformsTo: .macStudio) {
            return "macstudio"
        } else if checkModel(model, conformsTo: .iMac) {
            return "desktopcomputer"
        } else if checkModel(model, conformsTo: .macPro2019) {
            return "macpro.gen3"
        } else if checkModel(model, conformsTo: .macPro2013) {
            return "macpro.gen2"
        } else if checkModel(model, conformsTo: .macPro) {
            return "macpro"
        }
        return "display"
    }
}

#Preview {
    MacDeviceLabel("MacBook", device: MacDevice(model: "Mac14,6"))
}
