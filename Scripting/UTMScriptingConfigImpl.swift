//
// Copyright © 2023 osy. All rights reserved.
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

@objc extension UTMScriptingVirtualMachineImpl {
    @objc var configuration: [AnyHashable : Any] {
        let wrapper = UTMScriptingConfigImpl(vm.config, data: data)
        return wrapper.serializeConfiguration()
    }
    
    @objc func updateConfiguration(_ command: NSScriptCommand) {
        let newConfiguration = command.evaluatedArguments?["newConfiguration"] as? [AnyHashable : Any]
        withScriptCommand(command) { [self] in
            guard let newConfiguration = newConfiguration else {
                throw ScriptingError.invalidParameter
            }
            guard vm.state == .stopped else {
                throw ScriptingError.notStopped
            }
            let wrapper = UTMScriptingConfigImpl(vm.config)
            try wrapper.updateConfiguration(from: newConfiguration)
            try await data.save(vm: box)
        }
    }
}

@MainActor
class UTMScriptingConfigImpl {
    private var bytesInMib: Int64 {
        1048576
    }
    
    private(set) var config: any UTMConfiguration
    private weak var data: UTMData?
    
    init(_ config: any UTMConfiguration, data: UTMData? = nil) {
        self.config = config
        self.data = data
    }
    
    func serializeConfiguration() -> [AnyHashable : Any] {
        if let qemuConfig = config as? UTMQemuConfiguration {
            return serializeQemuConfiguration(qemuConfig)
        } else if let appleConfig = config as? UTMAppleConfiguration {
            return serializeAppleConfiguration(appleConfig)
        } else {
            fatalError()
        }
    }
    
    func updateConfiguration(from record: [AnyHashable : Any]) throws {
        if let _ = config as? UTMQemuConfiguration {
            try updateQemuConfiguration(from: record)
        } else if let _ = config as? UTMAppleConfiguration {
            try updateAppleConfiguration(from: record)
        } else {
            fatalError()
        }
    }
    
    private func size(of drive: any UTMConfigurationDrive) -> Int {
        guard let data = data else {
            return 0
        }
        guard let url = drive.imageURL else {
            return 0
        }
        return Int(data.computeSize(for: url) / bytesInMib)
    }
}

@MainActor
extension UTMScriptingConfigImpl {
    private func qemuDirectoryShareMode(from mode: QEMUFileShareMode) -> UTMScriptingQemuDirectoryShareMode {
        switch mode {
        case .none: return .none
        case .webdav: return .webDAV
        case .virtfs: return .virtFS
        }
    }
    
    private func serializeQemuConfiguration(_ config: UTMQemuConfiguration) -> [AnyHashable : Any] {
        [
            "name": config.information.name,
            "icon": config.information.iconURL?.deletingPathExtension().lastPathComponent ?? "",
            "notes": config.information.notes ?? "",
            "architecture": config.system.architecture.rawValue,
            "machine": config.system.target.rawValue,
            "memory": config.system.memorySize,
            "cpuCores": config.system.cpuCount,
            "hypervisor": config.qemu.hasHypervisor,
            "uefi": config.qemu.hasUefiBoot,
            "directoryShareMode": qemuDirectoryShareMode(from: config.sharing.directoryShareMode).rawValue,
            "drives": config.drives.map({ serializeQemuDriveExisting($0) }),
            "networkInterfaces": config.networks.enumerated().map({ serializeQemuNetwork($1, index: $0) }),
            "serialPorts": config.serials.enumerated().map({ serializeQemuSerial($1, index: $0) }),
            "displays": config.displays.map({ serializeQemuDisplay($0)}),
            "qemuAdditionalArguments": config.qemu.additionalArguments.map({ serializeQemuAdditionalArgument($0)}),
        ]
    }
    
