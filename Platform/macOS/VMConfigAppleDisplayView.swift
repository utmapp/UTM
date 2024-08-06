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
struct VMConfigAppleDisplayView: View {
    typealias Resolution = UTMAppleConfigurationDisplay
    private struct NamedResolution: Identifiable, Hashable {
        let name: String
        let resolution: Resolution
        var id: String {
            name
        }
        func hash(into hasher: inout Hasher) {
            resolution.widthInPixels.hash(into: &hasher)
            resolution.heightInPixels.hash(into: &hasher)
            resolution.pixelsPerInch.hash(into: &hasher)
        }
        static func == (lhs: NamedResolution, rhs: NamedResolution) -> Bool {
            lhs.hashValue == rhs.hashValue
        }
        static func == (lhs: NamedResolution, rhs: Resolution) -> Bool {
            lhs.resolution.widthInPixels == rhs.widthInPixels &&
            lhs.resolution.heightInPixels == rhs.heightInPixels
        }
    }
    
    private static let customResolution = NamedResolution(name: NSLocalizedString("Custom", comment: "VMConfigAppleDisplayView"),
                                                    resolution: Resolution(width: 0, height: 0))
    
    private var customResolution: NamedResolution {
        Self.customResolution
    }
    
    private let resolutions = [
        Self.customResolution,
        NamedResolution(name: "1024 × 640 — 16:10",
                        resolution: Resolution(width: 1024, height: 640)),
        NamedResolution(name: "1024 × 665 — MacBook Pro (14-inch, 2021) Scaled",
                        resolution: Resolution(width: 1024, height: 665)),
        NamedResolution(name: "1024 × 768 — 4:3 XGA",
                        resolution: Resolution(width: 1024, height: 768)),
        NamedResolution(name: "1147 × 745 — MacBook Pro (14-inch, 2021) Scaled",
                        resolution: Resolution(width: 1147, height: 745)),
        NamedResolution(name: "1152 × 720 — MacBook Pro (16-inch, 2019) Scaled",
                        resolution: Resolution(width: 1152, height: 720)),
        NamedResolution(name: "1168 × 755 — MacBook Pro (16-inch, 2021) Scaled",
                        resolution: Resolution(width: 1168, height: 755)),
        NamedResolution(name: "1280 × 800 — 16:10 WXGA",
                        resolution: Resolution(width: 1280, height: 800)),
        NamedResolution(name: "1280 × 1024 — 5:4 SXGA",
                        resolution: Resolution(width: 1280, height: 1024)),
        NamedResolution(name: "1312 × 848 — MacBook Pro (16-inch, 2021) Scaled",
                        resolution: Resolution(width: 1312, height: 848)),
        NamedResolution(name: "1344 × 840 — MacBook Pro (16-inch, 2019) Scaled",
                        resolution: Resolution(width: 1344, height: 840)),
        NamedResolution(name: "1352 × 878 — MacBook Pro (14-inch, 2021) Scaled",
                        resolution: Resolution(width: 1352, height: 878)),
        NamedResolution(name: "1440 × 900 — 16:10 WXGA+",
                        resolution: Resolution(width: 1440, height: 900)),
        NamedResolution(name: "1496 × 967 — MacBook Pro (16-inch, 2021) Scaled",
                        resolution: Resolution(width: 1496, height: 967)),
        NamedResolution(name: "1512 × 982 — MacBook Pro (14-inch, 2021) Scaled",
                        resolution: Resolution(width: 1512, height: 982)),
        NamedResolution(name: "1680 × 1050 — 16:10 WSXGA+",
                        resolution: Resolution(width: 1680, height: 1050)),
        NamedResolution(name: "1728 × 1117 — MacBook Pro (16-inch, 2021) Scaled",
                        resolution: Resolution(width: 1728, height: 1117)),
        NamedResolution(name: "1792 × 1120 — MacBook Pro (16-inch, 2019) Scaled",
                        resolution: Resolution(width: 1792, height: 1120)),
        NamedResolution(name: "1800 × 1169 — MacBook Pro (14-inch, 2021) Scaled",
                        resolution: Resolution(width: 1800, height: 1169)),
        NamedResolution(name: "1920 × 1080 — Full HD",
                        resolution: Resolution(width: 1920, height: 1080)),
        NamedResolution(name: "1920 × 1200 — 16:10 WUXGA",
                        resolution: Resolution(width: 1920, height: 1200)),
        NamedResolution(name: "2048 × 1280 — MacBook Pro (16-inch, 2019) Scaled",
                        resolution: Resolution(width: 2048, height: 1280)),
        NamedResolution(name: "2056 × 1329 — MacBook Pro (14-inch, 2021) Scaled",
                        resolution: Resolution(width: 2056, height: 1329)),
        NamedResolution(name: "2240 × 1260 — 16:9 Scaled",
                        resolution: Resolution(width: 2240, height: 1260)),
        NamedResolution(name: "2304 × 1440 — MacBook (12-inch, 2015)",
                        resolution: Resolution(width: 2304, height: 1440)), // ppi: 226
        NamedResolution(name: "2560 × 1440 — Quad HD",
                        resolution: Resolution(width: 2560, height: 1440)),
        NamedResolution(name: "2560 × 1600 — MacBook Pro/Air (13-inch, 2012/2018)",
                        resolution: Resolution(width: 2560, height: 1600)), // ppi: 227
        NamedResolution(name: "2560 × 1664 — MacBook Air (13-inch, 2022)",
                        resolution: Resolution(width: 2560, height: 1664)), // ppi: 224
        NamedResolution(name: "2880 × 1800 — MacBook Pro (15-inch, 2012)",
                        resolution: Resolution(width: 2880, height: 1800)), // ppi: 220
        NamedResolution(name: "2880 × 1864 — MacBook Air (15-inch, 2022)",
                        resolution: Resolution(width: 2880, height: 1864)), // ppi: 224
        NamedResolution(name: "3024 × 1890 — MacBook Pro (14-inch, 2021) Full Screen Window",
                        resolution: Resolution(width: 3024, height: 1890)), // ppi: 254
        NamedResolution(name: "3024 × 1964 — MacBook Pro (14-inch, 2021)",
                        resolution: Resolution(width: 3024, height: 1964)), // ppi: 254
        NamedResolution(name: "3072 × 1920 — MacBook Pro (16-inch, 2019)",
                        resolution: Resolution(width: 3072, height: 1920)), // ppi: 226
        NamedResolution(name: "3440 × 1440 — 21:9 Widescreen",
                        resolution: Resolution(width: 3440, height: 1440)),
        NamedResolution(name: "3456 × 2160 — MacBook Pro (16-inch, 2021) Full Screen Window",
                        resolution: Resolution(width: 3456, height: 2160)), // ppi: 254
        NamedResolution(name: "3456 × 2234 — MacBook Pro (16-inch, 2021)",
                        resolution: Resolution(width: 3456, height: 2234)), // ppi: 254
        NamedResolution(name: "3840 × 2160 — 4K Ultra HD",
                        resolution: Resolution(width: 3840, height: 2160)),
        NamedResolution(name: "4480 × 2520 — iMac (24-inch, 2021)",
                        resolution: Resolution(width: 4480, height: 2520)), // ppi: 218
        NamedResolution(name: "5120 × 1440 — 5K Ultra Wide HD",
                        resolution: Resolution(width: 5120, height: 1440)),
        NamedResolution(name: "5120 × 2880 — 5K Ultra HD",
                        resolution: Resolution(width: 5120, height: 2880)),
    ]
    
