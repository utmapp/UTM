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
#if os(macOS)
import Virtualization // for getting network interfaces
#endif

/// Build QEMU arguments from config
@MainActor extension UTMQemuConfiguration {
    /// Helper function to generate a final argument
    /// - Parameter string: Argument fragment
    /// - Returns: Final argument fragment
    private func f(_ string: String = "") -> QEMUArgumentFragment {
        QEMUArgumentFragment(final: string)
    }
    
    /// Shared between helper and main process to store Unix sockets
    var socketURL: URL {
        #if os(iOS) || os(visionOS)
        return FileManager.default.temporaryDirectory
        #else
        let appGroup = Bundle.main.infoDictionary?["AppGroupIdentifier"] as? String
        let helper = Bundle.main.infoDictionary?["HelperIdentifier"] as? String
        // default to unsigned sandbox path
        var parentURL: URL = FileManager.default.homeDirectoryForCurrentUser
        parentURL.deleteLastPathComponent()
        parentURL.deleteLastPathComponent()
        parentURL.appendPathComponent(helper ?? "com.utmapp.QEMUHelper")
        parentURL.appendPathComponent("Data")
        parentURL.appendPathComponent("tmp")
        if let appGroup = appGroup, !appGroup.hasPrefix("invalid.") {
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
                return containerURL
            }
        }
        return parentURL
        #endif
    }
    
    /// Return the socket file for communicating with SPICE
    var spiceSocketURL: URL {
        socketURL.appendingPathComponent(information.uuid.uuidString).appendingPathExtension("spice")
    }
    
    /// Return the socket file for communicating with SWTPM
    var swtpmSocketURL: URL {
        socketURL.appendingPathComponent(information.uuid.uuidString).appendingPathExtension("swtpm")
    }
    
    /// Combined generated and user specified arguments.
    @QEMUArgumentBuilder var allArguments: [QEMUArgument] {
        generatedArguments
        userArguments
    }
    
    /// Only UTM generated arguments.
    @QEMUArgumentBuilder var generatedArguments: [QEMUArgument] {
        f("-L")
        resourceURL
        f()
        f("-S") // startup stopped
        spiceArguments
        networkArguments
        displayArguments
        serialArguments
        cpuArguments
        machineArguments
        architectureArguments
        if !sound.isEmpty {
            soundArguments
        }
        if isUsbUsed {
            usbArguments
        }
        drivesArguments
        sharingArguments
        miscArguments
    }
    
    @QEMUArgumentBuilder private var userArguments: [QEMUArgument] {
        let regex = try! NSRegularExpression(pattern: "((?:[^\"\\s]*\"[^\"]*\"[^\"\\s]*)+|[^\"\\s]+)")
        for arg in qemu.additionalArguments {
            let argString = arg.string
            if argString.count > 0 {
                let range = NSRange(argString.startIndex..<argString.endIndex, in: argString)
                let split = regex.matches(in: argString, options: [], range: range)
                for match in split {
                    let matchRange = Range(match.range(at: 1), in: argString)!
                    let fragment = argString[matchRange]
                    f(fragment.replacingOccurrences(of: "\"", with: ""))
                }
            }
        }
    }
    
    @QEMUArgumentBuilder private var spiceArguments: [QEMUArgument] {
        f("-spice")
        "unix=on"
        "addr=\(spiceSocketURL.lastPathComponent)"
        "disable-ticketing=on"
        "image-compression=off"
        "playback-compression=off"
        "streaming-video=off"
        "gl=\(isGLOn ? "on" : "off")"
        f()
        f("-chardev")
        f("spiceport,id=org.qemu.monitor.qmp,name=org.qemu.monitor.qmp.0")
        f("-mon")
        f("chardev=org.qemu.monitor.qmp,mode=control")
        if !isSparc { // disable -vga and other default devices
            // prevent QEMU default devices, which leads to duplicate CD drive (fix #2538)
            // see https://github.com/qemu/qemu/blob/6005ee07c380cbde44292f5f6c96e7daa70f4f7d/docs/qdev-device-use.txt#L382
            f("-nodefaults")
            f("-vga")
            f("none")
        }
    }
    
    @QEMUArgumentBuilder private var displayArguments: [QEMUArgument] {
        if displays.isEmpty {
            f("-nographic")
        } else if isSparc { // only one display supported
            f("-vga")
            displays[0].hardware
            if let vgaRamSize = displays[0].vgaRamMib {
                "vgamem_mb=\(vgaRamSize)"
            }
            f()
        } else {
            for display in displays {
                f("-device")
                display.hardware
                if let vgaRamSize = displays[0].vgaRamMib {
                    "vgamem_mb=\(vgaRamSize)"
                }
                f()
            }
        }
    }
    
    private var isGLOn: Bool {
        displays.contains { display in
            display.hardware.rawValue.contains("-gl-") || display.hardware.rawValue.hasSuffix("-gl")
        }
    }
    
    private var isSparc: Bool {
        system.architecture == .sparc || system.architecture == .sparc64
    }
    
    @QEMUArgumentBuilder private var serialArguments: [QEMUArgument] {
        for i in serials.indices {
            f("-chardev")
            switch serials[i].mode {
            case .builtin:
                f("spiceport,id=term\(i),name=com.utmapp.terminal.\(i)")
            case .tcpClient:
                "socket"
                "id=term\(i)"
                "port=\(serials[i].tcpPort ?? 1234)"
                "host=\(serials[i].tcpHostAddress ?? "example.com")"
                "server=off"
                f()
            case .tcpServer:
                "socket"
                "id=term\(i)"
                "port=\(serials[i].tcpPort ?? 1234)"
                "host=\(serials[i].isRemoteConnectionAllowed == true ? "0.0.0.0" : "127.0.0.1")"
                "server=on"
                "wait=\(serials[i].isWaitForConnection == true ? "on" : "off")"
                f()
            #if os(macOS)
            case .ptty:
                f("pty,id=term\(i)")
            #endif
            }
            switch serials[i].target {
            case .autoDevice:
                f("-serial")
                f("chardev:term\(i)")
            case .manualDevice:
                f("-device")
                f("\(serials[i].hardware?.rawValue ?? "invalid"),chardev=term\(i)")
            case .monitor:
                f("-mon")
                f("chardev=term\(i),mode=readline")
            case .gdb:
                f("-gdb")
                f("chardev:term\(i)")
            }
        }
    }
    
    @QEMUArgumentBuilder private var cpuArguments: [QEMUArgument] {
        if system.cpu.rawValue == system.architecture.cpuType.default.rawValue {
            // if default and not hypervisor, we don't pass any -cpu argument for x86 and use host for ARM
            if isHypervisorUsed {
                #if !arch(x86_64)
                f("-cpu")
                f("host")
                #endif
            } else if system.architecture == .aarch64 {
                // ARM64 QEMU does not support "-cpu default" so we hard code a sensible default
                f("-cpu")
                f("cortex-a72")
            } else if system.architecture == .arm {
                // ARM64 QEMU does not support "-cpu default" so we hard code a sensible default
                f("-cpu")
                f("cortex-a15")
            }
        } else {
            f("-cpu")
            system.cpu
            for flag in system.cpuFlagsAdd {
                "+\(flag.rawValue)"
            }
            for flag in system.cpuFlagsRemove {
                "-\(flag.rawValue)"
            }
            f()
        }
        let emulatedCpuCount = self.emulatedCpuCount
        f("-smp")
        "cpus=\(emulatedCpuCount.1)"
        "sockets=1"
        "cores=\(emulatedCpuCount.0)"
        "threads=\(emulatedCpuCount.1/emulatedCpuCount.0)"
        f()
    }
    
    private static func sysctlIntRead(_ name: String) -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }
    
    private var emulatedCpuCount: (Int, Int) {
        let singleCpu = (1, 1)
        let hostPhysicalCpu = Int(Self.sysctlIntRead("hw.physicalcpu"))
        let hostLogicalCpu = Int(Self.sysctlIntRead("hw.logicalcpu"))
        let userCpu = system.cpuCount
        if userCpu > 0 || hostPhysicalCpu == 0 {
            return (userCpu, userCpu) // user override
        }
        // SPARC5 defaults to single CPU
        if isSparc {
            return singleCpu
        }
        #if arch(arm64)
        let hostPcorePhysicalCpu = Int(Self.sysctlIntRead("hw.perflevel0.physicalcpu"))
        let hostPcoreLogicalCpu = Int(Self.sysctlIntRead("hw.perflevel0.logicalcpu"))
        // in ARM we can only emulate other weak architectures
        let weakArchitectures: [QEMUArchitecture] = [.alpha, .arm, .aarch64, .avr, .mips, .mips64, .mipsel, .mips64el, .ppc, .ppc64, .riscv32, .riscv64, .xtensa, .xtensaeb]
        if weakArchitectures.contains(system.architecture) {
            if hostPcorePhysicalCpu > 0 {
                return (hostPcorePhysicalCpu, hostPcoreLogicalCpu)
            } else {
                return (hostPhysicalCpu, hostLogicalCpu)
            }
        } else {
            return singleCpu
        }
        #elseif arch(x86_64)
        // in x86 we can emulate weak on strong
        return (hostPhysicalCpu, hostLogicalCpu)
        #else
        return singleCpu
        #endif
    }
    
    private var isHypervisorUsed: Bool {
        system.architecture.hasHypervisorSupport && qemu.hasHypervisor
    }
    
    private var isTSOUsed: Bool {
        system.architecture.hasTSOSupport && qemu.hasTSO
    }
    
    private var isUsbUsed: Bool {
        system.architecture.hasUsbSupport && system.target.hasUsbSupport && input.usbBusSupport != .disabled
    }
    
    private var isSecureBootUsed: Bool {
        system.architecture.hasSecureBootSupport && system.target.hasSecureBootSupport && qemu.hasTPMDevice
    }
    
    @QEMUArgumentBuilder private var machineArguments: [QEMUArgument] {
        f("-machine")
        system.target
        f(machineProperties)
        if isHypervisorUsed {
            f("-accel")
            "hvf"
            if isTSOUsed {
                "tso=on"
            }
            f()
        } else {
            f("-accel")
            "tcg"
            if system.isForceMulticore {
                "thread=multi"
            }
            let tbSize = system.jitCacheSize > 0 ? system.jitCacheSize : system.memorySize / 4
            "tb-size=\(tbSize)"
            #if !WITH_QEMU_TCI
            // use mirror mapping when we don't have JIT entitlements
            if !jb_has_jit_entitlement() {
                "split-wx=on"
            }
            #endif
            f()
        }
    }
    
    private var machineProperties: String {
        let target = system.target.rawValue
        let architecture = system.architecture.rawValue
        var properties = qemu.machinePropertyOverride ?? ""
        if target.hasPrefix("pc") || target.hasPrefix("q35") || target == "isapc" {
            properties = properties.appendingDefaultPropertyName("vmport", value: "off")
            // disable PS/2 emulation if we are not legacy input and it's not explicitly enabled
            if isUsbUsed && !qemu.hasPS2Controller {
                properties = properties.appendingDefaultPropertyName("i8042", value: "off")
            }
            #if os(macOS)
            if sound.contains(where: { $0.hardware.rawValue == "pcspk" }) {
                properties = properties.appendingDefaultPropertyName("pcspk-audiodev", value: "audio1")
            }
            #endif
            // disable HPET because it causes issues for some OS and also hinders performance
            properties = properties.appendingDefaultPropertyName("hpet", value: "off")
        }
        if target == "virt" || target.hasPrefix("virt-") && !architecture.hasPrefix("riscv") {
            if #available(macOS 12.4, iOS 15.5, *, *) {
                // default highmem value is fine here
            } else {
                // a kernel panic is triggered on M1 Max if highmem=on and running < macOS 12.4
                properties = properties.appendingDefaultPropertyName("highmem", value: "off")
            }
            // required to boot Windows ARM on TCG
            if system.architecture == .aarch64 && !isHypervisorUsed {
                properties = properties.appendingDefaultPropertyName("virtualization", value: "on")
            }
            // required for > 8 CPUs
            if system.architecture == .aarch64 && emulatedCpuCount.0 > 8 {
                properties = properties.appendingDefaultPropertyName("gic-version", value: "3")
            }
        }
        if target == "mac99" {
            properties = properties.appendingDefaultPropertyName("via", value: "pmu")
        }
        return properties
    }
    
    @QEMUArgumentBuilder private var architectureArguments: [QEMUArgument] {
        if system.architecture == .x86_64 || system.architecture == .i386 {
            f("-global")
            f("PIIX4_PM.disable_s3=1") // applies for pc-i440fx-* types
            f("-global")
            f("ICH9-LPC.disable_s3=1") // applies for pc-q35-* types
        }
        if qemu.hasUefiBoot {
            let secure = isSecureBootUsed ? "-secure" : ""
            let code = system.target.rawValue == "microvm" ? "microvm" : "code"
            let bios = resourceURL.appendingPathComponent("edk2-\(system.architecture.rawValue)\(secure)-\(code).fd")
            let vars = qemu.efiVarsURL ?? URL(fileURLWithPath: "/\(QEMUPackageFileName.efiVariables.rawValue)")
            if !hasCustomBios && FileManager.default.fileExists(atPath: bios.path) {
                f("-drive")
                "if=pflash"
                "format=raw"
                "unit=0"
                "file="
                bios
                "readonly=on"
                f()
                f("-drive")
                "if=pflash"
                "unit=1"
                "file="
                vars
                f()
            }
        }
        f("-m")
        system.memorySize
        f()
    }
    
    private var hasCustomBios: Bool {
        for drive in drives {
            if drive.imageType == .disk || drive.imageType == .cd {
                if drive.interface == .pflash {
                    return true
                }
            } else if drive.imageType == .bios || drive.imageType == .linuxKernel {
                return true
            }
        }
        return false
    }
    
    private var resourceURL: URL {
        Bundle.main.url(forResource: "qemu", withExtension: nil)!
    }
    
    private var soundBackend: UTMQEMUSoundBackend {
        let value = UserDefaults.standard.integer(forKey: "QEMUSoundBackend")
        if let backend = UTMQEMUSoundBackend(rawValue: value), backend != .qemuSoundBackendMax {
            return backend
        } else {
            return .qemuSoundBackendDefault
        }
    }
    
    private var useCoreAudioBackend: Bool {
        #if os(iOS) || os(visionOS)
        return false
        #else
        // force CoreAudio backend for mac99 which only supports 44100 Hz
        // pcspk doesn't work with SPICE audio
        if sound.contains(where: { $0.hardware.rawValue == "screamer" || $0.hardware.rawValue == "pcspk" }) {
            return true
        }
        if soundBackend == .qemuSoundBackendCoreAudio {
            return true
        }
        return false
        #endif
    }
    
    @QEMUArgumentBuilder private var soundArguments: [QEMUArgument] {
        if useCoreAudioBackend {
            f("-audiodev")
            "coreaudio"
            f("id=audio1")
        }
        f("-audiodev")
        "spice"
        f("id=audio0")
        // screamer has no extra device, pcspk is handled in machineProperties
        for _sound in sound.filter({ $0.hardware.rawValue != "screamer" && $0.hardware.rawValue != "pcspk" }) {
            f("-device")
            _sound.hardware
            if _sound.hardware.rawValue.contains("hda") {
                f()
                f("-device")
                if soundBackend == .qemuSoundBackendCoreAudio {
                    "hda-output"
                    "audiodev=audio1"
                } else {
                    "hda-duplex"
                    "audiodev=audio0"
                }
                f()
            } else {
                if soundBackend == .qemuSoundBackendCoreAudio {
                    f("audiodev=audio1")
                } else {
                    f("audiodev=audio0")
                }
            }
        }
    }
    
    @QEMUArgumentBuilder private var drivesArguments: [QEMUArgument] {
        var busInterfaceMap: [String: Int] = [:]
        for drive in drives {
            let hasImage = !drive.isExternal && drive.imageURL != nil
            if drive.imageType == .disk || drive.imageType == .cd {
                driveArgument(for: drive, busInterfaceMap: &busInterfaceMap)
            } else if hasImage {
                switch drive.imageType {
                case .bios:
                    f("-bios")
                    drive.imageURL!
                case .linuxKernel:
                    f("-kernel")
                    drive.imageURL!
                case .linuxInitrd:
                    f("-initrd")
                    drive.imageURL!
                case .linuxDtb:
                    f("-dtb")
                    drive.imageURL!
                default:
                    f()
                }
                f()
            }
        }
    }
    
    /// These machines are hard coded to have one IDE unit per bus in QEMU
    private var isIdeInterfaceSingleUnit: Bool {
        system.target.rawValue.contains("q35") ||
        system.target.rawValue == "microvm" ||
        system.target.rawValue == "cubieboard" ||
        system.target.rawValue == "highbank" ||
        system.target.rawValue == "midway" ||
        system.target.rawValue == "xlnx_zcu102"
    }
    
    @QEMUArgumentBuilder private func driveArgument(for drive: UTMQemuConfigurationDrive, busInterfaceMap: inout [String: Int]) -> [QEMUArgument] {
        let isRemovable = drive.imageType == .cd || drive.isExternal
        let isCd = drive.imageType == .cd && drive.interface != .floppy
        var bootindex = busInterfaceMap["boot", default: 0]
        var busindex = busInterfaceMap[drive.interface.rawValue, default: 0]
        var realInterface = QEMUDriveInterface.none
        if drive.interface == .ide {
            f("-device")
            if isCd {
                "ide-cd"
            } else {
                "ide-hd"
            }
            if drive.interfaceVersion >= 1 && !isIdeInterfaceSingleUnit {
                "bus=ide.\(busindex / 2)"
                "unit=\(busindex % 2)"
            } else {
                "bus=ide.\(busindex)"
            }
            busindex += 1
            "drive=drive\(drive.id)"
            "bootindex=\(bootindex)"
            bootindex += 1
            f()
        } else if drive.interface == .scsi {
            var bus = "scsi"
            if system.architecture != .sparc && system.architecture != .sparc64 {
                bus = "scsi0"
                if busindex == 0 {
                    f("-device")
                    f("lsi53c895a,id=scsi0")
                }
            }
            f("-device")
            if isCd {
                "scsi-cd"
            } else {
                "scsi-hd"
            }
            "bus=\(bus).0"
            "channel=0"
            "scsi-id=\(busindex)"
            busindex += 1
            "drive=drive\(drive.id)"
            "bootindex=\(bootindex)"
            bootindex += 1
            f()
        } else if drive.interface == .virtio {
            f("-device")
            if system.architecture == .s390x {
                "virtio-blk-ccw"
            } else {
                "virtio-blk-pci"
            }
            "drive=drive\(drive.id)"
            "bootindex=\(bootindex)"
            bootindex += 1
            f()
        } else if drive.interface == .nvme {
            f("-device")
            "nvme"
            "drive=drive\(drive.id)"
            "serial=\(drive.id)"
            "bootindex=\(bootindex)"
            bootindex += 1
            f()
        } else if drive.interface == .usb {
            f("-device")
            // use usb 3 bus for virt system, unless using legacy input setting (this mirrors the code in argsForUsb)
            let isUsb3 = isUsbUsed && system.target.rawValue.hasPrefix("virt")
            "usb-storage"
            "drive=drive\(drive.id)"
            "removable=\(isRemovable)"
            "bootindex=\(bootindex)"
            bootindex += 1
            if isUsb3 {
                "bus=usb-bus.0"
            }
            f()
        } else if drive.interface == .floppy {
            if system.target.rawValue.hasPrefix("q35") {
                f("-device")
                "isa-fdc"
                "id=fdc\(busindex)"
                "bootindexA=\(bootindex)"
                bootindex += 1
                f()
                f("-device")
                "floppy"
                "unit=0"
                "bus=fdc\(busindex).0"
                busindex += 1
                "drive=drive\(drive.id)"
                f()
            } else {
                realInterface = drive.interface
            }
        } else {
            realInterface = drive.interface
        }
        busInterfaceMap["boot"] = bootindex
        busInterfaceMap[drive.interface.rawValue] = busindex
        f("-drive")
        switch realInterface {
        case .ide:
            "if=ide"
        case .scsi:
            "if=scsi"
        case .sd:
            "if=sd"
        case .mtd:
            "if=mtd"
        case .floppy:
            "if=floppy"
        case .pflash:
            "if=pflash"
        default:
            "if=none"
        }
        if isCd {
            "media=cdrom"
        } else {
            "media=disk"
        }
        "id=drive\(drive.id)"
        if let imageURL = drive.imageURL {
            "file="
            imageURL
        } else if !isCd {
            "file=/dev/null"
        }
        if drive.isReadOnly || isCd {
            "readonly=on"
        } else {
            "discard=unmap"
            "detect-zeroes=unmap"
        }
        f()
    }
    
    @QEMUArgumentBuilder private var usbArguments: [QEMUArgument] {
        if system.target.rawValue.hasPrefix("virt") {
            f("-device")
            f("nec-usb-xhci,id=usb-bus")
        } else {
            f("-usb")
        }
        f("-device")
        f("usb-tablet,bus=usb-bus.0")
        f("-device")
        f("usb-mouse,bus=usb-bus.0")
        f("-device")
        f("usb-kbd,bus=usb-bus.0")
        #if !WITH_QEMU_TCI
        let maxDevices = input.maximumUsbShare
        let buses = (maxDevices + 2) / 3
        if input.usbBusSupport == .usb3_0 {
            var controller = "qemu-xhci"
            if system.target.rawValue.hasPrefix("pc") || system.target.rawValue.hasPrefix("q35") {
                controller = "nec-usb-xhci"
            }
            for i in 0..<buses {
                f("-device")
                f("\(controller),id=usb-controller-\(i)")
            }
        } else {
            for i in 0..<buses {
                f("-device")
                f("ich9-usb-ehci1,id=usb-controller-\(i)")
                f("-device")
                f("ich9-usb-uhci1,masterbus=usb-controller-\(i).0,firstport=0,multifunction=on")
                f("-device")
                f("ich9-usb-uhci2,masterbus=usb-controller-\(i).0,firstport=2,multifunction=on")
                f("-device")
                f("ich9-usb-uhci3,masterbus=usb-controller-\(i).0,firstport=4,multifunction=on")
            }
        }
        // set up usb forwarding
        for i in 0..<maxDevices {
            f("-chardev")
            f("spicevmc,name=usbredir,id=usbredirchardev\(i)")
            f("-device")
            f("usb-redir,chardev=usbredirchardev\(i),id=usbredirdev\(i),bus=usb-controller-\(i/3).0")
        }
        #endif
    }
    
    private func parseNetworkSubnet(from network: UTMQemuConfigurationNetwork) -> (start: String, end: String, mask: String)? {
        guard let net = network.vlanGuestAddress else {
            return nil
        }
        let components = net.split(separator: "/")
        let address: String
        let binaryMask: UInt32
        guard components.count >= 1 else {
            return nil
        }
        if components.count == 2 {
            var netmaskAddr = in_addr()
            if inet_pton(AF_INET, String(components[1]), &netmaskAddr) == 1 {
                binaryMask = UInt32(bigEndian: netmaskAddr.s_addr)
            } else {
                let topbits = Int(components[1])
                guard let topbits = topbits, topbits >= 0 && topbits < 32 else {
                    return nil
                }
                binaryMask = (0xFFFFFFFF as UInt32) << (32 - topbits)
            }
        } else {
            binaryMask = 0xFFFFFF00
        }
        address = String(components[0])
        var networkAddr = in_addr()
        let netmask = in_addr(s_addr: in_addr_t(bigEndian: binaryMask))
        guard inet_pton(AF_INET, address, &networkAddr) == 1 else {
            return nil
        }
        let firstAddr = in_addr(s_addr: (in_addr_t(bigEndian: networkAddr.s_addr & netmask.s_addr) + 1).bigEndian)
        let lastAddr = in_addr(s_addr: (in_addr_t(bigEndian: networkAddr.s_addr | ~netmask.s_addr) - 1).bigEndian)
        let firstAddrStr = String(cString: inet_ntoa(firstAddr))
        let lastAddrStr = String(cString: inet_ntoa(lastAddr))
        let netmaskStr = String(cString: inet_ntoa(netmask))
        return (network.vlanDhcpStartAddress ?? firstAddrStr, network.vlanDhcpEndAddress ?? lastAddrStr, netmaskStr)
    }
    
    #if os(macOS)
    private var defaultBridgedInterface: String {
        VZBridgedNetworkInterface.networkInterfaces.first?.identifier ?? "en0"
    }
    #endif
    
    @QEMUArgumentBuilder private var networkArguments: [QEMUArgument] {
        for i in networks.indices {
            if isSparc {
                f("-net")
                "nic"
                "model=lance"
                "macaddr=\(networks[i].macAddress)"
                "netdev=net\(i)"
                f()
            } else {
                f("-device")
                networks[i].hardware
                "mac=\(networks[i].macAddress)"
                "netdev=net\(i)"
                f()
            }
            f("-netdev")
            var useVMnet = false
            #if os(macOS)
            if networks[i].mode == .shared {
                useVMnet = true
                "vmnet-shared"
                "id=net\(i)"
            } else if networks[i].mode == .bridged {
                useVMnet = true
                "vmnet-bridged"
                "id=net\(i)"
                "ifname=\(networks[i].bridgeInterface ?? defaultBridgedInterface)"
            } else if networks[i].mode == .host {
                useVMnet = true
                "vmnet-host"
                "id=net\(i)"
            } else {
                "user"
                "id=net\(i)"
            }
            #else
            "user"
            "id=net\(i)"
            #endif
            if networks[i].isIsolateFromHost {
                if useVMnet {
                    "isolated=on"
                } else {
                    "restrict=on"
                }
            }
            if useVMnet {
                if let subnet = parseNetworkSubnet(from: networks[i]) {
                    "start-address=\(subnet.start)"
                    "end-address=\(subnet.end)"
                    "subnet-mask=\(subnet.mask)"
                }
                if let nat66prefix = networks[i].vlanGuestAddressIPv6 {
                    "nat66-prefix=\(nat66prefix)"
                }
            } else {
                if let guestAddress = networks[i].vlanGuestAddress {
                    "net=\(guestAddress)"
                }
                if let hostAddress = networks[i].vlanHostAddress {
                    "host=\(hostAddress)"
                }
                if let guestAddressIPv6 = networks[i].vlanGuestAddressIPv6 {
                    "ipv6-net=\(guestAddressIPv6)"
                }
                if let hostAddressIPv6 = networks[i].vlanHostAddressIPv6 {
                    "ipv6-host=\(hostAddressIPv6)"
                }
                if let dhcpStartAddress = networks[i].vlanDhcpStartAddress {
                    "dhcpstart=\(dhcpStartAddress)"
                }
                if let dnsServerAddress = networks[i].vlanDnsServerAddress {
                    "dns=\(dnsServerAddress)"
                }
                if let dnsServerAddressIPv6 = networks[i].vlanDnsServerAddressIPv6 {
                    "ipv6-dns=\(dnsServerAddressIPv6)"
                }
                if let dnsSearchDomain = networks[i].vlanDnsSearchDomain {
                    "dnssearch=\(dnsSearchDomain)"
                }
                if let dhcpDomain = networks[i].vlanDhcpDomain {
                    "domainname=\(dhcpDomain)"
                }
                for forward in networks[i].portForward {
                    "hostfwd=\(forward.protocol.rawValue.lowercased()):\(forward.hostAddress ?? ""):\(forward.hostPort)-\(forward.guestAddress ?? ""):\(forward.guestPort)"
                }
            }
            f()
        }
        if networks.count == 0 {
            f("-nic")
            f("none")
        }
    }
    
    private var isSpiceAgentUsed: Bool {
        guard system.architecture.hasAgentSupport && system.target.hasAgentSupport else {
            return false
        }
        return sharing.hasClipboardSharing || sharing.directoryShareMode == .webdav || displays.contains(where: { $0.isDynamicResolution })
    }
    
    @QEMUArgumentBuilder private var sharingArguments: [QEMUArgument] {
        if system.architecture.hasAgentSupport && system.target.hasAgentSupport {
            f("-device")
            f("virtio-serial")
            f("-device")
            f("virtserialport,chardev=org.qemu.guest_agent,name=org.qemu.guest_agent.0")
            f("-chardev")
            f("spiceport,id=org.qemu.guest_agent,name=org.qemu.guest_agent.0")
        }
        if isSpiceAgentUsed {
            f("-device")
            f("virtserialport,chardev=vdagent,name=com.redhat.spice.0")
            f("-chardev")
            f("spicevmc,id=vdagent,debug=0,name=vdagent")
            if sharing.directoryShareMode == .webdav {
                f("-device")
                f("virtserialport,chardev=charchannel1,id=channel1,name=org.spice-space.webdav.0")
                f("-chardev")
                f("spiceport,name=org.spice-space.webdav.0,id=charchannel1")
            }
        }
        if system.architecture.hasSharingSupport && sharing.directoryShareMode == .virtfs, let url = sharing.directoryShareUrl {
            f("-fsdev")
            "local"
            "id=virtfs0"
            "path="
            url
            "security_model=mapped-xattr"
            if sharing.isDirectoryShareReadOnly {
                "readonly=on"
            }
            f()
            f("-device")
            if system.architecture == .s390x {
                "virtio-9p-ccw"
            } else {
                "virtio-9p-pci"
            }
            "fsdev=virtfs0"
            "mount_tag=share"
        }
    }
    
    private func cleanupName(_ name: String) -> String {
        let allowedCharacterSet = CharacterSet.alphanumerics.union(.whitespaces)
        let filteredString = name.components(separatedBy: allowedCharacterSet.inverted)
                                 .joined(separator: "")
        return filteredString
    }
    
    @QEMUArgumentBuilder private var miscArguments: [QEMUArgument] {
        f("-name")
        f(cleanupName(information.name))
        if qemu.isDisposable {
            f("-snapshot")
        }
        f("-uuid")
        f(information.uuid.uuidString)
        if qemu.hasRTCLocalTime {
            f("-rtc")
            f("base=localtime")
        }
        if qemu.hasRNGDevice {
            f("-device")
            f("virtio-rng-pci")
        }
        if qemu.hasBalloonDevice {
            f("-device")
            f("virtio-balloon-pci")
        }
        if qemu.hasTPMDevice {
            tpmArguments
        }
    }
    
    @QEMUArgumentBuilder private var tpmArguments: [QEMUArgument] {
        f("-chardev")
        "socket"
        "id=chrtpm0"
        "path=\(swtpmSocketURL.lastPathComponent)"
        f()
        f("-tpmdev")
        "emulator"
        "id=tpm0"
        "chardev=chrtpm0"
        f()
        f("-device")
        if system.target.rawValue.hasPrefix("virt") {
            "tpm-crb-device"
        } else if system.architecture == .ppc64 {
            "tpm-spapr"
        } else {
            "tpm-crb"
        }
        "tpmdev=tpm0"
        f()
    }
}

private extension String {
    func appendingDefaultPropertyName(_ name: String, value: String) -> String {
        if !self.contains(name + "=") {
            return self.appending("\(self.count > 0 ? "," : "")\(name)=\(value)")
        } else {
            return self
        }
    }
}