    private func qemuDriveInterface(from interface: QEMUDriveInterface) -> UTMScriptingQemuDriveInterface {
        switch interface {
        case .none: return .none
        case .ide: return .ide
        case .scsi: return .scsi
        case .sd: return .sd
        case .mtd: return .mtd
        case .floppy: return .floppy
        case .pflash: return .pFlash
        case .virtio: return .virtIO
        case .nvme: return .nvMe
        case .usb: return .usb
        }
    }
    
    private func serializeQemuDriveExisting(_ config: UTMQemuConfigurationDrive) -> [AnyHashable : Any] {
        [
            "id": config.id,
            "removable": config.isExternal,
            "interface": qemuDriveInterface(from: config.interface).rawValue,
            "hostSize": size(of: config),
        ]
    }
    
    private func qemuNetworkMode(from mode: QEMUNetworkMode) -> UTMScriptingQemuNetworkMode {
        switch mode {
        case .emulated: return .emulated
        case .shared: return .shared
        case .host: return .host
        case .bridged: return .bridged
        }
    }
    
    private func serializeQemuNetwork(_ config: UTMQemuConfigurationNetwork, index: Int) -> [AnyHashable : Any] {
        [
            "index": index,
            "hardware": config.hardware.rawValue,
            "mode": qemuNetworkMode(from: config.mode).rawValue,
            "address": config.macAddress,
            "hostInterface": config.bridgeInterface ?? "",
            "portForwards": config.portForward.map({ serializeQemuPortForward($0) }),
        ]
    }
    
    private func networkProtocol(from protc: QEMUNetworkProtocol) -> UTMScriptingNetworkProtocol {
        switch protc {
        case .tcp: return .tcp
        case .udp: return .udp
        }
    }
    
    private func serializeQemuPortForward(_ config: UTMQemuConfigurationPortForward) -> [AnyHashable : Any] {
        [
            "protocol": networkProtocol(from: config.protocol).rawValue,
            "hostAddress": config.hostAddress ?? "",
            "hostPort": config.hostPort,
            "guestAddress": config.guestAddress ?? "",
            "guestPort": config.guestPort,
        ]
    }
    
    private func qemuSerialInterface(from mode: QEMUSerialMode) -> UTMScriptingSerialInterface {
        switch mode {
        case .ptty: return .ptty
        case .tcpServer: return .tcp
        default: return .unavailable
        }
    }
    
    private func serializeQemuSerial(_ config: UTMQemuConfigurationSerial, index: Int) -> [AnyHashable : Any] {
        [
            "index": index,
            "hardware": config.hardware?.rawValue ?? "",
            "interface": qemuSerialInterface(from: config.mode).rawValue,
            "port": config.tcpPort ?? 0,
        ]
    }
    
    private func qemuScaler(from filter: QEMUScaler) -> UTMScriptingQemuScaler {
        switch filter {
        case .linear: return .linear
        case .nearest: return .nearest
        }
    }
    
    private func serializeQemuDisplay(_ config: UTMQemuConfigurationDisplay) -> [AnyHashable : Any] {
        [
            "id": config.id.uuidString,
            "hardware": config.hardware.rawValue,
            "dynamicResolution": config.isDynamicResolution,
            "nativeResolution": config.isNativeResolution,
            "upscalingFilter": qemuScaler(from: config.upscalingFilter).rawValue,
            "downscalingFilter": qemuScaler(from: config.downscalingFilter).rawValue,
        ]
    }
    
    private func serializeQemuAdditionalArgument(_ argument: QEMUArgument) -> [AnyHashable: Any] {
        var serializedArgument: [AnyHashable: Any] = [
            "argumentString": argument.string
        ]
        // Only add fileUrls if it is not nil and contains URLs
        if let fileUrls = argument.fileUrls, !fileUrls.isEmpty {
            serializedArgument["fileUrls"] = fileUrls.map({ $0 as AnyHashable })
        }
        
        return serializedArgument
    }
    
