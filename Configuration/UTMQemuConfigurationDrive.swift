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

/// Settings for single QEMU disk device
@available(iOS 13, macOS 11, *)
struct UTMQemuConfigurationDrive: UTMConfigurationDrive {
    /// If not removable, this is the name of the file in the bundle.
    var imageName: String?
    
    /// Size of the image when creating a new image (in MiB). Not saved.
    var sizeMib: Int = 0
    
    /// If true, the drive image will be mounted as read-only.
    var isReadOnly: Bool = false
    
    /// If true, the drive image will not be copied to the bundle.
    var isRemovable: Bool = false
    
    /// If valid, will point to the actual location of the drive image. Not saved.
    var imageURL: URL?
    
    /// Unique identifier for this drive
    private(set) var id: String = ""
    
    /// Type of the image.
    var imageType: QEMUDriveImageType = .none
    
    /// Interface of the image (only valid when type is CD/Disk).
    var interface: QEMUDriveInterface = .none
    
    /// If true, the created image will be raw format and not QCOW2. Not saved.
    var isRawImage: Bool = false
    
    /// If initialized, returns a default interface for an image type. Not saved.
    var defaultInterfaceForImageType: ((QEMUDriveImageType) -> QEMUDriveInterface)?
    
    enum CodingKeys: String, CodingKey {
        case imageName = "ImageName"
        case isRemovable = "Removable"
        case imageType = "ImageType"
        case interface = "Interface"
        case identifier = "Identifier"
    }
    
    init() {
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        imageName = try values.decodeIfPresent(String.self, forKey: .imageName)
        isRemovable = try values.decode(Bool.self, forKey: .isRemovable)
        if !isRemovable, let imageName = imageName, let dataURL = decoder.userInfo[.dataURL] as? URL {
            imageURL = dataURL.appendingPathComponent(imageName)
        }
        imageType = try values.decode(QEMUDriveImageType.self, forKey: .imageType)
        interface = try values.decode(QEMUDriveInterface.self, forKey: .interface)
        id = try values.decode(String.self, forKey: .identifier)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !isRemovable {
            try container.encodeIfPresent(imageName, forKey: .imageName)
        }
        try container.encode(isRemovable, forKey: .isRemovable)
        try container.encode(imageType, forKey: .imageType)
        if imageType == .cd || imageType == .disk {
            try container.encode(interface, forKey: .interface)
        } else {
            try container.encode(QEMUDriveInterface.none, forKey: .interface)
        }
        try container.encode(id, forKey: .identifier)
    }
    
    func hash(into hasher: inout Hasher) {
        imageName?.hash(into: &hasher)
        sizeMib.hash(into: &hasher)
        isReadOnly.hash(into: &hasher)
        isRemovable.hash(into: &hasher)
        id.hash(into: &hasher)
        imageType.hash(into: &hasher)
        interface.hash(into: &hasher)
    }
    
    func clone() -> UTMQemuConfigurationDrive {
        var cloned = self
        cloned.id = "drive\(UUID().uuidString)"
        return cloned
    }
}

// MARK: - Default interface

@available(iOS 13, macOS 11, *)
extension UTMQemuConfigurationDrive {
    static func defaultInterface(forArchitecture architecture: QEMUArchitecture, target: QEMUTarget, imageType: QEMUDriveImageType) -> QEMUDriveInterface {
        let rawTarget = target.rawValue
        if rawTarget.hasPrefix("virt-") || rawTarget == "virt" {
            if imageType == .cd {
                return .usb
            } else {
                return .virtio
            }
        } else if architecture == .sparc || architecture == .sparc64 {
            return .scsi
        } else {
            return .ide
        }
    }
}

// MARK: - Conversion of old config format

@available(iOS 13, macOS 11, *)
extension UTMQemuConfigurationDrive {
    init(migrating oldConfig: UTMLegacyQemuConfiguration, at index: Int) {
        self.init()
        imageName = oldConfig.driveImagePath(for: index)
        imageType = convertImageType(from: oldConfig.driveImageType(for: index))
        interface = convertInterface(from: oldConfig.driveInterfaceType(for: index))
        isRemovable = oldConfig.driveRemovable(for: index)
        id = oldConfig.driveName(for: index)!
    }
    
    private func convertImageType(from type: UTMDiskImageType) -> QEMUDriveImageType {
        switch type {
        case .none:
            return .none
        case .disk:
            return .disk
        case .CD:
            return .cd
        case .BIOS:
            return .bios
        case .kernel:
            return .linuxKernel
        case .initrd:
            return .linuxInitrd
        case .DTB:
            return .linuxDtb
        case .max:
            return .none
        @unknown default:
            return .none
        }
    }
    
    private func convertInterface(from str: String?) -> QEMUDriveInterface {
        if str == "ide" {
            return .ide
        } else if str == "scsi" {
            return .scsi
        } else if str == "sd" {
            return .sd
        } else if str == "mtd" {
            return .mtd
        } else if str == "floppy" {
            return .floppy
        } else if str == "pflash" {
            return .pflash
        } else if str == "virtio" {
            return .virtio
        } else if str == "nvme" {
            return .nvme
        } else if str == "usb" {
            return .usb
        } else {
            return .none
        }
    }
}

// MARK: - New drive

@available(iOS 13, macOS 11, *)
extension UTMQemuConfigurationDrive {
    init(forArchitecture architecture: QEMUArchitecture, target: QEMUTarget, isRemovable: Bool = false) {
        self.isRemovable = isRemovable
        self.imageType = isRemovable ? .cd : .disk
        self.isRawImage = false
        self.imageName = nil
        self.sizeMib = 10240
        self.isReadOnly = false
        self.imageURL = nil
        self.id = "drive\(UUID().uuidString)"
        self.defaultInterfaceForImageType = { Self.defaultInterface(forArchitecture: architecture, target: target, imageType: $0) }
        self.interface = defaultInterfaceForImageType!(imageType)
    }
}
