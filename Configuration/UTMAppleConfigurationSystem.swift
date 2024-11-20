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

import Foundation
import Virtualization

/// Basic hardware settings.
@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
struct UTMAppleConfigurationSystem: Codable {
    private let bytesInMib = UInt64(1048576)
    
    static var currentArchitecture: String {
        #if arch(arm64)
        "aarch64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        #error("Unsupported architecture.")
        #endif
    }
    
    var architecture: String = Self.currentArchitecture
    
    /// Number of CPU cores to emulate. Set to 0 to match the number of available cores on the host.
    var cpuCount: Int = 0
    
    /// The RAM of the guest in MiB.
    var memorySize: Int = 4096
    
    var boot: UTMAppleConfigurationBoot = try! .init(for: .none)
    
    var macPlatform: UTMAppleConfigurationMacPlatform?
    
    var genericPlatform: UTMAppleConfigurationGenericPlatform?
    
    enum CodingKeys: String, CodingKey {
        case architecture = "Architecture"
        case cpuCount = "CPUCount"
        case memorySize = "MemorySize"
        case boot = "Boot"
        case macPlatform = "MacPlatform"
        case genericPlatform = "GenericPlatform"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        architecture = try values.decode(String.self, forKey: .architecture)
        cpuCount = try values.decode(Int.self, forKey: .cpuCount)
        memorySize = try values.decode(Int.self, forKey: .memorySize)
        boot = try values.decode(UTMAppleConfigurationBoot.self, forKey: .boot)
        macPlatform = try values.decodeIfPresent(UTMAppleConfigurationMacPlatform.self, forKey: .macPlatform)
        genericPlatform = try values.decodeIfPresent(UTMAppleConfigurationGenericPlatform.self, forKey: .genericPlatform)
        if boot.operatingSystem == .linux && genericPlatform == nil {
            // fix a bug where this was not created
            genericPlatform = UTMAppleConfigurationGenericPlatform()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(architecture, forKey: .architecture)
        try container.encode(cpuCount, forKey: .cpuCount)
        try container.encode(memorySize, forKey: .memorySize)
        try container.encode(boot, forKey: .boot)
        if boot.operatingSystem == .macOS {
            try container.encodeIfPresent(macPlatform, forKey: .macPlatform)
        } else if boot.operatingSystem == .linux {
            try container.encodeIfPresent(genericPlatform, forKey: .genericPlatform)
        }
    }
}

// MARK: - Conversion of old config format

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfigurationSystem {
    init(migrating oldConfig: UTMLegacyAppleConfiguration) {
        self.init()
        cpuCount = oldConfig.cpuCount
        memorySize = Int(oldConfig.memorySize / bytesInMib)
        if let oldBoot = oldConfig.bootLoader {
            boot = UTMAppleConfigurationBoot(migrating: oldBoot)
        }
        #if arch(arm64)
        if #available(macOS 12, *) {
            if let oldPlatform = oldConfig.macPlatform {
                macPlatform = UTMAppleConfigurationMacPlatform(migrating: oldPlatform)
            }
            boot.macRecoveryIpswURL = oldConfig.macRecoveryIpswURL
        }
        #endif
        if boot.operatingSystem == .linux {
            genericPlatform = UTMAppleConfigurationGenericPlatform()
        }
    }
}

// MARK: - Creating Apple config

@available(iOS, unavailable, message: "Apple Virtualization not available on iOS")
@available(macOS 11, *)
extension UTMAppleConfigurationSystem {
    func fillVZConfiguration(_ vzconfig: VZVirtualMachineConfiguration) throws {
        if cpuCount > 0 {
            vzconfig.cpuCount = cpuCount
        } else {
            let hostPcorePhysicalCpu = Int(Self.sysctlIntRead("hw.perflevel0.physicalcpu"))
            let hostPhysicalCpu = Int(Self.sysctlIntRead("hw.physicalcpu"))
            vzconfig.cpuCount = hostPcorePhysicalCpu > 0 ? hostPcorePhysicalCpu : hostPhysicalCpu
        }
        vzconfig.memorySize = UInt64(memorySize) * bytesInMib
        vzconfig.bootLoader = boot.vzBootloader()
        if boot.operatingSystem == .macOS {
            #if arch(arm64)
            if #available(macOS 12, *),
               let macPlatform = macPlatform,
               let platform = macPlatform.vzMacPlatform() {
                vzconfig.platform = platform
            } else {
                throw UTMAppleConfigurationError.platformUnsupported
            }
            #else
            throw UTMAppleConfigurationError.platformUnsupported
            #endif
        }
        if #available(macOS 12, *),
           let genericPlatform = genericPlatform,
           let platform = genericPlatform.vzGenericPlatform() {
            vzconfig.platform = platform
        }
    }
    
    private static func sysctlIntRead(_ name: String) -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }
}