    private func serializeAppleConfiguration(_ config: UTMAppleConfiguration) -> [AnyHashable : Any] {
        [
            "name": config.information.name,
            "icon": config.information.iconURL?.deletingPathExtension().lastPathComponent ?? "",
            "notes": config.information.notes ?? "",
            "memory": config.system.memorySize,
            "cpuCores": config.system.cpuCount,
            "directoryShares": config.sharedDirectories.enumerated().map({ serializeAppleDirectoryShare($1, index: $0) }),
            "drives": config.drives.map({ serializeAppleDriveExisting($0) }),
            "networkInterfaces": config.networks.enumerated().map({ serializeAppleNetwork($1, index: $0) }),
            "serialPorts": config.serials.enumerated().map({ serializeAppleSerial($1, index: $0) }),
            "displays": config.displays.map({ serializeAppleDisplay($0)}),
        ]
    }
    
    private func serializeAppleDirectoryShare(_ config: UTMAppleConfigurationSharedDirectory, index: Int) -> [AnyHashable : Any] {
        [
            "index": index,
            "readOnly": config.isReadOnly
        ]
    }
    
    private func serializeAppleDriveExisting(_ config: UTMAppleConfigurationDrive) -> [AnyHashable : Any] {
        [
            "id": config.id,
            "removable": config.isExternal,
            "hostSize": size(of: config),
        ]
    }
    
    private func appleNetworkMode(from mode: UTMAppleConfigurationNetwork.NetworkMode) -> UTMScriptingAppleNetworkMode {
        switch mode {
        case .shared: return .shared
        case .bridged: return .bridged
        }
    }
    
    private func serializeAppleNetwork(_ config: UTMAppleConfigurationNetwork, index: Int) -> [AnyHashable : Any] {
        [
            "index": index,
            "mode": appleNetworkMode(from: config.mode).rawValue,
            "address": config.macAddress,
            "hostInterface": config.bridgeInterface ?? "",
        ]
    }
    
    private func appleSerialInterface(from mode: UTMAppleConfigurationSerial.SerialMode) -> UTMScriptingSerialInterface {
        switch mode {
        case .ptty: return .ptty
        default: return .unavailable
        }
    }
    
    private func serializeAppleSerial(_ config: UTMAppleConfigurationSerial, index: Int) -> [AnyHashable : Any] {
        [
            "index": index,
            "interface": appleSerialInterface(from: config.mode).rawValue,
        ]
    }
    
    private func serializeAppleDisplay(_ config: UTMAppleConfigurationDisplay) -> [AnyHashable : Any] {
        [
            "id": config.id.uuidString,
            "dynamicResolution": config.isDynamicResolution,
        ]
    }
}

@MainActor
extension UTMScriptingConfigImpl {
    private func updateElements<T>(_ array: inout [T], with records: [[AnyHashable : Any]], onExisting: @MainActor (inout T, [AnyHashable : Any]) throws -> Void, onNew: @MainActor ([AnyHashable : Any]) throws -> T) throws {
        var unseenIndicies = IndexSet(integersIn: array.indices)
        for record in records {
            if let index = record["index"] as? Int {
                guard array.indices.contains(index) else {
                    throw ConfigurationError.indexNotFound(index: index)
                }
                try onExisting(&array[index], record)
                unseenIndicies.remove(index)
            } else {
                array.append(try onNew(record))
            }
        }
        array.remove(atOffsets: unseenIndicies)
    }
    
    private func updateIdentifiedElements<T: Identifiable>(_ array: inout [T], with records: [[AnyHashable : Any]], onExisting: @MainActor (inout T, [AnyHashable : Any]) throws -> Void, onNew: @MainActor ([AnyHashable : Any]) throws -> T) throws {
        var unseenIndicies = IndexSet(integersIn: array.indices)
        for record in records {
            if let id = record["id"] as? T.ID {
                guard let index = array.enumerated().first(where: { $1.id == id })?.offset else {
                    throw ConfigurationError.identifierNotFound(id: id)
                }
                try onExisting(&array[index], record)
                unseenIndicies.remove(index)
            } else {
                array.append(try onNew(record))
            }
        }
        array.remove(atOffsets: unseenIndicies)
    }
    
