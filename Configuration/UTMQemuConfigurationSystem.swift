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

/// Basic hardware settings.
struct UTMQemuConfigurationSystem: Codable {
    /// The QEMU architecture to emulate.
    var architecture: QEMUArchitecture = .x86_64
    
    /// The QEMU machine target to emulate.
    var target: any QEMUTarget = QEMUTarget_x86_64.q35
    
    /// The QEMU CPU to emulate. Note that `default` will use the default CPU for the architecture.
    var cpu: any QEMUCPU = QEMUCPU_x86_64.default
    
    /// Optional list of CPU flags to add to the target CPU.
    var cpuFlagsAdd: [any QEMUCPUFlag] = []
    
    /// Optional list of CPU flags to remove from the defaults of the target CPU. Parsed after `cpuFlagsAdd`.
    var cpuFlagsRemove: [any QEMUCPUFlag] = []
    
    /// Number of CPU cores to emulate. Set to 0 to match the number of available cores on the host.
    var cpuCount: Int = 0
    
    /// Set to true to force emulation on multiple cores even when the results may be incorrect.
    var isForceMulticore: Bool = false
    
    /// The RAM of the guest in MiB.
    var memorySize: Int = 512
    
    /// The JIT cache (code cache) in MiB.
    var jitCacheSize: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case architecture = "Architecture"
        case target = "Target"
        case cpu = "CPU"
        case cpuFlagsAdd = "CPUFlagsAdd"
        case cpuFlagsRemove = "CPUFlagsRemove"
        case cpuCount = "CPUCount"
        case isForceMulticore = "ForceMulticore"
        case memorySize = "MemorySize"
        case jitCacheSize = "JITCacheSize"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        architecture = try values.decode(QEMUArchitecture.self, forKey: .architecture)
        target = try values.decode(architecture.targetType, forKey: .target)
        do {
            cpu = try values.decode(architecture.cpuType, forKey: .cpu)
        } catch UTMConfigurationError.invalidConfigurationValue(let value) {
            logger.warning("Unable to decode CPU '\(value)', resetting to default CPU")
            cpu = architecture.cpuType.default
        }
        cpuFlagsAdd = try values.decode([AnyQEMUConstant].self, forKey: .cpuFlagsAdd)
        cpuFlagsRemove = try values.decode([AnyQEMUConstant].self, forKey: .cpuFlagsRemove)
        cpuCount = try values.decode(Int.self, forKey: .cpuCount)
        isForceMulticore = try values.decode(Bool.self, forKey: .isForceMulticore)
        memorySize = try values.decode(Int.self, forKey: .memorySize)
        jitCacheSize = try values.decode(Int.self, forKey: .jitCacheSize)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(architecture, forKey: .architecture)
        try container.encode(target.asAnyQEMUConstant(), forKey: .target)
        try container.encode(cpu.asAnyQEMUConstant(), forKey: .cpu)
        try container.encode(cpuFlagsAdd.map({ flag in flag.asAnyQEMUConstant() }), forKey: .cpuFlagsAdd)
        try container.encode(cpuFlagsRemove.map({ flag in flag.asAnyQEMUConstant() }), forKey: .cpuFlagsRemove)
        try container.encode(cpuCount, forKey: .cpuCount)
        try container.encode(isForceMulticore, forKey: .isForceMulticore)
        try container.encode(memorySize, forKey: .memorySize)
        try container.encode(jitCacheSize, forKey: .jitCacheSize)
    }
}

// MARK: - Conversion of old config format

extension UTMQemuConfigurationSystem {
    init(migrating oldConfig: UTMLegacyQemuConfiguration) {
        self.init()
        if let archStr = oldConfig.systemArchitecture, let arch = QEMUArchitecture(rawValue: archStr) {
            architecture = arch
        }
        if let targetStr = oldConfig.systemTarget {
            target = architecture.targetType.init(rawValue: targetStr) ?? architecture.targetType.default
        }
        if let cpuStr = oldConfig.systemCPU {
            cpu = architecture.cpuType.init(rawValue: cpuStr) ?? architecture.cpuType.default
        }
        if let cpuCountNum = oldConfig.systemCPUCount {
            cpuCount = cpuCountNum.intValue
        }
        if let oldFlags = oldConfig.systemCPUFlags {
            for oldFlag in oldFlags {
                var newFlag = oldFlag
                let isAdd: Bool
                if oldFlag.starts(with: "-") {
                    newFlag.removeFirst()
                    isAdd = false
                } else if oldFlag.starts(with: "+") {
                    newFlag.removeFirst()
                    isAdd = true
                } else {
                    isAdd = true
                }
                let flag = AnyQEMUConstant(rawValue: newFlag)!
                if isAdd {
                    cpuFlagsAdd.append(flag)
                } else {
                    cpuFlagsRemove.append(flag)
                }
            }
        }
        isForceMulticore = oldConfig.systemForceMulticore
        if let memoryNum = oldConfig.systemMemory {
            memorySize = memoryNum.intValue
        }
        if let jitCacheNum = oldConfig.systemJitCacheSize {
            jitCacheSize = jitCacheNum.intValue
        }
    }
}
