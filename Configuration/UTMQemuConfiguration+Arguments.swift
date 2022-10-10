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

/// Build QEMU arguments from config
@MainActor extension UTMQemuConfiguration {
    /// Helper function to generate a final argument
    /// - Parameter string: Argument fragment
    /// - Returns: Final argument fragment
    private func f(_ string: String = "") -> QEMUArgumentFragment {
        QEMUArgumentFragment(final: string)
    }
    
    /// Return the socket file for communicating with SPICE
    var spiceSocketURL: URL {
        #if os(iOS)
        let parentURL = FileManager.default.temporaryDirectory
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
                parentURL = containerURL
            }
        }
        #endif
        return parentURL.appendingPathComponent("\(information.uuid.uuidString).spice")
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
        soundArguments
        if input.usbBusSupport != .disabled {
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
        "addr="
        spiceSocketURL
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
                f("\(serials[i].hardware!.rawValue),chardev=term\(i)")
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
            if qemu.hasHypervisor {
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
    
    private var supportsHypervisor: Bool {
        guard jb_has_hypervisor() else {
            return false
        }
        #if arch(arm64)
        return system.architecture == .aarch64
        #elseif arch(x86_64)
        return system.architecture == .x86_64
        #else
        return false
        #endif
    }
    
    @QEMUArgumentBuilder private var machineArguments: [QEMUArgument] {
        f("-machine")
        system.target
        f(machineProperties)
        if qemu.hasHypervisor && supportsHypervisor {
            f("-accel")
            f("hvf")
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
        if target.hasPrefix("pc") || target.hasPrefix("q35") {
            properties = properties.appendingDefaultPropertyName("vmport", value: "off")
            // disable PS/2 emulation if we are not legacy input and it's not explicitly enabled
            if input.usbBusSupport != .disabled && !qemu.hasPS2Controller {
                properties = properties.appendingDefaultPropertyName("i8042", value: "off")
            }
        }
        if target == "virt" || target.hasPrefix("virt-") && !architecture.hasPrefix("riscv") {
            if #available(macOS 12.4, iOS 15.5, *, *) {
                // default highmem value is fine here
            } else {
                // a kernel panic is triggered on M1 Max if highmem=on and running < macOS 12.4
                properties = properties.appendingDefaultPropertyName("highmem", value: "off")
            }
            // required to boot Windows ARM on TCG
            if system.architecture == .aarch64 && !qemu.hasHypervisor {
                properties = properties.appendingDefaultPropertyName("virtualization", value: "on")
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
            let bios = resourceURL.appendingPathComponent("edk2-\(system.architecture.rawValue)-code.fd")
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
    
    @QEMUArgumentBuilder private var soundArguments: [QEMUArgument] {
        for _sound in sound {
            if _sound.hardware.rawValue == "screamer" {
                #if !os(iOS)
                // force CoreAudio backend for mac99 which only supports 44100 Hz
                f("-audiodev")
                f("coreaudio,id=audio0")
                // no device setting for screamer
                #endif
            } else {
                f("-device")
                _sound.hardware
                f()
                if _sound.hardware.rawValue.contains("hda") {
                    f("-device")
                    f("hda-duplex")
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
    
    @QEMUArgumentBuilder private func driveArgument(for drive: UTMQemuConfigurationDrive, busInterfaceMap: inout [String: Int]) -> [QEMUArgument] {
        let isRemovable = drive.imageType == .cd || drive.isExternal
        var bootindex = busInterfaceMap["boot", default: 0]
        var busindex = busInterfaceMap[drive.interface.rawValue, default: 0]
        var realInterface = QEMUDriveInterface.none
        if drive.interface == .ide {
            f("-device")
            if isRemovable {
                "ide-cd"
            } else {
                "ide-hd"
            }
            "bus=ide.\(busindex)"
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
            if isRemovable {
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
            let isUsb3 = input.usbBusSupport != .disabled && system.target.rawValue.hasPrefix("virt")
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
        if isRemovable && drive.interface != .floppy {
            "media=cdrom"
        } else {
            "media=disk"
        }
        "id=drive\(drive.id)"
        if let imageURL = drive.imageURL {
            "file="
            imageURL
        }
        if drive.isReadOnly {
            "readonly=on"
        } else if !drive.isExternal {
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
                "ifname=\(networks[i].bridgeInterface ?? "en0")"
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
            if !useVMnet {
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
    
    @QEMUArgumentBuilder private var sharingArguments: [QEMUArgument] {
        if sharing.hasClipboardSharing || sharing.directoryShareMode == .webdav || displays.contains(where: { $0.isDynamicResolution }) {
            f("-device")
            f("virtio-serial")
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
        if sharing.directoryShareMode == .virtfs, let url = sharing.directoryShareUrl {
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
    
    @QEMUArgumentBuilder private var miscArguments: [QEMUArgument] {
        f("-name")
        f(information.name)
        if let snapshotName = qemu.snapshotName {
            f("-loadvm")
            f(snapshotName)
        } else if qemu.isDisposable {
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
    }
}

private extension String {
    func appendingDefaultPropertyName(_ name: String, value: String) -> String {
        if !self.contains("name" + "=") {
            return self.appending("\(self.count > 0 ? "," : "")\(name)=\(value)")
        } else {
            return self
        }
    }
}