    private func parseQemuDirectoryShareMode(_ value: AEKeyword?) -> QEMUFileShareMode? {
        guard let value = value, let parsed = UTMScriptingQemuDirectoryShareMode(rawValue: value) else {
            return Optional.none
        }
        switch parsed {
        case .none: return QEMUFileShareMode.none
        case .webDAV: return .webdav
        case .virtFS: return .virtfs
        default: return Optional.none
        }
    }
    
    private func updateQemuConfiguration(from record: [AnyHashable : Any]) throws {
        let config = config as! UTMQemuConfiguration
        if let name = record["name"] as? String, !name.isEmpty {
            config.information.name = name
        }
        if let icon = record["icon"] as? String, !icon.isEmpty {
            if let url = UTMConfigurationInfo.builtinIcon(named: icon) {
                config.information.iconURL = url
            } else {
                throw ConfigurationError.iconNotFound(icon: icon)
            }
        }
        if let notes = record["notes"] as? String, !notes.isEmpty {
            config.information.notes = notes
        }
        let architecture = record["architecture"] as? String
        let arch = QEMUArchitecture(rawValue: architecture ?? "")
        let machine = record["machine"] as? String
        let target = arch?.targetType.init(rawValue: machine ?? "")
        if let arch = arch, arch != config.system.architecture {
            let target = target ?? arch.targetType.default
            config.system.architecture = arch
            config.system.target = target
            config.reset(forArchitecture: arch, target: target)
        } else if let target = target, target.rawValue != config.system.target.rawValue {
            config.system.target = target
            config.reset(forArchitecture: config.system.architecture, target: target)
        }
        if let memory = record["memory"] as? Int, memory != 0 {
            config.system.memorySize = memory
        }
        if let cpuCores = record["cpuCores"] as? Int {
            config.system.cpuCount = cpuCores
        }
        if let hypervisor = record["hypervisor"] as? Bool {
            config.qemu.hasHypervisor = hypervisor
        }
        if let uefi = record["uefi"] as? Bool {
            config.qemu.hasUefiBoot = uefi
        }
        if let directoryShareMode = parseQemuDirectoryShareMode(record["directoryShareMode"] as? AEKeyword) {
            config.sharing.directoryShareMode = directoryShareMode
        }
        if let drives = record["drives"] as? [[AnyHashable : Any]] {
            try updateQemuDrives(from: drives)
        }
        if let networkInterfaces = record["networkInterfaces"] as? [[AnyHashable : Any]] {
            try updateQemuNetworks(from: networkInterfaces)
        }
        if let serialPorts = record["serialPorts"] as? [[AnyHashable : Any]] {
            try updateQemuSerials(from: serialPorts)
        }
        if let displays = record["displays"] as? [[AnyHashable : Any]] {
            try updateQemuDisplays(from: displays)
        }
        if let qemuAdditionalArguments = record["qemuAdditionalArguments"] as? [[AnyHashable: Any]] {
            try updateQemuAdditionalArguments(from: qemuAdditionalArguments)
        }
    }
    
    private func parseQemuDriveInterface(_ value: AEKeyword?) -> QEMUDriveInterface? {
        guard let value = value, let parsed = UTMScriptingQemuDriveInterface(rawValue: value) else {
            return Optional.none
        }
        switch parsed {
        case .none: return QEMUDriveInterface.none
        case .ide: return .ide
        case .scsi: return .scsi
        case .sd: return .sd
        case .mtd: return .mtd
        case .floppy: return .floppy
        case .pFlash: return .pflash
        case .virtIO: return .virtio
        case .nvMe: return .nvme
        case .usb: return .usb
        default: return Optional.none
        }
    }
    
