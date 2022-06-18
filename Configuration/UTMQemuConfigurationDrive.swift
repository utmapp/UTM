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

/// Settings for single disk device
@available(iOS 13, macOS 11, *)
class UTMQemuConfigurationDrive: Codable, Identifiable, ObservableObject {
    /// If not removable, this is the name of the file in the bundle.
    @Published var imageName: String?
    
    /// Size of the image when creating a new image. Not saved.
    @Published var size: Int = 10240
    
    /// Type of the image.
    @Published var imageType: QEMUDriveImageType = .none
    
    /// Interface of the image (only valid when type is CD/Disk).
    @Published var interface: QEMUDriveInterface = .none
    
    /// If true, the drive image will not be copied to the bundle.
    @Published var isRemovable: Bool = false
    
    /// If true, the created image will be raw format and not QCOW2. Not saved.
    @Published var isRawImage: Bool = false
    
    /// If valid, will point to the actual location of the drive image. Not saved.
    @Published var imageURL: URL?
    
    let id = UUID()
    
    enum CodingKeys: String, CodingKey {
        case imageName = "ImageName"
        case imageType = "ImageType"
        case interface = "Interface"
        case isRemovable = "Removable"
    }
    
    init() {
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        imageName = try values.decodeIfPresent(String.self, forKey: .imageName)
        imageType = try values.decode(QEMUDriveImageType.self, forKey: .imageType)
        interface = try values.decode(QEMUDriveInterface.self, forKey: .interface)
        isRemovable = try values.decode(Bool.self, forKey: .isRemovable)
        if !isRemovable, let imageName = imageName, let dataURL = decoder.userInfo[.dataURL] as? URL {
            imageURL = dataURL.appendingPathComponent(imageName)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !isRemovable {
            try container.encodeIfPresent(imageName, forKey: .imageName)
        }
        try container.encode(imageType, forKey: .imageType)
        if imageType == .cd || imageType == .disk {
            try container.encode(interface, forKey: .interface)
        } else {
            try container.encode(QEMUDriveInterface.none, forKey: .interface)
        }
        try container.encode(isRemovable, forKey: .isRemovable)
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
    convenience init(migrating oldConfig: UTMLegacyQemuConfiguration, at index: Int) {
        self.init()
        imageName = oldConfig.driveName(for: index)
        imageType = convertImageType(from: oldConfig.driveImageType(for: index))
        interface = convertInterface(from: oldConfig.driveInterfaceType(for: index))
        isRemovable = oldConfig.driveRemovable(for: index)
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
