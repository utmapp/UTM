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

// !! THIS FILE IS GENERATED FROM const-gen.py, DO NOT MODIFY MANUALLY !!

import Foundation

enum QEMUArchitecture: String, CaseIterable, QEMUConstant {
    case alpha
    case arm
    case aarch64
    case avr
    case cris
    case hppa
    case i386
    case loongarch64
    case m68k
    case microblaze
    case microblazeel
    case mips
    case mipsel
    case mips64
    case mips64el
    case or1k
    case ppc
    case ppc64
    case riscv32
    case riscv64
    case rx
    case s390x
    case sh4
    case sh4eb
    case sparc
    case sparc64
    case tricore
    case x86_64
    case xtensa
    case xtensaeb

    var prettyValue: String {
        switch self {
        case .alpha: return "Alpha"
        case .arm: return "ARM (aarch32)"
        case .aarch64: return "ARM64 (aarch64)"
        case .avr: return "AVR"
        case .cris: return "CRIS"
        case .hppa: return "HPPA"
        case .i386: return "i386 (x86)"
        case .loongarch64: return "LoongArch64"
        case .m68k: return "m68k"
        case .microblaze: return "Microblaze"
        case .microblazeel: return "Microblaze (Little Endian)"
        case .mips: return "MIPS"
        case .mipsel: return "MIPS (Little Endian)"
        case .mips64: return "MIPS64"
        case .mips64el: return "MIPS64 (Little Endian)"
        case .or1k: return "OpenRISC"
        case .ppc: return "PowerPC"
        case .ppc64: return "PowerPC64"
        case .riscv32: return "RISC-V32"
        case .riscv64: return "RISC-V64"
        case .rx: return "RX"
        case .s390x: return "S390x (zSeries)"
        case .sh4: return "SH4"
        case .sh4eb: return "SH4 (Big Endian)"
        case .sparc: return "SPARC"
        case .sparc64: return "SPARC64"
        case .tricore: return "TriCore"
        case .x86_64: return "x86_64"
        case .xtensa: return "Xtensa"
        case .xtensaeb: return "Xtensa (Big Endian)"
        }
    }
}

enum QEMUCPU_alpha: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case ev4
    case ev5
    case ev56
    case ev6
    case ev67
    case ev68
    case pca56

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .ev4: return "ev4"
        case .ev5: return "ev5"
        case .ev56: return "ev56"
        case .ev6: return "ev6"
        case .ev67: return "ev67"
        case .ev68: return "ev68"
        case .pca56: return "pca56"
        }
    }
}

enum QEMUCPU_arm: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case arm1026
    case arm1136
    case arm1136_r2 = "arm1136-r2"
    case arm1176
    case arm11mpcore
    case arm926
    case arm946
    case cortex_a15 = "cortex-a15"
    case cortex_a7 = "cortex-a7"
    case cortex_a8 = "cortex-a8"
    case cortex_a9 = "cortex-a9"
    case cortex_m0 = "cortex-m0"
    case cortex_m3 = "cortex-m3"
    case cortex_m33 = "cortex-m33"
    case cortex_m4 = "cortex-m4"
    case cortex_m55 = "cortex-m55"
    case cortex_m7 = "cortex-m7"
    case cortex_r5 = "cortex-r5"
    case cortex_r52 = "cortex-r52"
    case cortex_r5f = "cortex-r5f"
    case max
    case pxa250
    case pxa255
    case pxa260
    case pxa261
    case pxa262
    case pxa270
    case pxa270_a0 = "pxa270-a0"
    case pxa270_a1 = "pxa270-a1"
    case pxa270_b0 = "pxa270-b0"
    case pxa270_b1 = "pxa270-b1"
    case pxa270_c0 = "pxa270-c0"
    case pxa270_c5 = "pxa270-c5"
    case sa1100
    case sa1110
    case ti925t

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .arm1026: return "arm1026"
        case .arm1136: return "arm1136"
        case .arm1136_r2: return "arm1136-r2"
        case .arm1176: return "arm1176"
        case .arm11mpcore: return "arm11mpcore"
        case .arm926: return "arm926"
        case .arm946: return "arm946"
        case .cortex_a15: return "cortex-a15"
        case .cortex_a7: return "cortex-a7"
        case .cortex_a8: return "cortex-a8"
        case .cortex_a9: return "cortex-a9"
        case .cortex_m0: return "cortex-m0"
        case .cortex_m3: return "cortex-m3"
        case .cortex_m33: return "cortex-m33"
        case .cortex_m4: return "cortex-m4"
        case .cortex_m55: return "cortex-m55"
        case .cortex_m7: return "cortex-m7"
        case .cortex_r5: return "cortex-r5"
        case .cortex_r52: return "cortex-r52"
        case .cortex_r5f: return "cortex-r5f"
        case .max: return "max"
        case .pxa250: return "pxa250"
        case .pxa255: return "pxa255"
        case .pxa260: return "pxa260"
        case .pxa261: return "pxa261"
        case .pxa262: return "pxa262"
        case .pxa270: return "pxa270"
        case .pxa270_a0: return "pxa270-a0"
        case .pxa270_a1: return "pxa270-a1"
        case .pxa270_b0: return "pxa270-b0"
        case .pxa270_b1: return "pxa270-b1"
        case .pxa270_c0: return "pxa270-c0"
        case .pxa270_c5: return "pxa270-c5"
        case .sa1100: return "sa1100"
        case .sa1110: return "sa1110"
        case .ti925t: return "ti925t"
        }
    }
}

enum QEMUCPU_aarch64: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case a64fx
    case arm1026
    case arm1136
    case arm1136_r2 = "arm1136-r2"
    case arm1176
    case arm11mpcore
    case arm926
    case arm946
    case cortex_a15 = "cortex-a15"
    case cortex_a35 = "cortex-a35"
    case cortex_a53 = "cortex-a53"
    case cortex_a55 = "cortex-a55"
    case cortex_a57 = "cortex-a57"
    case cortex_a7 = "cortex-a7"
    case cortex_a710 = "cortex-a710"
    case cortex_a72 = "cortex-a72"
    case cortex_a76 = "cortex-a76"
    case cortex_a8 = "cortex-a8"
    case cortex_a9 = "cortex-a9"
    case cortex_m0 = "cortex-m0"
    case cortex_m3 = "cortex-m3"
    case cortex_m33 = "cortex-m33"
    case cortex_m4 = "cortex-m4"
    case cortex_m55 = "cortex-m55"
    case cortex_m7 = "cortex-m7"
    case cortex_r5 = "cortex-r5"
    case cortex_r52 = "cortex-r52"
    case cortex_r5f = "cortex-r5f"
    case host
    case max
    case neoverse_n1 = "neoverse-n1"
    case neoverse_n2 = "neoverse-n2"
    case neoverse_v1 = "neoverse-v1"
    case pxa250
    case pxa255
    case pxa260
    case pxa261
    case pxa262
    case pxa270
    case pxa270_a0 = "pxa270-a0"
    case pxa270_a1 = "pxa270-a1"
    case pxa270_b0 = "pxa270-b0"
    case pxa270_b1 = "pxa270-b1"
    case pxa270_c0 = "pxa270-c0"
    case pxa270_c5 = "pxa270-c5"
    case sa1100
    case sa1110
    case ti925t

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .a64fx: return "a64fx"
        case .arm1026: return "arm1026"
        case .arm1136: return "arm1136"
        case .arm1136_r2: return "arm1136-r2"
        case .arm1176: return "arm1176"
        case .arm11mpcore: return "arm11mpcore"
        case .arm926: return "arm926"
        case .arm946: return "arm946"
        case .cortex_a15: return "cortex-a15"
        case .cortex_a35: return "cortex-a35"
        case .cortex_a53: return "cortex-a53"
        case .cortex_a55: return "cortex-a55"
        case .cortex_a57: return "cortex-a57"
        case .cortex_a7: return "cortex-a7"
        case .cortex_a710: return "cortex-a710"
        case .cortex_a72: return "cortex-a72"
        case .cortex_a76: return "cortex-a76"
        case .cortex_a8: return "cortex-a8"
        case .cortex_a9: return "cortex-a9"
        case .cortex_m0: return "cortex-m0"
        case .cortex_m3: return "cortex-m3"
        case .cortex_m33: return "cortex-m33"
        case .cortex_m4: return "cortex-m4"
        case .cortex_m55: return "cortex-m55"
        case .cortex_m7: return "cortex-m7"
        case .cortex_r5: return "cortex-r5"
        case .cortex_r52: return "cortex-r52"
        case .cortex_r5f: return "cortex-r5f"
        case .host: return "host"
        case .max: return "max"
        case .neoverse_n1: return "neoverse-n1"
        case .neoverse_n2: return "neoverse-n2"
        case .neoverse_v1: return "neoverse-v1"
        case .pxa250: return "pxa250"
        case .pxa255: return "pxa255"
        case .pxa260: return "pxa260"
        case .pxa261: return "pxa261"
        case .pxa262: return "pxa262"
        case .pxa270: return "pxa270"
        case .pxa270_a0: return "pxa270-a0"
        case .pxa270_a1: return "pxa270-a1"
        case .pxa270_b0: return "pxa270-b0"
        case .pxa270_b1: return "pxa270-b1"
        case .pxa270_c0: return "pxa270-c0"
        case .pxa270_c5: return "pxa270-c5"
        case .sa1100: return "sa1100"
        case .sa1110: return "sa1110"
        case .ti925t: return "ti925t"
        }
    }
}

enum QEMUCPU_avr: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case avr5
    case avr51
    case avr6

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .avr5: return "avr5"
        case .avr51: return "avr51"
        case .avr6: return "avr6"
        }
    }
}

enum QEMUCPU_cris: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case crisv10
    case crisv11
    case crisv17
    case crisv32
    case crisv8
    case crisv9

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .crisv10: return "crisv10"
        case .crisv11: return "crisv11"
        case .crisv17: return "crisv17"
        case .crisv32: return "crisv32"
        case .crisv8: return "crisv8"
        case .crisv9: return "crisv9"
        }
    }
}

enum QEMUCPU_hppa: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case hppa_cpu = "hppa-cpu"
    case hppa64_cpu = "hppa64-cpu"

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .hppa_cpu: return "hppa-cpu"
        case .hppa64_cpu: return "hppa64-cpu"
        }
    }
}

enum QEMUCPU_i386: String, CaseIterable, QEMUCPU {
    case _486 = "486"
    case _486_v1 = "486-v1"
    case EPYC_v1 = "EPYC-v1"
    case EPYC_v3 = "EPYC-v3"
    case EPYC_v2 = "EPYC-v2"
    case EPYC_Genoa_v1 = "EPYC-Genoa-v1"
    case EPYC_Milan_v1 = "EPYC-Milan-v1"
    case EPYC_Milan_v2 = "EPYC-Milan-v2"
    case EPYC_Rome_v1 = "EPYC-Rome-v1"
    case EPYC_Rome_v2 = "EPYC-Rome-v2"
    case EPYC_Rome_v3 = "EPYC-Rome-v3"
    case EPYC_Rome_v4 = "EPYC-Rome-v4"
    case EPYC_v4 = "EPYC-v4"
    case Opteron_G2_v1 = "Opteron_G2-v1"
    case Opteron_G3_v1 = "Opteron_G3-v1"
    case Opteron_G1_v1 = "Opteron_G1-v1"
    case Opteron_G4_v1 = "Opteron_G4-v1"
    case Opteron_G5_v1 = "Opteron_G5-v1"
    case phenom_v1 = "phenom-v1"
    case Broadwell
    case Broadwell_IBRS = "Broadwell-IBRS"
    case Broadwell_noTSX = "Broadwell-noTSX"
    case Broadwell_noTSX_IBRS = "Broadwell-noTSX-IBRS"
    case Cascadelake_Server = "Cascadelake-Server"
    case Cascadelake_Server_noTSX = "Cascadelake-Server-noTSX"
    case kvm32_v1 = "kvm32-v1"
    case kvm64_v1 = "kvm64-v1"
    case Conroe
    case Cooperlake
    case `default` = "default"
    case Denverton
    case Dhyana
    case EPYC
    case EPYC_Genoa = "EPYC-Genoa"
    case EPYC_IBPB = "EPYC-IBPB"
    case EPYC_Milan = "EPYC-Milan"
    case EPYC_Rome = "EPYC-Rome"
    case max
    case coreduo_v1 = "coreduo-v1"
    case GraniteRapids
    case Haswell
    case Haswell_IBRS = "Haswell-IBRS"
    case Haswell_noTSX = "Haswell-noTSX"
    case Haswell_noTSX_IBRS = "Haswell-noTSX-IBRS"
    case Dhyana_v1 = "Dhyana-v1"
    case Dhyana_v2 = "Dhyana-v2"
    case Icelake_Server = "Icelake-Server"
    case Icelake_Server_noTSX = "Icelake-Server-noTSX"
    case Denverton_v1 = "Denverton-v1"
    case Denverton_v3 = "Denverton-v3"
    case Denverton_v2 = "Denverton-v2"
    case Snowridge_v1 = "Snowridge-v1"
    case Snowridge_v2 = "Snowridge-v2"
    case Snowridge_v3 = "Snowridge-v3"
    case Snowridge_v4 = "Snowridge-v4"
    case Conroe_v1 = "Conroe-v1"
    case Penryn_v1 = "Penryn-v1"
    case Broadwell_v1 = "Broadwell-v1"
    case Broadwell_v3 = "Broadwell-v3"
    case Broadwell_v2 = "Broadwell-v2"
    case Broadwell_v4 = "Broadwell-v4"
    case Haswell_v1 = "Haswell-v1"
    case Haswell_v3 = "Haswell-v3"
    case Haswell_v2 = "Haswell-v2"
    case Haswell_v4 = "Haswell-v4"
    case Skylake_Client_v1 = "Skylake-Client-v1"
    case Skylake_Client_v2 = "Skylake-Client-v2"
    case Skylake_Client_v3 = "Skylake-Client-v3"
    case Skylake_Client_v4 = "Skylake-Client-v4"
    case Nehalem_v1 = "Nehalem-v1"
    case Nehalem_v2 = "Nehalem-v2"
    case IvyBridge_v1 = "IvyBridge-v1"
    case IvyBridge_v2 = "IvyBridge-v2"
    case SandyBridge_v1 = "SandyBridge-v1"
    case SandyBridge_v2 = "SandyBridge-v2"
    case KnightsMill_v1 = "KnightsMill-v1"
    case Cascadelake_Server_v1 = "Cascadelake-Server-v1"
    case Cascadelake_Server_v5 = "Cascadelake-Server-v5"
    case Cascadelake_Server_v3 = "Cascadelake-Server-v3"
    case Cascadelake_Server_v4 = "Cascadelake-Server-v4"
    case Cascadelake_Server_v2 = "Cascadelake-Server-v2"
    case Cooperlake_v1 = "Cooperlake-v1"
    case Cooperlake_v2 = "Cooperlake-v2"
    case GraniteRapids_v1 = "GraniteRapids-v1"
    case Icelake_Server_v1 = "Icelake-Server-v1"
    case Icelake_Server_v3 = "Icelake-Server-v3"
    case Icelake_Server_v4 = "Icelake-Server-v4"
    case Icelake_Server_v6 = "Icelake-Server-v6"
    case Icelake_Server_v7 = "Icelake-Server-v7"
    case Icelake_Server_v5 = "Icelake-Server-v5"
    case Icelake_Server_v2 = "Icelake-Server-v2"
    case SapphireRapids_v1 = "SapphireRapids-v1"
    case SapphireRapids_v2 = "SapphireRapids-v2"
    case SapphireRapids_v3 = "SapphireRapids-v3"
    case SierraForest_v1 = "SierraForest-v1"
    case Skylake_Server_v1 = "Skylake-Server-v1"
    case Skylake_Server_v2 = "Skylake-Server-v2"
    case Skylake_Server_v3 = "Skylake-Server-v3"
    case Skylake_Server_v4 = "Skylake-Server-v4"
    case Skylake_Server_v5 = "Skylake-Server-v5"
    case n270_v1 = "n270-v1"
    case core2duo_v1 = "core2duo-v1"
    case IvyBridge
    case IvyBridge_IBRS = "IvyBridge-IBRS"
    case KnightsMill
    case Nehalem
    case Nehalem_IBRS = "Nehalem-IBRS"
    case Opteron_G1
    case Opteron_G2
    case Opteron_G3
    case Opteron_G4
    case Opteron_G5
    case Penryn
    case athlon_v1 = "athlon-v1"
    case qemu32_v1 = "qemu32-v1"
    case qemu64_v1 = "qemu64-v1"
    case SandyBridge
    case SandyBridge_IBRS = "SandyBridge-IBRS"
    case SapphireRapids
    case SierraForest
    case Skylake_Client = "Skylake-Client"
    case Skylake_Client_IBRS = "Skylake-Client-IBRS"
    case Skylake_Client_noTSX_IBRS = "Skylake-Client-noTSX-IBRS"
    case Skylake_Server = "Skylake-Server"
    case Skylake_Server_IBRS = "Skylake-Server-IBRS"
    case Skylake_Server_noTSX_IBRS = "Skylake-Server-noTSX-IBRS"
    case Snowridge
    case Westmere
    case Westmere_v2 = "Westmere-v2"
    case Westmere_v1 = "Westmere-v1"
    case Westmere_IBRS = "Westmere-IBRS"
    case athlon
    case base
    case core2duo
    case coreduo
    case kvm32
    case kvm64
    case n270
    case pentium
    case pentium_v1 = "pentium-v1"
    case pentium2
    case pentium2_v1 = "pentium2-v1"
    case pentium3
    case pentium3_v1 = "pentium3-v1"
    case phenom
    case qemu32
    case qemu64

    var prettyValue: String {
        switch self {
        case ._486: return "486"
        case ._486_v1: return "486-v1"
        case .EPYC_v1: return "AMD EPYC Processor (EPYC-v1)"
        case .EPYC_v3: return "AMD EPYC Processor (EPYC-v3)"
        case .EPYC_v2: return "AMD EPYC Processor (with IBPB) (EPYC-v2)"
        case .EPYC_Genoa_v1: return "AMD EPYC-Genoa Processor (EPYC-Genoa-v1)"
        case .EPYC_Milan_v1: return "AMD EPYC-Milan Processor (EPYC-Milan-v1)"
        case .EPYC_Milan_v2: return "AMD EPYC-Milan-v2 Processor (EPYC-Milan-v2)"
        case .EPYC_Rome_v1: return "AMD EPYC-Rome Processor (EPYC-Rome-v1)"
        case .EPYC_Rome_v2: return "AMD EPYC-Rome Processor (EPYC-Rome-v2)"
        case .EPYC_Rome_v3: return "AMD EPYC-Rome-v3 Processor (EPYC-Rome-v3)"
        case .EPYC_Rome_v4: return "AMD EPYC-Rome-v4 Processor (no XSAVES) (EPYC-Rome-v4)"
        case .EPYC_v4: return "AMD EPYC-v4 Processor (EPYC-v4)"
        case .Opteron_G2_v1: return "AMD Opteron 22xx (Gen 2 Class Opteron) (Opteron_G2-v1)"
        case .Opteron_G3_v1: return "AMD Opteron 23xx (Gen 3 Class Opteron) (Opteron_G3-v1)"
        case .Opteron_G1_v1: return "AMD Opteron 240 (Gen 1 Class Opteron) (Opteron_G1-v1)"
        case .Opteron_G4_v1: return "AMD Opteron 62xx class CPU (Opteron_G4-v1)"
        case .Opteron_G5_v1: return "AMD Opteron 63xx class CPU (Opteron_G5-v1)"
        case .phenom_v1: return "AMD Phenom(tm) 9550 Quad-Core Processor (phenom-v1)"
        case .Broadwell: return "Broadwell"
        case .Broadwell_IBRS: return "Broadwell-IBRS"
        case .Broadwell_noTSX: return "Broadwell-noTSX"
        case .Broadwell_noTSX_IBRS: return "Broadwell-noTSX-IBRS"
        case .Cascadelake_Server: return "Cascadelake-Server"
        case .Cascadelake_Server_noTSX: return "Cascadelake-Server-noTSX"
        case .kvm32_v1: return "Common 32-bit KVM processor (kvm32-v1)"
        case .kvm64_v1: return "Common KVM processor (kvm64-v1)"
        case .Conroe: return "Conroe"
        case .Cooperlake: return "Cooperlake"
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .Denverton: return "Denverton"
        case .Dhyana: return "Dhyana"
        case .EPYC: return "EPYC"
        case .EPYC_Genoa: return "EPYC-Genoa"
        case .EPYC_IBPB: return "EPYC-IBPB"
        case .EPYC_Milan: return "EPYC-Milan"
        case .EPYC_Rome: return "EPYC-Rome"
        case .max: return "Enables all features supported by the accelerator in the current host (max)"
        case .coreduo_v1: return "Genuine Intel(R) CPU T2600 @ 2.16GHz (coreduo-v1)"
        case .GraniteRapids: return "GraniteRapids"
        case .Haswell: return "Haswell"
        case .Haswell_IBRS: return "Haswell-IBRS"
        case .Haswell_noTSX: return "Haswell-noTSX"
        case .Haswell_noTSX_IBRS: return "Haswell-noTSX-IBRS"
        case .Dhyana_v1: return "Hygon Dhyana Processor (Dhyana-v1)"
        case .Dhyana_v2: return "Hygon Dhyana Processor [XSAVES] (Dhyana-v2)"
        case .Icelake_Server: return "Icelake-Server"
        case .Icelake_Server_noTSX: return "Icelake-Server-noTSX"
        case .Denverton_v1: return "Intel Atom Processor (Denverton) (Denverton-v1)"
        case .Denverton_v3: return "Intel Atom Processor (Denverton) [XSAVES, no MPX, no MONITOR] (Denverton-v3)"
        case .Denverton_v2: return "Intel Atom Processor (Denverton) [no MPX, no MONITOR] (Denverton-v2)"
        case .Snowridge_v1: return "Intel Atom Processor (SnowRidge) (Snowridge-v1)"
        case .Snowridge_v2: return "Intel Atom Processor (Snowridge, no MPX) (Snowridge-v2)"
        case .Snowridge_v3: return "Intel Atom Processor (Snowridge, no MPX) [XSAVES, no MPX] (Snowridge-v3)"
        case .Snowridge_v4: return "Intel Atom Processor (Snowridge, no MPX) [no split lock detect, no core-capability] (Snowridge-v4)"
        case .Conroe_v1: return "Intel Celeron_4x0 (Conroe/Merom Class Core 2) (Conroe-v1)"
        case .Penryn_v1: return "Intel Core 2 Duo P9xxx (Penryn Class Core 2) (Penryn-v1)"
        case .Broadwell_v1: return "Intel Core Processor (Broadwell) (Broadwell-v1)"
        case .Broadwell_v3: return "Intel Core Processor (Broadwell, IBRS) (Broadwell-v3)"
        case .Broadwell_v2: return "Intel Core Processor (Broadwell, no TSX) (Broadwell-v2)"
        case .Broadwell_v4: return "Intel Core Processor (Broadwell, no TSX, IBRS) (Broadwell-v4)"
        case .Haswell_v1: return "Intel Core Processor (Haswell) (Haswell-v1)"
        case .Haswell_v3: return "Intel Core Processor (Haswell, IBRS) (Haswell-v3)"
        case .Haswell_v2: return "Intel Core Processor (Haswell, no TSX) (Haswell-v2)"
        case .Haswell_v4: return "Intel Core Processor (Haswell, no TSX, IBRS) (Haswell-v4)"
        case .Skylake_Client_v1: return "Intel Core Processor (Skylake) (Skylake-Client-v1)"
        case .Skylake_Client_v2: return "Intel Core Processor (Skylake, IBRS) (Skylake-Client-v2)"
        case .Skylake_Client_v3: return "Intel Core Processor (Skylake, IBRS, no TSX) (Skylake-Client-v3)"
        case .Skylake_Client_v4: return "Intel Core Processor (Skylake, IBRS, no TSX) [IBRS, XSAVES, no TSX] (Skylake-Client-v4)"
        case .Nehalem_v1: return "Intel Core i7 9xx (Nehalem Class Core i7) (Nehalem-v1)"
        case .Nehalem_v2: return "Intel Core i7 9xx (Nehalem Core i7, IBRS update) (Nehalem-v2)"
        case .IvyBridge_v1: return "Intel Xeon E3-12xx v2 (Ivy Bridge) (IvyBridge-v1)"
        case .IvyBridge_v2: return "Intel Xeon E3-12xx v2 (Ivy Bridge, IBRS) (IvyBridge-v2)"
        case .SandyBridge_v1: return "Intel Xeon E312xx (Sandy Bridge) (SandyBridge-v1)"
        case .SandyBridge_v2: return "Intel Xeon E312xx (Sandy Bridge, IBRS update) (SandyBridge-v2)"
        case .KnightsMill_v1: return "Intel Xeon Phi Processor (Knights Mill) (KnightsMill-v1)"
        case .Cascadelake_Server_v1: return "Intel Xeon Processor (Cascadelake) (Cascadelake-Server-v1)"
        case .Cascadelake_Server_v5: return "Intel Xeon Processor (Cascadelake) [ARCH_CAPABILITIES, EPT switching, XSAVES, no TSX] (Cascadelake-Server-v5)"
        case .Cascadelake_Server_v3: return "Intel Xeon Processor (Cascadelake) [ARCH_CAPABILITIES, no TSX] (Cascadelake-Server-v3)"
        case .Cascadelake_Server_v4: return "Intel Xeon Processor (Cascadelake) [ARCH_CAPABILITIES, no TSX] (Cascadelake-Server-v4)"
        case .Cascadelake_Server_v2: return "Intel Xeon Processor (Cascadelake) [ARCH_CAPABILITIES] (Cascadelake-Server-v2)"
        case .Cooperlake_v1: return "Intel Xeon Processor (Cooperlake) (Cooperlake-v1)"
        case .Cooperlake_v2: return "Intel Xeon Processor (Cooperlake) [XSAVES] (Cooperlake-v2)"
        case .GraniteRapids_v1: return "Intel Xeon Processor (GraniteRapids) (GraniteRapids-v1)"
        case .Icelake_Server_v1: return "Intel Xeon Processor (Icelake) (Icelake-Server-v1)"
        case .Icelake_Server_v3: return "Intel Xeon Processor (Icelake) (Icelake-Server-v3)"
        case .Icelake_Server_v4: return "Intel Xeon Processor (Icelake) (Icelake-Server-v4)"
        case .Icelake_Server_v6: return "Intel Xeon Processor (Icelake) [5-level EPT] (Icelake-Server-v6)"
        case .Icelake_Server_v7: return "Intel Xeon Processor (Icelake) [TSX, taa-no] (Icelake-Server-v7)"
        case .Icelake_Server_v5: return "Intel Xeon Processor (Icelake) [XSAVES] (Icelake-Server-v5)"
        case .Icelake_Server_v2: return "Intel Xeon Processor (Icelake) [no TSX] (Icelake-Server-v2)"
        case .SapphireRapids_v1: return "Intel Xeon Processor (SapphireRapids) (SapphireRapids-v1)"
        case .SapphireRapids_v2: return "Intel Xeon Processor (SapphireRapids) (SapphireRapids-v2)"
        case .SapphireRapids_v3: return "Intel Xeon Processor (SapphireRapids) (SapphireRapids-v3)"
        case .SierraForest_v1: return "Intel Xeon Processor (SierraForest) (SierraForest-v1)"
        case .Skylake_Server_v1: return "Intel Xeon Processor (Skylake) (Skylake-Server-v1)"
        case .Skylake_Server_v2: return "Intel Xeon Processor (Skylake, IBRS) (Skylake-Server-v2)"
        case .Skylake_Server_v3: return "Intel Xeon Processor (Skylake, IBRS, no TSX) (Skylake-Server-v3)"
        case .Skylake_Server_v4: return "Intel Xeon Processor (Skylake, IBRS, no TSX) (Skylake-Server-v4)"
        case .Skylake_Server_v5: return "Intel Xeon Processor (Skylake, IBRS, no TSX) [IBRS, XSAVES, EPT switching, no TSX] (Skylake-Server-v5)"
        case .n270_v1: return "Intel(R) Atom(TM) CPU N270 @ 1.60GHz (n270-v1)"
        case .core2duo_v1: return "Intel(R) Core(TM)2 Duo CPU T7700 @ 2.40GHz (core2duo-v1)"
        case .IvyBridge: return "IvyBridge"
        case .IvyBridge_IBRS: return "IvyBridge-IBRS"
        case .KnightsMill: return "KnightsMill"
        case .Nehalem: return "Nehalem"
        case .Nehalem_IBRS: return "Nehalem-IBRS"
        case .Opteron_G1: return "Opteron_G1"
        case .Opteron_G2: return "Opteron_G2"
        case .Opteron_G3: return "Opteron_G3"
        case .Opteron_G4: return "Opteron_G4"
        case .Opteron_G5: return "Opteron_G5"
        case .Penryn: return "Penryn"
        case .athlon_v1: return "QEMU Virtual CPU version 2.5+ (athlon-v1)"
        case .qemu32_v1: return "QEMU Virtual CPU version 2.5+ (qemu32-v1)"
        case .qemu64_v1: return "QEMU Virtual CPU version 2.5+ (qemu64-v1)"
        case .SandyBridge: return "SandyBridge"
        case .SandyBridge_IBRS: return "SandyBridge-IBRS"
        case .SapphireRapids: return "SapphireRapids"
        case .SierraForest: return "SierraForest"
        case .Skylake_Client: return "Skylake-Client"
        case .Skylake_Client_IBRS: return "Skylake-Client-IBRS"
        case .Skylake_Client_noTSX_IBRS: return "Skylake-Client-noTSX-IBRS"
        case .Skylake_Server: return "Skylake-Server"
        case .Skylake_Server_IBRS: return "Skylake-Server-IBRS"
        case .Skylake_Server_noTSX_IBRS: return "Skylake-Server-noTSX-IBRS"
        case .Snowridge: return "Snowridge"
        case .Westmere: return "Westmere"
        case .Westmere_v2: return "Westmere E56xx/L56xx/X56xx (IBRS update) (Westmere-v2)"
        case .Westmere_v1: return "Westmere E56xx/L56xx/X56xx (Nehalem-C) (Westmere-v1)"
        case .Westmere_IBRS: return "Westmere-IBRS"
        case .athlon: return "athlon"
        case .base: return "base CPU model type with no features enabled (base)"
        case .core2duo: return "core2duo"
        case .coreduo: return "coreduo"
        case .kvm32: return "kvm32"
        case .kvm64: return "kvm64"
        case .n270: return "n270"
        case .pentium: return "pentium"
        case .pentium_v1: return "pentium-v1"
        case .pentium2: return "pentium2"
        case .pentium2_v1: return "pentium2-v1"
        case .pentium3: return "pentium3"
        case .pentium3_v1: return "pentium3-v1"
        case .phenom: return "phenom"
        case .qemu32: return "qemu32"
        case .qemu64: return "qemu64"
        }
    }
}

enum QEMUCPU_loongarch64: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case la132
    case la464
    case max

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .la132: return "la132"
        case .la464: return "la464"
        case .max: return "max"
        }
    }
}

enum QEMUCPU_m68k: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case any
    case cfv4e
    case m5206
    case m5208
    case m68000
    case m68010
    case m68020
    case m68030
    case m68040
    case m68060

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .any: return "any"
        case .cfv4e: return "cfv4e"
        case .m5206: return "m5206"
        case .m5208: return "m5208"
        case .m68000: return "m68000"
        case .m68010: return "m68010"
        case .m68020: return "m68020"
        case .m68030: return "m68030"
        case .m68040: return "m68040"
        case .m68060: return "m68060"
        }
    }
}

enum QEMUCPU_microblaze: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case microblaze_cpu = "microblaze-cpu"

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .microblaze_cpu: return "microblaze-cpu"
        }
    }
}

enum QEMUCPU_microblazeel: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case microblaze_cpu = "microblaze-cpu"

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .microblaze_cpu: return "microblaze-cpu"
        }
    }
}

enum QEMUCPU_mips: String, CaseIterable, QEMUCPU {
    case _24KEc = "24KEc"
    case _24Kc = "24Kc"
    case _24Kf = "24Kf"
    case _34Kf = "34Kf"
    case _4KEc = "4KEc"
    case _4KEcR1 = "4KEcR1"
    case _4KEm = "4KEm"
    case _4KEmR1 = "4KEmR1"
    case _4Kc = "4Kc"
    case _4Km = "4Km"
    case _74Kf = "74Kf"
    case `default` = "default"
    case I7200
    case M14K
    case M14Kc
    case P5600
    case XBurstR1
    case XBurstR2
    case mips32r6_generic = "mips32r6-generic"

    var prettyValue: String {
        switch self {
        case ._24KEc: return "24KEc"
        case ._24Kc: return "24Kc"
        case ._24Kf: return "24Kf"
        case ._34Kf: return "34Kf"
        case ._4KEc: return "4KEc"
        case ._4KEcR1: return "4KEcR1"
        case ._4KEm: return "4KEm"
        case ._4KEmR1: return "4KEmR1"
        case ._4Kc: return "4Kc"
        case ._4Km: return "4Km"
        case ._74Kf: return "74Kf"
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .I7200: return "I7200"
        case .M14K: return "M14K"
        case .M14Kc: return "M14Kc"
        case .P5600: return "P5600"
        case .XBurstR1: return "XBurstR1"
        case .XBurstR2: return "XBurstR2"
        case .mips32r6_generic: return "mips32r6-generic"
        }
    }
}

enum QEMUCPU_mipsel: String, CaseIterable, QEMUCPU {
    case _24KEc = "24KEc"
    case _24Kc = "24Kc"
    case _24Kf = "24Kf"
    case _34Kf = "34Kf"
    case _4KEc = "4KEc"
    case _4KEcR1 = "4KEcR1"
    case _4KEm = "4KEm"
    case _4KEmR1 = "4KEmR1"
    case _4Kc = "4Kc"
    case _4Km = "4Km"
    case _74Kf = "74Kf"
    case `default` = "default"
    case I7200
    case M14K
    case M14Kc
    case P5600
    case XBurstR1
    case XBurstR2
    case mips32r6_generic = "mips32r6-generic"

    var prettyValue: String {
        switch self {
        case ._24KEc: return "24KEc"
        case ._24Kc: return "24Kc"
        case ._24Kf: return "24Kf"
        case ._34Kf: return "34Kf"
        case ._4KEc: return "4KEc"
        case ._4KEcR1: return "4KEcR1"
        case ._4KEm: return "4KEm"
        case ._4KEmR1: return "4KEmR1"
        case ._4Kc: return "4Kc"
        case ._4Km: return "4Km"
        case ._74Kf: return "74Kf"
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .I7200: return "I7200"
        case .M14K: return "M14K"
        case .M14Kc: return "M14Kc"
        case .P5600: return "P5600"
        case .XBurstR1: return "XBurstR1"
        case .XBurstR2: return "XBurstR2"
        case .mips32r6_generic: return "mips32r6-generic"
        }
    }
}

enum QEMUCPU_mips64: String, CaseIterable, QEMUCPU {
    case _20Kc = "20Kc"
    case _24KEc = "24KEc"
    case _24Kc = "24Kc"
    case _24Kf = "24Kf"
    case _34Kf = "34Kf"
    case _4KEc = "4KEc"
    case _4KEcR1 = "4KEcR1"
    case _4KEm = "4KEm"
    case _4KEmR1 = "4KEmR1"
    case _4Kc = "4Kc"
    case _4Km = "4Km"
    case _5KEc = "5KEc"
    case _5KEf = "5KEf"
    case _5Kc = "5Kc"
    case _5Kf = "5Kf"
    case _74Kf = "74Kf"
    case `default` = "default"
    case I6400
    case I6500
    case I7200
    case Loongson_2E = "Loongson-2E"
    case Loongson_2F = "Loongson-2F"
    case Loongson_3A1000 = "Loongson-3A1000"
    case Loongson_3A4000 = "Loongson-3A4000"
    case M14K
    case M14Kc
    case MIPS64R2_generic = "MIPS64R2-generic"
    case Octeon68XX
    case P5600
    case R4000
    case VR5432
    case XBurstR1
    case XBurstR2
    case mips32r6_generic = "mips32r6-generic"
    case mips64dspr2

    var prettyValue: String {
        switch self {
        case ._20Kc: return "20Kc"
        case ._24KEc: return "24KEc"
        case ._24Kc: return "24Kc"
        case ._24Kf: return "24Kf"
        case ._34Kf: return "34Kf"
        case ._4KEc: return "4KEc"
        case ._4KEcR1: return "4KEcR1"
        case ._4KEm: return "4KEm"
        case ._4KEmR1: return "4KEmR1"
        case ._4Kc: return "4Kc"
        case ._4Km: return "4Km"
        case ._5KEc: return "5KEc"
        case ._5KEf: return "5KEf"
        case ._5Kc: return "5Kc"
        case ._5Kf: return "5Kf"
        case ._74Kf: return "74Kf"
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .I6400: return "I6400"
        case .I6500: return "I6500"
        case .I7200: return "I7200"
        case .Loongson_2E: return "Loongson-2E"
        case .Loongson_2F: return "Loongson-2F"
        case .Loongson_3A1000: return "Loongson-3A1000"
        case .Loongson_3A4000: return "Loongson-3A4000"
        case .M14K: return "M14K"
        case .M14Kc: return "M14Kc"
        case .MIPS64R2_generic: return "MIPS64R2-generic"
        case .Octeon68XX: return "Octeon68XX"
        case .P5600: return "P5600"
        case .R4000: return "R4000"
        case .VR5432: return "VR5432"
        case .XBurstR1: return "XBurstR1"
        case .XBurstR2: return "XBurstR2"
        case .mips32r6_generic: return "mips32r6-generic"
        case .mips64dspr2: return "mips64dspr2"
        }
    }
}

enum QEMUCPU_mips64el: String, CaseIterable, QEMUCPU {
    case _20Kc = "20Kc"
    case _24KEc = "24KEc"
    case _24Kc = "24Kc"
    case _24Kf = "24Kf"
    case _34Kf = "34Kf"
    case _4KEc = "4KEc"
    case _4KEcR1 = "4KEcR1"
    case _4KEm = "4KEm"
    case _4KEmR1 = "4KEmR1"
    case _4Kc = "4Kc"
    case _4Km = "4Km"
    case _5KEc = "5KEc"
    case _5KEf = "5KEf"
    case _5Kc = "5Kc"
    case _5Kf = "5Kf"
    case _74Kf = "74Kf"
    case `default` = "default"
    case I6400
    case I6500
    case I7200
    case Loongson_2E = "Loongson-2E"
    case Loongson_2F = "Loongson-2F"
    case Loongson_3A1000 = "Loongson-3A1000"
    case Loongson_3A4000 = "Loongson-3A4000"
    case M14K
    case M14Kc
    case MIPS64R2_generic = "MIPS64R2-generic"
    case Octeon68XX
    case P5600
    case R4000
    case VR5432
    case XBurstR1
    case XBurstR2
    case mips32r6_generic = "mips32r6-generic"
    case mips64dspr2

    var prettyValue: String {
        switch self {
        case ._20Kc: return "20Kc"
        case ._24KEc: return "24KEc"
        case ._24Kc: return "24Kc"
        case ._24Kf: return "24Kf"
        case ._34Kf: return "34Kf"
        case ._4KEc: return "4KEc"
        case ._4KEcR1: return "4KEcR1"
        case ._4KEm: return "4KEm"
        case ._4KEmR1: return "4KEmR1"
        case ._4Kc: return "4Kc"
        case ._4Km: return "4Km"
        case ._5KEc: return "5KEc"
        case ._5KEf: return "5KEf"
        case ._5Kc: return "5Kc"
        case ._5Kf: return "5Kf"
        case ._74Kf: return "74Kf"
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .I6400: return "I6400"
        case .I6500: return "I6500"
        case .I7200: return "I7200"
        case .Loongson_2E: return "Loongson-2E"
        case .Loongson_2F: return "Loongson-2F"
        case .Loongson_3A1000: return "Loongson-3A1000"
        case .Loongson_3A4000: return "Loongson-3A4000"
        case .M14K: return "M14K"
        case .M14Kc: return "M14Kc"
        case .MIPS64R2_generic: return "MIPS64R2-generic"
        case .Octeon68XX: return "Octeon68XX"
        case .P5600: return "P5600"
        case .R4000: return "R4000"
        case .VR5432: return "VR5432"
        case .XBurstR1: return "XBurstR1"
        case .XBurstR2: return "XBurstR2"
        case .mips32r6_generic: return "mips32r6-generic"
        case .mips64dspr2: return "mips64dspr2"
        }
    }
}

enum QEMUCPU_or1k: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case any
    case or1200

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .any: return "any"
        case .or1200: return "or1200"
        }
    }
}

enum QEMUCPU_ppc: String, CaseIterable, QEMUCPU {
    case _405 = "405"
    case _405cr = "405cr"
    case _405gp = "405gp"
    case _405gpe = "405gpe"
    case _440ep = "440ep"
    case _460ex = "460ex"
    case _603e = "603e"
    case _603r = "603r"
    case _604e = "604e"
    case _740 = "740"
    case _7400 = "7400"
    case _7410 = "7410"
    case _7441 = "7441"
    case _7445 = "7445"
    case _7447 = "7447"
    case _7447a = "7447a"
    case _7448 = "7448"
    case _745 = "745"
    case _7450 = "7450"
    case _7451 = "7451"
    case _7455 = "7455"
    case _7457 = "7457"
    case _7457a = "7457a"
    case _750 = "750"
    case _750cl = "750cl"
    case _750cx = "750cx"
    case _750cxe = "750cxe"
    case _750fx = "750fx"
    case _750gx = "750gx"
    case _750l = "750l"
    case _755 = "755"
    case `default` = "default"
    case _603 = "603"
    case _604 = "604"
    case _603e_v1_1 = "603e_v1.1"
    case _603e_v1_2 = "603e_v1.2"
    case _603e_v1_3 = "603e_v1.3"
    case _603e_v1_4 = "603e_v1.4"
    case _603e_v2_2 = "603e_v2.2"
    case _603e_v3 = "603e_v3"
    case _603e_v4 = "603e_v4"
    case _603e_v4_1 = "603e_v4.1"
    case _603p = "603p"
    case _603e7v = "603e7v"
    case _603e7v1 = "603e7v1"
    case _603e7 = "603e7"
    case _603e7v2 = "603e7v2"
    case _603e7t = "603e7t"
    case _740_v1_0 = "740_v1.0"
    case _740e = "740e"
    case _750_v1_0 = "750_v1.0"
    case _740_v2_0 = "740_v2.0"
    case _750_v2_0 = "750_v2.0"
    case _750e = "750e"
    case _740_v2_1 = "740_v2.1"
    case _750_v2_1 = "750_v2.1"
    case _740_v2_2 = "740_v2.2"
    case _750_v2_2 = "750_v2.2"
    case _740_v3_0 = "740_v3.0"
    case _750_v3_0 = "750_v3.0"
    case _740_v3_1 = "740_v3.1"
    case _750_v3_1 = "750_v3.1"
    case _750cx_v1_0 = "750cx_v1.0"
    case _750cx_v2_0 = "750cx_v2.0"
    case _750cx_v2_1 = "750cx_v2.1"
    case _750cx_v2_2 = "750cx_v2.2"
    case _750cxe_v2_1 = "750cxe_v2.1"
    case _750cxe_v2_2 = "750cxe_v2.2"
    case _750cxe_v2_3 = "750cxe_v2.3"
    case _750cxe_v2_4 = "750cxe_v2.4"
    case _750cxe_v3_0 = "750cxe_v3.0"
    case _750cxe_v3_1 = "750cxe_v3.1"
    case _745_v1_0 = "745_v1.0"
    case _755_v1_0 = "755_v1.0"
    case _745_v1_1 = "745_v1.1"
    case _755_v1_1 = "755_v1.1"
    case _745_v2_0 = "745_v2.0"
    case _755_v2_0 = "755_v2.0"
    case _745_v2_1 = "745_v2.1"
    case _755_v2_1 = "755_v2.1"
    case _745_v2_2 = "745_v2.2"
    case _755_v2_2 = "755_v2.2"
    case _745_v2_3 = "745_v2.3"
    case _755_v2_3 = "755_v2.3"
    case _745_v2_4 = "745_v2.4"
    case _755_v2_4 = "755_v2.4"
    case _745_v2_5 = "745_v2.5"
    case _755_v2_5 = "755_v2.5"
    case _745_v2_6 = "745_v2.6"
    case _755_v2_6 = "755_v2.6"
    case _745_v2_7 = "745_v2.7"
    case _755_v2_7 = "755_v2.7"
    case _745_v2_8 = "745_v2.8"
    case _755_v2_8 = "755_v2.8"
    case _750cxe_v2_4b = "750cxe_v2.4b"
    case _750cxe_v3_1b = "750cxe_v3.1b"
    case _750cxr = "750cxr"
    case _750cl_v1_0 = "750cl_v1.0"
    case _750cl_v2_0 = "750cl_v2.0"
    case _750l_v2_0 = "750l_v2.0"
    case _750l_v2_1 = "750l_v2.1"
    case _750l_v2_2 = "750l_v2.2"
    case _750l_v3_0 = "750l_v3.0"
    case _750l_v3_2 = "750l_v3.2"
    case _604e_v1_0 = "604e_v1.0"
    case _604e_v2_2 = "604e_v2.2"
    case _604e_v2_4 = "604e_v2.4"
    case _604r = "604r"
    case _7400_v1_0 = "7400_v1.0"
    case _7400_v1_1 = "7400_v1.1"
    case _7400_v2_0 = "7400_v2.0"
    case _7400_v2_1 = "7400_v2.1"
    case _7400_v2_2 = "7400_v2.2"
    case _7400_v2_6 = "7400_v2.6"
    case _7400_v2_7 = "7400_v2.7"
    case _7400_v2_8 = "7400_v2.8"
    case _7400_v2_9 = "7400_v2.9"
    case g2
    case mpc603
    case g2hip3
    case e300c1
    case mpc8343
    case mpc8343a
    case mpc8343e
    case mpc8343ea
    case mpc8347ap
    case mpc8347at
    case mpc8347eap
    case mpc8347eat
    case mpc8347ep
    case mpc8347et
    case mpc8347p
    case mpc8347t
    case mpc8349
    case mpc8349a
    case mpc8349e
    case mpc8349ea
    case e300c2
    case e300c3
    case e300c4
    case mpc8377
    case mpc8377e
    case mpc8378
    case mpc8378e
    case mpc8379
    case mpc8379e
    case _740p = "740p"
    case _750p = "750p"
    case _460exb = "460exb"
    case _440epx = "440epx"
    case _405d2 = "405d2"
    case x2vp4
    case x2vp20
    case _405gpa = "405gpa"
    case _405gpb = "405gpb"
    case _405cra = "405cra"
    case _405gpc = "405gpc"
    case _405gpd = "405gpd"
    case _405crb = "405crb"
    case _405crc = "405crc"
    case stb03
    case npe4gs3
    case npe405h
    case npe405h2
    case _405ez = "405ez"
    case npe405l
    case _405d4 = "405d4"
    case stb04
    case _405lp = "405lp"
    case _440epa = "440epa"
    case _440epb = "440epb"
    case _405gpr = "405gpr"
    case _405ep = "405ep"
    case stb25
    case _750fx_v1_0 = "750fx_v1.0"
    case _750fx_v2_0 = "750fx_v2.0"
    case _750fx_v2_1 = "750fx_v2.1"
    case _750fx_v2_2 = "750fx_v2.2"
    case _750fl = "750fl"
    case _750fx_v2_3 = "750fx_v2.3"
    case _750gx_v1_0 = "750gx_v1.0"
    case _750gx_v1_1 = "750gx_v1.1"
    case _750gl = "750gl"
    case _750gx_v1_2 = "750gx_v1.2"
    case _440_xilinx = "440-xilinx"
    case _440_xilinx_w_dfpu = "440-xilinx-w-dfpu"
    case _7450_v1_0 = "7450_v1.0"
    case _7450_v1_1 = "7450_v1.1"
    case _7450_v1_2 = "7450_v1.2"
    case _7450_v2_0 = "7450_v2.0"
    case _7441_v2_1 = "7441_v2.1"
    case _7450_v2_1 = "7450_v2.1"
    case _7441_v2_3 = "7441_v2.3"
    case _7451_v2_3 = "7451_v2.3"
    case _7441_v2_10 = "7441_v2.10"
    case _7451_v2_10 = "7451_v2.10"
    case _7445_v1_0 = "7445_v1.0"
    case _7455_v1_0 = "7455_v1.0"
    case _7445_v2_1 = "7445_v2.1"
    case _7455_v2_1 = "7455_v2.1"
    case _7445_v3_2 = "7445_v3.2"
    case _7455_v3_2 = "7455_v3.2"
    case _7445_v3_3 = "7445_v3.3"
    case _7455_v3_3 = "7455_v3.3"
    case _7445_v3_4 = "7445_v3.4"
    case _7455_v3_4 = "7455_v3.4"
    case _7447_v1_0 = "7447_v1.0"
    case _7457_v1_0 = "7457_v1.0"
    case _7447_v1_1 = "7447_v1.1"
    case _7457_v1_1 = "7457_v1.1"
    case _7457_v1_2 = "7457_v1.2"
    case _7447a_v1_0 = "7447a_v1.0"
    case _7457a_v1_0 = "7457a_v1.0"
    case _7447a_v1_1 = "7447a_v1.1"
    case _7457a_v1_1 = "7457a_v1.1"
    case _7447a_v1_2 = "7447a_v1.2"
    case _7457a_v1_2 = "7457a_v1.2"
    case e600
    case mpc8610
    case mpc8641
    case mpc8641d
    case _7448_v1_0 = "7448_v1.0"
    case _7448_v1_1 = "7448_v1.1"
    case _7448_v2_0 = "7448_v2.0"
    case _7448_v2_1 = "7448_v2.1"
    case _7410_v1_0 = "7410_v1.0"
    case _7410_v1_1 = "7410_v1.1"
    case _7410_v1_2 = "7410_v1.2"
    case _7410_v1_3 = "7410_v1.3"
    case _7410_v1_4 = "7410_v1.4"
    case e500_v10
    case mpc8540_v10
    case mpc8560_v10
    case e500_v20
    case mpc8540_v20
    case mpc8540_v21
    case mpc8541_v10
    case mpc8541_v11
    case mpc8541e_v10
    case mpc8541e_v11
    case mpc8555_v10
    case mpc8555_v11
    case mpc8555e_v10
    case mpc8555e_v11
    case mpc8560_v20
    case mpc8560_v21
    case e500v2_v10
    case mpc8543_v10
    case mpc8543e_v10
    case mpc8548_v10
    case mpc8548e_v10
    case mpc8543_v11
    case mpc8543e_v11
    case mpc8548_v11
    case mpc8548e_v11
    case e500v2_v20
    case mpc8543_v20
    case mpc8543e_v20
    case mpc8545_v20
    case mpc8545e_v20
    case mpc8547e_v20
    case mpc8548_v20
    case mpc8548e_v20
    case e500v2_v21
    case mpc8533_v10
    case mpc8533e_v10
    case mpc8543_v21
    case mpc8543e_v21
    case mpc8544_v10
    case mpc8544e_v10
    case mpc8545_v21
    case mpc8545e_v21
    case mpc8547e_v21
    case mpc8548_v21
    case mpc8548e_v21
    case e500v2_v22
    case mpc8533_v11
    case mpc8533e_v11
    case mpc8544_v11
    case mpc8544e_v11
    case mpc8567
    case mpc8567e
    case mpc8568
    case mpc8568e
    case e500v2_v30
    case mpc8572
    case mpc8572e
    case e500mc
    case g2h4
    case g2hip4
    case g2le
    case g2gp
    case g2legp
    case g2legp1
    case mpc5200_v10
    case mpc5200_v11
    case mpc5200_v12
    case mpc5200b_v20
    case mpc5200b_v21
    case g2legp3
    case e200z5
    case e200z6
    case g2ls
    case g2lels
    case apollo6
    case apollo7
    case apollo7pm
    case arthur
    case conan_doyle = "conan/doyle"
    case e200
    case e300
    case e500
    case e500v1
    case e500v2
    case g3
    case g4
    case goldeneye
    case goldfinger
    case lonestar
    case mach5
    case mpc5200
    case mpc5200b
    case mpc52xx
    case mpc8240
    case mpc8241
    case mpc8245
    case mpc8247
    case mpc8248
    case mpc8250
    case mpc8250_hip3
    case mpc8250_hip4
    case mpc8255
    case mpc8255_hip3
    case mpc8255_hip4
    case mpc8260
    case mpc8260_hip3
    case mpc8260_hip4
    case mpc8264
    case mpc8264_hip3
    case mpc8264_hip4
    case mpc8265
    case mpc8265_hip3
    case mpc8265_hip4
    case mpc8266
    case mpc8266_hip3
    case mpc8266_hip4
    case mpc8270
    case mpc8271
    case mpc8272
    case mpc8275
    case mpc8280
    case mpc82xx
    case mpc8347
    case mpc8347a
    case mpc8347e
    case mpc8347ea
    case mpc8533
    case mpc8533e
    case mpc8540
    case mpc8541
    case mpc8541e
    case mpc8543
    case mpc8543e
    case mpc8544
    case mpc8544e
    case mpc8545
    case mpc8545e
    case mpc8547e
    case mpc8548
    case mpc8548e
    case mpc8555
    case mpc8555e
    case mpc8560
    case nitro
    case powerquicc_ii = "powerquicc-ii"
    case ppc
    case ppc32
    case sirocco
    case stretch
    case typhoon
    case vaillant
    case vanilla
    case vger
    case x2vp50
    case x2vp7

    var prettyValue: String {
        switch self {
        case ._405: return "405"
        case ._405cr: return "405cr"
        case ._405gp: return "405gp"
        case ._405gpe: return "405gpe"
        case ._440ep: return "440ep"
        case ._460ex: return "460ex"
        case ._603e: return "603e"
        case ._603r: return "603r"
        case ._604e: return "604e"
        case ._740: return "740"
        case ._7400: return "7400"
        case ._7410: return "7410"
        case ._7441: return "7441"
        case ._7445: return "7445"
        case ._7447: return "7447"
        case ._7447a: return "7447a"
        case ._7448: return "7448"
        case ._745: return "745"
        case ._7450: return "7450"
        case ._7451: return "7451"
        case ._7455: return "7455"
        case ._7457: return "7457"
        case ._7457a: return "7457a"
        case ._750: return "750"
        case ._750cl: return "750cl"
        case ._750cx: return "750cx"
        case ._750cxe: return "750cxe"
        case ._750fx: return "750fx"
        case ._750gx: return "750gx"
        case ._750l: return "750l"
        case ._755: return "755"
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case ._603: return "PVR 00030100 (603)"
        case ._604: return "PVR 00040103 (604)"
        case ._603e_v1_1: return "PVR 00060101 (603e_v1.1)"
        case ._603e_v1_2: return "PVR 00060102 (603e_v1.2)"
        case ._603e_v1_3: return "PVR 00060103 (603e_v1.3)"
        case ._603e_v1_4: return "PVR 00060104 (603e_v1.4)"
        case ._603e_v2_2: return "PVR 00060202 (603e_v2.2)"
        case ._603e_v3: return "PVR 00060300 (603e_v3)"
        case ._603e_v4: return "PVR 00060400 (603e_v4)"
        case ._603e_v4_1: return "PVR 00060401 (603e_v4.1)"
        case ._603p: return "PVR 00070000 (603p)"
        case ._603e7v: return "PVR 00070100 (603e7v)"
        case ._603e7v1: return "PVR 00070101 (603e7v1)"
        case ._603e7: return "PVR 00070200 (603e7)"
        case ._603e7v2: return "PVR 00070201 (603e7v2)"
        case ._603e7t: return "PVR 00071201 (603e7t)"
        case ._740_v1_0: return "PVR 00080100 (740_v1.0)"
        case ._740e: return "PVR 00080100 (740e)"
        case ._750_v1_0: return "PVR 00080100 (750_v1.0)"
        case ._740_v2_0: return "PVR 00080200 (740_v2.0)"
        case ._750_v2_0: return "PVR 00080200 (750_v2.0)"
        case ._750e: return "PVR 00080200 (750e)"
        case ._740_v2_1: return "PVR 00080201 (740_v2.1)"
        case ._750_v2_1: return "PVR 00080201 (750_v2.1)"
        case ._740_v2_2: return "PVR 00080202 (740_v2.2)"
        case ._750_v2_2: return "PVR 00080202 (750_v2.2)"
        case ._740_v3_0: return "PVR 00080300 (740_v3.0)"
        case ._750_v3_0: return "PVR 00080300 (750_v3.0)"
        case ._740_v3_1: return "PVR 00080301 (740_v3.1)"
        case ._750_v3_1: return "PVR 00080301 (750_v3.1)"
        case ._750cx_v1_0: return "PVR 00082100 (750cx_v1.0)"
        case ._750cx_v2_0: return "PVR 00082200 (750cx_v2.0)"
        case ._750cx_v2_1: return "PVR 00082201 (750cx_v2.1)"
        case ._750cx_v2_2: return "PVR 00082202 (750cx_v2.2)"
        case ._750cxe_v2_1: return "PVR 00082211 (750cxe_v2.1)"
        case ._750cxe_v2_2: return "PVR 00082212 (750cxe_v2.2)"
        case ._750cxe_v2_3: return "PVR 00082213 (750cxe_v2.3)"
        case ._750cxe_v2_4: return "PVR 00082214 (750cxe_v2.4)"
        case ._750cxe_v3_0: return "PVR 00082310 (750cxe_v3.0)"
        case ._750cxe_v3_1: return "PVR 00082311 (750cxe_v3.1)"
        case ._745_v1_0: return "PVR 00083100 (745_v1.0)"
        case ._755_v1_0: return "PVR 00083100 (755_v1.0)"
        case ._745_v1_1: return "PVR 00083101 (745_v1.1)"
        case ._755_v1_1: return "PVR 00083101 (755_v1.1)"
        case ._745_v2_0: return "PVR 00083200 (745_v2.0)"
        case ._755_v2_0: return "PVR 00083200 (755_v2.0)"
        case ._745_v2_1: return "PVR 00083201 (745_v2.1)"
        case ._755_v2_1: return "PVR 00083201 (755_v2.1)"
        case ._745_v2_2: return "PVR 00083202 (745_v2.2)"
        case ._755_v2_2: return "PVR 00083202 (755_v2.2)"
        case ._745_v2_3: return "PVR 00083203 (745_v2.3)"
        case ._755_v2_3: return "PVR 00083203 (755_v2.3)"
        case ._745_v2_4: return "PVR 00083204 (745_v2.4)"
        case ._755_v2_4: return "PVR 00083204 (755_v2.4)"
        case ._745_v2_5: return "PVR 00083205 (745_v2.5)"
        case ._755_v2_5: return "PVR 00083205 (755_v2.5)"
        case ._745_v2_6: return "PVR 00083206 (745_v2.6)"
        case ._755_v2_6: return "PVR 00083206 (755_v2.6)"
        case ._745_v2_7: return "PVR 00083207 (745_v2.7)"
        case ._755_v2_7: return "PVR 00083207 (755_v2.7)"
        case ._745_v2_8: return "PVR 00083208 (745_v2.8)"
        case ._755_v2_8: return "PVR 00083208 (755_v2.8)"
        case ._750cxe_v2_4b: return "PVR 00083214 (750cxe_v2.4b)"
        case ._750cxe_v3_1b: return "PVR 00083311 (750cxe_v3.1b)"
        case ._750cxr: return "PVR 00083410 (750cxr)"
        case ._750cl_v1_0: return "PVR 00087200 (750cl_v1.0)"
        case ._750cl_v2_0: return "PVR 00087210 (750cl_v2.0)"
        case ._750l_v2_0: return "PVR 00088200 (750l_v2.0)"
        case ._750l_v2_1: return "PVR 00088201 (750l_v2.1)"
        case ._750l_v2_2: return "PVR 00088202 (750l_v2.2)"
        case ._750l_v3_0: return "PVR 00088300 (750l_v3.0)"
        case ._750l_v3_2: return "PVR 00088302 (750l_v3.2)"
        case ._604e_v1_0: return "PVR 00090100 (604e_v1.0)"
        case ._604e_v2_2: return "PVR 00090202 (604e_v2.2)"
        case ._604e_v2_4: return "PVR 00090204 (604e_v2.4)"
        case ._604r: return "PVR 000a0101 (604r)"
        case ._7400_v1_0: return "PVR 000c0100 (7400_v1.0)"
        case ._7400_v1_1: return "PVR 000c0101 (7400_v1.1)"
        case ._7400_v2_0: return "PVR 000c0200 (7400_v2.0)"
        case ._7400_v2_1: return "PVR 000c0201 (7400_v2.1)"
        case ._7400_v2_2: return "PVR 000c0202 (7400_v2.2)"
        case ._7400_v2_6: return "PVR 000c0206 (7400_v2.6)"
        case ._7400_v2_7: return "PVR 000c0207 (7400_v2.7)"
        case ._7400_v2_8: return "PVR 000c0208 (7400_v2.8)"
        case ._7400_v2_9: return "PVR 000c0209 (7400_v2.9)"
        case .g2: return "PVR 00810011 (g2)"
        case .mpc603: return "PVR 00810100 (mpc603)"
        case .g2hip3: return "PVR 00810101 (g2hip3)"
        case .e300c1: return "PVR 00830010 (e300c1)"
        case .mpc8343: return "PVR 00830010 (mpc8343)"
        case .mpc8343a: return "PVR 00830010 (mpc8343a)"
        case .mpc8343e: return "PVR 00830010 (mpc8343e)"
        case .mpc8343ea: return "PVR 00830010 (mpc8343ea)"
        case .mpc8347ap: return "PVR 00830010 (mpc8347ap)"
        case .mpc8347at: return "PVR 00830010 (mpc8347at)"
        case .mpc8347eap: return "PVR 00830010 (mpc8347eap)"
        case .mpc8347eat: return "PVR 00830010 (mpc8347eat)"
        case .mpc8347ep: return "PVR 00830010 (mpc8347ep)"
        case .mpc8347et: return "PVR 00830010 (mpc8347et)"
        case .mpc8347p: return "PVR 00830010 (mpc8347p)"
        case .mpc8347t: return "PVR 00830010 (mpc8347t)"
        case .mpc8349: return "PVR 00830010 (mpc8349)"
        case .mpc8349a: return "PVR 00830010 (mpc8349a)"
        case .mpc8349e: return "PVR 00830010 (mpc8349e)"
        case .mpc8349ea: return "PVR 00830010 (mpc8349ea)"
        case .e300c2: return "PVR 00840010 (e300c2)"
        case .e300c3: return "PVR 00850010 (e300c3)"
        case .e300c4: return "PVR 00860010 (e300c4)"
        case .mpc8377: return "PVR 00860010 (mpc8377)"
        case .mpc8377e: return "PVR 00860010 (mpc8377e)"
        case .mpc8378: return "PVR 00860010 (mpc8378)"
        case .mpc8378e: return "PVR 00860010 (mpc8378e)"
        case .mpc8379: return "PVR 00860010 (mpc8379)"
        case .mpc8379e: return "PVR 00860010 (mpc8379e)"
        case ._740p: return "PVR 10080000 (740p)"
        case ._750p: return "PVR 10080000 (750p)"
        case ._460exb: return "PVR 130218a4 (460exb)"
        case ._440epx: return "PVR 200008d0 (440epx)"
        case ._405d2: return "PVR 20010000 (405d2)"
        case .x2vp4: return "PVR 20010820 (x2vp4)"
        case .x2vp20: return "PVR 20010860 (x2vp20)"
        case ._405gpa: return "PVR 40110000 (405gpa)"
        case ._405gpb: return "PVR 40110040 (405gpb)"
        case ._405cra: return "PVR 40110041 (405cra)"
        case ._405gpc: return "PVR 40110082 (405gpc)"
        case ._405gpd: return "PVR 401100c4 (405gpd)"
        case ._405crb: return "PVR 401100c5 (405crb)"
        case ._405crc: return "PVR 40110145 (405crc)"
        case .stb03: return "PVR 40310000 (stb03)"
        case .npe4gs3: return "PVR 40b10000 (npe4gs3)"
        case .npe405h: return "PVR 414100c0 (npe405h)"
        case .npe405h2: return "PVR 41410140 (npe405h2)"
        case ._405ez: return "PVR 41511460 (405ez)"
        case .npe405l: return "PVR 416100c0 (npe405l)"
        case ._405d4: return "PVR 41810000 (405d4)"
        case .stb04: return "PVR 41810000 (stb04)"
        case ._405lp: return "PVR 41f10000 (405lp)"
        case ._440epa: return "PVR 42221850 (440epa)"
        case ._440epb: return "PVR 422218d3 (440epb)"
        case ._405gpr: return "PVR 50910951 (405gpr)"
        case ._405ep: return "PVR 51210950 (405ep)"
        case .stb25: return "PVR 51510950 (stb25)"
        case ._750fx_v1_0: return "PVR 70000100 (750fx_v1.0)"
        case ._750fx_v2_0: return "PVR 70000200 (750fx_v2.0)"
        case ._750fx_v2_1: return "PVR 70000201 (750fx_v2.1)"
        case ._750fx_v2_2: return "PVR 70000202 (750fx_v2.2)"
        case ._750fl: return "PVR 70000203 (750fl)"
        case ._750fx_v2_3: return "PVR 70000203 (750fx_v2.3)"
        case ._750gx_v1_0: return "PVR 70020100 (750gx_v1.0)"
        case ._750gx_v1_1: return "PVR 70020101 (750gx_v1.1)"
        case ._750gl: return "PVR 70020102 (750gl)"
        case ._750gx_v1_2: return "PVR 70020102 (750gx_v1.2)"
        case ._440_xilinx: return "PVR 7ff21910 (440-xilinx)"
        case ._440_xilinx_w_dfpu: return "PVR 7ff21910 (440-xilinx-w-dfpu)"
        case ._7450_v1_0: return "PVR 80000100 (7450_v1.0)"
        case ._7450_v1_1: return "PVR 80000101 (7450_v1.1)"
        case ._7450_v1_2: return "PVR 80000102 (7450_v1.2)"
        case ._7450_v2_0: return "PVR 80000200 (7450_v2.0)"
        case ._7441_v2_1: return "PVR 80000201 (7441_v2.1)"
        case ._7450_v2_1: return "PVR 80000201 (7450_v2.1)"
        case ._7441_v2_3: return "PVR 80000203 (7441_v2.3)"
        case ._7451_v2_3: return "PVR 80000203 (7451_v2.3)"
        case ._7441_v2_10: return "PVR 80000210 (7441_v2.10)"
        case ._7451_v2_10: return "PVR 80000210 (7451_v2.10)"
        case ._7445_v1_0: return "PVR 80010100 (7445_v1.0)"
        case ._7455_v1_0: return "PVR 80010100 (7455_v1.0)"
        case ._7445_v2_1: return "PVR 80010201 (7445_v2.1)"
        case ._7455_v2_1: return "PVR 80010201 (7455_v2.1)"
        case ._7445_v3_2: return "PVR 80010302 (7445_v3.2)"
        case ._7455_v3_2: return "PVR 80010302 (7455_v3.2)"
        case ._7445_v3_3: return "PVR 80010303 (7445_v3.3)"
        case ._7455_v3_3: return "PVR 80010303 (7455_v3.3)"
        case ._7445_v3_4: return "PVR 80010304 (7445_v3.4)"
        case ._7455_v3_4: return "PVR 80010304 (7455_v3.4)"
        case ._7447_v1_0: return "PVR 80020100 (7447_v1.0)"
        case ._7457_v1_0: return "PVR 80020100 (7457_v1.0)"
        case ._7447_v1_1: return "PVR 80020101 (7447_v1.1)"
        case ._7457_v1_1: return "PVR 80020101 (7457_v1.1)"
        case ._7457_v1_2: return "PVR 80020102 (7457_v1.2)"
        case ._7447a_v1_0: return "PVR 80030100 (7447a_v1.0)"
        case ._7457a_v1_0: return "PVR 80030100 (7457a_v1.0)"
        case ._7447a_v1_1: return "PVR 80030101 (7447a_v1.1)"
        case ._7457a_v1_1: return "PVR 80030101 (7457a_v1.1)"
        case ._7447a_v1_2: return "PVR 80030102 (7447a_v1.2)"
        case ._7457a_v1_2: return "PVR 80030102 (7457a_v1.2)"
        case .e600: return "PVR 80040010 (e600)"
        case .mpc8610: return "PVR 80040010 (mpc8610)"
        case .mpc8641: return "PVR 80040010 (mpc8641)"
        case .mpc8641d: return "PVR 80040010 (mpc8641d)"
        case ._7448_v1_0: return "PVR 80040100 (7448_v1.0)"
        case ._7448_v1_1: return "PVR 80040101 (7448_v1.1)"
        case ._7448_v2_0: return "PVR 80040200 (7448_v2.0)"
        case ._7448_v2_1: return "PVR 80040201 (7448_v2.1)"
        case ._7410_v1_0: return "PVR 800c1100 (7410_v1.0)"
        case ._7410_v1_1: return "PVR 800c1101 (7410_v1.1)"
        case ._7410_v1_2: return "PVR 800c1102 (7410_v1.2)"
        case ._7410_v1_3: return "PVR 800c1103 (7410_v1.3)"
        case ._7410_v1_4: return "PVR 800c1104 (7410_v1.4)"
        case .e500_v10: return "PVR 80200010 (e500_v10)"
        case .mpc8540_v10: return "PVR 80200010 (mpc8540_v10)"
        case .mpc8560_v10: return "PVR 80200010 (mpc8560_v10)"
        case .e500_v20: return "PVR 80200020 (e500_v20)"
        case .mpc8540_v20: return "PVR 80200020 (mpc8540_v20)"
        case .mpc8540_v21: return "PVR 80200020 (mpc8540_v21)"
        case .mpc8541_v10: return "PVR 80200020 (mpc8541_v10)"
        case .mpc8541_v11: return "PVR 80200020 (mpc8541_v11)"
        case .mpc8541e_v10: return "PVR 80200020 (mpc8541e_v10)"
        case .mpc8541e_v11: return "PVR 80200020 (mpc8541e_v11)"
        case .mpc8555_v10: return "PVR 80200020 (mpc8555_v10)"
        case .mpc8555_v11: return "PVR 80200020 (mpc8555_v11)"
        case .mpc8555e_v10: return "PVR 80200020 (mpc8555e_v10)"
        case .mpc8555e_v11: return "PVR 80200020 (mpc8555e_v11)"
        case .mpc8560_v20: return "PVR 80200020 (mpc8560_v20)"
        case .mpc8560_v21: return "PVR 80200020 (mpc8560_v21)"
        case .e500v2_v10: return "PVR 80210010 (e500v2_v10)"
        case .mpc8543_v10: return "PVR 80210010 (mpc8543_v10)"
        case .mpc8543e_v10: return "PVR 80210010 (mpc8543e_v10)"
        case .mpc8548_v10: return "PVR 80210010 (mpc8548_v10)"
        case .mpc8548e_v10: return "PVR 80210010 (mpc8548e_v10)"
        case .mpc8543_v11: return "PVR 80210011 (mpc8543_v11)"
        case .mpc8543e_v11: return "PVR 80210011 (mpc8543e_v11)"
        case .mpc8548_v11: return "PVR 80210011 (mpc8548_v11)"
        case .mpc8548e_v11: return "PVR 80210011 (mpc8548e_v11)"
        case .e500v2_v20: return "PVR 80210020 (e500v2_v20)"
        case .mpc8543_v20: return "PVR 80210020 (mpc8543_v20)"
        case .mpc8543e_v20: return "PVR 80210020 (mpc8543e_v20)"
        case .mpc8545_v20: return "PVR 80210020 (mpc8545_v20)"
        case .mpc8545e_v20: return "PVR 80210020 (mpc8545e_v20)"
        case .mpc8547e_v20: return "PVR 80210020 (mpc8547e_v20)"
        case .mpc8548_v20: return "PVR 80210020 (mpc8548_v20)"
        case .mpc8548e_v20: return "PVR 80210020 (mpc8548e_v20)"
        case .e500v2_v21: return "PVR 80210021 (e500v2_v21)"
        case .mpc8533_v10: return "PVR 80210021 (mpc8533_v10)"
        case .mpc8533e_v10: return "PVR 80210021 (mpc8533e_v10)"
        case .mpc8543_v21: return "PVR 80210021 (mpc8543_v21)"
        case .mpc8543e_v21: return "PVR 80210021 (mpc8543e_v21)"
        case .mpc8544_v10: return "PVR 80210021 (mpc8544_v10)"
        case .mpc8544e_v10: return "PVR 80210021 (mpc8544e_v10)"
        case .mpc8545_v21: return "PVR 80210021 (mpc8545_v21)"
        case .mpc8545e_v21: return "PVR 80210021 (mpc8545e_v21)"
        case .mpc8547e_v21: return "PVR 80210021 (mpc8547e_v21)"
        case .mpc8548_v21: return "PVR 80210021 (mpc8548_v21)"
        case .mpc8548e_v21: return "PVR 80210021 (mpc8548e_v21)"
        case .e500v2_v22: return "PVR 80210022 (e500v2_v22)"
        case .mpc8533_v11: return "PVR 80210022 (mpc8533_v11)"
        case .mpc8533e_v11: return "PVR 80210022 (mpc8533e_v11)"
        case .mpc8544_v11: return "PVR 80210022 (mpc8544_v11)"
        case .mpc8544e_v11: return "PVR 80210022 (mpc8544e_v11)"
        case .mpc8567: return "PVR 80210022 (mpc8567)"
        case .mpc8567e: return "PVR 80210022 (mpc8567e)"
        case .mpc8568: return "PVR 80210022 (mpc8568)"
        case .mpc8568e: return "PVR 80210022 (mpc8568e)"
        case .e500v2_v30: return "PVR 80210030 (e500v2_v30)"
        case .mpc8572: return "PVR 80210030 (mpc8572)"
        case .mpc8572e: return "PVR 80210030 (mpc8572e)"
        case .e500mc: return "PVR 80230020 (e500mc)"
        case .g2h4: return "PVR 80811010 (g2h4)"
        case .g2hip4: return "PVR 80811014 (g2hip4)"
        case .g2le: return "PVR 80820010 (g2le)"
        case .g2gp: return "PVR 80821010 (g2gp)"
        case .g2legp: return "PVR 80822010 (g2legp)"
        case .g2legp1: return "PVR 80822011 (g2legp1)"
        case .mpc5200_v10: return "PVR 80822011 (mpc5200_v10)"
        case .mpc5200_v11: return "PVR 80822011 (mpc5200_v11)"
        case .mpc5200_v12: return "PVR 80822011 (mpc5200_v12)"
        case .mpc5200b_v20: return "PVR 80822011 (mpc5200b_v20)"
        case .mpc5200b_v21: return "PVR 80822011 (mpc5200b_v21)"
        case .g2legp3: return "PVR 80822013 (g2legp3)"
        case .e200z5: return "PVR 81000000 (e200z5)"
        case .e200z6: return "PVR 81120000 (e200z6)"
        case .g2ls: return "PVR 90810010 (g2ls)"
        case .g2lels: return "PVR a0822010 (g2lels)"
        case .apollo6: return "apollo6"
        case .apollo7: return "apollo7"
        case .apollo7pm: return "apollo7pm"
        case .arthur: return "arthur"
        case .conan_doyle: return "conan/doyle"
        case .e200: return "e200"
        case .e300: return "e300"
        case .e500: return "e500"
        case .e500v1: return "e500v1"
        case .e500v2: return "e500v2"
        case .g3: return "g3"
        case .g4: return "g4"
        case .goldeneye: return "goldeneye"
        case .goldfinger: return "goldfinger"
        case .lonestar: return "lonestar"
        case .mach5: return "mach5"
        case .mpc5200: return "mpc5200"
        case .mpc5200b: return "mpc5200b"
        case .mpc52xx: return "mpc52xx"
        case .mpc8240: return "mpc8240"
        case .mpc8241: return "mpc8241"
        case .mpc8245: return "mpc8245"
        case .mpc8247: return "mpc8247"
        case .mpc8248: return "mpc8248"
        case .mpc8250: return "mpc8250"
        case .mpc8250_hip3: return "mpc8250_hip3"
        case .mpc8250_hip4: return "mpc8250_hip4"
        case .mpc8255: return "mpc8255"
        case .mpc8255_hip3: return "mpc8255_hip3"
        case .mpc8255_hip4: return "mpc8255_hip4"
        case .mpc8260: return "mpc8260"
        case .mpc8260_hip3: return "mpc8260_hip3"
        case .mpc8260_hip4: return "mpc8260_hip4"
        case .mpc8264: return "mpc8264"
        case .mpc8264_hip3: return "mpc8264_hip3"
        case .mpc8264_hip4: return "mpc8264_hip4"
        case .mpc8265: return "mpc8265"
        case .mpc8265_hip3: return "mpc8265_hip3"
        case .mpc8265_hip4: return "mpc8265_hip4"
        case .mpc8266: return "mpc8266"
        case .mpc8266_hip3: return "mpc8266_hip3"
        case .mpc8266_hip4: return "mpc8266_hip4"
        case .mpc8270: return "mpc8270"
        case .mpc8271: return "mpc8271"
        case .mpc8272: return "mpc8272"
        case .mpc8275: return "mpc8275"
        case .mpc8280: return "mpc8280"
        case .mpc82xx: return "mpc82xx"
        case .mpc8347: return "mpc8347"
        case .mpc8347a: return "mpc8347a"
        case .mpc8347e: return "mpc8347e"
        case .mpc8347ea: return "mpc8347ea"
        case .mpc8533: return "mpc8533"
        case .mpc8533e: return "mpc8533e"
        case .mpc8540: return "mpc8540"
        case .mpc8541: return "mpc8541"
        case .mpc8541e: return "mpc8541e"
        case .mpc8543: return "mpc8543"
        case .mpc8543e: return "mpc8543e"
        case .mpc8544: return "mpc8544"
        case .mpc8544e: return "mpc8544e"
        case .mpc8545: return "mpc8545"
        case .mpc8545e: return "mpc8545e"
        case .mpc8547e: return "mpc8547e"
        case .mpc8548: return "mpc8548"
        case .mpc8548e: return "mpc8548e"
        case .mpc8555: return "mpc8555"
        case .mpc8555e: return "mpc8555e"
        case .mpc8560: return "mpc8560"
        case .nitro: return "nitro"
        case .powerquicc_ii: return "powerquicc-ii"
        case .ppc: return "ppc"
        case .ppc32: return "ppc32"
        case .sirocco: return "sirocco"
        case .stretch: return "stretch"
        case .typhoon: return "typhoon"
        case .vaillant: return "vaillant"
        case .vanilla: return "vanilla"
        case .vger: return "vger"
        case .x2vp50: return "x2vp50"
        case .x2vp7: return "x2vp7"
        }
    }
}

enum QEMUCPU_ppc64: String, CaseIterable, QEMUCPU {
    case _405 = "405"
    case _405cr = "405cr"
    case _405gp = "405gp"
    case _405gpe = "405gpe"
    case _440ep = "440ep"
    case _460ex = "460ex"
    case _603e = "603e"
    case _603r = "603r"
    case _604e = "604e"
    case _740 = "740"
    case _7400 = "7400"
    case _7410 = "7410"
    case _7441 = "7441"
    case _7445 = "7445"
    case _7447 = "7447"
    case _7447a = "7447a"
    case _7448 = "7448"
    case _745 = "745"
    case _7450 = "7450"
    case _7451 = "7451"
    case _7455 = "7455"
    case _7457 = "7457"
    case _7457a = "7457a"
    case _750 = "750"
    case _750cl = "750cl"
    case _750cx = "750cx"
    case _750cxe = "750cxe"
    case _750fx = "750fx"
    case _750gx = "750gx"
    case _750l = "750l"
    case _755 = "755"
    case _970 = "970"
    case _970fx = "970fx"
    case _970mp = "970mp"
    case `default` = "default"
    case _603 = "603"
    case _604 = "604"
    case _603e_v1_1 = "603e_v1.1"
    case _603e_v1_2 = "603e_v1.2"
    case _603e_v1_3 = "603e_v1.3"
    case _603e_v1_4 = "603e_v1.4"
    case _603e_v2_2 = "603e_v2.2"
    case _603e_v3 = "603e_v3"
    case _603e_v4 = "603e_v4"
    case _603e_v4_1 = "603e_v4.1"
    case _603p = "603p"
    case _603e7v = "603e7v"
    case _603e7v1 = "603e7v1"
    case _603e7 = "603e7"
    case _603e7v2 = "603e7v2"
    case _603e7t = "603e7t"
    case _740_v1_0 = "740_v1.0"
    case _740e = "740e"
    case _750_v1_0 = "750_v1.0"
    case _740_v2_0 = "740_v2.0"
    case _750_v2_0 = "750_v2.0"
    case _750e = "750e"
    case _740_v2_1 = "740_v2.1"
    case _750_v2_1 = "750_v2.1"
    case _740_v2_2 = "740_v2.2"
    case _750_v2_2 = "750_v2.2"
    case _740_v3_0 = "740_v3.0"
    case _750_v3_0 = "750_v3.0"
    case _740_v3_1 = "740_v3.1"
    case _750_v3_1 = "750_v3.1"
    case _750cx_v1_0 = "750cx_v1.0"
    case _750cx_v2_0 = "750cx_v2.0"
    case _750cx_v2_1 = "750cx_v2.1"
    case _750cx_v2_2 = "750cx_v2.2"
    case _750cxe_v2_1 = "750cxe_v2.1"
    case _750cxe_v2_2 = "750cxe_v2.2"
    case _750cxe_v2_3 = "750cxe_v2.3"
    case _750cxe_v2_4 = "750cxe_v2.4"
    case _750cxe_v3_0 = "750cxe_v3.0"
    case _750cxe_v3_1 = "750cxe_v3.1"
    case _745_v1_0 = "745_v1.0"
    case _755_v1_0 = "755_v1.0"
    case _745_v1_1 = "745_v1.1"
    case _755_v1_1 = "755_v1.1"
    case _745_v2_0 = "745_v2.0"
    case _755_v2_0 = "755_v2.0"
    case _745_v2_1 = "745_v2.1"
    case _755_v2_1 = "755_v2.1"
    case _745_v2_2 = "745_v2.2"
    case _755_v2_2 = "755_v2.2"
    case _745_v2_3 = "745_v2.3"
    case _755_v2_3 = "755_v2.3"
    case _745_v2_4 = "745_v2.4"
    case _755_v2_4 = "755_v2.4"
    case _745_v2_5 = "745_v2.5"
    case _755_v2_5 = "755_v2.5"
    case _745_v2_6 = "745_v2.6"
    case _755_v2_6 = "755_v2.6"
    case _745_v2_7 = "745_v2.7"
    case _755_v2_7 = "755_v2.7"
    case _745_v2_8 = "745_v2.8"
    case _755_v2_8 = "755_v2.8"
    case _750cxe_v2_4b = "750cxe_v2.4b"
    case _750cxe_v3_1b = "750cxe_v3.1b"
    case _750cxr = "750cxr"
    case _750cl_v1_0 = "750cl_v1.0"
    case _750cl_v2_0 = "750cl_v2.0"
    case _750l_v2_0 = "750l_v2.0"
    case _750l_v2_1 = "750l_v2.1"
    case _750l_v2_2 = "750l_v2.2"
    case _750l_v3_0 = "750l_v3.0"
    case _750l_v3_2 = "750l_v3.2"
    case _604e_v1_0 = "604e_v1.0"
    case _604e_v2_2 = "604e_v2.2"
    case _604e_v2_4 = "604e_v2.4"
    case _604r = "604r"
    case _7400_v1_0 = "7400_v1.0"
    case _7400_v1_1 = "7400_v1.1"
    case _7400_v2_0 = "7400_v2.0"
    case _7400_v2_1 = "7400_v2.1"
    case _7400_v2_2 = "7400_v2.2"
    case _7400_v2_6 = "7400_v2.6"
    case _7400_v2_7 = "7400_v2.7"
    case _7400_v2_8 = "7400_v2.8"
    case _7400_v2_9 = "7400_v2.9"
    case _970_v2_2 = "970_v2.2"
    case _970fx_v1_0 = "970fx_v1.0"
    case power5p_v2_1 = "power5p_v2.1"
    case _970fx_v2_0 = "970fx_v2.0"
    case _970fx_v2_1 = "970fx_v2.1"
    case _970fx_v3_0 = "970fx_v3.0"
    case _970fx_v3_1 = "970fx_v3.1"
    case power7_v2_3 = "power7_v2.3"
    case _970mp_v1_0 = "970mp_v1.0"
    case _970mp_v1_1 = "970mp_v1.1"
    case power7p_v2_1 = "power7p_v2.1"
    case power8e_v2_1 = "power8e_v2.1"
    case power8nvl_v1_0 = "power8nvl_v1.0"
    case power8_v2_0 = "power8_v2.0"
    case power9_v2_0 = "power9_v2.0"
    case power9_v2_2 = "power9_v2.2"
    case power10_v2_0 = "power10_v2.0"
    case g2
    case mpc603
    case g2hip3
    case e300c1
    case mpc8343
    case mpc8343a
    case mpc8343e
    case mpc8343ea
    case mpc8347ap
    case mpc8347at
    case mpc8347eap
    case mpc8347eat
    case mpc8347ep
    case mpc8347et
    case mpc8347p
    case mpc8347t
    case mpc8349
    case mpc8349a
    case mpc8349e
    case mpc8349ea
    case e300c2
    case e300c3
    case e300c4
    case mpc8377
    case mpc8377e
    case mpc8378
    case mpc8378e
    case mpc8379
    case mpc8379e
    case _740p = "740p"
    case _750p = "750p"
    case _460exb = "460exb"
    case _440epx = "440epx"
    case _405d2 = "405d2"
    case x2vp4
    case x2vp20
    case _405gpa = "405gpa"
    case _405gpb = "405gpb"
    case _405cra = "405cra"
    case _405gpc = "405gpc"
    case _405gpd = "405gpd"
    case _405crb = "405crb"
    case _405crc = "405crc"
    case stb03
    case npe4gs3
    case npe405h
    case npe405h2
    case _405ez = "405ez"
    case npe405l
    case _405d4 = "405d4"
    case stb04
    case _405lp = "405lp"
    case _440epa = "440epa"
    case _440epb = "440epb"
    case _405gpr = "405gpr"
    case _405ep = "405ep"
    case stb25
    case _750fx_v1_0 = "750fx_v1.0"
    case _750fx_v2_0 = "750fx_v2.0"
    case _750fx_v2_1 = "750fx_v2.1"
    case _750fx_v2_2 = "750fx_v2.2"
    case _750fl = "750fl"
    case _750fx_v2_3 = "750fx_v2.3"
    case _750gx_v1_0 = "750gx_v1.0"
    case _750gx_v1_1 = "750gx_v1.1"
    case _750gl = "750gl"
    case _750gx_v1_2 = "750gx_v1.2"
    case _440_xilinx = "440-xilinx"
    case _440_xilinx_w_dfpu = "440-xilinx-w-dfpu"
    case _7450_v1_0 = "7450_v1.0"
    case _7450_v1_1 = "7450_v1.1"
    case _7450_v1_2 = "7450_v1.2"
    case _7450_v2_0 = "7450_v2.0"
    case _7441_v2_1 = "7441_v2.1"
    case _7450_v2_1 = "7450_v2.1"
    case _7441_v2_3 = "7441_v2.3"
    case _7451_v2_3 = "7451_v2.3"
    case _7441_v2_10 = "7441_v2.10"
    case _7451_v2_10 = "7451_v2.10"
    case _7445_v1_0 = "7445_v1.0"
    case _7455_v1_0 = "7455_v1.0"
    case _7445_v2_1 = "7445_v2.1"
    case _7455_v2_1 = "7455_v2.1"
    case _7445_v3_2 = "7445_v3.2"
    case _7455_v3_2 = "7455_v3.2"
    case _7445_v3_3 = "7445_v3.3"
    case _7455_v3_3 = "7455_v3.3"
    case _7445_v3_4 = "7445_v3.4"
    case _7455_v3_4 = "7455_v3.4"
    case _7447_v1_0 = "7447_v1.0"
    case _7457_v1_0 = "7457_v1.0"
    case _7447_v1_1 = "7447_v1.1"
    case _7457_v1_1 = "7457_v1.1"
    case _7457_v1_2 = "7457_v1.2"
    case _7447a_v1_0 = "7447a_v1.0"
    case _7457a_v1_0 = "7457a_v1.0"
    case _7447a_v1_1 = "7447a_v1.1"
    case _7457a_v1_1 = "7457a_v1.1"
    case _7447a_v1_2 = "7447a_v1.2"
    case _7457a_v1_2 = "7457a_v1.2"
    case e600
    case mpc8610
    case mpc8641
    case mpc8641d
    case _7448_v1_0 = "7448_v1.0"
    case _7448_v1_1 = "7448_v1.1"
    case _7448_v2_0 = "7448_v2.0"
    case _7448_v2_1 = "7448_v2.1"
    case _7410_v1_0 = "7410_v1.0"
    case _7410_v1_1 = "7410_v1.1"
    case _7410_v1_2 = "7410_v1.2"
    case _7410_v1_3 = "7410_v1.3"
    case _7410_v1_4 = "7410_v1.4"
    case e500_v10
    case mpc8540_v10
    case mpc8560_v10
    case e500_v20
    case mpc8540_v20
    case mpc8540_v21
    case mpc8541_v10
    case mpc8541_v11
    case mpc8541e_v10
    case mpc8541e_v11
    case mpc8555_v10
    case mpc8555_v11
    case mpc8555e_v10
    case mpc8555e_v11
    case mpc8560_v20
    case mpc8560_v21
    case e500v2_v10
    case mpc8543_v10
    case mpc8543e_v10
    case mpc8548_v10
    case mpc8548e_v10
    case mpc8543_v11
    case mpc8543e_v11
    case mpc8548_v11
    case mpc8548e_v11
    case e500v2_v20
    case mpc8543_v20
    case mpc8543e_v20
    case mpc8545_v20
    case mpc8545e_v20
    case mpc8547e_v20
    case mpc8548_v20
    case mpc8548e_v20
    case e500v2_v21
    case mpc8533_v10
    case mpc8533e_v10
    case mpc8543_v21
    case mpc8543e_v21
    case mpc8544_v10
    case mpc8544e_v10
    case mpc8545_v21
    case mpc8545e_v21
    case mpc8547e_v21
    case mpc8548_v21
    case mpc8548e_v21
    case e500v2_v22
    case mpc8533_v11
    case mpc8533e_v11
    case mpc8544_v11
    case mpc8544e_v11
    case mpc8567
    case mpc8567e
    case mpc8568
    case mpc8568e
    case e500v2_v30
    case mpc8572
    case mpc8572e
    case e500mc
    case e5500
    case e6500
    case g2h4
    case g2hip4
    case g2le
    case g2gp
    case g2legp
    case g2legp1
    case mpc5200_v10
    case mpc5200_v11
    case mpc5200_v12
    case mpc5200b_v20
    case mpc5200b_v21
    case g2legp3
    case e200z5
    case e200z6
    case g2ls
    case g2lels
    case apollo6
    case apollo7
    case apollo7pm
    case arthur
    case conan_doyle = "conan/doyle"
    case e200
    case e300
    case e500
    case e500v1
    case e500v2
    case g3
    case g4
    case goldeneye
    case goldfinger
    case lonestar
    case mach5
    case mpc5200
    case mpc5200b
    case mpc52xx
    case mpc8240
    case mpc8241
    case mpc8245
    case mpc8247
    case mpc8248
    case mpc8250
    case mpc8250_hip3
    case mpc8250_hip4
    case mpc8255
    case mpc8255_hip3
    case mpc8255_hip4
    case mpc8260
    case mpc8260_hip3
    case mpc8260_hip4
    case mpc8264
    case mpc8264_hip3
    case mpc8264_hip4
    case mpc8265
    case mpc8265_hip3
    case mpc8265_hip4
    case mpc8266
    case mpc8266_hip3
    case mpc8266_hip4
    case mpc8270
    case mpc8271
    case mpc8272
    case mpc8275
    case mpc8280
    case mpc82xx
    case mpc8347
    case mpc8347a
    case mpc8347e
    case mpc8347ea
    case mpc8533
    case mpc8533e
    case mpc8540
    case mpc8541
    case mpc8541e
    case mpc8543
    case mpc8543e
    case mpc8544
    case mpc8544e
    case mpc8545
    case mpc8545e
    case mpc8547e
    case mpc8548
    case mpc8548e
    case mpc8555
    case mpc8555e
    case mpc8560
    case nitro
    case power10
    case power5_ = "power5+"
    case power5_v2_1 = "power5+_v2.1"
    case power5gs
    case power7
    case power7_ = "power7+"
    case power7_v2_1 = "power7+_v2.1"
    case power8
    case power8e
    case power8nvl
    case power9
    case powerquicc_ii = "powerquicc-ii"
    case ppc
    case ppc32
    case ppc64
    case sirocco
    case stretch
    case typhoon
    case vaillant
    case vanilla
    case vger
    case x2vp50
    case x2vp7

    var prettyValue: String {
        switch self {
        case ._405: return "405"
        case ._405cr: return "405cr"
        case ._405gp: return "405gp"
        case ._405gpe: return "405gpe"
        case ._440ep: return "440ep"
        case ._460ex: return "460ex"
        case ._603e: return "603e"
        case ._603r: return "603r"
        case ._604e: return "604e"
        case ._740: return "740"
        case ._7400: return "7400"
        case ._7410: return "7410"
        case ._7441: return "7441"
        case ._7445: return "7445"
        case ._7447: return "7447"
        case ._7447a: return "7447a"
        case ._7448: return "7448"
        case ._745: return "745"
        case ._7450: return "7450"
        case ._7451: return "7451"
        case ._7455: return "7455"
        case ._7457: return "7457"
        case ._7457a: return "7457a"
        case ._750: return "750"
        case ._750cl: return "750cl"
        case ._750cx: return "750cx"
        case ._750cxe: return "750cxe"
        case ._750fx: return "750fx"
        case ._750gx: return "750gx"
        case ._750l: return "750l"
        case ._755: return "755"
        case ._970: return "970"
        case ._970fx: return "970fx"
        case ._970mp: return "970mp"
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case ._603: return "PVR 00030100 (603)"
        case ._604: return "PVR 00040103 (604)"
        case ._603e_v1_1: return "PVR 00060101 (603e_v1.1)"
        case ._603e_v1_2: return "PVR 00060102 (603e_v1.2)"
        case ._603e_v1_3: return "PVR 00060103 (603e_v1.3)"
        case ._603e_v1_4: return "PVR 00060104 (603e_v1.4)"
        case ._603e_v2_2: return "PVR 00060202 (603e_v2.2)"
        case ._603e_v3: return "PVR 00060300 (603e_v3)"
        case ._603e_v4: return "PVR 00060400 (603e_v4)"
        case ._603e_v4_1: return "PVR 00060401 (603e_v4.1)"
        case ._603p: return "PVR 00070000 (603p)"
        case ._603e7v: return "PVR 00070100 (603e7v)"
        case ._603e7v1: return "PVR 00070101 (603e7v1)"
        case ._603e7: return "PVR 00070200 (603e7)"
        case ._603e7v2: return "PVR 00070201 (603e7v2)"
        case ._603e7t: return "PVR 00071201 (603e7t)"
        case ._740_v1_0: return "PVR 00080100 (740_v1.0)"
        case ._740e: return "PVR 00080100 (740e)"
        case ._750_v1_0: return "PVR 00080100 (750_v1.0)"
        case ._740_v2_0: return "PVR 00080200 (740_v2.0)"
        case ._750_v2_0: return "PVR 00080200 (750_v2.0)"
        case ._750e: return "PVR 00080200 (750e)"
        case ._740_v2_1: return "PVR 00080201 (740_v2.1)"
        case ._750_v2_1: return "PVR 00080201 (750_v2.1)"
        case ._740_v2_2: return "PVR 00080202 (740_v2.2)"
        case ._750_v2_2: return "PVR 00080202 (750_v2.2)"
        case ._740_v3_0: return "PVR 00080300 (740_v3.0)"
        case ._750_v3_0: return "PVR 00080300 (750_v3.0)"
        case ._740_v3_1: return "PVR 00080301 (740_v3.1)"
        case ._750_v3_1: return "PVR 00080301 (750_v3.1)"
        case ._750cx_v1_0: return "PVR 00082100 (750cx_v1.0)"
        case ._750cx_v2_0: return "PVR 00082200 (750cx_v2.0)"
        case ._750cx_v2_1: return "PVR 00082201 (750cx_v2.1)"
        case ._750cx_v2_2: return "PVR 00082202 (750cx_v2.2)"
        case ._750cxe_v2_1: return "PVR 00082211 (750cxe_v2.1)"
        case ._750cxe_v2_2: return "PVR 00082212 (750cxe_v2.2)"
        case ._750cxe_v2_3: return "PVR 00082213 (750cxe_v2.3)"
        case ._750cxe_v2_4: return "PVR 00082214 (750cxe_v2.4)"
        case ._750cxe_v3_0: return "PVR 00082310 (750cxe_v3.0)"
        case ._750cxe_v3_1: return "PVR 00082311 (750cxe_v3.1)"
        case ._745_v1_0: return "PVR 00083100 (745_v1.0)"
        case ._755_v1_0: return "PVR 00083100 (755_v1.0)"
        case ._745_v1_1: return "PVR 00083101 (745_v1.1)"
        case ._755_v1_1: return "PVR 00083101 (755_v1.1)"
        case ._745_v2_0: return "PVR 00083200 (745_v2.0)"
        case ._755_v2_0: return "PVR 00083200 (755_v2.0)"
        case ._745_v2_1: return "PVR 00083201 (745_v2.1)"
        case ._755_v2_1: return "PVR 00083201 (755_v2.1)"
        case ._745_v2_2: return "PVR 00083202 (745_v2.2)"
        case ._755_v2_2: return "PVR 00083202 (755_v2.2)"
        case ._745_v2_3: return "PVR 00083203 (745_v2.3)"
        case ._755_v2_3: return "PVR 00083203 (755_v2.3)"
        case ._745_v2_4: return "PVR 00083204 (745_v2.4)"
        case ._755_v2_4: return "PVR 00083204 (755_v2.4)"
        case ._745_v2_5: return "PVR 00083205 (745_v2.5)"
        case ._755_v2_5: return "PVR 00083205 (755_v2.5)"
        case ._745_v2_6: return "PVR 00083206 (745_v2.6)"
        case ._755_v2_6: return "PVR 00083206 (755_v2.6)"
        case ._745_v2_7: return "PVR 00083207 (745_v2.7)"
        case ._755_v2_7: return "PVR 00083207 (755_v2.7)"
        case ._745_v2_8: return "PVR 00083208 (745_v2.8)"
        case ._755_v2_8: return "PVR 00083208 (755_v2.8)"
        case ._750cxe_v2_4b: return "PVR 00083214 (750cxe_v2.4b)"
        case ._750cxe_v3_1b: return "PVR 00083311 (750cxe_v3.1b)"
        case ._750cxr: return "PVR 00083410 (750cxr)"
        case ._750cl_v1_0: return "PVR 00087200 (750cl_v1.0)"
        case ._750cl_v2_0: return "PVR 00087210 (750cl_v2.0)"
        case ._750l_v2_0: return "PVR 00088200 (750l_v2.0)"
        case ._750l_v2_1: return "PVR 00088201 (750l_v2.1)"
        case ._750l_v2_2: return "PVR 00088202 (750l_v2.2)"
        case ._750l_v3_0: return "PVR 00088300 (750l_v3.0)"
        case ._750l_v3_2: return "PVR 00088302 (750l_v3.2)"
        case ._604e_v1_0: return "PVR 00090100 (604e_v1.0)"
        case ._604e_v2_2: return "PVR 00090202 (604e_v2.2)"
        case ._604e_v2_4: return "PVR 00090204 (604e_v2.4)"
        case ._604r: return "PVR 000a0101 (604r)"
        case ._7400_v1_0: return "PVR 000c0100 (7400_v1.0)"
        case ._7400_v1_1: return "PVR 000c0101 (7400_v1.1)"
        case ._7400_v2_0: return "PVR 000c0200 (7400_v2.0)"
        case ._7400_v2_1: return "PVR 000c0201 (7400_v2.1)"
        case ._7400_v2_2: return "PVR 000c0202 (7400_v2.2)"
        case ._7400_v2_6: return "PVR 000c0206 (7400_v2.6)"
        case ._7400_v2_7: return "PVR 000c0207 (7400_v2.7)"
        case ._7400_v2_8: return "PVR 000c0208 (7400_v2.8)"
        case ._7400_v2_9: return "PVR 000c0209 (7400_v2.9)"
        case ._970_v2_2: return "PVR 00390202 (970_v2.2)"
        case ._970fx_v1_0: return "PVR 00391100 (970fx_v1.0)"
        case .power5p_v2_1: return "PVR 003b0201 (power5p_v2.1)"
        case ._970fx_v2_0: return "PVR 003c0200 (970fx_v2.0)"
        case ._970fx_v2_1: return "PVR 003c0201 (970fx_v2.1)"
        case ._970fx_v3_0: return "PVR 003c0300 (970fx_v3.0)"
        case ._970fx_v3_1: return "PVR 003c0301 (970fx_v3.1)"
        case .power7_v2_3: return "PVR 003f0203 (power7_v2.3)"
        case ._970mp_v1_0: return "PVR 00440100 (970mp_v1.0)"
        case ._970mp_v1_1: return "PVR 00440101 (970mp_v1.1)"
        case .power7p_v2_1: return "PVR 004a0201 (power7p_v2.1)"
        case .power8e_v2_1: return "PVR 004b0201 (power8e_v2.1)"
        case .power8nvl_v1_0: return "PVR 004c0100 (power8nvl_v1.0)"
        case .power8_v2_0: return "PVR 004d0200 (power8_v2.0)"
        case .power9_v2_0: return "PVR 004e1200 (power9_v2.0)"
        case .power9_v2_2: return "PVR 004e1202 (power9_v2.2)"
        case .power10_v2_0: return "PVR 00801200 (power10_v2.0)"
        case .g2: return "PVR 00810011 (g2)"
        case .mpc603: return "PVR 00810100 (mpc603)"
        case .g2hip3: return "PVR 00810101 (g2hip3)"
        case .e300c1: return "PVR 00830010 (e300c1)"
        case .mpc8343: return "PVR 00830010 (mpc8343)"
        case .mpc8343a: return "PVR 00830010 (mpc8343a)"
        case .mpc8343e: return "PVR 00830010 (mpc8343e)"
        case .mpc8343ea: return "PVR 00830010 (mpc8343ea)"
        case .mpc8347ap: return "PVR 00830010 (mpc8347ap)"
        case .mpc8347at: return "PVR 00830010 (mpc8347at)"
        case .mpc8347eap: return "PVR 00830010 (mpc8347eap)"
        case .mpc8347eat: return "PVR 00830010 (mpc8347eat)"
        case .mpc8347ep: return "PVR 00830010 (mpc8347ep)"
        case .mpc8347et: return "PVR 00830010 (mpc8347et)"
        case .mpc8347p: return "PVR 00830010 (mpc8347p)"
        case .mpc8347t: return "PVR 00830010 (mpc8347t)"
        case .mpc8349: return "PVR 00830010 (mpc8349)"
        case .mpc8349a: return "PVR 00830010 (mpc8349a)"
        case .mpc8349e: return "PVR 00830010 (mpc8349e)"
        case .mpc8349ea: return "PVR 00830010 (mpc8349ea)"
        case .e300c2: return "PVR 00840010 (e300c2)"
        case .e300c3: return "PVR 00850010 (e300c3)"
        case .e300c4: return "PVR 00860010 (e300c4)"
        case .mpc8377: return "PVR 00860010 (mpc8377)"
        case .mpc8377e: return "PVR 00860010 (mpc8377e)"
        case .mpc8378: return "PVR 00860010 (mpc8378)"
        case .mpc8378e: return "PVR 00860010 (mpc8378e)"
        case .mpc8379: return "PVR 00860010 (mpc8379)"
        case .mpc8379e: return "PVR 00860010 (mpc8379e)"
        case ._740p: return "PVR 10080000 (740p)"
        case ._750p: return "PVR 10080000 (750p)"
        case ._460exb: return "PVR 130218a4 (460exb)"
        case ._440epx: return "PVR 200008d0 (440epx)"
        case ._405d2: return "PVR 20010000 (405d2)"
        case .x2vp4: return "PVR 20010820 (x2vp4)"
        case .x2vp20: return "PVR 20010860 (x2vp20)"
        case ._405gpa: return "PVR 40110000 (405gpa)"
        case ._405gpb: return "PVR 40110040 (405gpb)"
        case ._405cra: return "PVR 40110041 (405cra)"
        case ._405gpc: return "PVR 40110082 (405gpc)"
        case ._405gpd: return "PVR 401100c4 (405gpd)"
        case ._405crb: return "PVR 401100c5 (405crb)"
        case ._405crc: return "PVR 40110145 (405crc)"
        case .stb03: return "PVR 40310000 (stb03)"
        case .npe4gs3: return "PVR 40b10000 (npe4gs3)"
        case .npe405h: return "PVR 414100c0 (npe405h)"
        case .npe405h2: return "PVR 41410140 (npe405h2)"
        case ._405ez: return "PVR 41511460 (405ez)"
        case .npe405l: return "PVR 416100c0 (npe405l)"
        case ._405d4: return "PVR 41810000 (405d4)"
        case .stb04: return "PVR 41810000 (stb04)"
        case ._405lp: return "PVR 41f10000 (405lp)"
        case ._440epa: return "PVR 42221850 (440epa)"
        case ._440epb: return "PVR 422218d3 (440epb)"
        case ._405gpr: return "PVR 50910951 (405gpr)"
        case ._405ep: return "PVR 51210950 (405ep)"
        case .stb25: return "PVR 51510950 (stb25)"
        case ._750fx_v1_0: return "PVR 70000100 (750fx_v1.0)"
        case ._750fx_v2_0: return "PVR 70000200 (750fx_v2.0)"
        case ._750fx_v2_1: return "PVR 70000201 (750fx_v2.1)"
        case ._750fx_v2_2: return "PVR 70000202 (750fx_v2.2)"
        case ._750fl: return "PVR 70000203 (750fl)"
        case ._750fx_v2_3: return "PVR 70000203 (750fx_v2.3)"
        case ._750gx_v1_0: return "PVR 70020100 (750gx_v1.0)"
        case ._750gx_v1_1: return "PVR 70020101 (750gx_v1.1)"
        case ._750gl: return "PVR 70020102 (750gl)"
        case ._750gx_v1_2: return "PVR 70020102 (750gx_v1.2)"
        case ._440_xilinx: return "PVR 7ff21910 (440-xilinx)"
        case ._440_xilinx_w_dfpu: return "PVR 7ff21910 (440-xilinx-w-dfpu)"
        case ._7450_v1_0: return "PVR 80000100 (7450_v1.0)"
        case ._7450_v1_1: return "PVR 80000101 (7450_v1.1)"
        case ._7450_v1_2: return "PVR 80000102 (7450_v1.2)"
        case ._7450_v2_0: return "PVR 80000200 (7450_v2.0)"
        case ._7441_v2_1: return "PVR 80000201 (7441_v2.1)"
        case ._7450_v2_1: return "PVR 80000201 (7450_v2.1)"
        case ._7441_v2_3: return "PVR 80000203 (7441_v2.3)"
        case ._7451_v2_3: return "PVR 80000203 (7451_v2.3)"
        case ._7441_v2_10: return "PVR 80000210 (7441_v2.10)"
        case ._7451_v2_10: return "PVR 80000210 (7451_v2.10)"
        case ._7445_v1_0: return "PVR 80010100 (7445_v1.0)"
        case ._7455_v1_0: return "PVR 80010100 (7455_v1.0)"
        case ._7445_v2_1: return "PVR 80010201 (7445_v2.1)"
        case ._7455_v2_1: return "PVR 80010201 (7455_v2.1)"
        case ._7445_v3_2: return "PVR 80010302 (7445_v3.2)"
        case ._7455_v3_2: return "PVR 80010302 (7455_v3.2)"
        case ._7445_v3_3: return "PVR 80010303 (7445_v3.3)"
        case ._7455_v3_3: return "PVR 80010303 (7455_v3.3)"
        case ._7445_v3_4: return "PVR 80010304 (7445_v3.4)"
        case ._7455_v3_4: return "PVR 80010304 (7455_v3.4)"
        case ._7447_v1_0: return "PVR 80020100 (7447_v1.0)"
        case ._7457_v1_0: return "PVR 80020100 (7457_v1.0)"
        case ._7447_v1_1: return "PVR 80020101 (7447_v1.1)"
        case ._7457_v1_1: return "PVR 80020101 (7457_v1.1)"
        case ._7457_v1_2: return "PVR 80020102 (7457_v1.2)"
        case ._7447a_v1_0: return "PVR 80030100 (7447a_v1.0)"
        case ._7457a_v1_0: return "PVR 80030100 (7457a_v1.0)"
        case ._7447a_v1_1: return "PVR 80030101 (7447a_v1.1)"
        case ._7457a_v1_1: return "PVR 80030101 (7457a_v1.1)"
        case ._7447a_v1_2: return "PVR 80030102 (7447a_v1.2)"
        case ._7457a_v1_2: return "PVR 80030102 (7457a_v1.2)"
        case .e600: return "PVR 80040010 (e600)"
        case .mpc8610: return "PVR 80040010 (mpc8610)"
        case .mpc8641: return "PVR 80040010 (mpc8641)"
        case .mpc8641d: return "PVR 80040010 (mpc8641d)"
        case ._7448_v1_0: return "PVR 80040100 (7448_v1.0)"
        case ._7448_v1_1: return "PVR 80040101 (7448_v1.1)"
        case ._7448_v2_0: return "PVR 80040200 (7448_v2.0)"
        case ._7448_v2_1: return "PVR 80040201 (7448_v2.1)"
        case ._7410_v1_0: return "PVR 800c1100 (7410_v1.0)"
        case ._7410_v1_1: return "PVR 800c1101 (7410_v1.1)"
        case ._7410_v1_2: return "PVR 800c1102 (7410_v1.2)"
        case ._7410_v1_3: return "PVR 800c1103 (7410_v1.3)"
        case ._7410_v1_4: return "PVR 800c1104 (7410_v1.4)"
        case .e500_v10: return "PVR 80200010 (e500_v10)"
        case .mpc8540_v10: return "PVR 80200010 (mpc8540_v10)"
        case .mpc8560_v10: return "PVR 80200010 (mpc8560_v10)"
        case .e500_v20: return "PVR 80200020 (e500_v20)"
        case .mpc8540_v20: return "PVR 80200020 (mpc8540_v20)"
        case .mpc8540_v21: return "PVR 80200020 (mpc8540_v21)"
        case .mpc8541_v10: return "PVR 80200020 (mpc8541_v10)"
        case .mpc8541_v11: return "PVR 80200020 (mpc8541_v11)"
        case .mpc8541e_v10: return "PVR 80200020 (mpc8541e_v10)"
        case .mpc8541e_v11: return "PVR 80200020 (mpc8541e_v11)"
        case .mpc8555_v10: return "PVR 80200020 (mpc8555_v10)"
        case .mpc8555_v11: return "PVR 80200020 (mpc8555_v11)"
        case .mpc8555e_v10: return "PVR 80200020 (mpc8555e_v10)"
        case .mpc8555e_v11: return "PVR 80200020 (mpc8555e_v11)"
        case .mpc8560_v20: return "PVR 80200020 (mpc8560_v20)"
        case .mpc8560_v21: return "PVR 80200020 (mpc8560_v21)"
        case .e500v2_v10: return "PVR 80210010 (e500v2_v10)"
        case .mpc8543_v10: return "PVR 80210010 (mpc8543_v10)"
        case .mpc8543e_v10: return "PVR 80210010 (mpc8543e_v10)"
        case .mpc8548_v10: return "PVR 80210010 (mpc8548_v10)"
        case .mpc8548e_v10: return "PVR 80210010 (mpc8548e_v10)"
        case .mpc8543_v11: return "PVR 80210011 (mpc8543_v11)"
        case .mpc8543e_v11: return "PVR 80210011 (mpc8543e_v11)"
        case .mpc8548_v11: return "PVR 80210011 (mpc8548_v11)"
        case .mpc8548e_v11: return "PVR 80210011 (mpc8548e_v11)"
        case .e500v2_v20: return "PVR 80210020 (e500v2_v20)"
        case .mpc8543_v20: return "PVR 80210020 (mpc8543_v20)"
        case .mpc8543e_v20: return "PVR 80210020 (mpc8543e_v20)"
        case .mpc8545_v20: return "PVR 80210020 (mpc8545_v20)"
        case .mpc8545e_v20: return "PVR 80210020 (mpc8545e_v20)"
        case .mpc8547e_v20: return "PVR 80210020 (mpc8547e_v20)"
        case .mpc8548_v20: return "PVR 80210020 (mpc8548_v20)"
        case .mpc8548e_v20: return "PVR 80210020 (mpc8548e_v20)"
        case .e500v2_v21: return "PVR 80210021 (e500v2_v21)"
        case .mpc8533_v10: return "PVR 80210021 (mpc8533_v10)"
        case .mpc8533e_v10: return "PVR 80210021 (mpc8533e_v10)"
        case .mpc8543_v21: return "PVR 80210021 (mpc8543_v21)"
        case .mpc8543e_v21: return "PVR 80210021 (mpc8543e_v21)"
        case .mpc8544_v10: return "PVR 80210021 (mpc8544_v10)"
        case .mpc8544e_v10: return "PVR 80210021 (mpc8544e_v10)"
        case .mpc8545_v21: return "PVR 80210021 (mpc8545_v21)"
        case .mpc8545e_v21: return "PVR 80210021 (mpc8545e_v21)"
        case .mpc8547e_v21: return "PVR 80210021 (mpc8547e_v21)"
        case .mpc8548_v21: return "PVR 80210021 (mpc8548_v21)"
        case .mpc8548e_v21: return "PVR 80210021 (mpc8548e_v21)"
        case .e500v2_v22: return "PVR 80210022 (e500v2_v22)"
        case .mpc8533_v11: return "PVR 80210022 (mpc8533_v11)"
        case .mpc8533e_v11: return "PVR 80210022 (mpc8533e_v11)"
        case .mpc8544_v11: return "PVR 80210022 (mpc8544_v11)"
        case .mpc8544e_v11: return "PVR 80210022 (mpc8544e_v11)"
        case .mpc8567: return "PVR 80210022 (mpc8567)"
        case .mpc8567e: return "PVR 80210022 (mpc8567e)"
        case .mpc8568: return "PVR 80210022 (mpc8568)"
        case .mpc8568e: return "PVR 80210022 (mpc8568e)"
        case .e500v2_v30: return "PVR 80210030 (e500v2_v30)"
        case .mpc8572: return "PVR 80210030 (mpc8572)"
        case .mpc8572e: return "PVR 80210030 (mpc8572e)"
        case .e500mc: return "PVR 80230020 (e500mc)"
        case .e5500: return "PVR 80240020 (e5500)"
        case .e6500: return "PVR 80400020 (e6500)"
        case .g2h4: return "PVR 80811010 (g2h4)"
        case .g2hip4: return "PVR 80811014 (g2hip4)"
        case .g2le: return "PVR 80820010 (g2le)"
        case .g2gp: return "PVR 80821010 (g2gp)"
        case .g2legp: return "PVR 80822010 (g2legp)"
        case .g2legp1: return "PVR 80822011 (g2legp1)"
        case .mpc5200_v10: return "PVR 80822011 (mpc5200_v10)"
        case .mpc5200_v11: return "PVR 80822011 (mpc5200_v11)"
        case .mpc5200_v12: return "PVR 80822011 (mpc5200_v12)"
        case .mpc5200b_v20: return "PVR 80822011 (mpc5200b_v20)"
        case .mpc5200b_v21: return "PVR 80822011 (mpc5200b_v21)"
        case .g2legp3: return "PVR 80822013 (g2legp3)"
        case .e200z5: return "PVR 81000000 (e200z5)"
        case .e200z6: return "PVR 81120000 (e200z6)"
        case .g2ls: return "PVR 90810010 (g2ls)"
        case .g2lels: return "PVR a0822010 (g2lels)"
        case .apollo6: return "apollo6"
        case .apollo7: return "apollo7"
        case .apollo7pm: return "apollo7pm"
        case .arthur: return "arthur"
        case .conan_doyle: return "conan/doyle"
        case .e200: return "e200"
        case .e300: return "e300"
        case .e500: return "e500"
        case .e500v1: return "e500v1"
        case .e500v2: return "e500v2"
        case .g3: return "g3"
        case .g4: return "g4"
        case .goldeneye: return "goldeneye"
        case .goldfinger: return "goldfinger"
        case .lonestar: return "lonestar"
        case .mach5: return "mach5"
        case .mpc5200: return "mpc5200"
        case .mpc5200b: return "mpc5200b"
        case .mpc52xx: return "mpc52xx"
        case .mpc8240: return "mpc8240"
        case .mpc8241: return "mpc8241"
        case .mpc8245: return "mpc8245"
        case .mpc8247: return "mpc8247"
        case .mpc8248: return "mpc8248"
        case .mpc8250: return "mpc8250"
        case .mpc8250_hip3: return "mpc8250_hip3"
        case .mpc8250_hip4: return "mpc8250_hip4"
        case .mpc8255: return "mpc8255"
        case .mpc8255_hip3: return "mpc8255_hip3"
        case .mpc8255_hip4: return "mpc8255_hip4"
        case .mpc8260: return "mpc8260"
        case .mpc8260_hip3: return "mpc8260_hip3"
        case .mpc8260_hip4: return "mpc8260_hip4"
        case .mpc8264: return "mpc8264"
        case .mpc8264_hip3: return "mpc8264_hip3"
        case .mpc8264_hip4: return "mpc8264_hip4"
        case .mpc8265: return "mpc8265"
        case .mpc8265_hip3: return "mpc8265_hip3"
        case .mpc8265_hip4: return "mpc8265_hip4"
        case .mpc8266: return "mpc8266"
        case .mpc8266_hip3: return "mpc8266_hip3"
        case .mpc8266_hip4: return "mpc8266_hip4"
        case .mpc8270: return "mpc8270"
        case .mpc8271: return "mpc8271"
        case .mpc8272: return "mpc8272"
        case .mpc8275: return "mpc8275"
        case .mpc8280: return "mpc8280"
        case .mpc82xx: return "mpc82xx"
        case .mpc8347: return "mpc8347"
        case .mpc8347a: return "mpc8347a"
        case .mpc8347e: return "mpc8347e"
        case .mpc8347ea: return "mpc8347ea"
        case .mpc8533: return "mpc8533"
        case .mpc8533e: return "mpc8533e"
        case .mpc8540: return "mpc8540"
        case .mpc8541: return "mpc8541"
        case .mpc8541e: return "mpc8541e"
        case .mpc8543: return "mpc8543"
        case .mpc8543e: return "mpc8543e"
        case .mpc8544: return "mpc8544"
        case .mpc8544e: return "mpc8544e"
        case .mpc8545: return "mpc8545"
        case .mpc8545e: return "mpc8545e"
        case .mpc8547e: return "mpc8547e"
        case .mpc8548: return "mpc8548"
        case .mpc8548e: return "mpc8548e"
        case .mpc8555: return "mpc8555"
        case .mpc8555e: return "mpc8555e"
        case .mpc8560: return "mpc8560"
        case .nitro: return "nitro"
        case .power10: return "power10"
        case .power5_: return "power5+"
        case .power5_v2_1: return "power5+_v2.1"
        case .power5gs: return "power5gs"
        case .power7: return "power7"
        case .power7_: return "power7+"
        case .power7_v2_1: return "power7+_v2.1"
        case .power8: return "power8"
        case .power8e: return "power8e"
        case .power8nvl: return "power8nvl"
        case .power9: return "power9"
        case .powerquicc_ii: return "powerquicc-ii"
        case .ppc: return "ppc"
        case .ppc32: return "ppc32"
        case .ppc64: return "ppc64"
        case .sirocco: return "sirocco"
        case .stretch: return "stretch"
        case .typhoon: return "typhoon"
        case .vaillant: return "vaillant"
        case .vanilla: return "vanilla"
        case .vger: return "vger"
        case .x2vp50: return "x2vp50"
        case .x2vp7: return "x2vp7"
        }
    }
}

enum QEMUCPU_riscv32: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case any
    case lowrisc_ibex = "lowrisc-ibex"
    case max
    case rv32
    case rv32e
    case rv32i
    case sifive_e31 = "sifive-e31"
    case sifive_e34 = "sifive-e34"
    case sifive_u34 = "sifive-u34"

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .any: return "any"
        case .lowrisc_ibex: return "lowrisc-ibex"
        case .max: return "max"
        case .rv32: return "rv32"
        case .rv32e: return "rv32e"
        case .rv32i: return "rv32i"
        case .sifive_e31: return "sifive-e31"
        case .sifive_e34: return "sifive-e34"
        case .sifive_u34: return "sifive-u34"
        }
    }
}

enum QEMUCPU_riscv64: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case any
    case max
    case rv64
    case rv64e
    case rv64i
    case rva22s64
    case rva22u64
    case shakti_c = "shakti-c"
    case sifive_e51 = "sifive-e51"
    case sifive_u54 = "sifive-u54"
    case thead_c906 = "thead-c906"
    case veyron_v1 = "veyron-v1"
    case x_rv128 = "x-rv128"

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .any: return "any"
        case .max: return "max"
        case .rv64: return "rv64"
        case .rv64e: return "rv64e"
        case .rv64i: return "rv64i"
        case .rva22s64: return "rva22s64"
        case .rva22u64: return "rva22u64"
        case .shakti_c: return "shakti-c"
        case .sifive_e51: return "sifive-e51"
        case .sifive_u54: return "sifive-u54"
        case .thead_c906: return "thead-c906"
        case .veyron_v1: return "veyron-v1"
        case .x_rv128: return "x-rv128"
        }
    }
}

enum QEMUCPU_rx: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case rx62n

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .rx62n: return "rx62n"
        }
    }
}

enum QEMUCPU_s390x: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case max
    case gen16a
    case gen16a_base = "gen16a-base"
    case gen16b
    case gen16b_base = "gen16b-base"
    case z10BC
    case z10BC_base = "z10BC-base"
    case z10BC_2 = "z10BC.2"
    case z10BC_2_base = "z10BC.2-base"
    case z10EC
    case z10EC_base = "z10EC-base"
    case z10EC_2 = "z10EC.2"
    case z10EC_2_base = "z10EC.2-base"
    case z10EC_3 = "z10EC.3"
    case z10EC_3_base = "z10EC.3-base"
    case z9BC
    case z9BC_base = "z9BC-base"
    case z9BC_2 = "z9BC.2"
    case z9BC_2_base = "z9BC.2-base"
    case z9EC
    case z9EC_base = "z9EC-base"
    case z9EC_2 = "z9EC.2"
    case z9EC_2_base = "z9EC.2-base"
    case z9EC_3 = "z9EC.3"
    case z9EC_3_base = "z9EC.3-base"
    case z13
    case z13_base = "z13-base"
    case z13_2 = "z13.2"
    case z13_2_base = "z13.2-base"
    case z13s
    case z13s_base = "z13s-base"
    case z14
    case z14_base = "z14-base"
    case z14_2 = "z14.2"
    case z14_2_base = "z14.2-base"
    case z14ZR1
    case z14ZR1_base = "z14ZR1-base"
    case gen15a
    case gen15a_base = "gen15a-base"
    case gen15b
    case gen15b_base = "gen15b-base"
    case z114
    case z114_base = "z114-base"
    case z196
    case z196_base = "z196-base"
    case z196_2 = "z196.2"
    case z196_2_base = "z196.2-base"
    case zBC12
    case zBC12_base = "zBC12-base"
    case zEC12
    case zEC12_base = "zEC12-base"
    case zEC12_2 = "zEC12.2"
    case zEC12_2_base = "zEC12.2-base"
    case z800
    case z800_base = "z800-base"
    case z890
    case z890_base = "z890-base"
    case z890_2 = "z890.2"
    case z890_2_base = "z890.2-base"
    case z890_3 = "z890.3"
    case z890_3_base = "z890.3-base"
    case z900
    case z900_base = "z900-base"
    case z900_2 = "z900.2"
    case z900_2_base = "z900.2-base"
    case z900_3 = "z900.3"
    case z900_3_base = "z900.3-base"
    case z990
    case z990_base = "z990-base"
    case z990_2 = "z990.2"
    case z990_2_base = "z990.2-base"
    case z990_3 = "z990.3"
    case z990_3_base = "z990.3-base"
    case z990_4 = "z990.4"
    case z990_4_base = "z990.4-base"
    case z990_5 = "z990.5"
    case z990_5_base = "z990.5-base"
    case qemu

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .max: return "Enables all features supported by the accelerator in the current host (max)"
        case .gen16a: return "IBM 3931 GA1 (migration-safe) (gen16a)"
        case .gen16a_base: return "IBM 3931 GA1 (static, migration-safe) (gen16a-base)"
        case .gen16b: return "IBM 3932 GA1 (migration-safe) (gen16b)"
        case .gen16b_base: return "IBM 3932 GA1 (static, migration-safe) (gen16b-base)"
        case .z10BC: return "IBM System z10 BC GA1 (migration-safe) (z10BC)"
        case .z10BC_base: return "IBM System z10 BC GA1 (static, migration-safe) (z10BC-base)"
        case .z10BC_2: return "IBM System z10 BC GA2 (migration-safe) (z10BC.2)"
        case .z10BC_2_base: return "IBM System z10 BC GA2 (static, migration-safe) (z10BC.2-base)"
        case .z10EC: return "IBM System z10 EC GA1 (migration-safe) (z10EC)"
        case .z10EC_base: return "IBM System z10 EC GA1 (static, migration-safe) (z10EC-base)"
        case .z10EC_2: return "IBM System z10 EC GA2 (migration-safe) (z10EC.2)"
        case .z10EC_2_base: return "IBM System z10 EC GA2 (static, migration-safe) (z10EC.2-base)"
        case .z10EC_3: return "IBM System z10 EC GA3 (migration-safe) (z10EC.3)"
        case .z10EC_3_base: return "IBM System z10 EC GA3 (static, migration-safe) (z10EC.3-base)"
        case .z9BC: return "IBM System z9 BC GA1 (migration-safe) (z9BC)"
        case .z9BC_base: return "IBM System z9 BC GA1 (static, migration-safe) (z9BC-base)"
        case .z9BC_2: return "IBM System z9 BC GA2 (migration-safe) (z9BC.2)"
        case .z9BC_2_base: return "IBM System z9 BC GA2 (static, migration-safe) (z9BC.2-base)"
        case .z9EC: return "IBM System z9 EC GA1 (migration-safe) (z9EC)"
        case .z9EC_base: return "IBM System z9 EC GA1 (static, migration-safe) (z9EC-base)"
        case .z9EC_2: return "IBM System z9 EC GA2 (migration-safe) (z9EC.2)"
        case .z9EC_2_base: return "IBM System z9 EC GA2 (static, migration-safe) (z9EC.2-base)"
        case .z9EC_3: return "IBM System z9 EC GA3 (migration-safe) (z9EC.3)"
        case .z9EC_3_base: return "IBM System z9 EC GA3 (static, migration-safe) (z9EC.3-base)"
        case .z13: return "IBM z13 GA1 (migration-safe) (z13)"
        case .z13_base: return "IBM z13 GA1 (static, migration-safe) (z13-base)"
        case .z13_2: return "IBM z13 GA2 (migration-safe) (z13.2)"
        case .z13_2_base: return "IBM z13 GA2 (static, migration-safe) (z13.2-base)"
        case .z13s: return "IBM z13s GA1 (migration-safe) (z13s)"
        case .z13s_base: return "IBM z13s GA1 (static, migration-safe) (z13s-base)"
        case .z14: return "IBM z14 GA1 (migration-safe) (z14)"
        case .z14_base: return "IBM z14 GA1 (static, migration-safe) (z14-base)"
        case .z14_2: return "IBM z14 GA2 (migration-safe) (z14.2)"
        case .z14_2_base: return "IBM z14 GA2 (static, migration-safe) (z14.2-base)"
        case .z14ZR1: return "IBM z14 Model ZR1 GA1 (migration-safe) (z14ZR1)"
        case .z14ZR1_base: return "IBM z14 Model ZR1 GA1 (static, migration-safe) (z14ZR1-base)"
        case .gen15a: return "IBM z15 T01 GA1 (migration-safe) (gen15a)"
        case .gen15a_base: return "IBM z15 T01 GA1 (static, migration-safe) (gen15a-base)"
        case .gen15b: return "IBM z15 T02 GA1 (migration-safe) (gen15b)"
        case .gen15b_base: return "IBM z15 T02 GA1 (static, migration-safe) (gen15b-base)"
        case .z114: return "IBM zEnterprise 114 GA1 (migration-safe) (z114)"
        case .z114_base: return "IBM zEnterprise 114 GA1 (static, migration-safe) (z114-base)"
        case .z196: return "IBM zEnterprise 196 GA1 (migration-safe) (z196)"
        case .z196_base: return "IBM zEnterprise 196 GA1 (static, migration-safe) (z196-base)"
        case .z196_2: return "IBM zEnterprise 196 GA2 (migration-safe) (z196.2)"
        case .z196_2_base: return "IBM zEnterprise 196 GA2 (static, migration-safe) (z196.2-base)"
        case .zBC12: return "IBM zEnterprise BC12 GA1 (migration-safe) (zBC12)"
        case .zBC12_base: return "IBM zEnterprise BC12 GA1 (static, migration-safe) (zBC12-base)"
        case .zEC12: return "IBM zEnterprise EC12 GA1 (migration-safe) (zEC12)"
        case .zEC12_base: return "IBM zEnterprise EC12 GA1 (static, migration-safe) (zEC12-base)"
        case .zEC12_2: return "IBM zEnterprise EC12 GA2 (migration-safe) (zEC12.2)"
        case .zEC12_2_base: return "IBM zEnterprise EC12 GA2 (static, migration-safe) (zEC12.2-base)"
        case .z800: return "IBM zSeries 800 GA1 (migration-safe) (z800)"
        case .z800_base: return "IBM zSeries 800 GA1 (static, migration-safe) (z800-base)"
        case .z890: return "IBM zSeries 880 GA1 (migration-safe) (z890)"
        case .z890_base: return "IBM zSeries 880 GA1 (static, migration-safe) (z890-base)"
        case .z890_2: return "IBM zSeries 880 GA2 (migration-safe) (z890.2)"
        case .z890_2_base: return "IBM zSeries 880 GA2 (static, migration-safe) (z890.2-base)"
        case .z890_3: return "IBM zSeries 880 GA3 (migration-safe) (z890.3)"
        case .z890_3_base: return "IBM zSeries 880 GA3 (static, migration-safe) (z890.3-base)"
        case .z900: return "IBM zSeries 900 GA1 (migration-safe) (z900)"
        case .z900_base: return "IBM zSeries 900 GA1 (static, migration-safe) (z900-base)"
        case .z900_2: return "IBM zSeries 900 GA2 (migration-safe) (z900.2)"
        case .z900_2_base: return "IBM zSeries 900 GA2 (static, migration-safe) (z900.2-base)"
        case .z900_3: return "IBM zSeries 900 GA3 (migration-safe) (z900.3)"
        case .z900_3_base: return "IBM zSeries 900 GA3 (static, migration-safe) (z900.3-base)"
        case .z990: return "IBM zSeries 990 GA1 (migration-safe) (z990)"
        case .z990_base: return "IBM zSeries 990 GA1 (static, migration-safe) (z990-base)"
        case .z990_2: return "IBM zSeries 990 GA2 (migration-safe) (z990.2)"
        case .z990_2_base: return "IBM zSeries 990 GA2 (static, migration-safe) (z990.2-base)"
        case .z990_3: return "IBM zSeries 990 GA3 (migration-safe) (z990.3)"
        case .z990_3_base: return "IBM zSeries 990 GA3 (static, migration-safe) (z990.3-base)"
        case .z990_4: return "IBM zSeries 990 GA4 (migration-safe) (z990.4)"
        case .z990_4_base: return "IBM zSeries 990 GA4 (static, migration-safe) (z990.4-base)"
        case .z990_5: return "IBM zSeries 990 GA5 (migration-safe) (z990.5)"
        case .z990_5_base: return "IBM zSeries 990 GA5 (static, migration-safe) (z990.5-base)"
        case .qemu: return "QEMU Virtual CPU version 2.5+ (migration-safe) (qemu)"
        }
    }
}

enum QEMUCPU_sh4: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case sh7750r
    case sh7751r
    case sh7785

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .sh7750r: return "sh7750r"
        case .sh7751r: return "sh7751r"
        case .sh7785: return "sh7785"
        }
    }
}

enum QEMUCPU_sh4eb: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case sh7750r
    case sh7751r
    case sh7785

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .sh7750r: return "sh7750r"
        case .sh7751r: return "sh7751r"
        case .sh7785: return "sh7785"
        }
    }
}

enum QEMUCPU_sparc: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case Fujitsu_MB86904_ = "Fujitsu-MB86904     "
    case Fujitsu_MB86907_ = "Fujitsu-MB86907     "
    case LEON2_ = "LEON2               "
    case LEON3_ = "LEON3               "
    case TI_MicroSparc_I_ = "TI-MicroSparc-I     "
    case TI_MicroSparc_II_ = "TI-MicroSparc-II    "
    case TI_MicroSparc_IIep_ = "TI-MicroSparc-IIep  "
    case TI_SuperSparc_40_ = "TI-SuperSparc-40    "
    case TI_SuperSparc_50_ = "TI-SuperSparc-50    "
    case TI_SuperSparc_51_ = "TI-SuperSparc-51    "
    case TI_SuperSparc_60_ = "TI-SuperSparc-60    "
    case TI_SuperSparc_61_ = "TI-SuperSparc-61    "
    case TI_SuperSparc_II_ = "TI-SuperSparc-II    "

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .Fujitsu_MB86904_: return "Fujitsu-MB86904     "
        case .Fujitsu_MB86907_: return "Fujitsu-MB86907     "
        case .LEON2_: return "LEON2               "
        case .LEON3_: return "LEON3               "
        case .TI_MicroSparc_I_: return "TI-MicroSparc-I     "
        case .TI_MicroSparc_II_: return "TI-MicroSparc-II    "
        case .TI_MicroSparc_IIep_: return "TI-MicroSparc-IIep  "
        case .TI_SuperSparc_40_: return "TI-SuperSparc-40    "
        case .TI_SuperSparc_50_: return "TI-SuperSparc-50    "
        case .TI_SuperSparc_51_: return "TI-SuperSparc-51    "
        case .TI_SuperSparc_60_: return "TI-SuperSparc-60    "
        case .TI_SuperSparc_61_: return "TI-SuperSparc-61    "
        case .TI_SuperSparc_II_: return "TI-SuperSparc-II    "
        }
    }
}

enum QEMUCPU_sparc64: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case Fujitsu_Sparc64_ = "Fujitsu-Sparc64     "
    case Fujitsu_Sparc64_III_ = "Fujitsu-Sparc64-III "
    case Fujitsu_Sparc64_IV_ = "Fujitsu-Sparc64-IV  "
    case Fujitsu_Sparc64_V_ = "Fujitsu-Sparc64-V   "
    case NEC_UltraSparc_I_ = "NEC-UltraSparc-I    "
    case Sun_UltraSparc_III_ = "Sun-UltraSparc-III  "
    case Sun_UltraSparc_III_Cu = "Sun-UltraSparc-III-Cu"
    case Sun_UltraSparc_IIIi_ = "Sun-UltraSparc-IIIi "
    case Sun_UltraSparc_IIIi_plus = "Sun-UltraSparc-IIIi-plus"
    case Sun_UltraSparc_IV_ = "Sun-UltraSparc-IV   "
    case Sun_UltraSparc_IV_plus = "Sun-UltraSparc-IV-plus"
    case Sun_UltraSparc_T1_ = "Sun-UltraSparc-T1   "
    case Sun_UltraSparc_T2_ = "Sun-UltraSparc-T2   "
    case TI_UltraSparc_I_ = "TI-UltraSparc-I     "
    case TI_UltraSparc_II_ = "TI-UltraSparc-II    "
    case TI_UltraSparc_IIe_ = "TI-UltraSparc-IIe   "
    case TI_UltraSparc_IIi_ = "TI-UltraSparc-IIi   "

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .Fujitsu_Sparc64_: return "Fujitsu-Sparc64     "
        case .Fujitsu_Sparc64_III_: return "Fujitsu-Sparc64-III "
        case .Fujitsu_Sparc64_IV_: return "Fujitsu-Sparc64-IV  "
        case .Fujitsu_Sparc64_V_: return "Fujitsu-Sparc64-V   "
        case .NEC_UltraSparc_I_: return "NEC-UltraSparc-I    "
        case .Sun_UltraSparc_III_: return "Sun-UltraSparc-III  "
        case .Sun_UltraSparc_III_Cu: return "Sun-UltraSparc-III-Cu"
        case .Sun_UltraSparc_IIIi_: return "Sun-UltraSparc-IIIi "
        case .Sun_UltraSparc_IIIi_plus: return "Sun-UltraSparc-IIIi-plus"
        case .Sun_UltraSparc_IV_: return "Sun-UltraSparc-IV   "
        case .Sun_UltraSparc_IV_plus: return "Sun-UltraSparc-IV-plus"
        case .Sun_UltraSparc_T1_: return "Sun-UltraSparc-T1   "
        case .Sun_UltraSparc_T2_: return "Sun-UltraSparc-T2   "
        case .TI_UltraSparc_I_: return "TI-UltraSparc-I     "
        case .TI_UltraSparc_II_: return "TI-UltraSparc-II    "
        case .TI_UltraSparc_IIe_: return "TI-UltraSparc-IIe   "
        case .TI_UltraSparc_IIi_: return "TI-UltraSparc-IIi   "
        }
    }
}

enum QEMUCPU_tricore: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case tc1796
    case tc1797
    case tc27x
    case tc37x

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .tc1796: return "tc1796"
        case .tc1797: return "tc1797"
        case .tc27x: return "tc27x"
        case .tc37x: return "tc37x"
        }
    }
}

enum QEMUCPU_x86_64: String, CaseIterable, QEMUCPU {
    case _486 = "486"
    case _486_v1 = "486-v1"
    case EPYC_v1 = "EPYC-v1"
    case EPYC_v3 = "EPYC-v3"
    case EPYC_v2 = "EPYC-v2"
    case EPYC_Genoa_v1 = "EPYC-Genoa-v1"
    case EPYC_Milan_v1 = "EPYC-Milan-v1"
    case EPYC_Milan_v2 = "EPYC-Milan-v2"
    case EPYC_Rome_v1 = "EPYC-Rome-v1"
    case EPYC_Rome_v2 = "EPYC-Rome-v2"
    case EPYC_Rome_v3 = "EPYC-Rome-v3"
    case EPYC_Rome_v4 = "EPYC-Rome-v4"
    case EPYC_v4 = "EPYC-v4"
    case Opteron_G2_v1 = "Opteron_G2-v1"
    case Opteron_G3_v1 = "Opteron_G3-v1"
    case Opteron_G1_v1 = "Opteron_G1-v1"
    case Opteron_G4_v1 = "Opteron_G4-v1"
    case Opteron_G5_v1 = "Opteron_G5-v1"
    case phenom_v1 = "phenom-v1"
    case Broadwell
    case Broadwell_IBRS = "Broadwell-IBRS"
    case Broadwell_noTSX = "Broadwell-noTSX"
    case Broadwell_noTSX_IBRS = "Broadwell-noTSX-IBRS"
    case Cascadelake_Server = "Cascadelake-Server"
    case Cascadelake_Server_noTSX = "Cascadelake-Server-noTSX"
    case kvm32_v1 = "kvm32-v1"
    case kvm64_v1 = "kvm64-v1"
    case Conroe
    case Cooperlake
    case `default` = "default"
    case Denverton
    case Dhyana
    case EPYC
    case EPYC_Genoa = "EPYC-Genoa"
    case EPYC_IBPB = "EPYC-IBPB"
    case EPYC_Milan = "EPYC-Milan"
    case EPYC_Rome = "EPYC-Rome"
    case max
    case coreduo_v1 = "coreduo-v1"
    case GraniteRapids
    case Haswell
    case Haswell_IBRS = "Haswell-IBRS"
    case Haswell_noTSX = "Haswell-noTSX"
    case Haswell_noTSX_IBRS = "Haswell-noTSX-IBRS"
    case Dhyana_v1 = "Dhyana-v1"
    case Dhyana_v2 = "Dhyana-v2"
    case Icelake_Server = "Icelake-Server"
    case Icelake_Server_noTSX = "Icelake-Server-noTSX"
    case Denverton_v1 = "Denverton-v1"
    case Denverton_v3 = "Denverton-v3"
    case Denverton_v2 = "Denverton-v2"
    case Snowridge_v1 = "Snowridge-v1"
    case Snowridge_v2 = "Snowridge-v2"
    case Snowridge_v3 = "Snowridge-v3"
    case Snowridge_v4 = "Snowridge-v4"
    case Conroe_v1 = "Conroe-v1"
    case Penryn_v1 = "Penryn-v1"
    case Broadwell_v1 = "Broadwell-v1"
    case Broadwell_v3 = "Broadwell-v3"
    case Broadwell_v2 = "Broadwell-v2"
    case Broadwell_v4 = "Broadwell-v4"
    case Haswell_v1 = "Haswell-v1"
    case Haswell_v3 = "Haswell-v3"
    case Haswell_v2 = "Haswell-v2"
    case Haswell_v4 = "Haswell-v4"
    case Skylake_Client_v1 = "Skylake-Client-v1"
    case Skylake_Client_v2 = "Skylake-Client-v2"
    case Skylake_Client_v3 = "Skylake-Client-v3"
    case Skylake_Client_v4 = "Skylake-Client-v4"
    case Nehalem_v1 = "Nehalem-v1"
    case Nehalem_v2 = "Nehalem-v2"
    case IvyBridge_v1 = "IvyBridge-v1"
    case IvyBridge_v2 = "IvyBridge-v2"
    case SandyBridge_v1 = "SandyBridge-v1"
    case SandyBridge_v2 = "SandyBridge-v2"
    case KnightsMill_v1 = "KnightsMill-v1"
    case Cascadelake_Server_v1 = "Cascadelake-Server-v1"
    case Cascadelake_Server_v5 = "Cascadelake-Server-v5"
    case Cascadelake_Server_v3 = "Cascadelake-Server-v3"
    case Cascadelake_Server_v4 = "Cascadelake-Server-v4"
    case Cascadelake_Server_v2 = "Cascadelake-Server-v2"
    case Cooperlake_v1 = "Cooperlake-v1"
    case Cooperlake_v2 = "Cooperlake-v2"
    case GraniteRapids_v1 = "GraniteRapids-v1"
    case Icelake_Server_v1 = "Icelake-Server-v1"
    case Icelake_Server_v3 = "Icelake-Server-v3"
    case Icelake_Server_v4 = "Icelake-Server-v4"
    case Icelake_Server_v6 = "Icelake-Server-v6"
    case Icelake_Server_v7 = "Icelake-Server-v7"
    case Icelake_Server_v5 = "Icelake-Server-v5"
    case Icelake_Server_v2 = "Icelake-Server-v2"
    case SapphireRapids_v1 = "SapphireRapids-v1"
    case SapphireRapids_v2 = "SapphireRapids-v2"
    case SapphireRapids_v3 = "SapphireRapids-v3"
    case SierraForest_v1 = "SierraForest-v1"
    case Skylake_Server_v1 = "Skylake-Server-v1"
    case Skylake_Server_v2 = "Skylake-Server-v2"
    case Skylake_Server_v3 = "Skylake-Server-v3"
    case Skylake_Server_v4 = "Skylake-Server-v4"
    case Skylake_Server_v5 = "Skylake-Server-v5"
    case n270_v1 = "n270-v1"
    case core2duo_v1 = "core2duo-v1"
    case IvyBridge
    case IvyBridge_IBRS = "IvyBridge-IBRS"
    case KnightsMill
    case Nehalem
    case Nehalem_IBRS = "Nehalem-IBRS"
    case Opteron_G1
    case Opteron_G2
    case Opteron_G3
    case Opteron_G4
    case Opteron_G5
    case Penryn
    case athlon_v1 = "athlon-v1"
    case qemu32_v1 = "qemu32-v1"
    case qemu64_v1 = "qemu64-v1"
    case SandyBridge
    case SandyBridge_IBRS = "SandyBridge-IBRS"
    case SapphireRapids
    case SierraForest
    case Skylake_Client = "Skylake-Client"
    case Skylake_Client_IBRS = "Skylake-Client-IBRS"
    case Skylake_Client_noTSX_IBRS = "Skylake-Client-noTSX-IBRS"
    case Skylake_Server = "Skylake-Server"
    case Skylake_Server_IBRS = "Skylake-Server-IBRS"
    case Skylake_Server_noTSX_IBRS = "Skylake-Server-noTSX-IBRS"
    case Snowridge
    case Westmere
    case Westmere_v2 = "Westmere-v2"
    case Westmere_v1 = "Westmere-v1"
    case Westmere_IBRS = "Westmere-IBRS"
    case athlon
    case base
    case core2duo
    case coreduo
    case kvm32
    case kvm64
    case n270
    case pentium
    case pentium_v1 = "pentium-v1"
    case pentium2
    case pentium2_v1 = "pentium2-v1"
    case pentium3
    case pentium3_v1 = "pentium3-v1"
    case phenom
    case qemu32
    case qemu64

    var prettyValue: String {
        switch self {
        case ._486: return "486"
        case ._486_v1: return "486-v1"
        case .EPYC_v1: return "AMD EPYC Processor (EPYC-v1)"
        case .EPYC_v3: return "AMD EPYC Processor (EPYC-v3)"
        case .EPYC_v2: return "AMD EPYC Processor (with IBPB) (EPYC-v2)"
        case .EPYC_Genoa_v1: return "AMD EPYC-Genoa Processor (EPYC-Genoa-v1)"
        case .EPYC_Milan_v1: return "AMD EPYC-Milan Processor (EPYC-Milan-v1)"
        case .EPYC_Milan_v2: return "AMD EPYC-Milan-v2 Processor (EPYC-Milan-v2)"
        case .EPYC_Rome_v1: return "AMD EPYC-Rome Processor (EPYC-Rome-v1)"
        case .EPYC_Rome_v2: return "AMD EPYC-Rome Processor (EPYC-Rome-v2)"
        case .EPYC_Rome_v3: return "AMD EPYC-Rome-v3 Processor (EPYC-Rome-v3)"
        case .EPYC_Rome_v4: return "AMD EPYC-Rome-v4 Processor (no XSAVES) (EPYC-Rome-v4)"
        case .EPYC_v4: return "AMD EPYC-v4 Processor (EPYC-v4)"
        case .Opteron_G2_v1: return "AMD Opteron 22xx (Gen 2 Class Opteron) (Opteron_G2-v1)"
        case .Opteron_G3_v1: return "AMD Opteron 23xx (Gen 3 Class Opteron) (Opteron_G3-v1)"
        case .Opteron_G1_v1: return "AMD Opteron 240 (Gen 1 Class Opteron) (Opteron_G1-v1)"
        case .Opteron_G4_v1: return "AMD Opteron 62xx class CPU (Opteron_G4-v1)"
        case .Opteron_G5_v1: return "AMD Opteron 63xx class CPU (Opteron_G5-v1)"
        case .phenom_v1: return "AMD Phenom(tm) 9550 Quad-Core Processor (phenom-v1)"
        case .Broadwell: return "Broadwell"
        case .Broadwell_IBRS: return "Broadwell-IBRS"
        case .Broadwell_noTSX: return "Broadwell-noTSX"
        case .Broadwell_noTSX_IBRS: return "Broadwell-noTSX-IBRS"
        case .Cascadelake_Server: return "Cascadelake-Server"
        case .Cascadelake_Server_noTSX: return "Cascadelake-Server-noTSX"
        case .kvm32_v1: return "Common 32-bit KVM processor (kvm32-v1)"
        case .kvm64_v1: return "Common KVM processor (kvm64-v1)"
        case .Conroe: return "Conroe"
        case .Cooperlake: return "Cooperlake"
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .Denverton: return "Denverton"
        case .Dhyana: return "Dhyana"
        case .EPYC: return "EPYC"
        case .EPYC_Genoa: return "EPYC-Genoa"
        case .EPYC_IBPB: return "EPYC-IBPB"
        case .EPYC_Milan: return "EPYC-Milan"
        case .EPYC_Rome: return "EPYC-Rome"
        case .max: return "Enables all features supported by the accelerator in the current host (max)"
        case .coreduo_v1: return "Genuine Intel(R) CPU T2600 @ 2.16GHz (coreduo-v1)"
        case .GraniteRapids: return "GraniteRapids"
        case .Haswell: return "Haswell"
        case .Haswell_IBRS: return "Haswell-IBRS"
        case .Haswell_noTSX: return "Haswell-noTSX"
        case .Haswell_noTSX_IBRS: return "Haswell-noTSX-IBRS"
        case .Dhyana_v1: return "Hygon Dhyana Processor (Dhyana-v1)"
        case .Dhyana_v2: return "Hygon Dhyana Processor [XSAVES] (Dhyana-v2)"
        case .Icelake_Server: return "Icelake-Server"
        case .Icelake_Server_noTSX: return "Icelake-Server-noTSX"
        case .Denverton_v1: return "Intel Atom Processor (Denverton) (Denverton-v1)"
        case .Denverton_v3: return "Intel Atom Processor (Denverton) [XSAVES, no MPX, no MONITOR] (Denverton-v3)"
        case .Denverton_v2: return "Intel Atom Processor (Denverton) [no MPX, no MONITOR] (Denverton-v2)"
        case .Snowridge_v1: return "Intel Atom Processor (SnowRidge) (Snowridge-v1)"
        case .Snowridge_v2: return "Intel Atom Processor (Snowridge, no MPX) (Snowridge-v2)"
        case .Snowridge_v3: return "Intel Atom Processor (Snowridge, no MPX) [XSAVES, no MPX] (Snowridge-v3)"
        case .Snowridge_v4: return "Intel Atom Processor (Snowridge, no MPX) [no split lock detect, no core-capability] (Snowridge-v4)"
        case .Conroe_v1: return "Intel Celeron_4x0 (Conroe/Merom Class Core 2) (Conroe-v1)"
        case .Penryn_v1: return "Intel Core 2 Duo P9xxx (Penryn Class Core 2) (Penryn-v1)"
        case .Broadwell_v1: return "Intel Core Processor (Broadwell) (Broadwell-v1)"
        case .Broadwell_v3: return "Intel Core Processor (Broadwell, IBRS) (Broadwell-v3)"
        case .Broadwell_v2: return "Intel Core Processor (Broadwell, no TSX) (Broadwell-v2)"
        case .Broadwell_v4: return "Intel Core Processor (Broadwell, no TSX, IBRS) (Broadwell-v4)"
        case .Haswell_v1: return "Intel Core Processor (Haswell) (Haswell-v1)"
        case .Haswell_v3: return "Intel Core Processor (Haswell, IBRS) (Haswell-v3)"
        case .Haswell_v2: return "Intel Core Processor (Haswell, no TSX) (Haswell-v2)"
        case .Haswell_v4: return "Intel Core Processor (Haswell, no TSX, IBRS) (Haswell-v4)"
        case .Skylake_Client_v1: return "Intel Core Processor (Skylake) (Skylake-Client-v1)"
        case .Skylake_Client_v2: return "Intel Core Processor (Skylake, IBRS) (Skylake-Client-v2)"
        case .Skylake_Client_v3: return "Intel Core Processor (Skylake, IBRS, no TSX) (Skylake-Client-v3)"
        case .Skylake_Client_v4: return "Intel Core Processor (Skylake, IBRS, no TSX) [IBRS, XSAVES, no TSX] (Skylake-Client-v4)"
        case .Nehalem_v1: return "Intel Core i7 9xx (Nehalem Class Core i7) (Nehalem-v1)"
        case .Nehalem_v2: return "Intel Core i7 9xx (Nehalem Core i7, IBRS update) (Nehalem-v2)"
        case .IvyBridge_v1: return "Intel Xeon E3-12xx v2 (Ivy Bridge) (IvyBridge-v1)"
        case .IvyBridge_v2: return "Intel Xeon E3-12xx v2 (Ivy Bridge, IBRS) (IvyBridge-v2)"
        case .SandyBridge_v1: return "Intel Xeon E312xx (Sandy Bridge) (SandyBridge-v1)"
        case .SandyBridge_v2: return "Intel Xeon E312xx (Sandy Bridge, IBRS update) (SandyBridge-v2)"
        case .KnightsMill_v1: return "Intel Xeon Phi Processor (Knights Mill) (KnightsMill-v1)"
        case .Cascadelake_Server_v1: return "Intel Xeon Processor (Cascadelake) (Cascadelake-Server-v1)"
        case .Cascadelake_Server_v5: return "Intel Xeon Processor (Cascadelake) [ARCH_CAPABILITIES, EPT switching, XSAVES, no TSX] (Cascadelake-Server-v5)"
        case .Cascadelake_Server_v3: return "Intel Xeon Processor (Cascadelake) [ARCH_CAPABILITIES, no TSX] (Cascadelake-Server-v3)"
        case .Cascadelake_Server_v4: return "Intel Xeon Processor (Cascadelake) [ARCH_CAPABILITIES, no TSX] (Cascadelake-Server-v4)"
        case .Cascadelake_Server_v2: return "Intel Xeon Processor (Cascadelake) [ARCH_CAPABILITIES] (Cascadelake-Server-v2)"
        case .Cooperlake_v1: return "Intel Xeon Processor (Cooperlake) (Cooperlake-v1)"
        case .Cooperlake_v2: return "Intel Xeon Processor (Cooperlake) [XSAVES] (Cooperlake-v2)"
        case .GraniteRapids_v1: return "Intel Xeon Processor (GraniteRapids) (GraniteRapids-v1)"
        case .Icelake_Server_v1: return "Intel Xeon Processor (Icelake) (Icelake-Server-v1)"
        case .Icelake_Server_v3: return "Intel Xeon Processor (Icelake) (Icelake-Server-v3)"
        case .Icelake_Server_v4: return "Intel Xeon Processor (Icelake) (Icelake-Server-v4)"
        case .Icelake_Server_v6: return "Intel Xeon Processor (Icelake) [5-level EPT] (Icelake-Server-v6)"
        case .Icelake_Server_v7: return "Intel Xeon Processor (Icelake) [TSX, taa-no] (Icelake-Server-v7)"
        case .Icelake_Server_v5: return "Intel Xeon Processor (Icelake) [XSAVES] (Icelake-Server-v5)"
        case .Icelake_Server_v2: return "Intel Xeon Processor (Icelake) [no TSX] (Icelake-Server-v2)"
        case .SapphireRapids_v1: return "Intel Xeon Processor (SapphireRapids) (SapphireRapids-v1)"
        case .SapphireRapids_v2: return "Intel Xeon Processor (SapphireRapids) (SapphireRapids-v2)"
        case .SapphireRapids_v3: return "Intel Xeon Processor (SapphireRapids) (SapphireRapids-v3)"
        case .SierraForest_v1: return "Intel Xeon Processor (SierraForest) (SierraForest-v1)"
        case .Skylake_Server_v1: return "Intel Xeon Processor (Skylake) (Skylake-Server-v1)"
        case .Skylake_Server_v2: return "Intel Xeon Processor (Skylake, IBRS) (Skylake-Server-v2)"
        case .Skylake_Server_v3: return "Intel Xeon Processor (Skylake, IBRS, no TSX) (Skylake-Server-v3)"
        case .Skylake_Server_v4: return "Intel Xeon Processor (Skylake, IBRS, no TSX) (Skylake-Server-v4)"
        case .Skylake_Server_v5: return "Intel Xeon Processor (Skylake, IBRS, no TSX) [IBRS, XSAVES, EPT switching, no TSX] (Skylake-Server-v5)"
        case .n270_v1: return "Intel(R) Atom(TM) CPU N270 @ 1.60GHz (n270-v1)"
        case .core2duo_v1: return "Intel(R) Core(TM)2 Duo CPU T7700 @ 2.40GHz (core2duo-v1)"
        case .IvyBridge: return "IvyBridge"
        case .IvyBridge_IBRS: return "IvyBridge-IBRS"
        case .KnightsMill: return "KnightsMill"
        case .Nehalem: return "Nehalem"
        case .Nehalem_IBRS: return "Nehalem-IBRS"
        case .Opteron_G1: return "Opteron_G1"
        case .Opteron_G2: return "Opteron_G2"
        case .Opteron_G3: return "Opteron_G3"
        case .Opteron_G4: return "Opteron_G4"
        case .Opteron_G5: return "Opteron_G5"
        case .Penryn: return "Penryn"
        case .athlon_v1: return "QEMU Virtual CPU version 2.5+ (athlon-v1)"
        case .qemu32_v1: return "QEMU Virtual CPU version 2.5+ (qemu32-v1)"
        case .qemu64_v1: return "QEMU Virtual CPU version 2.5+ (qemu64-v1)"
        case .SandyBridge: return "SandyBridge"
        case .SandyBridge_IBRS: return "SandyBridge-IBRS"
        case .SapphireRapids: return "SapphireRapids"
        case .SierraForest: return "SierraForest"
        case .Skylake_Client: return "Skylake-Client"
        case .Skylake_Client_IBRS: return "Skylake-Client-IBRS"
        case .Skylake_Client_noTSX_IBRS: return "Skylake-Client-noTSX-IBRS"
        case .Skylake_Server: return "Skylake-Server"
        case .Skylake_Server_IBRS: return "Skylake-Server-IBRS"
        case .Skylake_Server_noTSX_IBRS: return "Skylake-Server-noTSX-IBRS"
        case .Snowridge: return "Snowridge"
        case .Westmere: return "Westmere"
        case .Westmere_v2: return "Westmere E56xx/L56xx/X56xx (IBRS update) (Westmere-v2)"
        case .Westmere_v1: return "Westmere E56xx/L56xx/X56xx (Nehalem-C) (Westmere-v1)"
        case .Westmere_IBRS: return "Westmere-IBRS"
        case .athlon: return "athlon"
        case .base: return "base CPU model type with no features enabled (base)"
        case .core2duo: return "core2duo"
        case .coreduo: return "coreduo"
        case .kvm32: return "kvm32"
        case .kvm64: return "kvm64"
        case .n270: return "n270"
        case .pentium: return "pentium"
        case .pentium_v1: return "pentium-v1"
        case .pentium2: return "pentium2"
        case .pentium2_v1: return "pentium2-v1"
        case .pentium3: return "pentium3"
        case .pentium3_v1: return "pentium3-v1"
        case .phenom: return "phenom"
        case .qemu32: return "qemu32"
        case .qemu64: return "qemu64"
        }
    }
}

enum QEMUCPU_xtensa: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case dc232b
    case dc233c
    case de212
    case de233_fpu
    case dsp3400
    case lx106
    case sample_controller
    case test_mmuhifi_c3

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .dc232b: return "dc232b"
        case .dc233c: return "dc233c"
        case .de212: return "de212"
        case .de233_fpu: return "de233_fpu"
        case .dsp3400: return "dsp3400"
        case .lx106: return "lx106"
        case .sample_controller: return "sample_controller"
        case .test_mmuhifi_c3: return "test_mmuhifi_c3"
        }
    }
}

enum QEMUCPU_xtensaeb: String, CaseIterable, QEMUCPU {
    case `default` = "default"
    case fsf
    case test_kc705_be

    var prettyValue: String {
        switch self {
        case .`default`: return NSLocalizedString("Default", comment: "QEMUConstantGenerated")
        case .fsf: return "fsf"
        case .test_kc705_be: return "test_kc705_be"
        }
    }
}

typealias QEMUCPUFlag_alpha = AnyQEMUConstant

typealias QEMUCPUFlag_arm = AnyQEMUConstant

typealias QEMUCPUFlag_aarch64 = AnyQEMUConstant

typealias QEMUCPUFlag_avr = AnyQEMUConstant

typealias QEMUCPUFlag_cris = AnyQEMUConstant

typealias QEMUCPUFlag_hppa = AnyQEMUConstant

enum QEMUCPUFlag_i386: String, CaseIterable, QEMUCPUFlag {
    case _3dnow = "3dnow"
    case _3dnowext = "3dnowext"
    case _3dnowprefetch = "3dnowprefetch"
    case abm
    case ace2
    case ace2_en = "ace2-en"
    case acpi
    case adx
    case aes
    case amd_no_ssb = "amd-no-ssb"
    case amd_psfd = "amd-psfd"
    case amd_ssbd = "amd-ssbd"
    case amd_stibp = "amd-stibp"
    case amx_bf16 = "amx-bf16"
    case amx_complex = "amx-complex"
    case amx_fp16 = "amx-fp16"
    case amx_int8 = "amx-int8"
    case amx_tile = "amx-tile"
    case apic
    case arat
    case arch_capabilities = "arch-capabilities"
    case arch_lbr = "arch-lbr"
    case auto_ibrs = "auto-ibrs"
    case avic
    case avx
    case avx_ifma = "avx-ifma"
    case avx_ne_convert = "avx-ne-convert"
    case avx_vnni = "avx-vnni"
    case avx_vnni_int16 = "avx-vnni-int16"
    case avx_vnni_int8 = "avx-vnni-int8"
    case avx2
    case avx512_4fmaps = "avx512-4fmaps"
    case avx512_4vnniw = "avx512-4vnniw"
    case avx512_bf16 = "avx512-bf16"
    case avx512_fp16 = "avx512-fp16"
    case avx512_vp2intersect = "avx512-vp2intersect"
    case avx512_vpopcntdq = "avx512-vpopcntdq"
    case avx512bitalg
    case avx512bw
    case avx512cd
    case avx512dq
    case avx512er
    case avx512f
    case avx512ifma
    case avx512pf
    case avx512vbmi
    case avx512vbmi2
    case avx512vl
    case avx512vnni
    case bmi1
    case bmi2
    case bus_lock_detect = "bus-lock-detect"
    case cid
    case cldemote
    case clflush
    case clflushopt
    case clwb
    case clzero
    case cmov
    case cmp_legacy = "cmp-legacy"
    case cmpccxadd
    case core_capability = "core-capability"
    case cr8legacy
    case cx16
    case cx8
    case dca
    case de
    case decodeassists
    case ds
    case ds_cpl = "ds-cpl"
    case dtes64
    case erms
    case est
    case extapic
    case f16c
    case fb_clear = "fb-clear"
    case fbsdp_no = "fbsdp-no"
    case flush_l1d = "flush-l1d"
    case flushbyasid
    case fma
    case fma4
    case fpu
    case fred
    case fsgsbase
    case fsrc
    case fsrm
    case fsrs
    case full_width_write = "full-width-write"
    case fxsr
    case fxsr_opt = "fxsr-opt"
    case fzrm
    case gds_no = "gds-no"
    case gfni
    case hle
    case ht
    case hypervisor
    case ia64
    case ibpb
    case ibrs
    case ibrs_all = "ibrs-all"
    case ibs
    case intel_pt = "intel-pt"
    case intel_pt_lip = "intel-pt-lip"
    case invpcid
    case invtsc
    case kvm_asyncpf = "kvm-asyncpf"
    case kvm_asyncpf_int = "kvm-asyncpf-int"
    case kvm_asyncpf_vmexit = "kvm-asyncpf-vmexit"
    case kvm_hint_dedicated = "kvm-hint-dedicated"
    case kvm_mmu = "kvm-mmu"
    case kvm_msi_ext_dest_id = "kvm-msi-ext-dest-id"
    case kvm_nopiodelay = "kvm-nopiodelay"
    case kvm_poll_control = "kvm-poll-control"
    case kvm_pv_eoi = "kvm-pv-eoi"
    case kvm_pv_ipi = "kvm-pv-ipi"
    case kvm_pv_sched_yield = "kvm-pv-sched-yield"
    case kvm_pv_tlb_flush = "kvm-pv-tlb-flush"
    case kvm_pv_unhalt = "kvm-pv-unhalt"
    case kvm_steal_time = "kvm-steal-time"
    case kvmclock
    case kvmclock_stable_bit = "kvmclock-stable-bit"
    case la57
    case lahf_lm = "lahf-lm"
    case lam
    case lbrv
    case lfence_always_serializing = "lfence-always-serializing"
    case lkgs
    case lm
    case lwp
    case mca
    case mcdt_no = "mcdt-no"
    case mce
    case md_clear = "md-clear"
    case mds_no = "mds-no"
    case misalignsse
    case mmx
    case mmxext
    case monitor
    case movbe
    case movdir64b
    case movdiri
    case mpx
    case msr
    case mtrr
    case no_nested_data_bp = "no-nested-data-bp"
    case nodeid_msr = "nodeid-msr"
    case npt
    case nrip_save = "nrip-save"
    case null_sel_clr_base = "null-sel-clr-base"
    case nx
    case osvw
    case overflow_recov = "overflow-recov"
    case pae
    case pat
    case pause_filter = "pause-filter"
    case pbe
    case pbrsb_no = "pbrsb-no"
    case pcid
    case pclmulqdq
    case pcommit
    case pdcm
    case pdpe1gb
    case perfctr_core = "perfctr-core"
    case perfctr_nb = "perfctr-nb"
    case pfthreshold
    case pge
    case phe
    case phe_en = "phe-en"
    case pks
    case pku
    case pmm
    case pmm_en = "pmm-en"
    case pn
    case pni
    case popcnt
    case prefetchiti
    case pschange_mc_no = "pschange-mc-no"
    case psdp_no = "psdp-no"
    case pse
    case pse36
    case rdctl_no = "rdctl-no"
    case rdpid
    case rdrand
    case rdseed
    case rdtscp
    case rfds_clear = "rfds-clear"
    case rfds_no = "rfds-no"
    case rsba
    case rtm
    case sbdr_ssdp_no = "sbdr-ssdp-no"
    case sep
    case serialize
    case sgx
    case sgx_aex_notify = "sgx-aex-notify"
    case sgx_debug = "sgx-debug"
    case sgx_edeccssa = "sgx-edeccssa"
    case sgx_exinfo = "sgx-exinfo"
    case sgx_kss = "sgx-kss"
    case sgx_mode64 = "sgx-mode64"
    case sgx_provisionkey = "sgx-provisionkey"
    case sgx_tokenkey = "sgx-tokenkey"
    case sgx1
    case sgx2
    case sgxlc
    case sha_ni = "sha-ni"
    case skinit
    case skip_l1dfl_vmentry = "skip-l1dfl-vmentry"
    case smap
    case smep
    case smx
    case spec_ctrl = "spec-ctrl"
    case split_lock_detect = "split-lock-detect"
    case ss
    case ssb_no = "ssb-no"
    case ssbd
    case sse
    case sse2
    case sse4_1 = "sse4.1"
    case sse4_2 = "sse4.2"
    case sse4a
    case ssse3
    case stibp
    case stibp_always_on = "stibp-always-on"
    case succor
    case svm
    case svm_lock = "svm-lock"
    case svme_addr_chk = "svme-addr-chk"
    case syscall
    case taa_no = "taa-no"
    case tbm
    case tce
    case tm
    case tm2
    case topoext
    case tsc
    case tsc_adjust = "tsc-adjust"
    case tsc_deadline = "tsc-deadline"
    case tsc_scale = "tsc-scale"
    case tsx_ctrl = "tsx-ctrl"
    case tsx_ldtrk = "tsx-ldtrk"
    case umip
    case v_vmsave_vmload = "v-vmsave-vmload"
    case vaes
    case vgif
    case virt_ssbd = "virt-ssbd"
    case vmcb_clean = "vmcb-clean"
    case vme
    case vmx
    case vmx_activity_hlt = "vmx-activity-hlt"
    case vmx_activity_shutdown = "vmx-activity-shutdown"
    case vmx_activity_wait_sipi = "vmx-activity-wait-sipi"
    case vmx_any_errcode = "vmx-any-errcode"
    case vmx_apicv_register = "vmx-apicv-register"
    case vmx_apicv_vid = "vmx-apicv-vid"
    case vmx_apicv_x2apic = "vmx-apicv-x2apic"
    case vmx_apicv_xapic = "vmx-apicv-xapic"
    case vmx_cr3_load_noexit = "vmx-cr3-load-noexit"
    case vmx_cr3_store_noexit = "vmx-cr3-store-noexit"
    case vmx_cr8_load_exit = "vmx-cr8-load-exit"
    case vmx_cr8_store_exit = "vmx-cr8-store-exit"
    case vmx_desc_exit = "vmx-desc-exit"
    case vmx_enable_user_wait_pause = "vmx-enable-user-wait-pause"
    case vmx_encls_exit = "vmx-encls-exit"
    case vmx_entry_ia32e_mode = "vmx-entry-ia32e-mode"
    case vmx_entry_load_bndcfgs = "vmx-entry-load-bndcfgs"
    case vmx_entry_load_efer = "vmx-entry-load-efer"
    case vmx_entry_load_pat = "vmx-entry-load-pat"
    case vmx_entry_load_perf_global_ctrl = "vmx-entry-load-perf-global-ctrl"
    case vmx_entry_load_pkrs = "vmx-entry-load-pkrs"
    case vmx_entry_load_rtit_ctl = "vmx-entry-load-rtit-ctl"
    case vmx_entry_noload_debugctl = "vmx-entry-noload-debugctl"
    case vmx_ept = "vmx-ept"
    case vmx_ept_1gb = "vmx-ept-1gb"
    case vmx_ept_2mb = "vmx-ept-2mb"
    case vmx_ept_advanced_exitinfo = "vmx-ept-advanced-exitinfo"
    case vmx_ept_execonly = "vmx-ept-execonly"
    case vmx_eptad = "vmx-eptad"
    case vmx_eptp_switching = "vmx-eptp-switching"
    case vmx_exit_ack_intr = "vmx-exit-ack-intr"
    case vmx_exit_clear_bndcfgs = "vmx-exit-clear-bndcfgs"
    case vmx_exit_clear_rtit_ctl = "vmx-exit-clear-rtit-ctl"
    case vmx_exit_load_efer = "vmx-exit-load-efer"
    case vmx_exit_load_pat = "vmx-exit-load-pat"
    case vmx_exit_load_perf_global_ctrl = "vmx-exit-load-perf-global-ctrl"
    case vmx_exit_load_pkrs = "vmx-exit-load-pkrs"
    case vmx_exit_nosave_debugctl = "vmx-exit-nosave-debugctl"
    case vmx_exit_save_efer = "vmx-exit-save-efer"
    case vmx_exit_save_pat = "vmx-exit-save-pat"
    case vmx_exit_save_preemption_timer = "vmx-exit-save-preemption-timer"
    case vmx_flexpriority = "vmx-flexpriority"
    case vmx_hlt_exit = "vmx-hlt-exit"
    case vmx_ins_outs = "vmx-ins-outs"
    case vmx_intr_exit = "vmx-intr-exit"
    case vmx_invept = "vmx-invept"
    case vmx_invept_all_context = "vmx-invept-all-context"
    case vmx_invept_single_context = "vmx-invept-single-context"
    case vmx_invept_single_context_noglobals = "vmx-invept-single-context-noglobals"
    case vmx_invlpg_exit = "vmx-invlpg-exit"
    case vmx_invpcid_exit = "vmx-invpcid-exit"
    case vmx_invvpid = "vmx-invvpid"
    case vmx_invvpid_all_context = "vmx-invvpid-all-context"
    case vmx_invvpid_single_addr = "vmx-invvpid-single-addr"
    case vmx_io_bitmap = "vmx-io-bitmap"
    case vmx_io_exit = "vmx-io-exit"
    case vmx_monitor_exit = "vmx-monitor-exit"
    case vmx_movdr_exit = "vmx-movdr-exit"
    case vmx_msr_bitmap = "vmx-msr-bitmap"
    case vmx_mtf = "vmx-mtf"
    case vmx_mwait_exit = "vmx-mwait-exit"
    case vmx_nested_exception = "vmx-nested-exception"
    case vmx_nmi_exit = "vmx-nmi-exit"
    case vmx_page_walk_4 = "vmx-page-walk-4"
    case vmx_page_walk_5 = "vmx-page-walk-5"
    case vmx_pause_exit = "vmx-pause-exit"
    case vmx_ple = "vmx-ple"
    case vmx_pml = "vmx-pml"
    case vmx_posted_intr = "vmx-posted-intr"
    case vmx_preemption_timer = "vmx-preemption-timer"
    case vmx_rdpmc_exit = "vmx-rdpmc-exit"
    case vmx_rdrand_exit = "vmx-rdrand-exit"
    case vmx_rdseed_exit = "vmx-rdseed-exit"
    case vmx_rdtsc_exit = "vmx-rdtsc-exit"
    case vmx_rdtscp_exit = "vmx-rdtscp-exit"
    case vmx_secondary_ctls = "vmx-secondary-ctls"
    case vmx_shadow_vmcs = "vmx-shadow-vmcs"
    case vmx_store_lma = "vmx-store-lma"
    case vmx_true_ctls = "vmx-true-ctls"
    case vmx_tsc_offset = "vmx-tsc-offset"
    case vmx_tsc_scaling = "vmx-tsc-scaling"
    case vmx_unrestricted_guest = "vmx-unrestricted-guest"
    case vmx_vintr_pending = "vmx-vintr-pending"
    case vmx_vmfunc = "vmx-vmfunc"
    case vmx_vmwrite_vmexit_fields = "vmx-vmwrite-vmexit-fields"
    case vmx_vnmi = "vmx-vnmi"
    case vmx_vnmi_pending = "vmx-vnmi-pending"
    case vmx_vpid = "vmx-vpid"
    case vmx_wbinvd_exit = "vmx-wbinvd-exit"
    case vmx_xsaves = "vmx-xsaves"
    case vmx_zero_len_inject = "vmx-zero-len-inject"
    case vnmi
    case vpclmulqdq
    case waitpkg
    case wbnoinvd
    case wdt
    case wrmsrns
    case x2apic
    case xcrypt
    case xcrypt_en = "xcrypt-en"
    case xfd
    case xgetbv1
    case xop
    case xsave
    case xsavec
    case xsaveerptr
    case xsaveopt
    case xsaves
    case xstore
    case xstore_en = "xstore-en"
    case xtpr

    var prettyValue: String {
        switch self {
        case ._3dnow: return "3dnow"
        case ._3dnowext: return "3dnowext"
        case ._3dnowprefetch: return "3dnowprefetch"
        case .abm: return "abm"
        case .ace2: return "ace2"
        case .ace2_en: return "ace2-en"
        case .acpi: return "acpi"
        case .adx: return "adx"
        case .aes: return "aes"
        case .amd_no_ssb: return "amd-no-ssb"
        case .amd_psfd: return "amd-psfd"
        case .amd_ssbd: return "amd-ssbd"
        case .amd_stibp: return "amd-stibp"
        case .amx_bf16: return "amx-bf16"
        case .amx_complex: return "amx-complex"
        case .amx_fp16: return "amx-fp16"
        case .amx_int8: return "amx-int8"
        case .amx_tile: return "amx-tile"
        case .apic: return "apic"
        case .arat: return "arat"
        case .arch_capabilities: return "arch-capabilities"
        case .arch_lbr: return "arch-lbr"
        case .auto_ibrs: return "auto-ibrs"
        case .avic: return "avic"
        case .avx: return "avx"
        case .avx_ifma: return "avx-ifma"
        case .avx_ne_convert: return "avx-ne-convert"
        case .avx_vnni: return "avx-vnni"
        case .avx_vnni_int16: return "avx-vnni-int16"
        case .avx_vnni_int8: return "avx-vnni-int8"
        case .avx2: return "avx2"
        case .avx512_4fmaps: return "avx512-4fmaps"
        case .avx512_4vnniw: return "avx512-4vnniw"
        case .avx512_bf16: return "avx512-bf16"
        case .avx512_fp16: return "avx512-fp16"
        case .avx512_vp2intersect: return "avx512-vp2intersect"
        case .avx512_vpopcntdq: return "avx512-vpopcntdq"
        case .avx512bitalg: return "avx512bitalg"
        case .avx512bw: return "avx512bw"
        case .avx512cd: return "avx512cd"
        case .avx512dq: return "avx512dq"
        case .avx512er: return "avx512er"
        case .avx512f: return "avx512f"
        case .avx512ifma: return "avx512ifma"
        case .avx512pf: return "avx512pf"
        case .avx512vbmi: return "avx512vbmi"
        case .avx512vbmi2: return "avx512vbmi2"
        case .avx512vl: return "avx512vl"
        case .avx512vnni: return "avx512vnni"
        case .bmi1: return "bmi1"
        case .bmi2: return "bmi2"
        case .bus_lock_detect: return "bus-lock-detect"
        case .cid: return "cid"
        case .cldemote: return "cldemote"
        case .clflush: return "clflush"
        case .clflushopt: return "clflushopt"
        case .clwb: return "clwb"
        case .clzero: return "clzero"
        case .cmov: return "cmov"
        case .cmp_legacy: return "cmp-legacy"
        case .cmpccxadd: return "cmpccxadd"
        case .core_capability: return "core-capability"
        case .cr8legacy: return "cr8legacy"
        case .cx16: return "cx16"
        case .cx8: return "cx8"
        case .dca: return "dca"
        case .de: return "de"
        case .decodeassists: return "decodeassists"
        case .ds: return "ds"
        case .ds_cpl: return "ds-cpl"
        case .dtes64: return "dtes64"
        case .erms: return "erms"
        case .est: return "est"
        case .extapic: return "extapic"
        case .f16c: return "f16c"
        case .fb_clear: return "fb-clear"
        case .fbsdp_no: return "fbsdp-no"
        case .flush_l1d: return "flush-l1d"
        case .flushbyasid: return "flushbyasid"
        case .fma: return "fma"
        case .fma4: return "fma4"
        case .fpu: return "fpu"
        case .fred: return "fred"
        case .fsgsbase: return "fsgsbase"
        case .fsrc: return "fsrc"
        case .fsrm: return "fsrm"
        case .fsrs: return "fsrs"
        case .full_width_write: return "full-width-write"
        case .fxsr: return "fxsr"
        case .fxsr_opt: return "fxsr-opt"
        case .fzrm: return "fzrm"
        case .gds_no: return "gds-no"
        case .gfni: return "gfni"
        case .hle: return "hle"
        case .ht: return "ht"
        case .hypervisor: return "hypervisor"
        case .ia64: return "ia64"
        case .ibpb: return "ibpb"
        case .ibrs: return "ibrs"
        case .ibrs_all: return "ibrs-all"
        case .ibs: return "ibs"
        case .intel_pt: return "intel-pt"
        case .intel_pt_lip: return "intel-pt-lip"
        case .invpcid: return "invpcid"
        case .invtsc: return "invtsc"
        case .kvm_asyncpf: return "kvm-asyncpf"
        case .kvm_asyncpf_int: return "kvm-asyncpf-int"
        case .kvm_asyncpf_vmexit: return "kvm-asyncpf-vmexit"
        case .kvm_hint_dedicated: return "kvm-hint-dedicated"
        case .kvm_mmu: return "kvm-mmu"
        case .kvm_msi_ext_dest_id: return "kvm-msi-ext-dest-id"
        case .kvm_nopiodelay: return "kvm-nopiodelay"
        case .kvm_poll_control: return "kvm-poll-control"
        case .kvm_pv_eoi: return "kvm-pv-eoi"
        case .kvm_pv_ipi: return "kvm-pv-ipi"
        case .kvm_pv_sched_yield: return "kvm-pv-sched-yield"
        case .kvm_pv_tlb_flush: return "kvm-pv-tlb-flush"
        case .kvm_pv_unhalt: return "kvm-pv-unhalt"
        case .kvm_steal_time: return "kvm-steal-time"
        case .kvmclock: return "kvmclock"
        case .kvmclock_stable_bit: return "kvmclock-stable-bit"
        case .la57: return "la57"
        case .lahf_lm: return "lahf-lm"
        case .lam: return "lam"
        case .lbrv: return "lbrv"
        case .lfence_always_serializing: return "lfence-always-serializing"
        case .lkgs: return "lkgs"
        case .lm: return "lm"
        case .lwp: return "lwp"
        case .mca: return "mca"
        case .mcdt_no: return "mcdt-no"
        case .mce: return "mce"
        case .md_clear: return "md-clear"
        case .mds_no: return "mds-no"
        case .misalignsse: return "misalignsse"
        case .mmx: return "mmx"
        case .mmxext: return "mmxext"
        case .monitor: return "monitor"
        case .movbe: return "movbe"
        case .movdir64b: return "movdir64b"
        case .movdiri: return "movdiri"
        case .mpx: return "mpx"
        case .msr: return "msr"
        case .mtrr: return "mtrr"
        case .no_nested_data_bp: return "no-nested-data-bp"
        case .nodeid_msr: return "nodeid-msr"
        case .npt: return "npt"
        case .nrip_save: return "nrip-save"
        case .null_sel_clr_base: return "null-sel-clr-base"
        case .nx: return "nx"
        case .osvw: return "osvw"
        case .overflow_recov: return "overflow-recov"
        case .pae: return "pae"
        case .pat: return "pat"
        case .pause_filter: return "pause-filter"
        case .pbe: return "pbe"
        case .pbrsb_no: return "pbrsb-no"
        case .pcid: return "pcid"
        case .pclmulqdq: return "pclmulqdq"
        case .pcommit: return "pcommit"
        case .pdcm: return "pdcm"
        case .pdpe1gb: return "pdpe1gb"
        case .perfctr_core: return "perfctr-core"
        case .perfctr_nb: return "perfctr-nb"
        case .pfthreshold: return "pfthreshold"
        case .pge: return "pge"
        case .phe: return "phe"
        case .phe_en: return "phe-en"
        case .pks: return "pks"
        case .pku: return "pku"
        case .pmm: return "pmm"
        case .pmm_en: return "pmm-en"
        case .pn: return "pn"
        case .pni: return "pni"
        case .popcnt: return "popcnt"
        case .prefetchiti: return "prefetchiti"
        case .pschange_mc_no: return "pschange-mc-no"
        case .psdp_no: return "psdp-no"
        case .pse: return "pse"
        case .pse36: return "pse36"
        case .rdctl_no: return "rdctl-no"
        case .rdpid: return "rdpid"
        case .rdrand: return "rdrand"
        case .rdseed: return "rdseed"
        case .rdtscp: return "rdtscp"
        case .rfds_clear: return "rfds-clear"
        case .rfds_no: return "rfds-no"
        case .rsba: return "rsba"
        case .rtm: return "rtm"
        case .sbdr_ssdp_no: return "sbdr-ssdp-no"
        case .sep: return "sep"
        case .serialize: return "serialize"
        case .sgx: return "sgx"
        case .sgx_aex_notify: return "sgx-aex-notify"
        case .sgx_debug: return "sgx-debug"
        case .sgx_edeccssa: return "sgx-edeccssa"
        case .sgx_exinfo: return "sgx-exinfo"
        case .sgx_kss: return "sgx-kss"
        case .sgx_mode64: return "sgx-mode64"
        case .sgx_provisionkey: return "sgx-provisionkey"
        case .sgx_tokenkey: return "sgx-tokenkey"
        case .sgx1: return "sgx1"
        case .sgx2: return "sgx2"
        case .sgxlc: return "sgxlc"
        case .sha_ni: return "sha-ni"
        case .skinit: return "skinit"
        case .skip_l1dfl_vmentry: return "skip-l1dfl-vmentry"
        case .smap: return "smap"
        case .smep: return "smep"
        case .smx: return "smx"
        case .spec_ctrl: return "spec-ctrl"
        case .split_lock_detect: return "split-lock-detect"
        case .ss: return "ss"
        case .ssb_no: return "ssb-no"
        case .ssbd: return "ssbd"
        case .sse: return "sse"
        case .sse2: return "sse2"
        case .sse4_1: return "sse4.1"
        case .sse4_2: return "sse4.2"
        case .sse4a: return "sse4a"
        case .ssse3: return "ssse3"
        case .stibp: return "stibp"
        case .stibp_always_on: return "stibp-always-on"
        case .succor: return "succor"
        case .svm: return "svm"
        case .svm_lock: return "svm-lock"
        case .svme_addr_chk: return "svme-addr-chk"
        case .syscall: return "syscall"
        case .taa_no: return "taa-no"
        case .tbm: return "tbm"
        case .tce: return "tce"
        case .tm: return "tm"
        case .tm2: return "tm2"
        case .topoext: return "topoext"
        case .tsc: return "tsc"
        case .tsc_adjust: return "tsc-adjust"
        case .tsc_deadline: return "tsc-deadline"
        case .tsc_scale: return "tsc-scale"
        case .tsx_ctrl: return "tsx-ctrl"
        case .tsx_ldtrk: return "tsx-ldtrk"
        case .umip: return "umip"
        case .v_vmsave_vmload: return "v-vmsave-vmload"
        case .vaes: return "vaes"
        case .vgif: return "vgif"
        case .virt_ssbd: return "virt-ssbd"
        case .vmcb_clean: return "vmcb-clean"
        case .vme: return "vme"
        case .vmx: return "vmx"
        case .vmx_activity_hlt: return "vmx-activity-hlt"
        case .vmx_activity_shutdown: return "vmx-activity-shutdown"
        case .vmx_activity_wait_sipi: return "vmx-activity-wait-sipi"
        case .vmx_any_errcode: return "vmx-any-errcode"
        case .vmx_apicv_register: return "vmx-apicv-register"
        case .vmx_apicv_vid: return "vmx-apicv-vid"
        case .vmx_apicv_x2apic: return "vmx-apicv-x2apic"
        case .vmx_apicv_xapic: return "vmx-apicv-xapic"
        case .vmx_cr3_load_noexit: return "vmx-cr3-load-noexit"
        case .vmx_cr3_store_noexit: return "vmx-cr3-store-noexit"
        case .vmx_cr8_load_exit: return "vmx-cr8-load-exit"
        case .vmx_cr8_store_exit: return "vmx-cr8-store-exit"
        case .vmx_desc_exit: return "vmx-desc-exit"
        case .vmx_enable_user_wait_pause: return "vmx-enable-user-wait-pause"
        case .vmx_encls_exit: return "vmx-encls-exit"
        case .vmx_entry_ia32e_mode: return "vmx-entry-ia32e-mode"
        case .vmx_entry_load_bndcfgs: return "vmx-entry-load-bndcfgs"
        case .vmx_entry_load_efer: return "vmx-entry-load-efer"
        case .vmx_entry_load_pat: return "vmx-entry-load-pat"
        case .vmx_entry_load_perf_global_ctrl: return "vmx-entry-load-perf-global-ctrl"
        case .vmx_entry_load_pkrs: return "vmx-entry-load-pkrs"
        case .vmx_entry_load_rtit_ctl: return "vmx-entry-load-rtit-ctl"
        case .vmx_entry_noload_debugctl: return "vmx-entry-noload-debugctl"
        case .vmx_ept: return "vmx-ept"
        case .vmx_ept_1gb: return "vmx-ept-1gb"
        case .vmx_ept_2mb: return "vmx-ept-2mb"
        case .vmx_ept_advanced_exitinfo: return "vmx-ept-advanced-exitinfo"
        case .vmx_ept_execonly: return "vmx-ept-execonly"
        case .vmx_eptad: return "vmx-eptad"
        case .vmx_eptp_switching: return "vmx-eptp-switching"
        case .vmx_exit_ack_intr: return "vmx-exit-ack-intr"
        case .vmx_exit_clear_bndcfgs: return "vmx-exit-clear-bndcfgs"
        case .vmx_exit_clear_rtit_ctl: return "vmx-exit-clear-rtit-ctl"
        case .vmx_exit_load_efer: return "vmx-exit-load-efer"
        case .vmx_exit_load_pat: return "vmx-exit-load-pat"
        case .vmx_exit_load_perf_global_ctrl: return "vmx-exit-load-perf-global-ctrl"
        case .vmx_exit_load_pkrs: return "vmx-exit-load-pkrs"
        case .vmx_exit_nosave_debugctl: return "vmx-exit-nosave-debugctl"
        case .vmx_exit_save_efer: return "vmx-exit-save-efer"
        case .vmx_exit_save_pat: return "vmx-exit-save-pat"
        case .vmx_exit_save_preemption_timer: return "vmx-exit-save-preemption-timer"
        case .vmx_flexpriority: return "vmx-flexpriority"
        case .vmx_hlt_exit: return "vmx-hlt-exit"
        case .vmx_ins_outs: return "vmx-ins-outs"
        case .vmx_intr_exit: return "vmx-intr-exit"
        case .vmx_invept: return "vmx-invept"
        case .vmx_invept_all_context: return "vmx-invept-all-context"
        case .vmx_invept_single_context: return "vmx-invept-single-context"
        case .vmx_invept_single_context_noglobals: return "vmx-invept-single-context-noglobals"
        case .vmx_invlpg_exit: return "vmx-invlpg-exit"
        case .vmx_invpcid_exit: return "vmx-invpcid-exit"
        case .vmx_invvpid: return "vmx-invvpid"
        case .vmx_invvpid_all_context: return "vmx-invvpid-all-context"
        case .vmx_invvpid_single_addr: return "vmx-invvpid-single-addr"
        case .vmx_io_bitmap: return "vmx-io-bitmap"
        case .vmx_io_exit: return "vmx-io-exit"
        case .vmx_monitor_exit: return "vmx-monitor-exit"
        case .vmx_movdr_exit: return "vmx-movdr-exit"
        case .vmx_msr_bitmap: return "vmx-msr-bitmap"
        case .vmx_mtf: return "vmx-mtf"
        case .vmx_mwait_exit: return "vmx-mwait-exit"
        case .vmx_nested_exception: return "vmx-nested-exception"
        case .vmx_nmi_exit: return "vmx-nmi-exit"
        case .vmx_page_walk_4: return "vmx-page-walk-4"
        case .vmx_page_walk_5: return "vmx-page-walk-5"
        case .vmx_pause_exit: return "vmx-pause-exit"
        case .vmx_ple: return "vmx-ple"
        case .vmx_pml: return "vmx-pml"
        case .vmx_posted_intr: return "vmx-posted-intr"
        case .vmx_preemption_timer: return "vmx-preemption-timer"
        case .vmx_rdpmc_exit: return "vmx-rdpmc-exit"
        case .vmx_rdrand_exit: return "vmx-rdrand-exit"
        case .vmx_rdseed_exit: return "vmx-rdseed-exit"
        case .vmx_rdtsc_exit: return "vmx-rdtsc-exit"
        case .vmx_rdtscp_exit: return "vmx-rdtscp-exit"
        case .vmx_secondary_ctls: return "vmx-secondary-ctls"
        case .vmx_shadow_vmcs: return "vmx-shadow-vmcs"
        case .vmx_store_lma: return "vmx-store-lma"
        case .vmx_true_ctls: return "vmx-true-ctls"
        case .vmx_tsc_offset: return "vmx-tsc-offset"
        case .vmx_tsc_scaling: return "vmx-tsc-scaling"
        case .vmx_unrestricted_guest: return "vmx-unrestricted-guest"
        case .vmx_vintr_pending: return "vmx-vintr-pending"
        case .vmx_vmfunc: return "vmx-vmfunc"
        case .vmx_vmwrite_vmexit_fields: return "vmx-vmwrite-vmexit-fields"
        case .vmx_vnmi: return "vmx-vnmi"
        case .vmx_vnmi_pending: return "vmx-vnmi-pending"
        case .vmx_vpid: return "vmx-vpid"
        case .vmx_wbinvd_exit: return "vmx-wbinvd-exit"
        case .vmx_xsaves: return "vmx-xsaves"
        case .vmx_zero_len_inject: return "vmx-zero-len-inject"
        case .vnmi: return "vnmi"
        case .vpclmulqdq: return "vpclmulqdq"
        case .waitpkg: return "waitpkg"
        case .wbnoinvd: return "wbnoinvd"
        case .wdt: return "wdt"
        case .wrmsrns: return "wrmsrns"
        case .x2apic: return "x2apic"
        case .xcrypt: return "xcrypt"
        case .xcrypt_en: return "xcrypt-en"
        case .xfd: return "xfd"
        case .xgetbv1: return "xgetbv1"
        case .xop: return "xop"
        case .xsave: return "xsave"
        case .xsavec: return "xsavec"
        case .xsaveerptr: return "xsaveerptr"
        case .xsaveopt: return "xsaveopt"
        case .xsaves: return "xsaves"
        case .xstore: return "xstore"
        case .xstore_en: return "xstore-en"
        case .xtpr: return "xtpr"
        }
    }
}

typealias QEMUCPUFlag_loongarch64 = AnyQEMUConstant

typealias QEMUCPUFlag_m68k = AnyQEMUConstant

typealias QEMUCPUFlag_microblaze = AnyQEMUConstant

typealias QEMUCPUFlag_microblazeel = AnyQEMUConstant

typealias QEMUCPUFlag_mips = AnyQEMUConstant

typealias QEMUCPUFlag_mipsel = AnyQEMUConstant

typealias QEMUCPUFlag_mips64 = AnyQEMUConstant

typealias QEMUCPUFlag_mips64el = AnyQEMUConstant

typealias QEMUCPUFlag_or1k = AnyQEMUConstant

typealias QEMUCPUFlag_ppc = AnyQEMUConstant

typealias QEMUCPUFlag_ppc64 = AnyQEMUConstant

typealias QEMUCPUFlag_riscv32 = AnyQEMUConstant

typealias QEMUCPUFlag_riscv64 = AnyQEMUConstant

typealias QEMUCPUFlag_rx = AnyQEMUConstant

enum QEMUCPUFlag_s390x: String, CaseIterable, QEMUCPUFlag {
    case _empty = ""

    var prettyValue: String {
        switch self {
        case ._empty: return ""
        }
    }
}

typealias QEMUCPUFlag_sh4 = AnyQEMUConstant

typealias QEMUCPUFlag_sh4eb = AnyQEMUConstant

enum QEMUCPUFlag_sparc: String, CaseIterable, QEMUCPUFlag {
    case div
    case float128
    case fsmuld
    case mul

    var prettyValue: String {
        switch self {
        case .div: return "div"
        case .float128: return "float128"
        case .fsmuld: return "fsmuld"
        case .mul: return "mul"
        }
    }
}

enum QEMUCPUFlag_sparc64: String, CaseIterable, QEMUCPUFlag {
    case cmt
    case float128
    case fmaf
    case gl
    case hypv
    case ima
    case vis1
    case vis2
    case vis3
    case vis4

    var prettyValue: String {
        switch self {
        case .cmt: return "cmt"
        case .float128: return "float128"
        case .fmaf: return "fmaf"
        case .gl: return "gl"
        case .hypv: return "hypv"
        case .ima: return "ima"
        case .vis1: return "vis1"
        case .vis2: return "vis2"
        case .vis3: return "vis3"
        case .vis4: return "vis4"
        }
    }
}

typealias QEMUCPUFlag_tricore = AnyQEMUConstant

enum QEMUCPUFlag_x86_64: String, CaseIterable, QEMUCPUFlag {
    case _3dnow = "3dnow"
    case _3dnowext = "3dnowext"
    case _3dnowprefetch = "3dnowprefetch"
    case abm
    case ace2
    case ace2_en = "ace2-en"
    case acpi
    case adx
    case aes
    case amd_no_ssb = "amd-no-ssb"
    case amd_psfd = "amd-psfd"
    case amd_ssbd = "amd-ssbd"
    case amd_stibp = "amd-stibp"
    case amx_bf16 = "amx-bf16"
    case amx_complex = "amx-complex"
    case amx_fp16 = "amx-fp16"
    case amx_int8 = "amx-int8"
    case amx_tile = "amx-tile"
    case apic
    case arat
    case arch_capabilities = "arch-capabilities"
    case arch_lbr = "arch-lbr"
    case auto_ibrs = "auto-ibrs"
    case avic
    case avx
    case avx_ifma = "avx-ifma"
    case avx_ne_convert = "avx-ne-convert"
    case avx_vnni = "avx-vnni"
    case avx_vnni_int16 = "avx-vnni-int16"
    case avx_vnni_int8 = "avx-vnni-int8"
    case avx2
    case avx512_4fmaps = "avx512-4fmaps"
    case avx512_4vnniw = "avx512-4vnniw"
    case avx512_bf16 = "avx512-bf16"
    case avx512_fp16 = "avx512-fp16"
    case avx512_vp2intersect = "avx512-vp2intersect"
    case avx512_vpopcntdq = "avx512-vpopcntdq"
    case avx512bitalg
    case avx512bw
    case avx512cd
    case avx512dq
    case avx512er
    case avx512f
    case avx512ifma
    case avx512pf
    case avx512vbmi
    case avx512vbmi2
    case avx512vl
    case avx512vnni
    case bmi1
    case bmi2
    case bus_lock_detect = "bus-lock-detect"
    case cid
    case cldemote
    case clflush
    case clflushopt
    case clwb
    case clzero
    case cmov
    case cmp_legacy = "cmp-legacy"
    case cmpccxadd
    case core_capability = "core-capability"
    case cr8legacy
    case cx16
    case cx8
    case dca
    case de
    case decodeassists
    case ds
    case ds_cpl = "ds-cpl"
    case dtes64
    case erms
    case est
    case extapic
    case f16c
    case fb_clear = "fb-clear"
    case fbsdp_no = "fbsdp-no"
    case flush_l1d = "flush-l1d"
    case flushbyasid
    case fma
    case fma4
    case fpu
    case fred
    case fsgsbase
    case fsrc
    case fsrm
    case fsrs
    case full_width_write = "full-width-write"
    case fxsr
    case fxsr_opt = "fxsr-opt"
    case fzrm
    case gds_no = "gds-no"
    case gfni
    case hle
    case ht
    case hypervisor
    case ia64
    case ibpb
    case ibrs
    case ibrs_all = "ibrs-all"
    case ibs
    case intel_pt = "intel-pt"
    case intel_pt_lip = "intel-pt-lip"
    case invpcid
    case invtsc
    case kvm_asyncpf = "kvm-asyncpf"
    case kvm_asyncpf_int = "kvm-asyncpf-int"
    case kvm_asyncpf_vmexit = "kvm-asyncpf-vmexit"
    case kvm_hint_dedicated = "kvm-hint-dedicated"
    case kvm_mmu = "kvm-mmu"
    case kvm_msi_ext_dest_id = "kvm-msi-ext-dest-id"
    case kvm_nopiodelay = "kvm-nopiodelay"
    case kvm_poll_control = "kvm-poll-control"
    case kvm_pv_eoi = "kvm-pv-eoi"
    case kvm_pv_ipi = "kvm-pv-ipi"
    case kvm_pv_sched_yield = "kvm-pv-sched-yield"
    case kvm_pv_tlb_flush = "kvm-pv-tlb-flush"
    case kvm_pv_unhalt = "kvm-pv-unhalt"
    case kvm_steal_time = "kvm-steal-time"
    case kvmclock
    case kvmclock_stable_bit = "kvmclock-stable-bit"
    case la57
    case lahf_lm = "lahf-lm"
    case lam
    case lbrv
    case lfence_always_serializing = "lfence-always-serializing"
    case lkgs
    case lm
    case lwp
    case mca
    case mcdt_no = "mcdt-no"
    case mce
    case md_clear = "md-clear"
    case mds_no = "mds-no"
    case misalignsse
    case mmx
    case mmxext
    case monitor
    case movbe
    case movdir64b
    case movdiri
    case mpx
    case msr
    case mtrr
    case no_nested_data_bp = "no-nested-data-bp"
    case nodeid_msr = "nodeid-msr"
    case npt
    case nrip_save = "nrip-save"
    case null_sel_clr_base = "null-sel-clr-base"
    case nx
    case osvw
    case overflow_recov = "overflow-recov"
    case pae
    case pat
    case pause_filter = "pause-filter"
    case pbe
    case pbrsb_no = "pbrsb-no"
    case pcid
    case pclmulqdq
    case pcommit
    case pdcm
    case pdpe1gb
    case perfctr_core = "perfctr-core"
    case perfctr_nb = "perfctr-nb"
    case pfthreshold
    case pge
    case phe
    case phe_en = "phe-en"
    case pks
    case pku
    case pmm
    case pmm_en = "pmm-en"
    case pn
    case pni
    case popcnt
    case prefetchiti
    case pschange_mc_no = "pschange-mc-no"
    case psdp_no = "psdp-no"
    case pse
    case pse36
    case rdctl_no = "rdctl-no"
    case rdpid
    case rdrand
    case rdseed
    case rdtscp
    case rfds_clear = "rfds-clear"
    case rfds_no = "rfds-no"
    case rsba
    case rtm
    case sbdr_ssdp_no = "sbdr-ssdp-no"
    case sep
    case serialize
    case sgx
    case sgx_aex_notify = "sgx-aex-notify"
    case sgx_debug = "sgx-debug"
    case sgx_edeccssa = "sgx-edeccssa"
    case sgx_exinfo = "sgx-exinfo"
    case sgx_kss = "sgx-kss"
    case sgx_mode64 = "sgx-mode64"
    case sgx_provisionkey = "sgx-provisionkey"
    case sgx_tokenkey = "sgx-tokenkey"
    case sgx1
    case sgx2
    case sgxlc
    case sha_ni = "sha-ni"
    case skinit
    case skip_l1dfl_vmentry = "skip-l1dfl-vmentry"
    case smap
    case smep
    case smx
    case spec_ctrl = "spec-ctrl"
    case split_lock_detect = "split-lock-detect"
    case ss
    case ssb_no = "ssb-no"
    case ssbd
    case sse
    case sse2
    case sse4_1 = "sse4.1"
    case sse4_2 = "sse4.2"
    case sse4a
    case ssse3
    case stibp
    case stibp_always_on = "stibp-always-on"
    case succor
    case svm
    case svm_lock = "svm-lock"
    case svme_addr_chk = "svme-addr-chk"
    case syscall
    case taa_no = "taa-no"
    case tbm
    case tce
    case tm
    case tm2
    case topoext
    case tsc
    case tsc_adjust = "tsc-adjust"
    case tsc_deadline = "tsc-deadline"
    case tsc_scale = "tsc-scale"
    case tsx_ctrl = "tsx-ctrl"
    case tsx_ldtrk = "tsx-ldtrk"
    case umip
    case v_vmsave_vmload = "v-vmsave-vmload"
    case vaes
    case vgif
    case virt_ssbd = "virt-ssbd"
    case vmcb_clean = "vmcb-clean"
    case vme
    case vmx
    case vmx_activity_hlt = "vmx-activity-hlt"
    case vmx_activity_shutdown = "vmx-activity-shutdown"
    case vmx_activity_wait_sipi = "vmx-activity-wait-sipi"
    case vmx_any_errcode = "vmx-any-errcode"
    case vmx_apicv_register = "vmx-apicv-register"
    case vmx_apicv_vid = "vmx-apicv-vid"
    case vmx_apicv_x2apic = "vmx-apicv-x2apic"
    case vmx_apicv_xapic = "vmx-apicv-xapic"
    case vmx_cr3_load_noexit = "vmx-cr3-load-noexit"
    case vmx_cr3_store_noexit = "vmx-cr3-store-noexit"
    case vmx_cr8_load_exit = "vmx-cr8-load-exit"
    case vmx_cr8_store_exit = "vmx-cr8-store-exit"
    case vmx_desc_exit = "vmx-desc-exit"
    case vmx_enable_user_wait_pause = "vmx-enable-user-wait-pause"
    case vmx_encls_exit = "vmx-encls-exit"
    case vmx_entry_ia32e_mode = "vmx-entry-ia32e-mode"
    case vmx_entry_load_bndcfgs = "vmx-entry-load-bndcfgs"
    case vmx_entry_load_efer = "vmx-entry-load-efer"
    case vmx_entry_load_pat = "vmx-entry-load-pat"
    case vmx_entry_load_perf_global_ctrl = "vmx-entry-load-perf-global-ctrl"
    case vmx_entry_load_pkrs = "vmx-entry-load-pkrs"
    case vmx_entry_load_rtit_ctl = "vmx-entry-load-rtit-ctl"
    case vmx_entry_noload_debugctl = "vmx-entry-noload-debugctl"
    case vmx_ept = "vmx-ept"
    case vmx_ept_1gb = "vmx-ept-1gb"
    case vmx_ept_2mb = "vmx-ept-2mb"
    case vmx_ept_advanced_exitinfo = "vmx-ept-advanced-exitinfo"
    case vmx_ept_execonly = "vmx-ept-execonly"
    case vmx_eptad = "vmx-eptad"
    case vmx_eptp_switching = "vmx-eptp-switching"
    case vmx_exit_ack_intr = "vmx-exit-ack-intr"
    case vmx_exit_clear_bndcfgs = "vmx-exit-clear-bndcfgs"
    case vmx_exit_clear_rtit_ctl = "vmx-exit-clear-rtit-ctl"
    case vmx_exit_load_efer = "vmx-exit-load-efer"
    case vmx_exit_load_pat = "vmx-exit-load-pat"
    case vmx_exit_load_perf_global_ctrl = "vmx-exit-load-perf-global-ctrl"
    case vmx_exit_load_pkrs = "vmx-exit-load-pkrs"
    case vmx_exit_nosave_debugctl = "vmx-exit-nosave-debugctl"
    case vmx_exit_save_efer = "vmx-exit-save-efer"
    case vmx_exit_save_pat = "vmx-exit-save-pat"
    case vmx_exit_save_preemption_timer = "vmx-exit-save-preemption-timer"
    case vmx_flexpriority = "vmx-flexpriority"
    case vmx_hlt_exit = "vmx-hlt-exit"
    case vmx_ins_outs = "vmx-ins-outs"
    case vmx_intr_exit = "vmx-intr-exit"
    case vmx_invept = "vmx-invept"
    case vmx_invept_all_context = "vmx-invept-all-context"
    case vmx_invept_single_context = "vmx-invept-single-context"
    case vmx_invept_single_context_noglobals = "vmx-invept-single-context-noglobals"
    case vmx_invlpg_exit = "vmx-invlpg-exit"
    case vmx_invpcid_exit = "vmx-invpcid-exit"
    case vmx_invvpid = "vmx-invvpid"
    case vmx_invvpid_all_context = "vmx-invvpid-all-context"
    case vmx_invvpid_single_addr = "vmx-invvpid-single-addr"
    case vmx_io_bitmap = "vmx-io-bitmap"
    case vmx_io_exit = "vmx-io-exit"
    case vmx_monitor_exit = "vmx-monitor-exit"
    case vmx_movdr_exit = "vmx-movdr-exit"
    case vmx_msr_bitmap = "vmx-msr-bitmap"
    case vmx_mtf = "vmx-mtf"
    case vmx_mwait_exit = "vmx-mwait-exit"
    case vmx_nested_exception = "vmx-nested-exception"
    case vmx_nmi_exit = "vmx-nmi-exit"
    case vmx_page_walk_4 = "vmx-page-walk-4"
    case vmx_page_walk_5 = "vmx-page-walk-5"
    case vmx_pause_exit = "vmx-pause-exit"
    case vmx_ple = "vmx-ple"
    case vmx_pml = "vmx-pml"
    case vmx_posted_intr = "vmx-posted-intr"
    case vmx_preemption_timer = "vmx-preemption-timer"
    case vmx_rdpmc_exit = "vmx-rdpmc-exit"
    case vmx_rdrand_exit = "vmx-rdrand-exit"
    case vmx_rdseed_exit = "vmx-rdseed-exit"
    case vmx_rdtsc_exit = "vmx-rdtsc-exit"
    case vmx_rdtscp_exit = "vmx-rdtscp-exit"
    case vmx_secondary_ctls = "vmx-secondary-ctls"
    case vmx_shadow_vmcs = "vmx-shadow-vmcs"
    case vmx_store_lma = "vmx-store-lma"
    case vmx_true_ctls = "vmx-true-ctls"
    case vmx_tsc_offset = "vmx-tsc-offset"
    case vmx_tsc_scaling = "vmx-tsc-scaling"
    case vmx_unrestricted_guest = "vmx-unrestricted-guest"
    case vmx_vintr_pending = "vmx-vintr-pending"
    case vmx_vmfunc = "vmx-vmfunc"
    case vmx_vmwrite_vmexit_fields = "vmx-vmwrite-vmexit-fields"
    case vmx_vnmi = "vmx-vnmi"
    case vmx_vnmi_pending = "vmx-vnmi-pending"
    case vmx_vpid = "vmx-vpid"
    case vmx_wbinvd_exit = "vmx-wbinvd-exit"
    case vmx_xsaves = "vmx-xsaves"
    case vmx_zero_len_inject = "vmx-zero-len-inject"
    case vnmi
    case vpclmulqdq
    case waitpkg
    case wbnoinvd
    case wdt
    case wrmsrns
    case x2apic
    case xcrypt
    case xcrypt_en = "xcrypt-en"
    case xfd
    case xgetbv1
    case xop
    case xsave
    case xsavec
    case xsaveerptr
    case xsaveopt
    case xsaves
    case xstore
    case xstore_en = "xstore-en"
    case xtpr

    var prettyValue: String {
        switch self {
        case ._3dnow: return "3dnow"
        case ._3dnowext: return "3dnowext"
        case ._3dnowprefetch: return "3dnowprefetch"
        case .abm: return "abm"
        case .ace2: return "ace2"
        case .ace2_en: return "ace2-en"
        case .acpi: return "acpi"
        case .adx: return "adx"
        case .aes: return "aes"
        case .amd_no_ssb: return "amd-no-ssb"
        case .amd_psfd: return "amd-psfd"
        case .amd_ssbd: return "amd-ssbd"
        case .amd_stibp: return "amd-stibp"
        case .amx_bf16: return "amx-bf16"
        case .amx_complex: return "amx-complex"
        case .amx_fp16: return "amx-fp16"
        case .amx_int8: return "amx-int8"
        case .amx_tile: return "amx-tile"
        case .apic: return "apic"
        case .arat: return "arat"
        case .arch_capabilities: return "arch-capabilities"
        case .arch_lbr: return "arch-lbr"
        case .auto_ibrs: return "auto-ibrs"
        case .avic: return "avic"
        case .avx: return "avx"
        case .avx_ifma: return "avx-ifma"
        case .avx_ne_convert: return "avx-ne-convert"
        case .avx_vnni: return "avx-vnni"
        case .avx_vnni_int16: return "avx-vnni-int16"
        case .avx_vnni_int8: return "avx-vnni-int8"
        case .avx2: return "avx2"
        case .avx512_4fmaps: return "avx512-4fmaps"
        case .avx512_4vnniw: return "avx512-4vnniw"
        case .avx512_bf16: return "avx512-bf16"
        case .avx512_fp16: return "avx512-fp16"
        case .avx512_vp2intersect: return "avx512-vp2intersect"
        case .avx512_vpopcntdq: return "avx512-vpopcntdq"
        case .avx512bitalg: return "avx512bitalg"
        case .avx512bw: return "avx512bw"
        case .avx512cd: return "avx512cd"
        case .avx512dq: return "avx512dq"
        case .avx512er: return "avx512er"
        case .avx512f: return "avx512f"
        case .avx512ifma: return "avx512ifma"
        case .avx512pf: return "avx512pf"
        case .avx512vbmi: return "avx512vbmi"
        case .avx512vbmi2: return "avx512vbmi2"
        case .avx512vl: return "avx512vl"
        case .avx512vnni: return "avx512vnni"
        case .bmi1: return "bmi1"
        case .bmi2: return "bmi2"
        case .bus_lock_detect: return "bus-lock-detect"
        case .cid: return "cid"
        case .cldemote: return "cldemote"
        case .clflush: return "clflush"
        case .clflushopt: return "clflushopt"
        case .clwb: return "clwb"
        case .clzero: return "clzero"
        case .cmov: return "cmov"
        case .cmp_legacy: return "cmp-legacy"
        case .cmpccxadd: return "cmpccxadd"
        case .core_capability: return "core-capability"
        case .cr8legacy: return "cr8legacy"
        case .cx16: return "cx16"
        case .cx8: return "cx8"
        case .dca: return "dca"
        case .de: return "de"
        case .decodeassists: return "decodeassists"
        case .ds: return "ds"
        case .ds_cpl: return "ds-cpl"
        case .dtes64: return "dtes64"
        case .erms: return "erms"
        case .est: return "est"
        case .extapic: return "extapic"
        case .f16c: return "f16c"
        case .fb_clear: return "fb-clear"
        case .fbsdp_no: return "fbsdp-no"
        case .flush_l1d: return "flush-l1d"
        case .flushbyasid: return "flushbyasid"
        case .fma: return "fma"
        case .fma4: return "fma4"
        case .fpu: return "fpu"
        case .fred: return "fred"
        case .fsgsbase: return "fsgsbase"
        case .fsrc: return "fsrc"
        case .fsrm: return "fsrm"
        case .fsrs: return "fsrs"
        case .full_width_write: return "full-width-write"
        case .fxsr: return "fxsr"
        case .fxsr_opt: return "fxsr-opt"
        case .fzrm: return "fzrm"
        case .gds_no: return "gds-no"
        case .gfni: return "gfni"
        case .hle: return "hle"
        case .ht: return "ht"
        case .hypervisor: return "hypervisor"
        case .ia64: return "ia64"
        case .ibpb: return "ibpb"
        case .ibrs: return "ibrs"
        case .ibrs_all: return "ibrs-all"
        case .ibs: return "ibs"
        case .intel_pt: return "intel-pt"
        case .intel_pt_lip: return "intel-pt-lip"
        case .invpcid: return "invpcid"
        case .invtsc: return "invtsc"
        case .kvm_asyncpf: return "kvm-asyncpf"
        case .kvm_asyncpf_int: return "kvm-asyncpf-int"
        case .kvm_asyncpf_vmexit: return "kvm-asyncpf-vmexit"
        case .kvm_hint_dedicated: return "kvm-hint-dedicated"
        case .kvm_mmu: return "kvm-mmu"
        case .kvm_msi_ext_dest_id: return "kvm-msi-ext-dest-id"
        case .kvm_nopiodelay: return "kvm-nopiodelay"
        case .kvm_poll_control: return "kvm-poll-control"
        case .kvm_pv_eoi: return "kvm-pv-eoi"
        case .kvm_pv_ipi: return "kvm-pv-ipi"
        case .kvm_pv_sched_yield: return "kvm-pv-sched-yield"
        case .kvm_pv_tlb_flush: return "kvm-pv-tlb-flush"
        case .kvm_pv_unhalt: return "kvm-pv-unhalt"
        case .kvm_steal_time: return "kvm-steal-time"
        case .kvmclock: return "kvmclock"
        case .kvmclock_stable_bit: return "kvmclock-stable-bit"
        case .la57: return "la57"
        case .lahf_lm: return "lahf-lm"
        case .lam: return "lam"
        case .lbrv: return "lbrv"
        case .lfence_always_serializing: return "lfence-always-serializing"
        case .lkgs: return "lkgs"
        case .lm: return "lm"
        case .lwp: return "lwp"
        case .mca: return "mca"
        case .mcdt_no: return "mcdt-no"
        case .mce: return "mce"
        case .md_clear: return "md-clear"
        case .mds_no: return "mds-no"
        case .misalignsse: return "misalignsse"
        case .mmx: return "mmx"
        case .mmxext: return "mmxext"
        case .monitor: return "monitor"
        case .movbe: return "movbe"
        case .movdir64b: return "movdir64b"
        case .movdiri: return "movdiri"
        case .mpx: return "mpx"
        case .msr: return "msr"
        case .mtrr: return "mtrr"
        case .no_nested_data_bp: return "no-nested-data-bp"
        case .nodeid_msr: return "nodeid-msr"
        case .npt: return "npt"
        case .nrip_save: return "nrip-save"
        case .null_sel_clr_base: return "null-sel-clr-base"
        case .nx: return "nx"
        case .osvw: return "osvw"
        case .overflow_recov: return "overflow-recov"
        case .pae: return "pae"
        case .pat: return "pat"
        case .pause_filter: return "pause-filter"
        case .pbe: return "pbe"
        case .pbrsb_no: return "pbrsb-no"
        case .pcid: return "pcid"
        case .pclmulqdq: return "pclmulqdq"
        case .pcommit: return "pcommit"
        case .pdcm: return "pdcm"
        case .pdpe1gb: return "pdpe1gb"
        case .perfctr_core: return "perfctr-core"
        case .perfctr_nb: return "perfctr-nb"
        case .pfthreshold: return "pfthreshold"
        case .pge: return "pge"
        case .phe: return "phe"
        case .phe_en: return "phe-en"
        case .pks: return "pks"
        case .pku: return "pku"
        case .pmm: return "pmm"
        case .pmm_en: return "pmm-en"
        case .pn: return "pn"
        case .pni: return "pni"
        case .popcnt: return "popcnt"
        case .prefetchiti: return "prefetchiti"
        case .pschange_mc_no: return "pschange-mc-no"
        case .psdp_no: return "psdp-no"
        case .pse: return "pse"
        case .pse36: return "pse36"
        case .rdctl_no: return "rdctl-no"
        case .rdpid: return "rdpid"
        case .rdrand: return "rdrand"
        case .rdseed: return "rdseed"
        case .rdtscp: return "rdtscp"
        case .rfds_clear: return "rfds-clear"
        case .rfds_no: return "rfds-no"
        case .rsba: return "rsba"
        case .rtm: return "rtm"
        case .sbdr_ssdp_no: return "sbdr-ssdp-no"
        case .sep: return "sep"
        case .serialize: return "serialize"
        case .sgx: return "sgx"
        case .sgx_aex_notify: return "sgx-aex-notify"
        case .sgx_debug: return "sgx-debug"
        case .sgx_edeccssa: return "sgx-edeccssa"
        case .sgx_exinfo: return "sgx-exinfo"
        case .sgx_kss: return "sgx-kss"
        case .sgx_mode64: return "sgx-mode64"
        case .sgx_provisionkey: return "sgx-provisionkey"
        case .sgx_tokenkey: return "sgx-tokenkey"
        case .sgx1: return "sgx1"
        case .sgx2: return "sgx2"
        case .sgxlc: return "sgxlc"
        case .sha_ni: return "sha-ni"
        case .skinit: return "skinit"
        case .skip_l1dfl_vmentry: return "skip-l1dfl-vmentry"
        case .smap: return "smap"
        case .smep: return "smep"
        case .smx: return "smx"
        case .spec_ctrl: return "spec-ctrl"
        case .split_lock_detect: return "split-lock-detect"
        case .ss: return "ss"
        case .ssb_no: return "ssb-no"
        case .ssbd: return "ssbd"
        case .sse: return "sse"
        case .sse2: return "sse2"
        case .sse4_1: return "sse4.1"
        case .sse4_2: return "sse4.2"
        case .sse4a: return "sse4a"
        case .ssse3: return "ssse3"
        case .stibp: return "stibp"
        case .stibp_always_on: return "stibp-always-on"
        case .succor: return "succor"
        case .svm: return "svm"
        case .svm_lock: return "svm-lock"
        case .svme_addr_chk: return "svme-addr-chk"
        case .syscall: return "syscall"
        case .taa_no: return "taa-no"
        case .tbm: return "tbm"
        case .tce: return "tce"
        case .tm: return "tm"
        case .tm2: return "tm2"
        case .topoext: return "topoext"
        case .tsc: return "tsc"
        case .tsc_adjust: return "tsc-adjust"
        case .tsc_deadline: return "tsc-deadline"
        case .tsc_scale: return "tsc-scale"
        case .tsx_ctrl: return "tsx-ctrl"
        case .tsx_ldtrk: return "tsx-ldtrk"
        case .umip: return "umip"
        case .v_vmsave_vmload: return "v-vmsave-vmload"
        case .vaes: return "vaes"
        case .vgif: return "vgif"
        case .virt_ssbd: return "virt-ssbd"
        case .vmcb_clean: return "vmcb-clean"
        case .vme: return "vme"
        case .vmx: return "vmx"
        case .vmx_activity_hlt: return "vmx-activity-hlt"
        case .vmx_activity_shutdown: return "vmx-activity-shutdown"
        case .vmx_activity_wait_sipi: return "vmx-activity-wait-sipi"
        case .vmx_any_errcode: return "vmx-any-errcode"
        case .vmx_apicv_register: return "vmx-apicv-register"
        case .vmx_apicv_vid: return "vmx-apicv-vid"
        case .vmx_apicv_x2apic: return "vmx-apicv-x2apic"
        case .vmx_apicv_xapic: return "vmx-apicv-xapic"
        case .vmx_cr3_load_noexit: return "vmx-cr3-load-noexit"
        case .vmx_cr3_store_noexit: return "vmx-cr3-store-noexit"
        case .vmx_cr8_load_exit: return "vmx-cr8-load-exit"
        case .vmx_cr8_store_exit: return "vmx-cr8-store-exit"
        case .vmx_desc_exit: return "vmx-desc-exit"
        case .vmx_enable_user_wait_pause: return "vmx-enable-user-wait-pause"
        case .vmx_encls_exit: return "vmx-encls-exit"
        case .vmx_entry_ia32e_mode: return "vmx-entry-ia32e-mode"
        case .vmx_entry_load_bndcfgs: return "vmx-entry-load-bndcfgs"
        case .vmx_entry_load_efer: return "vmx-entry-load-efer"
        case .vmx_entry_load_pat: return "vmx-entry-load-pat"
        case .vmx_entry_load_perf_global_ctrl: return "vmx-entry-load-perf-global-ctrl"
        case .vmx_entry_load_pkrs: return "vmx-entry-load-pkrs"
        case .vmx_entry_load_rtit_ctl: return "vmx-entry-load-rtit-ctl"
        case .vmx_entry_noload_debugctl: return "vmx-entry-noload-debugctl"
        case .vmx_ept: return "vmx-ept"
        case .vmx_ept_1gb: return "vmx-ept-1gb"
        case .vmx_ept_2mb: return "vmx-ept-2mb"
        case .vmx_ept_advanced_exitinfo: return "vmx-ept-advanced-exitinfo"
        case .vmx_ept_execonly: return "vmx-ept-execonly"
        case .vmx_eptad: return "vmx-eptad"
        case .vmx_eptp_switching: return "vmx-eptp-switching"
        case .vmx_exit_ack_intr: return "vmx-exit-ack-intr"
        case .vmx_exit_clear_bndcfgs: return "vmx-exit-clear-bndcfgs"
        case .vmx_exit_clear_rtit_ctl: return "vmx-exit-clear-rtit-ctl"
        case .vmx_exit_load_efer: return "vmx-exit-load-efer"
        case .vmx_exit_load_pat: return "vmx-exit-load-pat"
        case .vmx_exit_load_perf_global_ctrl: return "vmx-exit-load-perf-global-ctrl"
        case .vmx_exit_load_pkrs: return "vmx-exit-load-pkrs"
        case .vmx_exit_nosave_debugctl: return "vmx-exit-nosave-debugctl"
        case .vmx_exit_save_efer: return "vmx-exit-save-efer"
        case .vmx_exit_save_pat: return "vmx-exit-save-pat"
        case .vmx_exit_save_preemption_timer: return "vmx-exit-save-preemption-timer"
        case .vmx_flexpriority: return "vmx-flexpriority"
        case .vmx_hlt_exit: return "vmx-hlt-exit"
        case .vmx_ins_outs: return "vmx-ins-outs"
        case .vmx_intr_exit: return "vmx-intr-exit"
        case .vmx_invept: return "vmx-invept"
        case .vmx_invept_all_context: return "vmx-invept-all-context"
        case .vmx_invept_single_context: return "vmx-invept-single-context"
        case .vmx_invept_single_context_noglobals: return "vmx-invept-single-context-noglobals"
        case .vmx_invlpg_exit: return "vmx-invlpg-exit"
        case .vmx_invpcid_exit: return "vmx-invpcid-exit"
        case .vmx_invvpid: return "vmx-invvpid"
        case .vmx_invvpid_all_context: return "vmx-invvpid-all-context"
        case .vmx_invvpid_single_addr: return "vmx-invvpid-single-addr"
        case .vmx_io_bitmap: return "vmx-io-bitmap"
        case .vmx_io_exit: return "vmx-io-exit"
        case .vmx_monitor_exit: return "vmx-monitor-exit"
        case .vmx_movdr_exit: return "vmx-movdr-exit"
        case .vmx_msr_bitmap: return "vmx-msr-bitmap"
        case .vmx_mtf: return "vmx-mtf"
        case .vmx_mwait_exit: return "vmx-mwait-exit"
        case .vmx_nested_exception: return "vmx-nested-exception"
        case .vmx_nmi_exit: return "vmx-nmi-exit"
        case .vmx_page_walk_4: return "vmx-page-walk-4"
        case .vmx_page_walk_5: return "vmx-page-walk-5"
        case .vmx_pause_exit: return "vmx-pause-exit"
        case .vmx_ple: return "vmx-ple"
        case .vmx_pml: return "vmx-pml"
        case .vmx_posted_intr: return "vmx-posted-intr"
        case .vmx_preemption_timer: return "vmx-preemption-timer"
        case .vmx_rdpmc_exit: return "vmx-rdpmc-exit"
        case .vmx_rdrand_exit: return "vmx-rdrand-exit"
        case .vmx_rdseed_exit: return "vmx-rdseed-exit"
        case .vmx_rdtsc_exit: return "vmx-rdtsc-exit"
        case .vmx_rdtscp_exit: return "vmx-rdtscp-exit"
        case .vmx_secondary_ctls: return "vmx-secondary-ctls"
        case .vmx_shadow_vmcs: return "vmx-shadow-vmcs"
        case .vmx_store_lma: return "vmx-store-lma"
        case .vmx_true_ctls: return "vmx-true-ctls"
        case .vmx_tsc_offset: return "vmx-tsc-offset"
        case .vmx_tsc_scaling: return "vmx-tsc-scaling"
        case .vmx_unrestricted_guest: return "vmx-unrestricted-guest"
        case .vmx_vintr_pending: return "vmx-vintr-pending"
        case .vmx_vmfunc: return "vmx-vmfunc"
        case .vmx_vmwrite_vmexit_fields: return "vmx-vmwrite-vmexit-fields"
        case .vmx_vnmi: return "vmx-vnmi"
        case .vmx_vnmi_pending: return "vmx-vnmi-pending"
        case .vmx_vpid: return "vmx-vpid"
        case .vmx_wbinvd_exit: return "vmx-wbinvd-exit"
        case .vmx_xsaves: return "vmx-xsaves"
        case .vmx_zero_len_inject: return "vmx-zero-len-inject"
        case .vnmi: return "vnmi"
        case .vpclmulqdq: return "vpclmulqdq"
        case .waitpkg: return "waitpkg"
        case .wbnoinvd: return "wbnoinvd"
        case .wdt: return "wdt"
        case .wrmsrns: return "wrmsrns"
        case .x2apic: return "x2apic"
        case .xcrypt: return "xcrypt"
        case .xcrypt_en: return "xcrypt-en"
        case .xfd: return "xfd"
        case .xgetbv1: return "xgetbv1"
        case .xop: return "xop"
        case .xsave: return "xsave"
        case .xsavec: return "xsavec"
        case .xsaveerptr: return "xsaveerptr"
        case .xsaveopt: return "xsaveopt"
        case .xsaves: return "xsaves"
        case .xstore: return "xstore"
        case .xstore_en: return "xstore-en"
        case .xtpr: return "xtpr"
        }
    }
}

typealias QEMUCPUFlag_xtensa = AnyQEMUConstant

typealias QEMUCPUFlag_xtensaeb = AnyQEMUConstant

enum QEMUTarget_alpha: String, CaseIterable, QEMUTarget {
    case clipper
    case none

    static var `default`: QEMUTarget_alpha {
        .clipper
    }

    var prettyValue: String {
        switch self {
        case .clipper: return "Alpha DP264/CLIPPER (default) (clipper)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_arm: String, CaseIterable, QEMUTarget {
    case integratorcp
    case kzm
    case mps2_an385 = "mps2-an385"
    case mps2_an386 = "mps2-an386"
    case mps2_an500 = "mps2-an500"
    case mps2_an505 = "mps2-an505"
    case mps2_an511 = "mps2-an511"
    case mps2_an521 = "mps2-an521"
    case mps3_an524 = "mps3-an524"
    case mps3_an536 = "mps3-an536"
    case mps3_an547 = "mps3-an547"
    case musca_a = "musca-a"
    case musca_b1 = "musca-b1"
    case realview_eb_mpcore = "realview-eb-mpcore"
    case realview_eb = "realview-eb"
    case realview_pbx_a9 = "realview-pbx-a9"
    case realview_pb_a8 = "realview-pb-a8"
    case vexpress_a15 = "vexpress-a15"
    case vexpress_a9 = "vexpress-a9"
    case versatileab
    case versatilepb
    case imx25_pdk = "imx25-pdk"
    case ast1030_evb = "ast1030-evb"
    case ast2500_evb = "ast2500-evb"
    case ast2600_evb = "ast2600-evb"
    case b_l475e_iot01a = "b-l475e-iot01a"
    case microbit
    case bpim2u
    case g220a_bmc = "g220a-bmc"
    case highbank
    case midway
    case canon_a1100 = "canon-a1100"
    case bletchley_bmc = "bletchley-bmc"
    case fuji_bmc = "fuji-bmc"
    case tiogapass_bmc = "tiogapass-bmc"
    case yosemitev2_bmc = "yosemitev2-bmc"
    case fby35_bmc = "fby35-bmc"
    case sabrelite
    case mcimx6ul_evk = "mcimx6ul-evk"
    case mcimx7d_sabre = "mcimx7d-sabre"
    case connex
    case verdex
    case rainier_bmc = "rainier-bmc"
    case fp5280g2_bmc = "fp5280g2-bmc"
    case kudo_bmc = "kudo-bmc"
    case mainstone
    case musicpal
    case fby35
    case mori_bmc = "mori-bmc"
    case netduino2
    case netduinoplus2
    case n800
    case n810
    case npcm750_evb = "npcm750-evb"
    case sonorapass_bmc = "sonorapass-bmc"
    case olimex_stm32_h405 = "olimex-stm32-h405"
    case palmetto_bmc = "palmetto-bmc"
    case romulus_bmc = "romulus-bmc"
    case tacoma_bmc = "tacoma-bmc"
    case witherspoon_bmc = "witherspoon-bmc"
    case orangepi_pc = "orangepi-pc"
    case cheetah
    case virt_2_10 = "virt-2.10"
    case virt_2_11 = "virt-2.11"
    case virt_2_12 = "virt-2.12"
    case virt_2_6 = "virt-2.6"
    case virt_2_7 = "virt-2.7"
    case virt_2_8 = "virt-2.8"
    case virt_2_9 = "virt-2.9"
    case virt_3_0 = "virt-3.0"
    case virt_3_1 = "virt-3.1"
    case virt_4_0 = "virt-4.0"
    case virt_4_1 = "virt-4.1"
    case virt_4_2 = "virt-4.2"
    case virt_5_0 = "virt-5.0"
    case virt_5_1 = "virt-5.1"
    case virt_5_2 = "virt-5.2"
    case virt_6_0 = "virt-6.0"
    case virt_6_1 = "virt-6.1"
    case virt_6_2 = "virt-6.2"
    case virt_7_0 = "virt-7.0"
    case virt_7_1 = "virt-7.1"
    case virt_7_2 = "virt-7.2"
    case virt_8_0 = "virt-8.0"
    case virt_8_1 = "virt-8.1"
    case virt_8_2 = "virt-8.2"
    case virt_9_0 = "virt-9.0"
    case virt
    case virt_9_1 = "virt-9.1"
    case qcom_dc_scm_v1_bmc = "qcom-dc-scm-v1-bmc"
    case qcom_firework_bmc = "qcom-firework-bmc"
    case quanta_gbs_bmc = "quanta-gbs-bmc"
    case quanta_gsj = "quanta-gsj"
    case quanta_q71l_bmc = "quanta-q71l-bmc"
    case raspi2b
    case raspi1ap
    case raspi0
    case stm32vldiscovery
    case nuri
    case smdkc210
    case collie
    case tosa
    case akita
    case spitz
    case borzoi
    case terrier
    case sx1_v1 = "sx1-v1"
    case sx1
    case emcraft_sf2 = "emcraft-sf2"
    case lm3s6965evb
    case lm3s811evb
    case supermicrox11_bmc = "supermicrox11-bmc"
    case supermicro_x11spi_bmc = "supermicro-x11spi-bmc"
    case xilinx_zynq_a9 = "xilinx-zynq-a9"
    case z2
    case cubieboard
    case none

    static var `default`: QEMUTarget_arm {
        .virt
    }

    var prettyValue: String {
        switch self {
        case .integratorcp: return "ARM Integrator/CP (ARM926EJ-S) (integratorcp)"
        case .kzm: return "ARM KZM Emulation Baseboard (ARM1136) (kzm)"
        case .mps2_an385: return "ARM MPS2 with AN385 FPGA image for Cortex-M3 (mps2-an385)"
        case .mps2_an386: return "ARM MPS2 with AN386 FPGA image for Cortex-M4 (mps2-an386)"
        case .mps2_an500: return "ARM MPS2 with AN500 FPGA image for Cortex-M7 (mps2-an500)"
        case .mps2_an505: return "ARM MPS2 with AN505 FPGA image for Cortex-M33 (mps2-an505)"
        case .mps2_an511: return "ARM MPS2 with AN511 DesignStart FPGA image for Cortex-M3 (mps2-an511)"
        case .mps2_an521: return "ARM MPS2 with AN521 FPGA image for dual Cortex-M33 (mps2-an521)"
        case .mps3_an524: return "ARM MPS3 with AN524 FPGA image for dual Cortex-M33 (mps3-an524)"
        case .mps3_an536: return "ARM MPS3 with AN536 FPGA image for Cortex-R52 (mps3-an536)"
        case .mps3_an547: return "ARM MPS3 with AN547 FPGA image for Cortex-M55 (mps3-an547)"
        case .musca_a: return "ARM Musca-A board (dual Cortex-M33) (musca-a)"
        case .musca_b1: return "ARM Musca-B1 board (dual Cortex-M33) (musca-b1)"
        case .realview_eb_mpcore: return "ARM RealView Emulation Baseboard (ARM11MPCore) (realview-eb-mpcore)"
        case .realview_eb: return "ARM RealView Emulation Baseboard (ARM926EJ-S) (realview-eb)"
        case .realview_pbx_a9: return "ARM RealView Platform Baseboard Explore for Cortex-A9 (realview-pbx-a9)"
        case .realview_pb_a8: return "ARM RealView Platform Baseboard for Cortex-A8 (realview-pb-a8)"
        case .vexpress_a15: return "ARM Versatile Express for Cortex-A15 (vexpress-a15)"
        case .vexpress_a9: return "ARM Versatile Express for Cortex-A9 (vexpress-a9)"
        case .versatileab: return "ARM Versatile/AB (ARM926EJ-S) (versatileab)"
        case .versatilepb: return "ARM Versatile/PB (ARM926EJ-S) (versatilepb)"
        case .imx25_pdk: return "ARM i.MX25 PDK board (ARM926) (imx25-pdk)"
        case .ast1030_evb: return "Aspeed AST1030 MiniBMC (Cortex-M4) (ast1030-evb)"
        case .ast2500_evb: return "Aspeed AST2500 EVB (ARM1176) (ast2500-evb)"
        case .ast2600_evb: return "Aspeed AST2600 EVB (Cortex-A7) (ast2600-evb)"
        case .b_l475e_iot01a: return "B-L475E-IOT01A Discovery Kit (Cortex-M4) (b-l475e-iot01a)"
        case .microbit: return "BBC micro:bit (Cortex-M0) (microbit)"
        case .bpim2u: return "Bananapi M2U (Cortex-A7) (bpim2u)"
        case .g220a_bmc: return "Bytedance G220A BMC (ARM1176) (g220a-bmc)"
        case .highbank: return "Calxeda Highbank (ECX-1000) (highbank)"
        case .midway: return "Calxeda Midway (ECX-2000) (midway)"
        case .canon_a1100: return "Canon PowerShot A1100 IS (ARM946) (canon-a1100)"
        case .bletchley_bmc: return "Facebook Bletchley BMC (Cortex-A7) (bletchley-bmc)"
        case .fuji_bmc: return "Facebook Fuji BMC (Cortex-A7) (fuji-bmc)"
        case .tiogapass_bmc: return "Facebook Tiogapass BMC (ARM1176) (tiogapass-bmc)"
        case .yosemitev2_bmc: return "Facebook YosemiteV2 BMC (ARM1176) (yosemitev2-bmc)"
        case .fby35_bmc: return "Facebook fby35 BMC (Cortex-A7) (fby35-bmc)"
        case .sabrelite: return "Freescale i.MX6 Quad SABRE Lite Board (Cortex-A9) (sabrelite)"
        case .mcimx6ul_evk: return "Freescale i.MX6UL Evaluation Kit (Cortex-A7) (mcimx6ul-evk)"
        case .mcimx7d_sabre: return "Freescale i.MX7 DUAL SABRE (Cortex-A7) (mcimx7d-sabre)"
        case .connex: return "Gumstix Connex (PXA255) (deprecated) (connex)"
        case .verdex: return "Gumstix Verdex Pro XL6P COMs (PXA270) (deprecated) (verdex)"
        case .rainier_bmc: return "IBM Rainier BMC (Cortex-A7) (rainier-bmc)"
        case .fp5280g2_bmc: return "Inspur FP5280G2 BMC (ARM1176) (fp5280g2-bmc)"
        case .kudo_bmc: return "Kudo BMC (Cortex-A9) (kudo-bmc)"
        case .mainstone: return "Mainstone II (PXA27x) (deprecated) (mainstone)"
        case .musicpal: return "Marvell 88w8618 / MusicPal (ARM926EJ-S) (musicpal)"
        case .fby35: return "Meta Platforms fby35 (fby35)"
        case .mori_bmc: return "Mori BMC (Cortex-A9) (mori-bmc)"
        case .netduino2: return "Netduino 2 Machine (Cortex-M3) (netduino2)"
        case .netduinoplus2: return "Netduino Plus 2 Machine (Cortex-M4) (netduinoplus2)"
        case .n800: return "Nokia N800 tablet aka. RX-34 (OMAP2420) (deprecated) (n800)"
        case .n810: return "Nokia N810 tablet aka. RX-44 (OMAP2420) (deprecated) (n810)"
        case .npcm750_evb: return "Nuvoton NPCM750 Evaluation Board (Cortex-A9) (npcm750-evb)"
        case .sonorapass_bmc: return "OCP SonoraPass BMC (ARM1176) (sonorapass-bmc)"
        case .olimex_stm32_h405: return "Olimex STM32-H405 (Cortex-M4) (olimex-stm32-h405)"
        case .palmetto_bmc: return "OpenPOWER Palmetto BMC (ARM926EJ-S) (palmetto-bmc)"
        case .romulus_bmc: return "OpenPOWER Romulus BMC (ARM1176) (romulus-bmc)"
        case .tacoma_bmc: return "OpenPOWER Tacoma BMC (Cortex-A7) (deprecated) (tacoma-bmc)"
        case .witherspoon_bmc: return "OpenPOWER Witherspoon BMC (ARM1176) (witherspoon-bmc)"
        case .orangepi_pc: return "Orange Pi PC (Cortex-A7) (orangepi-pc)"
        case .cheetah: return "Palm Tungsten|E aka. Cheetah PDA (OMAP310) (deprecated) (cheetah)"
        case .virt_2_10: return "QEMU 2.10 ARM Virtual Machine (deprecated) (virt-2.10)"
        case .virt_2_11: return "QEMU 2.11 ARM Virtual Machine (deprecated) (virt-2.11)"
        case .virt_2_12: return "QEMU 2.12 ARM Virtual Machine (deprecated) (virt-2.12)"
        case .virt_2_6: return "QEMU 2.6 ARM Virtual Machine (deprecated) (virt-2.6)"
        case .virt_2_7: return "QEMU 2.7 ARM Virtual Machine (deprecated) (virt-2.7)"
        case .virt_2_8: return "QEMU 2.8 ARM Virtual Machine (deprecated) (virt-2.8)"
        case .virt_2_9: return "QEMU 2.9 ARM Virtual Machine (deprecated) (virt-2.9)"
        case .virt_3_0: return "QEMU 3.0 ARM Virtual Machine (deprecated) (virt-3.0)"
        case .virt_3_1: return "QEMU 3.1 ARM Virtual Machine (deprecated) (virt-3.1)"
        case .virt_4_0: return "QEMU 4.0 ARM Virtual Machine (deprecated) (virt-4.0)"
        case .virt_4_1: return "QEMU 4.1 ARM Virtual Machine (deprecated) (virt-4.1)"
        case .virt_4_2: return "QEMU 4.2 ARM Virtual Machine (deprecated) (virt-4.2)"
        case .virt_5_0: return "QEMU 5.0 ARM Virtual Machine (deprecated) (virt-5.0)"
        case .virt_5_1: return "QEMU 5.1 ARM Virtual Machine (deprecated) (virt-5.1)"
        case .virt_5_2: return "QEMU 5.2 ARM Virtual Machine (deprecated) (virt-5.2)"
        case .virt_6_0: return "QEMU 6.0 ARM Virtual Machine (deprecated) (virt-6.0)"
        case .virt_6_1: return "QEMU 6.1 ARM Virtual Machine (deprecated) (virt-6.1)"
        case .virt_6_2: return "QEMU 6.2 ARM Virtual Machine (virt-6.2)"
        case .virt_7_0: return "QEMU 7.0 ARM Virtual Machine (virt-7.0)"
        case .virt_7_1: return "QEMU 7.1 ARM Virtual Machine (virt-7.1)"
        case .virt_7_2: return "QEMU 7.2 ARM Virtual Machine (virt-7.2)"
        case .virt_8_0: return "QEMU 8.0 ARM Virtual Machine (virt-8.0)"
        case .virt_8_1: return "QEMU 8.1 ARM Virtual Machine (virt-8.1)"
        case .virt_8_2: return "QEMU 8.2 ARM Virtual Machine (virt-8.2)"
        case .virt_9_0: return "QEMU 9.0 ARM Virtual Machine (virt-9.0)"
        case .virt: return "QEMU 9.1 ARM Virtual Machine (alias of virt-9.1) (virt)"
        case .virt_9_1: return "QEMU 9.1 ARM Virtual Machine (virt-9.1)"
        case .qcom_dc_scm_v1_bmc: return "Qualcomm DC-SCM V1 BMC (Cortex A7) (qcom-dc-scm-v1-bmc)"
        case .qcom_firework_bmc: return "Qualcomm DC-SCM V1/Firework BMC (Cortex A7) (qcom-firework-bmc)"
        case .quanta_gbs_bmc: return "Quanta GBS (Cortex-A9) (quanta-gbs-bmc)"
        case .quanta_gsj: return "Quanta GSJ (Cortex-A9) (quanta-gsj)"
        case .quanta_q71l_bmc: return "Quanta-Q71l BMC (ARM926EJ-S) (quanta-q71l-bmc)"
        case .raspi2b: return "Raspberry Pi 2B (revision 1.1) (raspi2b)"
        case .raspi1ap: return "Raspberry Pi A+ (revision 1.1) (raspi1ap)"
        case .raspi0: return "Raspberry Pi Zero (revision 1.2) (raspi0)"
        case .stm32vldiscovery: return "ST STM32VLDISCOVERY (Cortex-M3) (stm32vldiscovery)"
        case .nuri: return "Samsung NURI board (Exynos4210) (nuri)"
        case .smdkc210: return "Samsung SMDKC210 board (Exynos4210) (smdkc210)"
        case .collie: return "Sharp SL-5500 (Collie) PDA (SA-1110) (collie)"
        case .tosa: return "Sharp SL-6000 (Tosa) PDA (PXA255) (deprecated) (tosa)"
        case .akita: return "Sharp SL-C1000 (Akita) PDA (PXA270) (deprecated) (akita)"
        case .spitz: return "Sharp SL-C3000 (Spitz) PDA (PXA270) (deprecated) (spitz)"
        case .borzoi: return "Sharp SL-C3100 (Borzoi) PDA (PXA270) (deprecated) (borzoi)"
        case .terrier: return "Sharp SL-C3200 (Terrier) PDA (PXA270) (deprecated) (terrier)"
        case .sx1_v1: return "Siemens SX1 (OMAP310) V1 (sx1-v1)"
        case .sx1: return "Siemens SX1 (OMAP310) V2 (sx1)"
        case .emcraft_sf2: return "SmartFusion2 SOM kit from Emcraft (M2S010) (emcraft-sf2)"
        case .lm3s6965evb: return "Stellaris LM3S6965EVB (Cortex-M3) (lm3s6965evb)"
        case .lm3s811evb: return "Stellaris LM3S811EVB (Cortex-M3) (lm3s811evb)"
        case .supermicrox11_bmc: return "Supermicro X11 BMC (ARM926EJ-S) (supermicrox11-bmc)"
        case .supermicro_x11spi_bmc: return "Supermicro X11 SPI BMC (ARM1176) (supermicro-x11spi-bmc)"
        case .xilinx_zynq_a9: return "Xilinx Zynq Platform Baseboard for Cortex-A9 (xilinx-zynq-a9)"
        case .z2: return "Zipit Z2 (PXA27x) (deprecated) (z2)"
        case .cubieboard: return "cubietech cubieboard (Cortex-A8) (cubieboard)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_aarch64: String, CaseIterable, QEMUTarget {
    case integratorcp
    case kzm
    case mps2_an385 = "mps2-an385"
    case mps2_an386 = "mps2-an386"
    case mps2_an500 = "mps2-an500"
    case mps2_an505 = "mps2-an505"
    case mps2_an511 = "mps2-an511"
    case mps2_an521 = "mps2-an521"
    case mps3_an524 = "mps3-an524"
    case mps3_an536 = "mps3-an536"
    case mps3_an547 = "mps3-an547"
    case musca_a = "musca-a"
    case musca_b1 = "musca-b1"
    case realview_eb_mpcore = "realview-eb-mpcore"
    case realview_eb = "realview-eb"
    case realview_pbx_a9 = "realview-pbx-a9"
    case realview_pb_a8 = "realview-pb-a8"
    case vexpress_a15 = "vexpress-a15"
    case vexpress_a9 = "vexpress-a9"
    case versatileab
    case versatilepb
    case imx25_pdk = "imx25-pdk"
    case ast1030_evb = "ast1030-evb"
    case ast2500_evb = "ast2500-evb"
    case ast2600_evb = "ast2600-evb"
    case ast2700_evb = "ast2700-evb"
    case b_l475e_iot01a = "b-l475e-iot01a"
    case microbit
    case bpim2u
    case g220a_bmc = "g220a-bmc"
    case highbank
    case midway
    case canon_a1100 = "canon-a1100"
    case bletchley_bmc = "bletchley-bmc"
    case fuji_bmc = "fuji-bmc"
    case tiogapass_bmc = "tiogapass-bmc"
    case yosemitev2_bmc = "yosemitev2-bmc"
    case fby35_bmc = "fby35-bmc"
    case sabrelite
    case mcimx6ul_evk = "mcimx6ul-evk"
    case mcimx7d_sabre = "mcimx7d-sabre"
    case connex
    case verdex
    case rainier_bmc = "rainier-bmc"
    case fp5280g2_bmc = "fp5280g2-bmc"
    case kudo_bmc = "kudo-bmc"
    case mainstone
    case musicpal
    case fby35
    case mori_bmc = "mori-bmc"
    case netduino2
    case netduinoplus2
    case n800
    case n810
    case npcm750_evb = "npcm750-evb"
    case sonorapass_bmc = "sonorapass-bmc"
    case olimex_stm32_h405 = "olimex-stm32-h405"
    case palmetto_bmc = "palmetto-bmc"
    case romulus_bmc = "romulus-bmc"
    case tacoma_bmc = "tacoma-bmc"
    case witherspoon_bmc = "witherspoon-bmc"
    case orangepi_pc = "orangepi-pc"
    case cheetah
    case sbsa_ref = "sbsa-ref"
    case virt_2_10 = "virt-2.10"
    case virt_2_11 = "virt-2.11"
    case virt_2_12 = "virt-2.12"
    case virt_2_6 = "virt-2.6"
    case virt_2_7 = "virt-2.7"
    case virt_2_8 = "virt-2.8"
    case virt_2_9 = "virt-2.9"
    case virt_3_0 = "virt-3.0"
    case virt_3_1 = "virt-3.1"
    case virt_4_0 = "virt-4.0"
    case virt_4_1 = "virt-4.1"
    case virt_4_2 = "virt-4.2"
    case virt_5_0 = "virt-5.0"
    case virt_5_1 = "virt-5.1"
    case virt_5_2 = "virt-5.2"
    case virt_6_0 = "virt-6.0"
    case virt_6_1 = "virt-6.1"
    case virt_6_2 = "virt-6.2"
    case virt_7_0 = "virt-7.0"
    case virt_7_1 = "virt-7.1"
    case virt_7_2 = "virt-7.2"
    case virt_8_0 = "virt-8.0"
    case virt_8_1 = "virt-8.1"
    case virt_8_2 = "virt-8.2"
    case virt_9_0 = "virt-9.0"
    case virt
    case virt_9_1 = "virt-9.1"
    case qcom_dc_scm_v1_bmc = "qcom-dc-scm-v1-bmc"
    case qcom_firework_bmc = "qcom-firework-bmc"
    case quanta_gbs_bmc = "quanta-gbs-bmc"
    case quanta_gsj = "quanta-gsj"
    case quanta_q71l_bmc = "quanta-q71l-bmc"
    case raspi2b
    case raspi3ap
    case raspi3b
    case raspi4b
    case raspi1ap
    case raspi0
    case stm32vldiscovery
    case nuri
    case smdkc210
    case collie
    case tosa
    case akita
    case spitz
    case borzoi
    case terrier
    case sx1_v1 = "sx1-v1"
    case sx1
    case emcraft_sf2 = "emcraft-sf2"
    case lm3s6965evb
    case lm3s811evb
    case supermicrox11_bmc = "supermicrox11-bmc"
    case supermicro_x11spi_bmc = "supermicro-x11spi-bmc"
    case xlnx_versal_virt = "xlnx-versal-virt"
    case xilinx_zynq_a9 = "xilinx-zynq-a9"
    case xlnx_zcu102 = "xlnx-zcu102"
    case z2
    case cubieboard
    case none

    static var `default`: QEMUTarget_aarch64 {
        .virt
    }

    var prettyValue: String {
        switch self {
        case .integratorcp: return "ARM Integrator/CP (ARM926EJ-S) (integratorcp)"
        case .kzm: return "ARM KZM Emulation Baseboard (ARM1136) (kzm)"
        case .mps2_an385: return "ARM MPS2 with AN385 FPGA image for Cortex-M3 (mps2-an385)"
        case .mps2_an386: return "ARM MPS2 with AN386 FPGA image for Cortex-M4 (mps2-an386)"
        case .mps2_an500: return "ARM MPS2 with AN500 FPGA image for Cortex-M7 (mps2-an500)"
        case .mps2_an505: return "ARM MPS2 with AN505 FPGA image for Cortex-M33 (mps2-an505)"
        case .mps2_an511: return "ARM MPS2 with AN511 DesignStart FPGA image for Cortex-M3 (mps2-an511)"
        case .mps2_an521: return "ARM MPS2 with AN521 FPGA image for dual Cortex-M33 (mps2-an521)"
        case .mps3_an524: return "ARM MPS3 with AN524 FPGA image for dual Cortex-M33 (mps3-an524)"
        case .mps3_an536: return "ARM MPS3 with AN536 FPGA image for Cortex-R52 (mps3-an536)"
        case .mps3_an547: return "ARM MPS3 with AN547 FPGA image for Cortex-M55 (mps3-an547)"
        case .musca_a: return "ARM Musca-A board (dual Cortex-M33) (musca-a)"
        case .musca_b1: return "ARM Musca-B1 board (dual Cortex-M33) (musca-b1)"
        case .realview_eb_mpcore: return "ARM RealView Emulation Baseboard (ARM11MPCore) (realview-eb-mpcore)"
        case .realview_eb: return "ARM RealView Emulation Baseboard (ARM926EJ-S) (realview-eb)"
        case .realview_pbx_a9: return "ARM RealView Platform Baseboard Explore for Cortex-A9 (realview-pbx-a9)"
        case .realview_pb_a8: return "ARM RealView Platform Baseboard for Cortex-A8 (realview-pb-a8)"
        case .vexpress_a15: return "ARM Versatile Express for Cortex-A15 (vexpress-a15)"
        case .vexpress_a9: return "ARM Versatile Express for Cortex-A9 (vexpress-a9)"
        case .versatileab: return "ARM Versatile/AB (ARM926EJ-S) (versatileab)"
        case .versatilepb: return "ARM Versatile/PB (ARM926EJ-S) (versatilepb)"
        case .imx25_pdk: return "ARM i.MX25 PDK board (ARM926) (imx25-pdk)"
        case .ast1030_evb: return "Aspeed AST1030 MiniBMC (Cortex-M4) (ast1030-evb)"
        case .ast2500_evb: return "Aspeed AST2500 EVB (ARM1176) (ast2500-evb)"
        case .ast2600_evb: return "Aspeed AST2600 EVB (Cortex-A7) (ast2600-evb)"
        case .ast2700_evb: return "Aspeed AST2700 EVB (Cortex-A35) (ast2700-evb)"
        case .b_l475e_iot01a: return "B-L475E-IOT01A Discovery Kit (Cortex-M4) (b-l475e-iot01a)"
        case .microbit: return "BBC micro:bit (Cortex-M0) (microbit)"
        case .bpim2u: return "Bananapi M2U (Cortex-A7) (bpim2u)"
        case .g220a_bmc: return "Bytedance G220A BMC (ARM1176) (g220a-bmc)"
        case .highbank: return "Calxeda Highbank (ECX-1000) (highbank)"
        case .midway: return "Calxeda Midway (ECX-2000) (midway)"
        case .canon_a1100: return "Canon PowerShot A1100 IS (ARM946) (canon-a1100)"
        case .bletchley_bmc: return "Facebook Bletchley BMC (Cortex-A7) (bletchley-bmc)"
        case .fuji_bmc: return "Facebook Fuji BMC (Cortex-A7) (fuji-bmc)"
        case .tiogapass_bmc: return "Facebook Tiogapass BMC (ARM1176) (tiogapass-bmc)"
        case .yosemitev2_bmc: return "Facebook YosemiteV2 BMC (ARM1176) (yosemitev2-bmc)"
        case .fby35_bmc: return "Facebook fby35 BMC (Cortex-A7) (fby35-bmc)"
        case .sabrelite: return "Freescale i.MX6 Quad SABRE Lite Board (Cortex-A9) (sabrelite)"
        case .mcimx6ul_evk: return "Freescale i.MX6UL Evaluation Kit (Cortex-A7) (mcimx6ul-evk)"
        case .mcimx7d_sabre: return "Freescale i.MX7 DUAL SABRE (Cortex-A7) (mcimx7d-sabre)"
        case .connex: return "Gumstix Connex (PXA255) (deprecated) (connex)"
        case .verdex: return "Gumstix Verdex Pro XL6P COMs (PXA270) (deprecated) (verdex)"
        case .rainier_bmc: return "IBM Rainier BMC (Cortex-A7) (rainier-bmc)"
        case .fp5280g2_bmc: return "Inspur FP5280G2 BMC (ARM1176) (fp5280g2-bmc)"
        case .kudo_bmc: return "Kudo BMC (Cortex-A9) (kudo-bmc)"
        case .mainstone: return "Mainstone II (PXA27x) (deprecated) (mainstone)"
        case .musicpal: return "Marvell 88w8618 / MusicPal (ARM926EJ-S) (musicpal)"
        case .fby35: return "Meta Platforms fby35 (fby35)"
        case .mori_bmc: return "Mori BMC (Cortex-A9) (mori-bmc)"
        case .netduino2: return "Netduino 2 Machine (Cortex-M3) (netduino2)"
        case .netduinoplus2: return "Netduino Plus 2 Machine (Cortex-M4) (netduinoplus2)"
        case .n800: return "Nokia N800 tablet aka. RX-34 (OMAP2420) (deprecated) (n800)"
        case .n810: return "Nokia N810 tablet aka. RX-44 (OMAP2420) (deprecated) (n810)"
        case .npcm750_evb: return "Nuvoton NPCM750 Evaluation Board (Cortex-A9) (npcm750-evb)"
        case .sonorapass_bmc: return "OCP SonoraPass BMC (ARM1176) (sonorapass-bmc)"
        case .olimex_stm32_h405: return "Olimex STM32-H405 (Cortex-M4) (olimex-stm32-h405)"
        case .palmetto_bmc: return "OpenPOWER Palmetto BMC (ARM926EJ-S) (palmetto-bmc)"
        case .romulus_bmc: return "OpenPOWER Romulus BMC (ARM1176) (romulus-bmc)"
        case .tacoma_bmc: return "OpenPOWER Tacoma BMC (Cortex-A7) (deprecated) (tacoma-bmc)"
        case .witherspoon_bmc: return "OpenPOWER Witherspoon BMC (ARM1176) (witherspoon-bmc)"
        case .orangepi_pc: return "Orange Pi PC (Cortex-A7) (orangepi-pc)"
        case .cheetah: return "Palm Tungsten|E aka. Cheetah PDA (OMAP310) (deprecated) (cheetah)"
        case .sbsa_ref: return "QEMU 'SBSA Reference' ARM Virtual Machine (sbsa-ref)"
        case .virt_2_10: return "QEMU 2.10 ARM Virtual Machine (deprecated) (virt-2.10)"
        case .virt_2_11: return "QEMU 2.11 ARM Virtual Machine (deprecated) (virt-2.11)"
        case .virt_2_12: return "QEMU 2.12 ARM Virtual Machine (deprecated) (virt-2.12)"
        case .virt_2_6: return "QEMU 2.6 ARM Virtual Machine (deprecated) (virt-2.6)"
        case .virt_2_7: return "QEMU 2.7 ARM Virtual Machine (deprecated) (virt-2.7)"
        case .virt_2_8: return "QEMU 2.8 ARM Virtual Machine (deprecated) (virt-2.8)"
        case .virt_2_9: return "QEMU 2.9 ARM Virtual Machine (deprecated) (virt-2.9)"
        case .virt_3_0: return "QEMU 3.0 ARM Virtual Machine (deprecated) (virt-3.0)"
        case .virt_3_1: return "QEMU 3.1 ARM Virtual Machine (deprecated) (virt-3.1)"
        case .virt_4_0: return "QEMU 4.0 ARM Virtual Machine (deprecated) (virt-4.0)"
        case .virt_4_1: return "QEMU 4.1 ARM Virtual Machine (deprecated) (virt-4.1)"
        case .virt_4_2: return "QEMU 4.2 ARM Virtual Machine (deprecated) (virt-4.2)"
        case .virt_5_0: return "QEMU 5.0 ARM Virtual Machine (deprecated) (virt-5.0)"
        case .virt_5_1: return "QEMU 5.1 ARM Virtual Machine (deprecated) (virt-5.1)"
        case .virt_5_2: return "QEMU 5.2 ARM Virtual Machine (deprecated) (virt-5.2)"
        case .virt_6_0: return "QEMU 6.0 ARM Virtual Machine (deprecated) (virt-6.0)"
        case .virt_6_1: return "QEMU 6.1 ARM Virtual Machine (deprecated) (virt-6.1)"
        case .virt_6_2: return "QEMU 6.2 ARM Virtual Machine (virt-6.2)"
        case .virt_7_0: return "QEMU 7.0 ARM Virtual Machine (virt-7.0)"
        case .virt_7_1: return "QEMU 7.1 ARM Virtual Machine (virt-7.1)"
        case .virt_7_2: return "QEMU 7.2 ARM Virtual Machine (virt-7.2)"
        case .virt_8_0: return "QEMU 8.0 ARM Virtual Machine (virt-8.0)"
        case .virt_8_1: return "QEMU 8.1 ARM Virtual Machine (virt-8.1)"
        case .virt_8_2: return "QEMU 8.2 ARM Virtual Machine (virt-8.2)"
        case .virt_9_0: return "QEMU 9.0 ARM Virtual Machine (virt-9.0)"
        case .virt: return "QEMU 9.1 ARM Virtual Machine (alias of virt-9.1) (virt)"
        case .virt_9_1: return "QEMU 9.1 ARM Virtual Machine (virt-9.1)"
        case .qcom_dc_scm_v1_bmc: return "Qualcomm DC-SCM V1 BMC (Cortex A7) (qcom-dc-scm-v1-bmc)"
        case .qcom_firework_bmc: return "Qualcomm DC-SCM V1/Firework BMC (Cortex A7) (qcom-firework-bmc)"
        case .quanta_gbs_bmc: return "Quanta GBS (Cortex-A9) (quanta-gbs-bmc)"
        case .quanta_gsj: return "Quanta GSJ (Cortex-A9) (quanta-gsj)"
        case .quanta_q71l_bmc: return "Quanta-Q71l BMC (ARM926EJ-S) (quanta-q71l-bmc)"
        case .raspi2b: return "Raspberry Pi 2B (revision 1.1) (raspi2b)"
        case .raspi3ap: return "Raspberry Pi 3A+ (revision 1.0) (raspi3ap)"
        case .raspi3b: return "Raspberry Pi 3B (revision 1.2) (raspi3b)"
        case .raspi4b: return "Raspberry Pi 4B (revision 1.5) (raspi4b)"
        case .raspi1ap: return "Raspberry Pi A+ (revision 1.1) (raspi1ap)"
        case .raspi0: return "Raspberry Pi Zero (revision 1.2) (raspi0)"
        case .stm32vldiscovery: return "ST STM32VLDISCOVERY (Cortex-M3) (stm32vldiscovery)"
        case .nuri: return "Samsung NURI board (Exynos4210) (nuri)"
        case .smdkc210: return "Samsung SMDKC210 board (Exynos4210) (smdkc210)"
        case .collie: return "Sharp SL-5500 (Collie) PDA (SA-1110) (collie)"
        case .tosa: return "Sharp SL-6000 (Tosa) PDA (PXA255) (deprecated) (tosa)"
        case .akita: return "Sharp SL-C1000 (Akita) PDA (PXA270) (deprecated) (akita)"
        case .spitz: return "Sharp SL-C3000 (Spitz) PDA (PXA270) (deprecated) (spitz)"
        case .borzoi: return "Sharp SL-C3100 (Borzoi) PDA (PXA270) (deprecated) (borzoi)"
        case .terrier: return "Sharp SL-C3200 (Terrier) PDA (PXA270) (deprecated) (terrier)"
        case .sx1_v1: return "Siemens SX1 (OMAP310) V1 (sx1-v1)"
        case .sx1: return "Siemens SX1 (OMAP310) V2 (sx1)"
        case .emcraft_sf2: return "SmartFusion2 SOM kit from Emcraft (M2S010) (emcraft-sf2)"
        case .lm3s6965evb: return "Stellaris LM3S6965EVB (Cortex-M3) (lm3s6965evb)"
        case .lm3s811evb: return "Stellaris LM3S811EVB (Cortex-M3) (lm3s811evb)"
        case .supermicrox11_bmc: return "Supermicro X11 BMC (ARM926EJ-S) (supermicrox11-bmc)"
        case .supermicro_x11spi_bmc: return "Supermicro X11 SPI BMC (ARM1176) (supermicro-x11spi-bmc)"
        case .xlnx_versal_virt: return "Xilinx Versal Virtual development board (xlnx-versal-virt)"
        case .xilinx_zynq_a9: return "Xilinx Zynq Platform Baseboard for Cortex-A9 (xilinx-zynq-a9)"
        case .xlnx_zcu102: return "Xilinx ZynqMP ZCU102 board with 4xA53s and 2xR5Fs based on the value of smp (xlnx-zcu102)"
        case .z2: return "Zipit Z2 (PXA27x) (deprecated) (z2)"
        case .cubieboard: return "cubietech cubieboard (Cortex-A8) (cubieboard)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_avr: String, CaseIterable, QEMUTarget {
    case _2009 = "2009"
    case arduino_duemilanove = "arduino-duemilanove"
    case mega
    case arduino_mega = "arduino-mega"
    case mega2560
    case arduino_mega_2560_v3 = "arduino-mega-2560-v3"
    case uno
    case arduino_uno = "arduino-uno"
    case none

    static var `default`: QEMUTarget_avr {
        .mega
    }

    var prettyValue: String {
        switch self {
        case ._2009: return "Arduino Duemilanove (ATmega168) (alias of arduino-duemilanove) (2009)"
        case .arduino_duemilanove: return "Arduino Duemilanove (ATmega168) (arduino-duemilanove)"
        case .mega: return "Arduino Mega (ATmega1280) (alias of arduino-mega) (mega)"
        case .arduino_mega: return "Arduino Mega (ATmega1280) (arduino-mega)"
        case .mega2560: return "Arduino Mega 2560 (ATmega2560) (alias of arduino-mega-2560-v3) (mega2560)"
        case .arduino_mega_2560_v3: return "Arduino Mega 2560 (ATmega2560) (arduino-mega-2560-v3)"
        case .uno: return "Arduino UNO (ATmega328P) (alias of arduino-uno) (uno)"
        case .arduino_uno: return "Arduino UNO (ATmega328P) (arduino-uno)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_cris: String, CaseIterable, QEMUTarget {
    case axis_dev88 = "axis-dev88"
    case none

    static var `default`: QEMUTarget_cris {
        .axis_dev88
    }

    var prettyValue: String {
        switch self {
        case .axis_dev88: return "AXIS devboard 88 (default) (axis-dev88)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_hppa: String, CaseIterable, QEMUTarget {
    case B160L
    case C3700
    case none

    static var `default`: QEMUTarget_hppa {
        .B160L
    }

    var prettyValue: String {
        switch self {
        case .B160L: return "HP B160L workstation (default) (B160L)"
        case .C3700: return "HP C3700 workstation (C3700)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_i386: String, CaseIterable, QEMUTarget {
    case isapc
    case q35
    case pc_q35_2_10 = "pc-q35-2.10"
    case pc_q35_2_11 = "pc-q35-2.11"
    case pc_q35_2_12 = "pc-q35-2.12"
    case pc_q35_2_4 = "pc-q35-2.4"
    case pc_q35_2_5 = "pc-q35-2.5"
    case pc_q35_2_6 = "pc-q35-2.6"
    case pc_q35_2_7 = "pc-q35-2.7"
    case pc_q35_2_8 = "pc-q35-2.8"
    case pc_q35_2_9 = "pc-q35-2.9"
    case pc_q35_3_0 = "pc-q35-3.0"
    case pc_q35_3_1 = "pc-q35-3.1"
    case pc_q35_4_0 = "pc-q35-4.0"
    case pc_q35_4_0_1 = "pc-q35-4.0.1"
    case pc_q35_4_1 = "pc-q35-4.1"
    case pc_q35_4_2 = "pc-q35-4.2"
    case pc_q35_5_0 = "pc-q35-5.0"
    case pc_q35_5_1 = "pc-q35-5.1"
    case pc_q35_5_2 = "pc-q35-5.2"
    case pc_q35_6_0 = "pc-q35-6.0"
    case pc_q35_6_1 = "pc-q35-6.1"
    case pc_q35_6_2 = "pc-q35-6.2"
    case pc_q35_7_0 = "pc-q35-7.0"
    case pc_q35_7_1 = "pc-q35-7.1"
    case pc_q35_7_2 = "pc-q35-7.2"
    case pc_q35_8_0 = "pc-q35-8.0"
    case pc_q35_8_1 = "pc-q35-8.1"
    case pc_q35_8_2 = "pc-q35-8.2"
    case pc_q35_9_0 = "pc-q35-9.0"
    case pc_q35_9_1 = "pc-q35-9.1"
    case pc
    case pc_i440fx_9_1 = "pc-i440fx-9.1"
    case pc_i440fx_2_10 = "pc-i440fx-2.10"
    case pc_i440fx_2_11 = "pc-i440fx-2.11"
    case pc_i440fx_2_12 = "pc-i440fx-2.12"
    case pc_i440fx_2_4 = "pc-i440fx-2.4"
    case pc_i440fx_2_5 = "pc-i440fx-2.5"
    case pc_i440fx_2_6 = "pc-i440fx-2.6"
    case pc_i440fx_2_7 = "pc-i440fx-2.7"
    case pc_i440fx_2_8 = "pc-i440fx-2.8"
    case pc_i440fx_2_9 = "pc-i440fx-2.9"
    case pc_i440fx_3_0 = "pc-i440fx-3.0"
    case pc_i440fx_3_1 = "pc-i440fx-3.1"
    case pc_i440fx_4_0 = "pc-i440fx-4.0"
    case pc_i440fx_4_1 = "pc-i440fx-4.1"
    case pc_i440fx_4_2 = "pc-i440fx-4.2"
    case pc_i440fx_5_0 = "pc-i440fx-5.0"
    case pc_i440fx_5_1 = "pc-i440fx-5.1"
    case pc_i440fx_5_2 = "pc-i440fx-5.2"
    case pc_i440fx_6_0 = "pc-i440fx-6.0"
    case pc_i440fx_6_1 = "pc-i440fx-6.1"
    case pc_i440fx_6_2 = "pc-i440fx-6.2"
    case pc_i440fx_7_0 = "pc-i440fx-7.0"
    case pc_i440fx_7_1 = "pc-i440fx-7.1"
    case pc_i440fx_7_2 = "pc-i440fx-7.2"
    case pc_i440fx_8_0 = "pc-i440fx-8.0"
    case pc_i440fx_8_1 = "pc-i440fx-8.1"
    case pc_i440fx_8_2 = "pc-i440fx-8.2"
    case pc_i440fx_9_0 = "pc-i440fx-9.0"
    case none
    case microvm

    static var `default`: QEMUTarget_i386 {
        .q35
    }

    var prettyValue: String {
        switch self {
        case .isapc: return "ISA-only PC (isapc)"
        case .q35: return "Standard PC (Q35 + ICH9, 2009) (alias of pc-q35-9.1) (q35)"
        case .pc_q35_2_10: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.10)"
        case .pc_q35_2_11: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.11)"
        case .pc_q35_2_12: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.12)"
        case .pc_q35_2_4: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.4)"
        case .pc_q35_2_5: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.5)"
        case .pc_q35_2_6: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.6)"
        case .pc_q35_2_7: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.7)"
        case .pc_q35_2_8: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.8)"
        case .pc_q35_2_9: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.9)"
        case .pc_q35_3_0: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-3.0)"
        case .pc_q35_3_1: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-3.1)"
        case .pc_q35_4_0: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-4.0)"
        case .pc_q35_4_0_1: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-4.0.1)"
        case .pc_q35_4_1: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-4.1)"
        case .pc_q35_4_2: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-4.2)"
        case .pc_q35_5_0: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-5.0)"
        case .pc_q35_5_1: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-5.1)"
        case .pc_q35_5_2: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-5.2)"
        case .pc_q35_6_0: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-6.0)"
        case .pc_q35_6_1: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-6.1)"
        case .pc_q35_6_2: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-6.2)"
        case .pc_q35_7_0: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-7.0)"
        case .pc_q35_7_1: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-7.1)"
        case .pc_q35_7_2: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-7.2)"
        case .pc_q35_8_0: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-8.0)"
        case .pc_q35_8_1: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-8.1)"
        case .pc_q35_8_2: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-8.2)"
        case .pc_q35_9_0: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-9.0)"
        case .pc_q35_9_1: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-9.1)"
        case .pc: return "Standard PC (i440FX + PIIX, 1996) (alias of pc-i440fx-9.1) (pc)"
        case .pc_i440fx_9_1: return "Standard PC (i440FX + PIIX, 1996) (default) (pc-i440fx-9.1)"
        case .pc_i440fx_2_10: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.10)"
        case .pc_i440fx_2_11: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.11)"
        case .pc_i440fx_2_12: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.12)"
        case .pc_i440fx_2_4: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.4)"
        case .pc_i440fx_2_5: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.5)"
        case .pc_i440fx_2_6: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.6)"
        case .pc_i440fx_2_7: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.7)"
        case .pc_i440fx_2_8: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.8)"
        case .pc_i440fx_2_9: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.9)"
        case .pc_i440fx_3_0: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-3.0)"
        case .pc_i440fx_3_1: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-3.1)"
        case .pc_i440fx_4_0: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-4.0)"
        case .pc_i440fx_4_1: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-4.1)"
        case .pc_i440fx_4_2: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-4.2)"
        case .pc_i440fx_5_0: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-5.0)"
        case .pc_i440fx_5_1: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-5.1)"
        case .pc_i440fx_5_2: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-5.2)"
        case .pc_i440fx_6_0: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-6.0)"
        case .pc_i440fx_6_1: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-6.1)"
        case .pc_i440fx_6_2: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-6.2)"
        case .pc_i440fx_7_0: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-7.0)"
        case .pc_i440fx_7_1: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-7.1)"
        case .pc_i440fx_7_2: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-7.2)"
        case .pc_i440fx_8_0: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-8.0)"
        case .pc_i440fx_8_1: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-8.1)"
        case .pc_i440fx_8_2: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-8.2)"
        case .pc_i440fx_9_0: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-9.0)"
        case .none: return "empty machine (none)"
        case .microvm: return "microvm (i386) (microvm)"
        }
    }
}

enum QEMUTarget_loongarch64: String, CaseIterable, QEMUTarget {
    case virt
    case none

    static var `default`: QEMUTarget_loongarch64 {
        .virt
    }

    var prettyValue: String {
        switch self {
        case .virt: return "(null) (default) (virt)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_m68k: String, CaseIterable, QEMUTarget {
    case an5206
    case mcf5208evb
    case q800
    case next_cube = "next-cube"
    case virt_6_0 = "virt-6.0"
    case virt_6_1 = "virt-6.1"
    case virt_6_2 = "virt-6.2"
    case virt_7_0 = "virt-7.0"
    case virt_7_1 = "virt-7.1"
    case virt_7_2 = "virt-7.2"
    case virt_8_0 = "virt-8.0"
    case virt_8_1 = "virt-8.1"
    case virt_8_2 = "virt-8.2"
    case virt_9_0 = "virt-9.0"
    case virt
    case virt_9_1 = "virt-9.1"
    case none

    static var `default`: QEMUTarget_m68k {
        .mcf5208evb
    }

    var prettyValue: String {
        switch self {
        case .an5206: return "Arnewsh 5206 (an5206)"
        case .mcf5208evb: return "MCF5208EVB (default) (mcf5208evb)"
        case .q800: return "Macintosh Quadra 800 (q800)"
        case .next_cube: return "NeXT Cube (next-cube)"
        case .virt_6_0: return "QEMU 6.0 M68K Virtual Machine (deprecated) (virt-6.0)"
        case .virt_6_1: return "QEMU 6.1 M68K Virtual Machine (deprecated) (virt-6.1)"
        case .virt_6_2: return "QEMU 6.2 M68K Virtual Machine (virt-6.2)"
        case .virt_7_0: return "QEMU 7.0 M68K Virtual Machine (virt-7.0)"
        case .virt_7_1: return "QEMU 7.1 M68K Virtual Machine (virt-7.1)"
        case .virt_7_2: return "QEMU 7.2 M68K Virtual Machine (virt-7.2)"
        case .virt_8_0: return "QEMU 8.0 M68K Virtual Machine (virt-8.0)"
        case .virt_8_1: return "QEMU 8.1 M68K Virtual Machine (virt-8.1)"
        case .virt_8_2: return "QEMU 8.2 M68K Virtual Machine (virt-8.2)"
        case .virt_9_0: return "QEMU 9.0 M68K Virtual Machine (virt-9.0)"
        case .virt: return "QEMU 9.1 M68K Virtual Machine (alias of virt-9.1) (virt)"
        case .virt_9_1: return "QEMU 9.1 M68K Virtual Machine (virt-9.1)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_microblaze: String, CaseIterable, QEMUTarget {
    case petalogix_s3adsp1800 = "petalogix-s3adsp1800"
    case petalogix_ml605 = "petalogix-ml605"
    case xlnx_zynqmp_pmu = "xlnx-zynqmp-pmu"
    case none

    static var `default`: QEMUTarget_microblaze {
        .petalogix_s3adsp1800
    }

    var prettyValue: String {
        switch self {
        case .petalogix_s3adsp1800: return "PetaLogix linux refdesign for xilinx Spartan 3ADSP1800 (default) (petalogix-s3adsp1800)"
        case .petalogix_ml605: return "PetaLogix linux refdesign for xilinx ml605 little endian (petalogix-ml605)"
        case .xlnx_zynqmp_pmu: return "Xilinx ZynqMP PMU machine (xlnx-zynqmp-pmu)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_microblazeel: String, CaseIterable, QEMUTarget {
    case petalogix_s3adsp1800 = "petalogix-s3adsp1800"
    case petalogix_ml605 = "petalogix-ml605"
    case xlnx_zynqmp_pmu = "xlnx-zynqmp-pmu"
    case none

    static var `default`: QEMUTarget_microblazeel {
        .petalogix_s3adsp1800
    }

    var prettyValue: String {
        switch self {
        case .petalogix_s3adsp1800: return "PetaLogix linux refdesign for xilinx Spartan 3ADSP1800 (default) (petalogix-s3adsp1800)"
        case .petalogix_ml605: return "PetaLogix linux refdesign for xilinx ml605 little endian (petalogix-ml605)"
        case .xlnx_zynqmp_pmu: return "Xilinx ZynqMP PMU machine (xlnx-zynqmp-pmu)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_mips: String, CaseIterable, QEMUTarget {
    case mipssim
    case malta
    case none

    static var `default`: QEMUTarget_mips {
        .malta
    }

    var prettyValue: String {
        switch self {
        case .mipssim: return "MIPS MIPSsim platform (mipssim)"
        case .malta: return "MIPS Malta Core LV (default) (malta)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_mipsel: String, CaseIterable, QEMUTarget {
    case mipssim
    case malta
    case none

    static var `default`: QEMUTarget_mipsel {
        .malta
    }

    var prettyValue: String {
        switch self {
        case .mipssim: return "MIPS MIPSsim platform (mipssim)"
        case .malta: return "MIPS Malta Core LV (default) (malta)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_mips64: String, CaseIterable, QEMUTarget {
    case pica61
    case mipssim
    case magnum
    case malta
    case none

    static var `default`: QEMUTarget_mips64 {
        .malta
    }

    var prettyValue: String {
        switch self {
        case .pica61: return "Acer Pica 61 (pica61)"
        case .mipssim: return "MIPS MIPSsim platform (mipssim)"
        case .magnum: return "MIPS Magnum (magnum)"
        case .malta: return "MIPS Malta Core LV (default) (malta)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_mips64el: String, CaseIterable, QEMUTarget {
    case pica61
    case fuloong2e
    case loongson3_virt = "loongson3-virt"
    case boston
    case mipssim
    case magnum
    case malta
    case none

    static var `default`: QEMUTarget_mips64el {
        .malta
    }

    var prettyValue: String {
        switch self {
        case .pica61: return "Acer Pica 61 (pica61)"
        case .fuloong2e: return "Fuloong 2e mini pc (fuloong2e)"
        case .loongson3_virt: return "Loongson-3 Virtualization Platform (loongson3-virt)"
        case .boston: return "MIPS Boston (boston)"
        case .mipssim: return "MIPS MIPSsim platform (mipssim)"
        case .magnum: return "MIPS Magnum (magnum)"
        case .malta: return "MIPS Malta Core LV (default) (malta)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_or1k: String, CaseIterable, QEMUTarget {
    case none
    case or1k_sim = "or1k-sim"
    case virt

    static var `default`: QEMUTarget_or1k {
        .or1k_sim
    }

    var prettyValue: String {
        switch self {
        case .none: return "empty machine (none)"
        case .or1k_sim: return "or1k simulation (default) (or1k-sim)"
        case .virt: return "or1k virtual machine (virt)"
        }
    }
}

enum QEMUTarget_ppc: String, CaseIterable, QEMUTarget {
    case amigaone
    case pegasos2
    case g3beige
    case _40p = "40p"
    case mac99
    case virtex_ml507 = "virtex-ml507"
    case sam460ex
    case bamboo
    case none
    case ppce500
    case mpc8544ds
    case ref405ep

    static var `default`: QEMUTarget_ppc {
        .g3beige
    }

    var prettyValue: String {
        switch self {
        case .amigaone: return "Eyetech AmigaOne/Mai Logic Teron (amigaone)"
        case .pegasos2: return "Genesi/bPlan Pegasos II (pegasos2)"
        case .g3beige: return "Heathrow based PowerMAC (default) (g3beige)"
        case ._40p: return "IBM RS/6000 7020 (40p) (40p)"
        case .mac99: return "Mac99 based PowerMAC (mac99)"
        case .virtex_ml507: return "Xilinx Virtex ML507 reference design (virtex-ml507)"
        case .sam460ex: return "aCube Sam460ex (sam460ex)"
        case .bamboo: return "bamboo (bamboo)"
        case .none: return "empty machine (none)"
        case .ppce500: return "generic paravirt e500 platform (ppce500)"
        case .mpc8544ds: return "mpc8544ds (mpc8544ds)"
        case .ref405ep: return "ref405ep (deprecated) (ref405ep)"
        }
    }
}

enum QEMUTarget_ppc64: String, CaseIterable, QEMUTarget {
    case amigaone
    case pegasos2
    case g3beige
    case powernv
    case powernv10
    case powernv10_rainier = "powernv10-rainier"
    case powernv8
    case powernv9
    case _40p = "40p"
    case mac99
    case virtex_ml507 = "virtex-ml507"
    case sam460ex
    case bamboo
    case none
    case ppce500
    case mpc8544ds
    case pseries
    case pseries_9_1 = "pseries-9.1"
    case pseries_2_1 = "pseries-2.1"
    case pseries_2_10 = "pseries-2.10"
    case pseries_2_11 = "pseries-2.11"
    case pseries_2_12 = "pseries-2.12"
    case pseries_2_12_sxxm = "pseries-2.12-sxxm"
    case pseries_2_2 = "pseries-2.2"
    case pseries_2_3 = "pseries-2.3"
    case pseries_2_4 = "pseries-2.4"
    case pseries_2_5 = "pseries-2.5"
    case pseries_2_6 = "pseries-2.6"
    case pseries_2_7 = "pseries-2.7"
    case pseries_2_8 = "pseries-2.8"
    case pseries_2_9 = "pseries-2.9"
    case pseries_3_0 = "pseries-3.0"
    case pseries_3_1 = "pseries-3.1"
    case pseries_4_0 = "pseries-4.0"
    case pseries_4_1 = "pseries-4.1"
    case pseries_4_2 = "pseries-4.2"
    case pseries_5_0 = "pseries-5.0"
    case pseries_5_1 = "pseries-5.1"
    case pseries_5_2 = "pseries-5.2"
    case pseries_6_0 = "pseries-6.0"
    case pseries_6_1 = "pseries-6.1"
    case pseries_6_2 = "pseries-6.2"
    case pseries_7_0 = "pseries-7.0"
    case pseries_7_1 = "pseries-7.1"
    case pseries_7_2 = "pseries-7.2"
    case pseries_8_0 = "pseries-8.0"
    case pseries_8_1 = "pseries-8.1"
    case pseries_8_2 = "pseries-8.2"
    case pseries_9_0 = "pseries-9.0"
    case ref405ep

    static var `default`: QEMUTarget_ppc64 {
        .pseries_9_1
    }

    var prettyValue: String {
        switch self {
        case .amigaone: return "Eyetech AmigaOne/Mai Logic Teron (amigaone)"
        case .pegasos2: return "Genesi/bPlan Pegasos II (pegasos2)"
        case .g3beige: return "Heathrow based PowerMAC (g3beige)"
        case .powernv: return "IBM PowerNV (Non-Virtualized) POWER10 (alias of powernv10) (powernv)"
        case .powernv10: return "IBM PowerNV (Non-Virtualized) POWER10 (powernv10)"
        case .powernv10_rainier: return "IBM PowerNV (Non-Virtualized) POWER10 Rainier (powernv10-rainier)"
        case .powernv8: return "IBM PowerNV (Non-Virtualized) POWER8 (powernv8)"
        case .powernv9: return "IBM PowerNV (Non-Virtualized) POWER9 (powernv9)"
        case ._40p: return "IBM RS/6000 7020 (40p) (40p)"
        case .mac99: return "Mac99 based PowerMAC (mac99)"
        case .virtex_ml507: return "Xilinx Virtex ML507 reference design (virtex-ml507)"
        case .sam460ex: return "aCube Sam460ex (sam460ex)"
        case .bamboo: return "bamboo (bamboo)"
        case .none: return "empty machine (none)"
        case .ppce500: return "generic paravirt e500 platform (ppce500)"
        case .mpc8544ds: return "mpc8544ds (mpc8544ds)"
        case .pseries: return "pSeries Logical Partition (PAPR compliant) (alias of pseries-9.1) (pseries)"
        case .pseries_9_1: return "pSeries Logical Partition (PAPR compliant) (default) (pseries-9.1)"
        case .pseries_2_1: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.1)"
        case .pseries_2_10: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.10)"
        case .pseries_2_11: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.11)"
        case .pseries_2_12: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.12)"
        case .pseries_2_12_sxxm: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.12-sxxm)"
        case .pseries_2_2: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.2)"
        case .pseries_2_3: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.3)"
        case .pseries_2_4: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.4)"
        case .pseries_2_5: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.5)"
        case .pseries_2_6: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.6)"
        case .pseries_2_7: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.7)"
        case .pseries_2_8: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.8)"
        case .pseries_2_9: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-2.9)"
        case .pseries_3_0: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-3.0)"
        case .pseries_3_1: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-3.1)"
        case .pseries_4_0: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-4.0)"
        case .pseries_4_1: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-4.1)"
        case .pseries_4_2: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-4.2)"
        case .pseries_5_0: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-5.0)"
        case .pseries_5_1: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-5.1)"
        case .pseries_5_2: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-5.2)"
        case .pseries_6_0: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-6.0)"
        case .pseries_6_1: return "pSeries Logical Partition (PAPR compliant) (deprecated) (pseries-6.1)"
        case .pseries_6_2: return "pSeries Logical Partition (PAPR compliant) (pseries-6.2)"
        case .pseries_7_0: return "pSeries Logical Partition (PAPR compliant) (pseries-7.0)"
        case .pseries_7_1: return "pSeries Logical Partition (PAPR compliant) (pseries-7.1)"
        case .pseries_7_2: return "pSeries Logical Partition (PAPR compliant) (pseries-7.2)"
        case .pseries_8_0: return "pSeries Logical Partition (PAPR compliant) (pseries-8.0)"
        case .pseries_8_1: return "pSeries Logical Partition (PAPR compliant) (pseries-8.1)"
        case .pseries_8_2: return "pSeries Logical Partition (PAPR compliant) (pseries-8.2)"
        case .pseries_9_0: return "pSeries Logical Partition (PAPR compliant) (pseries-9.0)"
        case .ref405ep: return "ref405ep (deprecated) (ref405ep)"
        }
    }
}

enum QEMUTarget_riscv32: String, CaseIterable, QEMUTarget {
    case opentitan
    case sifive_e
    case sifive_u
    case spike
    case virt
    case none

    static var `default`: QEMUTarget_riscv32 {
        .spike
    }

    var prettyValue: String {
        switch self {
        case .opentitan: return "RISC-V Board compatible with OpenTitan (opentitan)"
        case .sifive_e: return "RISC-V Board compatible with SiFive E SDK (sifive_e)"
        case .sifive_u: return "RISC-V Board compatible with SiFive U SDK (sifive_u)"
        case .spike: return "RISC-V Spike board (default) (spike)"
        case .virt: return "RISC-V VirtIO board (virt)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_riscv64: String, CaseIterable, QEMUTarget {
    case microchip_icicle_kit = "microchip-icicle-kit"
    case shakti_c
    case sifive_e
    case sifive_u
    case spike
    case virt
    case none

    static var `default`: QEMUTarget_riscv64 {
        .spike
    }

    var prettyValue: String {
        switch self {
        case .microchip_icicle_kit: return "Microchip PolarFire SoC Icicle Kit (microchip-icicle-kit)"
        case .shakti_c: return "RISC-V Board compatible with Shakti SDK (shakti_c)"
        case .sifive_e: return "RISC-V Board compatible with SiFive E SDK (sifive_e)"
        case .sifive_u: return "RISC-V Board compatible with SiFive U SDK (sifive_u)"
        case .spike: return "RISC-V Spike board (default) (spike)"
        case .virt: return "RISC-V VirtIO board (virt)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_rx: String, CaseIterable, QEMUTarget {
    case none
    case gdbsim_r5f562n7 = "gdbsim-r5f562n7"
    case gdbsim_r5f562n8 = "gdbsim-r5f562n8"

    static var `default`: QEMUTarget_rx {
        .gdbsim_r5f562n7
    }

    var prettyValue: String {
        switch self {
        case .none: return "empty machine (none)"
        case .gdbsim_r5f562n7: return "gdb simulator (R5F562N7 MCU and external RAM) (gdbsim-r5f562n7)"
        case .gdbsim_r5f562n8: return "gdb simulator (R5F562N8 MCU and external RAM) (gdbsim-r5f562n8)"
        }
    }
}

enum QEMUTarget_s390x: String, CaseIterable, QEMUTarget {
    case s390_ccw_virtio_2_10 = "s390-ccw-virtio-2.10"
    case s390_ccw_virtio_2_11 = "s390-ccw-virtio-2.11"
    case s390_ccw_virtio_2_12 = "s390-ccw-virtio-2.12"
    case s390_ccw_virtio_2_4 = "s390-ccw-virtio-2.4"
    case s390_ccw_virtio_2_5 = "s390-ccw-virtio-2.5"
    case s390_ccw_virtio_2_6 = "s390-ccw-virtio-2.6"
    case s390_ccw_virtio_2_7 = "s390-ccw-virtio-2.7"
    case s390_ccw_virtio_2_8 = "s390-ccw-virtio-2.8"
    case s390_ccw_virtio_2_9 = "s390-ccw-virtio-2.9"
    case s390_ccw_virtio_3_0 = "s390-ccw-virtio-3.0"
    case s390_ccw_virtio_3_1 = "s390-ccw-virtio-3.1"
    case s390_ccw_virtio_4_0 = "s390-ccw-virtio-4.0"
    case s390_ccw_virtio_4_1 = "s390-ccw-virtio-4.1"
    case s390_ccw_virtio_4_2 = "s390-ccw-virtio-4.2"
    case s390_ccw_virtio_5_0 = "s390-ccw-virtio-5.0"
    case s390_ccw_virtio_5_1 = "s390-ccw-virtio-5.1"
    case s390_ccw_virtio_5_2 = "s390-ccw-virtio-5.2"
    case s390_ccw_virtio_6_0 = "s390-ccw-virtio-6.0"
    case s390_ccw_virtio_6_1 = "s390-ccw-virtio-6.1"
    case s390_ccw_virtio_6_2 = "s390-ccw-virtio-6.2"
    case s390_ccw_virtio_7_0 = "s390-ccw-virtio-7.0"
    case s390_ccw_virtio_7_1 = "s390-ccw-virtio-7.1"
    case s390_ccw_virtio_7_2 = "s390-ccw-virtio-7.2"
    case s390_ccw_virtio_8_0 = "s390-ccw-virtio-8.0"
    case s390_ccw_virtio_8_1 = "s390-ccw-virtio-8.1"
    case s390_ccw_virtio_8_2 = "s390-ccw-virtio-8.2"
    case s390_ccw_virtio_9_0 = "s390-ccw-virtio-9.0"
    case s390_ccw_virtio = "s390-ccw-virtio"
    case s390_ccw_virtio_9_1 = "s390-ccw-virtio-9.1"
    case none

    static var `default`: QEMUTarget_s390x {
        .s390_ccw_virtio_9_1
    }

    var prettyValue: String {
        switch self {
        case .s390_ccw_virtio_2_10: return "Virtual s390x machine (version 2.10) (deprecated) (s390-ccw-virtio-2.10)"
        case .s390_ccw_virtio_2_11: return "Virtual s390x machine (version 2.11) (deprecated) (s390-ccw-virtio-2.11)"
        case .s390_ccw_virtio_2_12: return "Virtual s390x machine (version 2.12) (deprecated) (s390-ccw-virtio-2.12)"
        case .s390_ccw_virtio_2_4: return "Virtual s390x machine (version 2.4) (deprecated) (s390-ccw-virtio-2.4)"
        case .s390_ccw_virtio_2_5: return "Virtual s390x machine (version 2.5) (deprecated) (s390-ccw-virtio-2.5)"
        case .s390_ccw_virtio_2_6: return "Virtual s390x machine (version 2.6) (deprecated) (s390-ccw-virtio-2.6)"
        case .s390_ccw_virtio_2_7: return "Virtual s390x machine (version 2.7) (deprecated) (s390-ccw-virtio-2.7)"
        case .s390_ccw_virtio_2_8: return "Virtual s390x machine (version 2.8) (deprecated) (s390-ccw-virtio-2.8)"
        case .s390_ccw_virtio_2_9: return "Virtual s390x machine (version 2.9) (deprecated) (s390-ccw-virtio-2.9)"
        case .s390_ccw_virtio_3_0: return "Virtual s390x machine (version 3.0) (deprecated) (s390-ccw-virtio-3.0)"
        case .s390_ccw_virtio_3_1: return "Virtual s390x machine (version 3.1) (deprecated) (s390-ccw-virtio-3.1)"
        case .s390_ccw_virtio_4_0: return "Virtual s390x machine (version 4.0) (deprecated) (s390-ccw-virtio-4.0)"
        case .s390_ccw_virtio_4_1: return "Virtual s390x machine (version 4.1) (deprecated) (s390-ccw-virtio-4.1)"
        case .s390_ccw_virtio_4_2: return "Virtual s390x machine (version 4.2) (deprecated) (s390-ccw-virtio-4.2)"
        case .s390_ccw_virtio_5_0: return "Virtual s390x machine (version 5.0) (deprecated) (s390-ccw-virtio-5.0)"
        case .s390_ccw_virtio_5_1: return "Virtual s390x machine (version 5.1) (deprecated) (s390-ccw-virtio-5.1)"
        case .s390_ccw_virtio_5_2: return "Virtual s390x machine (version 5.2) (deprecated) (s390-ccw-virtio-5.2)"
        case .s390_ccw_virtio_6_0: return "Virtual s390x machine (version 6.0) (deprecated) (s390-ccw-virtio-6.0)"
        case .s390_ccw_virtio_6_1: return "Virtual s390x machine (version 6.1) (deprecated) (s390-ccw-virtio-6.1)"
        case .s390_ccw_virtio_6_2: return "Virtual s390x machine (version 6.2) (s390-ccw-virtio-6.2)"
        case .s390_ccw_virtio_7_0: return "Virtual s390x machine (version 7.0) (s390-ccw-virtio-7.0)"
        case .s390_ccw_virtio_7_1: return "Virtual s390x machine (version 7.1) (s390-ccw-virtio-7.1)"
        case .s390_ccw_virtio_7_2: return "Virtual s390x machine (version 7.2) (s390-ccw-virtio-7.2)"
        case .s390_ccw_virtio_8_0: return "Virtual s390x machine (version 8.0) (s390-ccw-virtio-8.0)"
        case .s390_ccw_virtio_8_1: return "Virtual s390x machine (version 8.1) (s390-ccw-virtio-8.1)"
        case .s390_ccw_virtio_8_2: return "Virtual s390x machine (version 8.2) (s390-ccw-virtio-8.2)"
        case .s390_ccw_virtio_9_0: return "Virtual s390x machine (version 9.0) (s390-ccw-virtio-9.0)"
        case .s390_ccw_virtio: return "Virtual s390x machine (version 9.1) (alias of s390-ccw-virtio-9.1) (s390-ccw-virtio)"
        case .s390_ccw_virtio_9_1: return "Virtual s390x machine (version 9.1) (default) (s390-ccw-virtio-9.1)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_sh4: String, CaseIterable, QEMUTarget {
    case none
    case r2d
    case shix

    static var `default`: QEMUTarget_sh4 {
        .shix
    }

    var prettyValue: String {
        switch self {
        case .none: return "empty machine (none)"
        case .r2d: return "r2d-plus board (r2d)"
        case .shix: return "shix card (default) (deprecated) (shix)"
        }
    }
}

enum QEMUTarget_sh4eb: String, CaseIterable, QEMUTarget {
    case none
    case r2d
    case shix

    static var `default`: QEMUTarget_sh4eb {
        .shix
    }

    var prettyValue: String {
        switch self {
        case .none: return "empty machine (none)"
        case .r2d: return "r2d-plus board (r2d)"
        case .shix: return "shix card (default) (deprecated) (shix)"
        }
    }
}

enum QEMUTarget_sparc: String, CaseIterable, QEMUTarget {
    case leon3_generic
    case SPARCClassic
    case SPARCbook
    case SS_600MP = "SS-600MP"
    case SS_10 = "SS-10"
    case SS_20 = "SS-20"
    case SS_4 = "SS-4"
    case SS_5 = "SS-5"
    case LX
    case Voyager
    case none

    static var `default`: QEMUTarget_sparc {
        .SS_5
    }

    var prettyValue: String {
        switch self {
        case .leon3_generic: return "Leon-3 generic (leon3_generic)"
        case .SPARCClassic: return "Sun4m platform, SPARCClassic (SPARCClassic)"
        case .SPARCbook: return "Sun4m platform, SPARCbook (SPARCbook)"
        case .SS_600MP: return "Sun4m platform, SPARCserver 600MP (SS-600MP)"
        case .SS_10: return "Sun4m platform, SPARCstation 10 (SS-10)"
        case .SS_20: return "Sun4m platform, SPARCstation 20 (SS-20)"
        case .SS_4: return "Sun4m platform, SPARCstation 4 (SS-4)"
        case .SS_5: return "Sun4m platform, SPARCstation 5 (default) (SS-5)"
        case .LX: return "Sun4m platform, SPARCstation LX (LX)"
        case .Voyager: return "Sun4m platform, SPARCstation Voyager (Voyager)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_sparc64: String, CaseIterable, QEMUTarget {
    case sun4u
    case sun4v
    case niagara
    case none

    static var `default`: QEMUTarget_sparc64 {
        .sun4u
    }

    var prettyValue: String {
        switch self {
        case .sun4u: return "Sun4u platform (default) (sun4u)"
        case .sun4v: return "Sun4v platform (sun4v)"
        case .niagara: return "Sun4v platform, Niagara (niagara)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_tricore: String, CaseIterable, QEMUTarget {
    case KIT_AURIX_TC277_TRB
    case tricore_testboard
    case none

    static var `default`: QEMUTarget_tricore {
        .tricore_testboard
    }

    var prettyValue: String {
        switch self {
        case .KIT_AURIX_TC277_TRB: return "Infineon AURIX TriBoard TC277 (D-Step) (KIT_AURIX_TC277_TRB)"
        case .tricore_testboard: return "a minimal TriCore board (tricore_testboard)"
        case .none: return "empty machine (none)"
        }
    }
}

enum QEMUTarget_x86_64: String, CaseIterable, QEMUTarget {
    case isapc
    case q35
    case pc_q35_2_10 = "pc-q35-2.10"
    case pc_q35_2_11 = "pc-q35-2.11"
    case pc_q35_2_12 = "pc-q35-2.12"
    case pc_q35_2_4 = "pc-q35-2.4"
    case pc_q35_2_5 = "pc-q35-2.5"
    case pc_q35_2_6 = "pc-q35-2.6"
    case pc_q35_2_7 = "pc-q35-2.7"
    case pc_q35_2_8 = "pc-q35-2.8"
    case pc_q35_2_9 = "pc-q35-2.9"
    case pc_q35_3_0 = "pc-q35-3.0"
    case pc_q35_3_1 = "pc-q35-3.1"
    case pc_q35_4_0 = "pc-q35-4.0"
    case pc_q35_4_0_1 = "pc-q35-4.0.1"
    case pc_q35_4_1 = "pc-q35-4.1"
    case pc_q35_4_2 = "pc-q35-4.2"
    case pc_q35_5_0 = "pc-q35-5.0"
    case pc_q35_5_1 = "pc-q35-5.1"
    case pc_q35_5_2 = "pc-q35-5.2"
    case pc_q35_6_0 = "pc-q35-6.0"
    case pc_q35_6_1 = "pc-q35-6.1"
    case pc_q35_6_2 = "pc-q35-6.2"
    case pc_q35_7_0 = "pc-q35-7.0"
    case pc_q35_7_1 = "pc-q35-7.1"
    case pc_q35_7_2 = "pc-q35-7.2"
    case pc_q35_8_0 = "pc-q35-8.0"
    case pc_q35_8_1 = "pc-q35-8.1"
    case pc_q35_8_2 = "pc-q35-8.2"
    case pc_q35_9_0 = "pc-q35-9.0"
    case pc_q35_9_1 = "pc-q35-9.1"
    case pc
    case pc_i440fx_9_1 = "pc-i440fx-9.1"
    case pc_i440fx_2_10 = "pc-i440fx-2.10"
    case pc_i440fx_2_11 = "pc-i440fx-2.11"
    case pc_i440fx_2_12 = "pc-i440fx-2.12"
    case pc_i440fx_2_4 = "pc-i440fx-2.4"
    case pc_i440fx_2_5 = "pc-i440fx-2.5"
    case pc_i440fx_2_6 = "pc-i440fx-2.6"
    case pc_i440fx_2_7 = "pc-i440fx-2.7"
    case pc_i440fx_2_8 = "pc-i440fx-2.8"
    case pc_i440fx_2_9 = "pc-i440fx-2.9"
    case pc_i440fx_3_0 = "pc-i440fx-3.0"
    case pc_i440fx_3_1 = "pc-i440fx-3.1"
    case pc_i440fx_4_0 = "pc-i440fx-4.0"
    case pc_i440fx_4_1 = "pc-i440fx-4.1"
    case pc_i440fx_4_2 = "pc-i440fx-4.2"
    case pc_i440fx_5_0 = "pc-i440fx-5.0"
    case pc_i440fx_5_1 = "pc-i440fx-5.1"
    case pc_i440fx_5_2 = "pc-i440fx-5.2"
    case pc_i440fx_6_0 = "pc-i440fx-6.0"
    case pc_i440fx_6_1 = "pc-i440fx-6.1"
    case pc_i440fx_6_2 = "pc-i440fx-6.2"
    case pc_i440fx_7_0 = "pc-i440fx-7.0"
    case pc_i440fx_7_1 = "pc-i440fx-7.1"
    case pc_i440fx_7_2 = "pc-i440fx-7.2"
    case pc_i440fx_8_0 = "pc-i440fx-8.0"
    case pc_i440fx_8_1 = "pc-i440fx-8.1"
    case pc_i440fx_8_2 = "pc-i440fx-8.2"
    case pc_i440fx_9_0 = "pc-i440fx-9.0"
    case none
    case microvm

    static var `default`: QEMUTarget_x86_64 {
        .q35
    }

    var prettyValue: String {
        switch self {
        case .isapc: return "ISA-only PC (isapc)"
        case .q35: return "Standard PC (Q35 + ICH9, 2009) (alias of pc-q35-9.1) (q35)"
        case .pc_q35_2_10: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.10)"
        case .pc_q35_2_11: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.11)"
        case .pc_q35_2_12: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.12)"
        case .pc_q35_2_4: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.4)"
        case .pc_q35_2_5: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.5)"
        case .pc_q35_2_6: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.6)"
        case .pc_q35_2_7: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.7)"
        case .pc_q35_2_8: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.8)"
        case .pc_q35_2_9: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-2.9)"
        case .pc_q35_3_0: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-3.0)"
        case .pc_q35_3_1: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-3.1)"
        case .pc_q35_4_0: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-4.0)"
        case .pc_q35_4_0_1: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-4.0.1)"
        case .pc_q35_4_1: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-4.1)"
        case .pc_q35_4_2: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-4.2)"
        case .pc_q35_5_0: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-5.0)"
        case .pc_q35_5_1: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-5.1)"
        case .pc_q35_5_2: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-5.2)"
        case .pc_q35_6_0: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-6.0)"
        case .pc_q35_6_1: return "Standard PC (Q35 + ICH9, 2009) (deprecated) (pc-q35-6.1)"
        case .pc_q35_6_2: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-6.2)"
        case .pc_q35_7_0: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-7.0)"
        case .pc_q35_7_1: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-7.1)"
        case .pc_q35_7_2: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-7.2)"
        case .pc_q35_8_0: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-8.0)"
        case .pc_q35_8_1: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-8.1)"
        case .pc_q35_8_2: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-8.2)"
        case .pc_q35_9_0: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-9.0)"
        case .pc_q35_9_1: return "Standard PC (Q35 + ICH9, 2009) (pc-q35-9.1)"
        case .pc: return "Standard PC (i440FX + PIIX, 1996) (alias of pc-i440fx-9.1) (pc)"
        case .pc_i440fx_9_1: return "Standard PC (i440FX + PIIX, 1996) (default) (pc-i440fx-9.1)"
        case .pc_i440fx_2_10: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.10)"
        case .pc_i440fx_2_11: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.11)"
        case .pc_i440fx_2_12: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.12)"
        case .pc_i440fx_2_4: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.4)"
        case .pc_i440fx_2_5: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.5)"
        case .pc_i440fx_2_6: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.6)"
        case .pc_i440fx_2_7: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.7)"
        case .pc_i440fx_2_8: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.8)"
        case .pc_i440fx_2_9: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-2.9)"
        case .pc_i440fx_3_0: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-3.0)"
        case .pc_i440fx_3_1: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-3.1)"
        case .pc_i440fx_4_0: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-4.0)"
        case .pc_i440fx_4_1: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-4.1)"
        case .pc_i440fx_4_2: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-4.2)"
        case .pc_i440fx_5_0: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-5.0)"
        case .pc_i440fx_5_1: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-5.1)"
        case .pc_i440fx_5_2: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-5.2)"
        case .pc_i440fx_6_0: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-6.0)"
        case .pc_i440fx_6_1: return "Standard PC (i440FX + PIIX, 1996) (deprecated) (pc-i440fx-6.1)"
        case .pc_i440fx_6_2: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-6.2)"
        case .pc_i440fx_7_0: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-7.0)"
        case .pc_i440fx_7_1: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-7.1)"
        case .pc_i440fx_7_2: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-7.2)"
        case .pc_i440fx_8_0: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-8.0)"
        case .pc_i440fx_8_1: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-8.1)"
        case .pc_i440fx_8_2: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-8.2)"
        case .pc_i440fx_9_0: return "Standard PC (i440FX + PIIX, 1996) (pc-i440fx-9.0)"
        case .none: return "empty machine (none)"
        case .microvm: return "microvm (i386) (microvm)"
        }
    }
}

enum QEMUTarget_xtensa: String, CaseIterable, QEMUTarget {
    case none
    case kc705
    case kc705_nommu = "kc705-nommu"
    case lx200
    case lx200_nommu = "lx200-nommu"
    case lx60
    case lx60_nommu = "lx60-nommu"
    case ml605
    case ml605_nommu = "ml605-nommu"
    case sim
    case virt

    static var `default`: QEMUTarget_xtensa {
        .sim
    }

    var prettyValue: String {
        switch self {
        case .none: return "empty machine (none)"
        case .kc705: return "kc705 EVB (dc232b) (kc705)"
        case .kc705_nommu: return "kc705 noMMU EVB (de212) (kc705-nommu)"
        case .lx200: return "lx200 EVB (dc232b) (lx200)"
        case .lx200_nommu: return "lx200 noMMU EVB (de212) (lx200-nommu)"
        case .lx60: return "lx60 EVB (dc232b) (lx60)"
        case .lx60_nommu: return "lx60 noMMU EVB (de212) (lx60-nommu)"
        case .ml605: return "ml605 EVB (dc232b) (ml605)"
        case .ml605_nommu: return "ml605 noMMU EVB (de212) (ml605-nommu)"
        case .sim: return "sim machine (dc232b) (default) (sim)"
        case .virt: return "virt machine (dc232b) (virt)"
        }
    }
}

enum QEMUTarget_xtensaeb: String, CaseIterable, QEMUTarget {
    case none
    case kc705
    case kc705_nommu = "kc705-nommu"
    case lx200
    case lx200_nommu = "lx200-nommu"
    case lx60
    case lx60_nommu = "lx60-nommu"
    case ml605
    case ml605_nommu = "ml605-nommu"
    case sim
    case virt

    static var `default`: QEMUTarget_xtensaeb {
        .sim
    }

    var prettyValue: String {
        switch self {
        case .none: return "empty machine (none)"
        case .kc705: return "kc705 EVB (fsf) (kc705)"
        case .kc705_nommu: return "kc705 noMMU EVB (fsf) (kc705-nommu)"
        case .lx200: return "lx200 EVB (fsf) (lx200)"
        case .lx200_nommu: return "lx200 noMMU EVB (fsf) (lx200-nommu)"
        case .lx60: return "lx60 EVB (fsf) (lx60)"
        case .lx60_nommu: return "lx60 noMMU EVB (fsf) (lx60-nommu)"
        case .ml605: return "ml605 EVB (fsf) (ml605)"
        case .ml605_nommu: return "ml605 noMMU EVB (fsf) (ml605-nommu)"
        case .sim: return "sim machine (fsf) (default) (sim)"
        case .virt: return "virt machine (fsf) (virt)"
        }
    }
}

enum QEMUDisplayDevice_alpha: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        }
    }
}

enum QEMUDisplayDevice_arm: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case dm163
    case led
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case ramfb
    case secondary_vga = "secondary-vga"
    case ssd0323
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_ramfb = "virtio-ramfb"
    case virtio_ramfb_gl = "virtio-ramfb-gl"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .dm163: return "DM163 (dm163)"
        case .led: return "LED (led)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .ramfb: return "ram framebuffer standalone device (ramfb)"
        case .secondary_vga: return "secondary-vga"
        case .ssd0323: return "ssd0323"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_ramfb: return "virtio-ramfb"
        case .virtio_ramfb_gl: return "virtio-ramfb-gl (GPU Supported)"
        }
    }
}

enum QEMUDisplayDevice_aarch64: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case dm163
    case led
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case ramfb
    case secondary_vga = "secondary-vga"
    case ssd0323
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_ramfb = "virtio-ramfb"
    case virtio_ramfb_gl = "virtio-ramfb-gl"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .dm163: return "DM163 (dm163)"
        case .led: return "LED (led)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .ramfb: return "ram framebuffer standalone device (ramfb)"
        case .secondary_vga: return "secondary-vga"
        case .ssd0323: return "ssd0323"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_ramfb: return "virtio-ramfb"
        case .virtio_ramfb_gl: return "virtio-ramfb-gl (GPU Supported)"
        }
    }
}

typealias QEMUDisplayDevice_avr = AnyQEMUConstant

typealias QEMUDisplayDevice_cris = AnyQEMUConstant

enum QEMUDisplayDevice_hppa: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_vga = "virtio-vga"
    case virtio_vga_gl = "virtio-vga-gl"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_vga: return "virtio-vga"
        case .virtio_vga_gl: return "virtio-vga-gl (GPU Supported)"
        }
    }
}

enum QEMUDisplayDevice_i386: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case qxl_vga = "qxl-vga"
    case qxl
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case isa_cirrus_vga = "isa-cirrus-vga"
    case isa_vga = "isa-vga"
    case ramfb
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_ramfb = "virtio-ramfb"
    case virtio_ramfb_gl = "virtio-ramfb-gl"
    case virtio_vga = "virtio-vga"
    case virtio_vga_gl = "virtio-vga-gl"
    case vmware_svga = "vmware-svga"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .qxl_vga: return "Spice QXL GPU (primary, vga compatible) (qxl-vga)"
        case .qxl: return "Spice QXL GPU (secondary) (qxl)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .isa_cirrus_vga: return "isa-cirrus-vga"
        case .isa_vga: return "isa-vga"
        case .ramfb: return "ram framebuffer standalone device (ramfb)"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_ramfb: return "virtio-ramfb"
        case .virtio_ramfb_gl: return "virtio-ramfb-gl (GPU Supported)"
        case .virtio_vga: return "virtio-vga"
        case .virtio_vga_gl: return "virtio-vga-gl (GPU Supported)"
        case .vmware_svga: return "vmware-svga"
        }
    }
}

enum QEMUDisplayDevice_loongarch64: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case ramfb
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_ramfb = "virtio-ramfb"
    case virtio_ramfb_gl = "virtio-ramfb-gl"
    case virtio_vga = "virtio-vga"
    case virtio_vga_gl = "virtio-vga-gl"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .ramfb: return "ram framebuffer standalone device (ramfb)"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_ramfb: return "virtio-ramfb"
        case .virtio_ramfb_gl: return "virtio-ramfb-gl (GPU Supported)"
        case .virtio_vga: return "virtio-vga"
        case .virtio_vga_gl: return "virtio-vga-gl (GPU Supported)"
        }
    }
}

enum QEMUDisplayDevice_m68k: String, CaseIterable, QEMUDisplayDevice {
    case nubus_macfb = "nubus-macfb"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"

    var prettyValue: String {
        switch self {
        case .nubus_macfb: return "Nubus Macintosh framebuffer (nubus-macfb)"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        }
    }
}

typealias QEMUDisplayDevice_microblaze = AnyQEMUConstant

typealias QEMUDisplayDevice_microblazeel = AnyQEMUConstant

enum QEMUDisplayDevice_mips: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case vmware_svga = "vmware-svga"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .vmware_svga: return "vmware-svga"
        }
    }
}

enum QEMUDisplayDevice_mipsel: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case vmware_svga = "vmware-svga"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .vmware_svga: return "vmware-svga"
        }
    }
}

enum QEMUDisplayDevice_mips64: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case vmware_svga = "vmware-svga"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .vmware_svga: return "vmware-svga"
        }
    }
}

enum QEMUDisplayDevice_mips64el: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case qxl_vga = "qxl-vga"
    case qxl
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_vga = "virtio-vga"
    case virtio_vga_gl = "virtio-vga-gl"
    case vmware_svga = "vmware-svga"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .qxl_vga: return "Spice QXL GPU (primary, vga compatible) (qxl-vga)"
        case .qxl: return "Spice QXL GPU (secondary) (qxl)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_vga: return "virtio-vga"
        case .virtio_vga_gl: return "virtio-vga-gl (GPU Supported)"
        case .vmware_svga: return "vmware-svga"
        }
    }
}

enum QEMUDisplayDevice_or1k: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_vga = "virtio-vga"
    case virtio_vga_gl = "virtio-vga-gl"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_vga: return "virtio-vga"
        case .virtio_vga_gl: return "virtio-vga-gl (GPU Supported)"
        }
    }
}

enum QEMUDisplayDevice_ppc: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case sm501
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .sm501: return "SM501 Display Controller (sm501)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        }
    }
}

enum QEMUDisplayDevice_ppc64: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case sm501
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_vga = "virtio-vga"
    case virtio_vga_gl = "virtio-vga-gl"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .sm501: return "SM501 Display Controller (sm501)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_vga: return "virtio-vga"
        case .virtio_vga_gl: return "virtio-vga-gl (GPU Supported)"
        }
    }
}

enum QEMUDisplayDevice_riscv32: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case ramfb
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_ramfb = "virtio-ramfb"
    case virtio_ramfb_gl = "virtio-ramfb-gl"
    case virtio_vga = "virtio-vga"
    case virtio_vga_gl = "virtio-vga-gl"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .ramfb: return "ram framebuffer standalone device (ramfb)"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_ramfb: return "virtio-ramfb"
        case .virtio_ramfb_gl: return "virtio-ramfb-gl (GPU Supported)"
        case .virtio_vga: return "virtio-vga"
        case .virtio_vga_gl: return "virtio-vga-gl (GPU Supported)"
        }
    }
}

enum QEMUDisplayDevice_riscv64: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case ramfb
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_ramfb = "virtio-ramfb"
    case virtio_ramfb_gl = "virtio-ramfb-gl"
    case virtio_vga = "virtio-vga"
    case virtio_vga_gl = "virtio-vga-gl"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .ramfb: return "ram framebuffer standalone device (ramfb)"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_ramfb: return "virtio-ramfb"
        case .virtio_ramfb_gl: return "virtio-ramfb-gl (GPU Supported)"
        case .virtio_vga: return "virtio-vga"
        case .virtio_vga_gl: return "virtio-vga-gl (GPU Supported)"
        }
    }
}

typealias QEMUDisplayDevice_rx = AnyQEMUConstant

enum QEMUDisplayDevice_s390x: String, CaseIterable, QEMUDisplayDevice {
    case virtio_gpu_ccw = "virtio-gpu-ccw"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case x_terminal3270 = "x-terminal3270"

    var prettyValue: String {
        switch self {
        case .virtio_gpu_ccw: return "virtio-gpu-ccw"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .x_terminal3270: return "x-terminal3270"
        }
    }
}

enum QEMUDisplayDevice_sh4: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case sm501
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .sm501: return "SM501 Display Controller (sm501)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        }
    }
}

enum QEMUDisplayDevice_sh4eb: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case sm501
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .sm501: return "SM501 Display Controller (sm501)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        }
    }
}

enum QEMUDisplayDevice_sparc: String, CaseIterable, QEMUDisplayDevice {
    case tcx
    case cg3

    var prettyValue: String {
        switch self {
        case .tcx: return "Sun TCX"
        case .cg3: return "Sun cgthree"
        }
    }
}

enum QEMUDisplayDevice_sparc64: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        }
    }
}

typealias QEMUDisplayDevice_tricore = AnyQEMUConstant

enum QEMUDisplayDevice_x86_64: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case qxl_vga = "qxl-vga"
    case qxl
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case isa_cirrus_vga = "isa-cirrus-vga"
    case isa_vga = "isa-vga"
    case ramfb
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"
    case virtio_ramfb = "virtio-ramfb"
    case virtio_ramfb_gl = "virtio-ramfb-gl"
    case virtio_vga = "virtio-vga"
    case virtio_vga_gl = "virtio-vga-gl"
    case vmware_svga = "vmware-svga"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .qxl_vga: return "Spice QXL GPU (primary, vga compatible) (qxl-vga)"
        case .qxl: return "Spice QXL GPU (secondary) (qxl)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .isa_cirrus_vga: return "isa-cirrus-vga"
        case .isa_vga: return "isa-vga"
        case .ramfb: return "ram framebuffer standalone device (ramfb)"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        case .virtio_ramfb: return "virtio-ramfb"
        case .virtio_ramfb_gl: return "virtio-ramfb-gl (GPU Supported)"
        case .virtio_vga: return "virtio-vga"
        case .virtio_vga_gl: return "virtio-vga-gl (GPU Supported)"
        case .vmware_svga: return "vmware-svga"
        }
    }
}

enum QEMUDisplayDevice_xtensa: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        }
    }
}

enum QEMUDisplayDevice_xtensaeb: String, CaseIterable, QEMUDisplayDevice {
    case cirrus_vga = "cirrus-vga"
    case VGA
    case ati_vga = "ati-vga"
    case bochs_display = "bochs-display"
    case secondary_vga = "secondary-vga"
    case virtio_gpu_device = "virtio-gpu-device"
    case virtio_gpu_gl_device = "virtio-gpu-gl-device"
    case virtio_gpu_gl_pci = "virtio-gpu-gl-pci"
    case virtio_gpu_pci = "virtio-gpu-pci"

    var prettyValue: String {
        switch self {
        case .cirrus_vga: return "Cirrus CLGD 54xx VGA (cirrus-vga)"
        case .VGA: return "VGA"
        case .ati_vga: return "ati-vga"
        case .bochs_display: return "bochs-display"
        case .secondary_vga: return "secondary-vga"
        case .virtio_gpu_device: return "virtio-gpu-device"
        case .virtio_gpu_gl_device: return "virtio-gpu-gl-device (GPU Supported)"
        case .virtio_gpu_gl_pci: return "virtio-gpu-gl-pci (GPU Supported)"
        case .virtio_gpu_pci: return "virtio-gpu-pci"
        }
    }
}

enum QEMUNetworkDevice_alpha: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_arm: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case rocker
    case vmxnet3
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .rocker: return "Rocker Switch (rocker)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_aarch64: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case rocker
    case vmxnet3
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .rocker: return "Rocker Switch (rocker)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

typealias QEMUNetworkDevice_avr = AnyQEMUConstant

typealias QEMUNetworkDevice_cris = AnyQEMUConstant

enum QEMUNetworkDevice_hppa: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_i386: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case rocker
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .rocker: return "Rocker Switch (rocker)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_loongarch64: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case rocker
    case vmxnet3
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .rocker: return "Rocker Switch (rocker)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_m68k: String, CaseIterable, QEMUNetworkDevice {
    case virtio_net_device = "virtio-net-device"

    var prettyValue: String {
        switch self {
        case .virtio_net_device: return "virtio-net-device"
        }
    }
}

typealias QEMUNetworkDevice_microblaze = AnyQEMUConstant

typealias QEMUNetworkDevice_microblazeel = AnyQEMUConstant

enum QEMUNetworkDevice_mips: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_mipsel: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_mips64: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_mips64el: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case rocker
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .rocker: return "Rocker Switch (rocker)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_or1k: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_ppc: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case rocker
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case sungem
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .rocker: return "Rocker Switch (rocker)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .sungem: return "sungem"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_ppc64: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case rocker
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case spapr_vlan = "spapr-vlan"
    case sungem
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .rocker: return "Rocker Switch (rocker)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .spapr_vlan: return "spapr-vlan"
        case .sungem: return "sungem"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_riscv32: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case rocker
    case vmxnet3
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .rocker: return "Rocker Switch (rocker)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_riscv64: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case rocker
    case vmxnet3
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .rocker: return "Rocker Switch (rocker)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

typealias QEMUNetworkDevice_rx = AnyQEMUConstant

enum QEMUNetworkDevice_s390x: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case usb_net = "usb-net"
    case virtio_net_ccw = "virtio-net-ccw"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .usb_net: return "usb-net"
        case .virtio_net_ccw: return "virtio-net-ccw"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_sh4: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_sh4eb: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_sparc: String, CaseIterable, QEMUNetworkDevice {
    case lance

    var prettyValue: String {
        switch self {
        case .lance: return "Lance (Am7990)"
        }
    }
}

enum QEMUNetworkDevice_sparc64: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case sunhme
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .sunhme: return "sunhme"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

typealias QEMUNetworkDevice_tricore = AnyQEMUConstant

enum QEMUNetworkDevice_x86_64: String, CaseIterable, QEMUNetworkDevice {
    case e1000e
    case igb
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case rocker
    case vmxnet3
    case ne2k_isa
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000e: return "Intel 82574L GbE Controller (e1000e)"
        case .igb: return "Intel 82576 Gigabit Ethernet Controller (igb)"
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .rocker: return "Rocker Switch (rocker)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_isa: return "ne2k_isa"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_xtensa: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUNetworkDevice_xtensaeb: String, CaseIterable, QEMUNetworkDevice {
    case e1000
    case e1000_82544gc = "e1000-82544gc"
    case e1000_82545em = "e1000-82545em"
    case i82550
    case i82551
    case i82557a
    case i82557b
    case i82557c
    case i82558a
    case i82558b
    case i82559a
    case i82559b
    case i82559c
    case i82559er
    case i82562
    case i82801
    case vmxnet3
    case ne2k_pci
    case pcnet
    case rtl8139
    case tulip
    case usb_net = "usb-net"
    case virtio_net_device = "virtio-net-device"
    case virtio_net_pci = "virtio-net-pci"
    case virtio_net_pci_non_transitional = "virtio-net-pci-non-transitional"
    case virtio_net_pci_transitional = "virtio-net-pci-transitional"

    var prettyValue: String {
        switch self {
        case .e1000: return "Intel Gigabit Ethernet (e1000)"
        case .e1000_82544gc: return "Intel Gigabit Ethernet (e1000-82544gc)"
        case .e1000_82545em: return "Intel Gigabit Ethernet (e1000-82545em)"
        case .i82550: return "Intel i82550 Ethernet (i82550)"
        case .i82551: return "Intel i82551 Ethernet (i82551)"
        case .i82557a: return "Intel i82557A Ethernet (i82557a)"
        case .i82557b: return "Intel i82557B Ethernet (i82557b)"
        case .i82557c: return "Intel i82557C Ethernet (i82557c)"
        case .i82558a: return "Intel i82558A Ethernet (i82558a)"
        case .i82558b: return "Intel i82558B Ethernet (i82558b)"
        case .i82559a: return "Intel i82559A Ethernet (i82559a)"
        case .i82559b: return "Intel i82559B Ethernet (i82559b)"
        case .i82559c: return "Intel i82559C Ethernet (i82559c)"
        case .i82559er: return "Intel i82559ER Ethernet (i82559er)"
        case .i82562: return "Intel i82562 Ethernet (i82562)"
        case .i82801: return "Intel i82801 Ethernet (i82801)"
        case .vmxnet3: return "VMWare Paravirtualized Ethernet v3 (vmxnet3)"
        case .ne2k_pci: return "ne2k_pci"
        case .pcnet: return "pcnet"
        case .rtl8139: return "rtl8139"
        case .tulip: return "tulip"
        case .usb_net: return "usb-net"
        case .virtio_net_device: return "virtio-net-device"
        case .virtio_net_pci: return "virtio-net-pci"
        case .virtio_net_pci_non_transitional: return "virtio-net-pci-non-transitional"
        case .virtio_net_pci_transitional: return "virtio-net-pci-transitional"
        }
    }
}

enum QEMUSoundDevice_alpha: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_arm: String, CaseIterable, QEMUSoundDevice {
    case ES1370
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_aarch64: String, CaseIterable, QEMUSoundDevice {
    case ES1370
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

typealias QEMUSoundDevice_avr = AnyQEMUConstant

typealias QEMUSoundDevice_cris = AnyQEMUConstant

enum QEMUSoundDevice_hppa: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_i386: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case pcspk
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .pcspk: return "PC Speaker"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_loongarch64: String, CaseIterable, QEMUSoundDevice {
    case ES1370
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_m68k: String, CaseIterable, QEMUSoundDevice {
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

typealias QEMUSoundDevice_microblaze = AnyQEMUConstant

typealias QEMUSoundDevice_microblazeel = AnyQEMUConstant

enum QEMUSoundDevice_mips: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_mipsel: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_mips64: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_mips64el: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_or1k: String, CaseIterable, QEMUSoundDevice {
    case ES1370
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_ppc: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case screamer
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .screamer: return "Screamer (Mac99 only)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_ppc64: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case screamer
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .screamer: return "Screamer (Mac99 only)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_riscv32: String, CaseIterable, QEMUSoundDevice {
    case ES1370
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_riscv64: String, CaseIterable, QEMUSoundDevice {
    case ES1370
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

typealias QEMUSoundDevice_rx = AnyQEMUConstant

enum QEMUSoundDevice_s390x: String, CaseIterable, QEMUSoundDevice {
    case virtio_sound_pci = "virtio-sound-pci"
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_sh4: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_sh4eb: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

typealias QEMUSoundDevice_sparc = AnyQEMUConstant

enum QEMUSoundDevice_sparc64: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

typealias QEMUSoundDevice_tricore = AnyQEMUConstant

enum QEMUSoundDevice_x86_64: String, CaseIterable, QEMUSoundDevice {
    case sb16
    case cs4231a
    case ES1370
    case gus
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case pcspk
    case virtio_sound_pci = "virtio-sound-pci"
    case adlib
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .sb16: return "Creative Sound Blaster 16 (sb16)"
        case .cs4231a: return "Crystal Semiconductor CS4231A (cs4231a)"
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .gus: return "Gravis Ultrasound GF1 (gus)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .pcspk: return "PC Speaker"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .adlib: return "Yamaha YM3812 (OPL2) (adlib)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_xtensa: String, CaseIterable, QEMUSoundDevice {
    case ES1370
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSoundDevice_xtensaeb: String, CaseIterable, QEMUSoundDevice {
    case ES1370
    case AC97
    case intel_hda = "intel-hda"
    case ich9_intel_hda = "ich9-intel-hda"
    case virtio_sound_pci = "virtio-sound-pci"
    case usb_audio = "usb-audio"
    case virtio_sound_device = "virtio-sound-device"

    var prettyValue: String {
        switch self {
        case .ES1370: return "ENSONIQ AudioPCI ES1370 (ES1370)"
        case .AC97: return "Intel 82801AA AC97 Audio (AC97)"
        case .intel_hda: return "Intel HD Audio Controller (ich6) (intel-hda)"
        case .ich9_intel_hda: return "Intel HD Audio Controller (ich9) (ich9-intel-hda)"
        case .virtio_sound_pci: return "Virtio Sound (virtio-sound-pci)"
        case .usb_audio: return "usb-audio"
        case .virtio_sound_device: return "virtio-sound-device"
        }
    }
}

enum QEMUSerialDevice_alpha: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_arm: String, CaseIterable, QEMUSerialDevice {
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_aarch64: String, CaseIterable, QEMUSerialDevice {
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

typealias QEMUSerialDevice_avr = AnyQEMUConstant

typealias QEMUSerialDevice_cris = AnyQEMUConstant

enum QEMUSerialDevice_hppa: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_i386: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_loongarch64: String, CaseIterable, QEMUSerialDevice {
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_m68k: String, CaseIterable, QEMUSerialDevice {
    case virtio_serial_device = "virtio-serial-device"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtserialport: return "virtserialport"
        }
    }
}

typealias QEMUSerialDevice_microblaze = AnyQEMUConstant

typealias QEMUSerialDevice_microblazeel = AnyQEMUConstant

enum QEMUSerialDevice_mips: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_mipsel: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_mips64: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_mips64el: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_or1k: String, CaseIterable, QEMUSerialDevice {
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_ppc: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_ppc64: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_riscv32: String, CaseIterable, QEMUSerialDevice {
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_riscv64: String, CaseIterable, QEMUSerialDevice {
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

typealias QEMUSerialDevice_rx = AnyQEMUConstant

enum QEMUSerialDevice_s390x: String, CaseIterable, QEMUSerialDevice {
    case usb_serial = "usb-serial"
    case virtio_serial_ccw = "virtio-serial-ccw"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .usb_serial: return "usb-serial"
        case .virtio_serial_ccw: return "virtio-serial-ccw"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_sh4: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_sh4eb: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

typealias QEMUSerialDevice_sparc = AnyQEMUConstant

enum QEMUSerialDevice_sparc64: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

typealias QEMUSerialDevice_tricore = AnyQEMUConstant

enum QEMUSerialDevice_x86_64: String, CaseIterable, QEMUSerialDevice {
    case isa_serial = "isa-serial"
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .isa_serial: return "isa-serial"
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_xtensa: String, CaseIterable, QEMUSerialDevice {
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

enum QEMUSerialDevice_xtensaeb: String, CaseIterable, QEMUSerialDevice {
    case pci_serial = "pci-serial"
    case pci_serial_2x = "pci-serial-2x"
    case pci_serial_4x = "pci-serial-4x"
    case usb_serial = "usb-serial"
    case virtio_serial_device = "virtio-serial-device"
    case virtio_serial_pci = "virtio-serial-pci"
    case virtio_serial_pci_non_transitional = "virtio-serial-pci-non-transitional"
    case virtio_serial_pci_transitional = "virtio-serial-pci-transitional"
    case virtserialport

    var prettyValue: String {
        switch self {
        case .pci_serial: return "pci-serial"
        case .pci_serial_2x: return "pci-serial-2x"
        case .pci_serial_4x: return "pci-serial-4x"
        case .usb_serial: return "usb-serial"
        case .virtio_serial_device: return "virtio-serial-device"
        case .virtio_serial_pci: return "virtio-serial-pci"
        case .virtio_serial_pci_non_transitional: return "virtio-serial-pci-non-transitional"
        case .virtio_serial_pci_transitional: return "virtio-serial-pci-transitional"
        case .virtserialport: return "virtserialport"
        }
    }
}

extension QEMUArchitecture {
    var cpuType: any QEMUCPU.Type {
        switch self {
        case .alpha: return QEMUCPU_alpha.self
        case .arm: return QEMUCPU_arm.self
        case .aarch64: return QEMUCPU_aarch64.self
        case .avr: return QEMUCPU_avr.self
        case .cris: return QEMUCPU_cris.self
        case .hppa: return QEMUCPU_hppa.self
        case .i386: return QEMUCPU_i386.self
        case .loongarch64: return QEMUCPU_loongarch64.self
        case .m68k: return QEMUCPU_m68k.self
        case .microblaze: return QEMUCPU_microblaze.self
        case .microblazeel: return QEMUCPU_microblazeel.self
        case .mips: return QEMUCPU_mips.self
        case .mipsel: return QEMUCPU_mipsel.self
        case .mips64: return QEMUCPU_mips64.self
        case .mips64el: return QEMUCPU_mips64el.self
        case .or1k: return QEMUCPU_or1k.self
        case .ppc: return QEMUCPU_ppc.self
        case .ppc64: return QEMUCPU_ppc64.self
        case .riscv32: return QEMUCPU_riscv32.self
        case .riscv64: return QEMUCPU_riscv64.self
        case .rx: return QEMUCPU_rx.self
        case .s390x: return QEMUCPU_s390x.self
        case .sh4: return QEMUCPU_sh4.self
        case .sh4eb: return QEMUCPU_sh4eb.self
        case .sparc: return QEMUCPU_sparc.self
        case .sparc64: return QEMUCPU_sparc64.self
        case .tricore: return QEMUCPU_tricore.self
        case .x86_64: return QEMUCPU_x86_64.self
        case .xtensa: return QEMUCPU_xtensa.self
        case .xtensaeb: return QEMUCPU_xtensaeb.self
        }
    }

    var cpuFlagType: any QEMUCPUFlag.Type {
        switch self {
        case .alpha: return QEMUCPUFlag_alpha.self
        case .arm: return QEMUCPUFlag_arm.self
        case .aarch64: return QEMUCPUFlag_aarch64.self
        case .avr: return QEMUCPUFlag_avr.self
        case .cris: return QEMUCPUFlag_cris.self
        case .hppa: return QEMUCPUFlag_hppa.self
        case .i386: return QEMUCPUFlag_i386.self
        case .loongarch64: return QEMUCPUFlag_loongarch64.self
        case .m68k: return QEMUCPUFlag_m68k.self
        case .microblaze: return QEMUCPUFlag_microblaze.self
        case .microblazeel: return QEMUCPUFlag_microblazeel.self
        case .mips: return QEMUCPUFlag_mips.self
        case .mipsel: return QEMUCPUFlag_mipsel.self
        case .mips64: return QEMUCPUFlag_mips64.self
        case .mips64el: return QEMUCPUFlag_mips64el.self
        case .or1k: return QEMUCPUFlag_or1k.self
        case .ppc: return QEMUCPUFlag_ppc.self
        case .ppc64: return QEMUCPUFlag_ppc64.self
        case .riscv32: return QEMUCPUFlag_riscv32.self
        case .riscv64: return QEMUCPUFlag_riscv64.self
        case .rx: return QEMUCPUFlag_rx.self
        case .s390x: return QEMUCPUFlag_s390x.self
        case .sh4: return QEMUCPUFlag_sh4.self
        case .sh4eb: return QEMUCPUFlag_sh4eb.self
        case .sparc: return QEMUCPUFlag_sparc.self
        case .sparc64: return QEMUCPUFlag_sparc64.self
        case .tricore: return QEMUCPUFlag_tricore.self
        case .x86_64: return QEMUCPUFlag_x86_64.self
        case .xtensa: return QEMUCPUFlag_xtensa.self
        case .xtensaeb: return QEMUCPUFlag_xtensaeb.self
        }
    }

    var targetType: any QEMUTarget.Type {
        switch self {
        case .alpha: return QEMUTarget_alpha.self
        case .arm: return QEMUTarget_arm.self
        case .aarch64: return QEMUTarget_aarch64.self
        case .avr: return QEMUTarget_avr.self
        case .cris: return QEMUTarget_cris.self
        case .hppa: return QEMUTarget_hppa.self
        case .i386: return QEMUTarget_i386.self
        case .loongarch64: return QEMUTarget_loongarch64.self
        case .m68k: return QEMUTarget_m68k.self
        case .microblaze: return QEMUTarget_microblaze.self
        case .microblazeel: return QEMUTarget_microblazeel.self
        case .mips: return QEMUTarget_mips.self
        case .mipsel: return QEMUTarget_mipsel.self
        case .mips64: return QEMUTarget_mips64.self
        case .mips64el: return QEMUTarget_mips64el.self
        case .or1k: return QEMUTarget_or1k.self
        case .ppc: return QEMUTarget_ppc.self
        case .ppc64: return QEMUTarget_ppc64.self
        case .riscv32: return QEMUTarget_riscv32.self
        case .riscv64: return QEMUTarget_riscv64.self
        case .rx: return QEMUTarget_rx.self
        case .s390x: return QEMUTarget_s390x.self
        case .sh4: return QEMUTarget_sh4.self
        case .sh4eb: return QEMUTarget_sh4eb.self
        case .sparc: return QEMUTarget_sparc.self
        case .sparc64: return QEMUTarget_sparc64.self
        case .tricore: return QEMUTarget_tricore.self
        case .x86_64: return QEMUTarget_x86_64.self
        case .xtensa: return QEMUTarget_xtensa.self
        case .xtensaeb: return QEMUTarget_xtensaeb.self
        }
    }

    var displayDeviceType: any QEMUDisplayDevice.Type {
        switch self {
        case .alpha: return QEMUDisplayDevice_alpha.self
        case .arm: return QEMUDisplayDevice_arm.self
        case .aarch64: return QEMUDisplayDevice_aarch64.self
        case .avr: return QEMUDisplayDevice_avr.self
        case .cris: return QEMUDisplayDevice_cris.self
        case .hppa: return QEMUDisplayDevice_hppa.self
        case .i386: return QEMUDisplayDevice_i386.self
        case .loongarch64: return QEMUDisplayDevice_loongarch64.self
        case .m68k: return QEMUDisplayDevice_m68k.self
        case .microblaze: return QEMUDisplayDevice_microblaze.self
        case .microblazeel: return QEMUDisplayDevice_microblazeel.self
        case .mips: return QEMUDisplayDevice_mips.self
        case .mipsel: return QEMUDisplayDevice_mipsel.self
        case .mips64: return QEMUDisplayDevice_mips64.self
        case .mips64el: return QEMUDisplayDevice_mips64el.self
        case .or1k: return QEMUDisplayDevice_or1k.self
        case .ppc: return QEMUDisplayDevice_ppc.self
        case .ppc64: return QEMUDisplayDevice_ppc64.self
        case .riscv32: return QEMUDisplayDevice_riscv32.self
        case .riscv64: return QEMUDisplayDevice_riscv64.self
        case .rx: return QEMUDisplayDevice_rx.self
        case .s390x: return QEMUDisplayDevice_s390x.self
        case .sh4: return QEMUDisplayDevice_sh4.self
        case .sh4eb: return QEMUDisplayDevice_sh4eb.self
        case .sparc: return QEMUDisplayDevice_sparc.self
        case .sparc64: return QEMUDisplayDevice_sparc64.self
        case .tricore: return QEMUDisplayDevice_tricore.self
        case .x86_64: return QEMUDisplayDevice_x86_64.self
        case .xtensa: return QEMUDisplayDevice_xtensa.self
        case .xtensaeb: return QEMUDisplayDevice_xtensaeb.self
        }
    }

    var networkDeviceType: any QEMUNetworkDevice.Type {
        switch self {
        case .alpha: return QEMUNetworkDevice_alpha.self
        case .arm: return QEMUNetworkDevice_arm.self
        case .aarch64: return QEMUNetworkDevice_aarch64.self
        case .avr: return QEMUNetworkDevice_avr.self
        case .cris: return QEMUNetworkDevice_cris.self
        case .hppa: return QEMUNetworkDevice_hppa.self
        case .i386: return QEMUNetworkDevice_i386.self
        case .loongarch64: return QEMUNetworkDevice_loongarch64.self
        case .m68k: return QEMUNetworkDevice_m68k.self
        case .microblaze: return QEMUNetworkDevice_microblaze.self
        case .microblazeel: return QEMUNetworkDevice_microblazeel.self
        case .mips: return QEMUNetworkDevice_mips.self
        case .mipsel: return QEMUNetworkDevice_mipsel.self
        case .mips64: return QEMUNetworkDevice_mips64.self
        case .mips64el: return QEMUNetworkDevice_mips64el.self
        case .or1k: return QEMUNetworkDevice_or1k.self
        case .ppc: return QEMUNetworkDevice_ppc.self
        case .ppc64: return QEMUNetworkDevice_ppc64.self
        case .riscv32: return QEMUNetworkDevice_riscv32.self
        case .riscv64: return QEMUNetworkDevice_riscv64.self
        case .rx: return QEMUNetworkDevice_rx.self
        case .s390x: return QEMUNetworkDevice_s390x.self
        case .sh4: return QEMUNetworkDevice_sh4.self
        case .sh4eb: return QEMUNetworkDevice_sh4eb.self
        case .sparc: return QEMUNetworkDevice_sparc.self
        case .sparc64: return QEMUNetworkDevice_sparc64.self
        case .tricore: return QEMUNetworkDevice_tricore.self
        case .x86_64: return QEMUNetworkDevice_x86_64.self
        case .xtensa: return QEMUNetworkDevice_xtensa.self
        case .xtensaeb: return QEMUNetworkDevice_xtensaeb.self
        }
    }

    var soundDeviceType: any QEMUSoundDevice.Type {
        switch self {
        case .alpha: return QEMUSoundDevice_alpha.self
        case .arm: return QEMUSoundDevice_arm.self
        case .aarch64: return QEMUSoundDevice_aarch64.self
        case .avr: return QEMUSoundDevice_avr.self
        case .cris: return QEMUSoundDevice_cris.self
        case .hppa: return QEMUSoundDevice_hppa.self
        case .i386: return QEMUSoundDevice_i386.self
        case .loongarch64: return QEMUSoundDevice_loongarch64.self
        case .m68k: return QEMUSoundDevice_m68k.self
        case .microblaze: return QEMUSoundDevice_microblaze.self
        case .microblazeel: return QEMUSoundDevice_microblazeel.self
        case .mips: return QEMUSoundDevice_mips.self
        case .mipsel: return QEMUSoundDevice_mipsel.self
        case .mips64: return QEMUSoundDevice_mips64.self
        case .mips64el: return QEMUSoundDevice_mips64el.self
        case .or1k: return QEMUSoundDevice_or1k.self
        case .ppc: return QEMUSoundDevice_ppc.self
        case .ppc64: return QEMUSoundDevice_ppc64.self
        case .riscv32: return QEMUSoundDevice_riscv32.self
        case .riscv64: return QEMUSoundDevice_riscv64.self
        case .rx: return QEMUSoundDevice_rx.self
        case .s390x: return QEMUSoundDevice_s390x.self
        case .sh4: return QEMUSoundDevice_sh4.self
        case .sh4eb: return QEMUSoundDevice_sh4eb.self
        case .sparc: return QEMUSoundDevice_sparc.self
        case .sparc64: return QEMUSoundDevice_sparc64.self
        case .tricore: return QEMUSoundDevice_tricore.self
        case .x86_64: return QEMUSoundDevice_x86_64.self
        case .xtensa: return QEMUSoundDevice_xtensa.self
        case .xtensaeb: return QEMUSoundDevice_xtensaeb.self
        }
    }

    var serialDeviceType: any QEMUSerialDevice.Type {
        switch self {
        case .alpha: return QEMUSerialDevice_alpha.self
        case .arm: return QEMUSerialDevice_arm.self
        case .aarch64: return QEMUSerialDevice_aarch64.self
        case .avr: return QEMUSerialDevice_avr.self
        case .cris: return QEMUSerialDevice_cris.self
        case .hppa: return QEMUSerialDevice_hppa.self
        case .i386: return QEMUSerialDevice_i386.self
        case .loongarch64: return QEMUSerialDevice_loongarch64.self
        case .m68k: return QEMUSerialDevice_m68k.self
        case .microblaze: return QEMUSerialDevice_microblaze.self
        case .microblazeel: return QEMUSerialDevice_microblazeel.self
        case .mips: return QEMUSerialDevice_mips.self
        case .mipsel: return QEMUSerialDevice_mipsel.self
        case .mips64: return QEMUSerialDevice_mips64.self
        case .mips64el: return QEMUSerialDevice_mips64el.self
        case .or1k: return QEMUSerialDevice_or1k.self
        case .ppc: return QEMUSerialDevice_ppc.self
        case .ppc64: return QEMUSerialDevice_ppc64.self
        case .riscv32: return QEMUSerialDevice_riscv32.self
        case .riscv64: return QEMUSerialDevice_riscv64.self
        case .rx: return QEMUSerialDevice_rx.self
        case .s390x: return QEMUSerialDevice_s390x.self
        case .sh4: return QEMUSerialDevice_sh4.self
        case .sh4eb: return QEMUSerialDevice_sh4eb.self
        case .sparc: return QEMUSerialDevice_sparc.self
        case .sparc64: return QEMUSerialDevice_sparc64.self
        case .tricore: return QEMUSerialDevice_tricore.self
        case .x86_64: return QEMUSerialDevice_x86_64.self
        case .xtensa: return QEMUSerialDevice_xtensa.self
        case .xtensaeb: return QEMUSerialDevice_xtensaeb.self
        }
    }

}