    private func updateQemuDrives(from records: [[AnyHashable : Any]]) throws {
        let config = config as! UTMQemuConfiguration
        try updateIdentifiedElements(&config.drives, with: records, onExisting: updateQemuExistingDrive, onNew: unserializeQemuDriveNew)
    }
    
    private func updateQemuExistingDrive(_ drive: inout UTMQemuConfigurationDrive, from record: [AnyHashable : Any]) throws {
        if let interface = parseQemuDriveInterface(record["interface"] as? AEKeyword) {
            drive.interface = interface
        }
        if let source = record["source"] as? URL {
            drive.imageURL = source
        }
    }
    
    private func unserializeQemuDriveNew(from record: [AnyHashable : Any]) throws -> UTMQemuConfigurationDrive {
        let config = config as! UTMQemuConfiguration
        let removable = record["removable"] as? Bool ?? false
        var newDrive = UTMQemuConfigurationDrive(forArchitecture: config.system.architecture, target: config.system.target, isExternal: removable)
        if let importUrl = record["source"] as? URL {
            newDrive.imageURL = importUrl
        } else if let size = record["guestSize"] as? Int {
            newDrive.sizeMib = size
        }
        if let interface = parseQemuDriveInterface(record["interface"] as? AEKeyword) {
            newDrive.interface = interface
        }
        if let raw = record["raw"] as? Bool {
            newDrive.isRawImage = raw
        }
        return newDrive
    }
    
    private func updateQemuNetworks(from records: [[AnyHashable : Any]]) throws {
        let config = config as! UTMQemuConfiguration
        try updateElements(&config.networks, with: records, onExisting: updateQemuExistingNetwork, onNew: { record in
            guard var newNetwork = UTMQemuConfigurationNetwork(forArchitecture: config.system.architecture, target: config.system.target) else {
                throw ConfigurationError.deviceNotSupported
            }
            try updateQemuExistingNetwork(&newNetwork, from: record)
            return newNetwork
        })
    }
    
    private func parseQemuNetworkMode(_ value: AEKeyword?) -> QEMUNetworkMode? {
        guard let value = value, let parsed = UTMScriptingQemuNetworkMode(rawValue: value) else {
            return Optional.none
        }
        switch parsed {
        case .emulated: return .emulated
        case .shared: return .shared
        case .host: return .host
        case .bridged: return .bridged
        default: return .none
        }
    }
    
    private func updateQemuExistingNetwork(_ network: inout UTMQemuConfigurationNetwork, from record: [AnyHashable : Any]) throws {
        let config = config as! UTMQemuConfiguration
        if let hardware = record["hardware"] as? String, let hardware = config.system.architecture.networkDeviceType.init(rawValue: hardware) {
            network.hardware = hardware
        }
        if let mode = parseQemuNetworkMode(record["mode"] as? AEKeyword) {
            network.mode = mode
        }
        if let address = record["address"] as? String, !address.isEmpty {
            network.macAddress = address
        }
        if let interface = record["hostInterface"] as? String, !interface.isEmpty {
            network.bridgeInterface = interface
        }
        if let portForwards = record["portForwards"] as? [[AnyHashable : Any]] {
            network.portForward = portForwards.map({ unserializeQemuPortForward(from: $0) })
        }
    }
    
    private func parseNetworkProtocol(_ value: AEKeyword?) -> QEMUNetworkProtocol? {
        guard let value = value, let parsed = UTMScriptingNetworkProtocol(rawValue: value) else {
            return Optional.none
        }
        switch parsed {
        case .tcp: return .tcp
        case .udp: return .udp
        default: return Optional.none
        }
    }
    
    private func unserializeQemuPortForward(from record: [AnyHashable : Any]) -> UTMQemuConfigurationPortForward {
        var forward = UTMQemuConfigurationPortForward()
        if let protoc = parseNetworkProtocol(record["protocol"] as? AEKeyword) {
            forward.protocol = protoc
        }
        if let hostAddress = record["hostAddress"] as? String, !hostAddress.isEmpty {
            forward.hostAddress = hostAddress
        }
        if let hostPort = record["hostPort"] as? Int {
            forward.hostPort = hostPort
        }
        if let guestAddress = record["guestAddress"] as? String, !guestAddress.isEmpty {
            forward.guestAddress = guestAddress
        }
        if let guestPort = record["guestPort"] as? Int {
            forward.guestPort = guestPort
        }
        return forward
    }
    