    @Binding var config: UTMAppleConfigurationDisplay
    
    private var displayResolution: Binding<NamedResolution> {
        Binding<NamedResolution> {
            for item in resolutions {
                if item == config {
                    return item
                }
            }
            return customResolution
        } set: { newValue in
            config.widthInPixels = newValue.resolution.widthInPixels
            config.heightInPixels = newValue.resolution.heightInPixels
            config.pixelsPerInch = newValue.resolution.pixelsPerInch
        }
    }
    
    private var isHidpi: Binding<Bool> {
        Binding<Bool> {
            return config.pixelsPerInch >= 226
        } set: { newValue in
            config.pixelsPerInch = newValue ? 226 : 80
        }
    }
    
    var body: some View {
        Form {
            Picker("Resolution", selection: displayResolution) {
                ForEach(resolutions) { item in
                    Text(item.name)
                        .tag(item)
                }
            }
            if displayResolution.wrappedValue == customResolution {
                NumberTextField("Width", number: $config.widthInPixels)
                NumberTextField("Height", number: $config.heightInPixels)
            }
            Toggle("HiDPI (Retina)", isOn: isHidpi)
                .help("Only available on macOS virtual machines.")
            if #available(macOS 14, *) {
                Toggle("Dynamic Resolution", isOn: $config.isDynamicResolution)
                    .help("Only available on macOS 14+ virtual machines.")
            }
        }
    }
}

@available(macOS 12, *)
struct VMConfigAppleDisplayView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfigurationDisplay()
    
    static var previews: some View {
        VMConfigAppleDisplayView(config: $config)
    }
}