    private func updateQemuSerials(from records: [[AnyHashable : Any]]) throws {
        let config = config as! UTMQemuConfiguration
        try updateElements(&config.serials, with: records, onExisting: updateQemuExistingSerial, onNew: { record in
            guard var newSerial = UTMQemuConfigurationSerial(forArchitecture: config.system.architecture, target: config.system.target) else {
                throw ConfigurationError.deviceNotSupported
            }
            try updateQemuExistingSerial(&newSerial, from: record)
            return newSerial
        })
    }
    
    private func parseQemuSerialInterface(_ value: AEKeyword?) -> QEMUSerialMode? {
        guard let value = value, let parsed = UTMScriptingSerialInterface(rawValue: value) else {
            return Optional.none
        }
        switch parsed {
        case .ptty: return .ptty
        case .tcp: return .tcpServer
        default: return Optional.none
        }
    }
    
    private func updateQemuExistingSerial(_ serial: inout UTMQemuConfigurationSerial, from record: [AnyHashable : Any]) throws {
        let config = config as! UTMQemuConfiguration
        if let hardware = record["hardware"] as? String, let hardware = config.system.architecture.serialDeviceType.init(rawValue: hardware) {
            serial.hardware = hardware
        }
        if let interface = parseQemuSerialInterface(record["interface"] as? AEKeyword) {
            serial.mode = interface
        }
        if let port = record["port"] as? Int {
            serial.tcpPort = port
        }
    }
    
    private func updateQemuDisplays(from records: [[AnyHashable : Any]]) throws {
        let config = config as! UTMQemuConfiguration
        try updateElements(&config.displays, with: records, onExisting: updateQemuExistingDisplay, onNew: { record in
            guard var newDisplay = UTMQemuConfigurationDisplay(forArchitecture: config.system.architecture, target: config.system.target) else {
                throw ConfigurationError.deviceNotSupported
            }
            try updateQemuExistingDisplay(&newDisplay, from: record)
            return newDisplay
        })
    }
    
    private func parseQemuScaler(_ value: AEKeyword?) -> QEMUScaler? {
        guard let value = value, let parsed = UTMScriptingQemuScaler(rawValue: value) else {
            return Optional.none
        }
        switch parsed {
        case .linear: return .linear
        case .nearest: return .nearest
        default: return Optional.none
        }
    }
    
    private func updateQemuExistingDisplay(_ display: inout UTMQemuConfigurationDisplay, from record: [AnyHashable : Any]) throws {
        let config = config as! UTMQemuConfiguration
        if let hardware = record["hardware"] as? String, let hardware = config.system.architecture.displayDeviceType.init(rawValue: hardware) {
            display.hardware = hardware
        }
        if let dynamicResolution = record["dynamicResolution"] as? Bool {
            display.isDynamicResolution = dynamicResolution
        }
        if let nativeResolution = record["nativeResolution"] as? Bool {
            display.isNativeResolution = nativeResolution
        }
        if let upscalingFilter = parseQemuScaler(record["upscalingFilter"] as? AEKeyword) {
            display.upscalingFilter = upscalingFilter
        }
        if let downscalingFilter = parseQemuScaler(record["downscalingFilter"] as? AEKeyword) {
            display.downscalingFilter = downscalingFilter
        }
    }
    
    private func updateQemuAdditionalArguments(from records: [[AnyHashable: Any]]) throws {
        let config = config as! UTMQemuConfiguration
        let additionalArguments = records.compactMap { record -> QEMUArgument? in
            guard let argumentString = record["argumentString"] as? String else { return nil }
            var argument = QEMUArgument(argumentString)
            // fileUrls are used as required resources by QEMU.
            if let fileUrls = record["fileUrls"] as? [URL] {
                argument.fileUrls = fileUrls
            }
            return argument
        }
        // Update entire additional arguments with new one.
        config.qemu.additionalArguments = additionalArguments
    }
        
    
    private func updateAppleConfiguration(from record: [AnyHashable : Any]) throws {
        let config = config as! UTMAppleConfiguration
        if let name = record["name"] as? String, !name.isEmpty {
            config.information.name = name
        }
        if let icon = record["icon"] as? String, !icon.isEmpty {
            if let url = UTMConfigurationInfo.builtinIcon(named: icon) {
                config.information.iconURL = url
            } else {
                throw ConfigurationError.iconNotFound(icon: icon)
            }
        }
        if let notes = record["notes"] as? String, !notes.isEmpty {
            config.information.notes = notes
        }
        if let memory = record["memory"] as? Int, memory != 0 {
            config.system.memorySize = memory
        }
        if let cpuCores = record["cpuCores"] as? Int {
            config.system.cpuCount = cpuCores
        }
        if let directoryShares = record["directoryShares"] as? [[AnyHashable : Any]] {
            try updateAppleDirectoryShares(from: directoryShares)
        }
        if let drives = record["drives"] as? [[AnyHashable : Any]] {
            try updateAppleDrives(from: drives)
        }
        if let networkInterfaces = record["networkInterfaces"] as? [[AnyHashable : Any]] {
            try updateAppleNetworks(from: networkInterfaces)
        }
        if let serialPorts = record["serialPorts"] as? [[AnyHashable : Any]] {
            try updateAppleSerials(from: serialPorts)
        }
        if let displays = record["displays"] as? [[AnyHashable : Any]] {
            try updateAppleDisplays(from: displays)
        }
    }
    
    private func updateAppleDirectoryShares(from records: [[AnyHashable : Any]]) throws {
        let config = config as! UTMAppleConfiguration
        try updateElements(&config.sharedDirectories, with: records, onExisting: updateAppleExistingDirectoryShare, onNew: { record in
            var newShare = UTMAppleConfigurationSharedDirectory(directoryURL: nil, isReadOnly: false)
            try updateAppleExistingDirectoryShare(&newShare, from: record)
            return newShare
        })
    }
    
    private func updateAppleExistingDirectoryShare(_ share: inout UTMAppleConfigurationSharedDirectory, from record: [AnyHashable : Any]) throws {
        if let readOnly = record["readOnly"] as? Bool {
            share.isReadOnly = readOnly
        }
    }
    
    private func updateAppleDrives(from records: [[AnyHashable : Any]]) throws {
        let config = config as! UTMAppleConfiguration
        try updateIdentifiedElements(&config.drives, with: records, onExisting: updateAppleExistingDrive, onNew: unserializeAppleNewDrive)
    }
    
    private func updateAppleExistingDrive(_ drive: inout UTMAppleConfigurationDrive, from record: [AnyHashable : Any]) throws {
        if let source = record["source"] as? URL {
            drive.imageURL = source
        }
    }
    
    private func unserializeAppleNewDrive(from record: [AnyHashable : Any]) throws -> UTMAppleConfigurationDrive {
        let removable = record["removable"] as? Bool ?? false
        var newDrive: UTMAppleConfigurationDrive
        if let size = record["guestSize"] as? Int {
            newDrive = UTMAppleConfigurationDrive(newSize: size)
        } else {
            newDrive = UTMAppleConfigurationDrive(existingURL: record["source"] as? URL, isExternal: removable)
        }
        return newDrive
    }
    
    private func updateAppleNetworks(from records: [[AnyHashable : Any]]) throws {
        let config = config as! UTMAppleConfiguration
        try updateElements(&config.networks, with: records, onExisting: updateAppleExistingNetwork, onNew: { record in
            var newNetwork = UTMAppleConfigurationNetwork()
            try updateAppleExistingNetwork(&newNetwork, from: record)
            return newNetwork
        })
    }
    
    private func parseAppleNetworkMode(_ value: AEKeyword?) -> UTMAppleConfigurationNetwork.NetworkMode? {
        guard let value = value, let parsed = UTMScriptingQemuNetworkMode(rawValue: value) else {
            return Optional.none
        }
        switch parsed {
        case .shared: return .shared
        case .bridged: return .bridged
        default: return Optional.none
        }
    }
    
    private func updateAppleExistingNetwork(_ network: inout UTMAppleConfigurationNetwork, from record: [AnyHashable : Any]) throws {
        if let mode = parseAppleNetworkMode(record["mode"] as? AEKeyword) {
            network.mode = mode
        }
        if let address = record["address"] as? String, !address.isEmpty {
            network.macAddress = address
        }
        if let interface = record["hostInterface"] as? String, !interface.isEmpty {
            network.bridgeInterface = interface
        }
    }
    
    private func updateAppleSerials(from records: [[AnyHashable : Any]]) throws {
        let config = config as! UTMAppleConfiguration
        try updateElements(&config.serials, with: records, onExisting: updateAppleExistingSerial, onNew: { record in
            var newSerial = UTMAppleConfigurationSerial()
            try updateAppleExistingSerial(&newSerial, from: record)
            return newSerial
        })
    }
    
    private func parseAppleSerialInterface(_ value: AEKeyword?) -> UTMAppleConfigurationSerial.SerialMode? {
        guard let value = value, let parsed = UTMScriptingSerialInterface(rawValue: value) else {
            return Optional.none
        }
        switch parsed {
        case .ptty: return .ptty
        default: return Optional.none
        }
    }
    
    private func updateAppleExistingSerial(_ serial: inout UTMAppleConfigurationSerial, from record: [AnyHashable : Any]) throws {
        if let interface = parseAppleSerialInterface(record["interface"] as? AEKeyword) {
            serial.mode = interface
        }
    }
    
    private func updateAppleDisplays(from records: [[AnyHashable : Any]]) throws {
        let config = config as! UTMAppleConfiguration
        try updateElements(&config.displays, with: records, onExisting: updateAppleExistingDisplay, onNew: { record in
            var newDisplay = UTMAppleConfigurationDisplay()
            try updateAppleExistingDisplay(&newDisplay, from: record)
            return newDisplay
        })
    }
    
    private func updateAppleExistingDisplay(_ display: inout UTMAppleConfigurationDisplay, from record: [AnyHashable : Any]) throws {
        if let dynamicResolution = record["dynamicResolution"] as? Bool {
            display.isDynamicResolution = dynamicResolution
        }
    }
    enum ConfigurationError: Error, LocalizedError {
        case identifierNotFound(id: any Hashable)
        case invalidDriveDescription
        case indexNotFound(index: Int)
        case deviceNotSupported
        case iconNotFound(icon: String)
        
        var errorDescription: String? {
            switch self {
            case .identifierNotFound(let id): return String.localizedStringWithFormat(NSLocalizedString("Identifier '%@' cannot be found.", comment: "UTMScriptingConfigImpl"), String(describing: id))
            case .invalidDriveDescription: return NSLocalizedString("Drive description is invalid.", comment: "UTMScriptingConfigImpl")
            case .indexNotFound(let index): return String.localizedStringWithFormat(NSLocalizedString("Index %lld cannot be found.", comment: "UTMScriptingConfigImpl"), index)
            case .deviceNotSupported: return NSLocalizedString("This device is not supported by the target.", comment: "UTMScriptingConfigImpl")
            case .iconNotFound(let icon): return String.localizedStringWithFormat(NSLocalizedString("The icon named '%@' cannot be found in the built-in icons.", comment: "UTMScriptingConfigImpl"), icon)
            }
        }
    }
}
