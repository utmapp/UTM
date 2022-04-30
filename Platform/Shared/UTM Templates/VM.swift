//
//  VM.swift
//  UTM Templates
//
//  Created by Christopher Mattar on 4/29/22.
//

import Foundation
import SwiftUI

func humanReadableByteCount(bytes: Int) -> String {
    if (bytes < 1000) { return "\(bytes) B" }
    let exp = Int(log2(Double(bytes)) / log2(1000.0))
    let unit = ["KB", "MB", "GB", "TB", "PB", "EB"][exp - 1]
    let number = Double(bytes) / pow(1000, Double(exp))
    return String(format: "%.1f %@", number, unit)
}

struct VMAttribute: Identifiable {
    let key: String
    let value: String
    let id = UUID()
}

struct VirtualMachine: Identifiable {
    var id: UUID
    
    var title: String
    var link: String
    var attributes: [VMAttribute] = []
    var instructions: String = ""
    var image: String = ""
    var verified: Bool? = nil
    
    init(title: String, link: String, attributes: [VMAttribute] = [], instructions: String = "", image: String = "", verified: Bool? = nil) {
        self.id = UUID()
        self.title = title
        self.link = link
        self.attributes = attributes
        self.instructions = instructions
        self.image = image
        self.verified = verified
        calc_vm_size()
    }
    
    mutating func calc_vm_size() {
        if let url = URL(string: link) {
            if let data = try? Data(contentsOf: url) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any] {
                    if let size = json["size"] as? Int {
                        attributes.append(VMAttribute(key: "Compressed Size", value: humanReadableByteCount(bytes: size)))
                    }
                }
            }
        }
    }
    
    func showSearch(search: String) -> Bool {
        return title.lowercased().contains(search.lowercased()) || search.lowercased().contains(title.lowercased()) || search == ""
    }
}

let officialVirtualMachines: [VirtualMachine] = [
    VirtualMachine(
        title: "ArchLinux ARM",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdnAweWJlY2FQNTQ0c3VreXc_ZT1SbWNleHU/root",
        attributes: [VMAttribute(key: "Memory", value: "2GB"),
                     VMAttribute(key: "Disk", value: "10GB"),
                     VMAttribute(key: "Username", value: "root"),
                     VMAttribute(key: "Password", value: "root"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Not Installed")],
        instructions: "", image: "arch-linux"),
    VirtualMachine(
        title: "Debian ARM 10.4 i3",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdnAzekxSUkZkSHpIaGowNUE_ZT1aaWlMa2E/root",
        attributes: [VMAttribute(key: "Memory", value: "1GB"),
                     VMAttribute(key: "Disk", value: "10GB"),
                     VMAttribute(key: "Username", value: "debian"),
                     VMAttribute(key: "Password", value: "debian"),
                     VMAttribute(key: "Root Username", value: "root"),
                     VMAttribute(key: "Root Password", value: "password"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Installed")],
        instructions: "", image: "debian"),
    VirtualMachine(
        title: "Debian ARM 10.4 LDXE",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdnA1Z3d1eFhhSS1TdWJJeFE_ZT0xS1JpN0g/root",
        attributes: [VMAttribute(key: "Memory", value: "1GB"),
                     VMAttribute(key: "Disk", value: "10GB"),
                     VMAttribute(key: "Username", value: "debian"),
                     VMAttribute(key: "Password", value: "debian"),
                     VMAttribute(key: "Root Username", value: "root"),
                     VMAttribute(key: "Root Password", value: "password"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Installed")],
        instructions: "", image: "debian"),
    VirtualMachine(
        title: "Debian ARM 10.4 XFCE",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdnA2dTdFZVBkRS1IN2N6akE_ZT1KRExWdzQ/root",
        attributes: [VMAttribute(key: "Memory", value: "1GB"),
                     VMAttribute(key: "Disk", value: "10GB"),
                     VMAttribute(key: "Username", value: "debian"),
                     VMAttribute(key: "Password", value: "debian"),
                     VMAttribute(key: "Root Username", value: "root"),
                     VMAttribute(key: "Root Password", value: "password"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Not Installed")],
        instructions: "", image: "debian"),
    VirtualMachine(
        title: "macOS 9.2.1",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdnAxVHAzTlNGSHJIMGZMd3c_ZT1NTlR4ejY/root",
        attributes: [VMAttribute(key: "Memory", value: "512MB"),
                     VMAttribute(key: "Disk", value: "20GB"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Not Installed")],
        instructions: "", image: "mac"),
    VirtualMachine(
        title: "ReactOS 0.4.14",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdnAyenM5NEY2TXZGU3hITHc_ZT1lSGlsS1c/root",
        attributes: [VMAttribute(key: "Memory", value: "512MB"),
                     VMAttribute(key: "Disk", value: "10GB"),
                     VMAttribute(key: "Root Username", value: "Administrator"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Not Installed")],
        instructions: "", image: "linux"),
    VirtualMachine(
        title: "Sun Solaris 9",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdnA0SzFZclphYzFydWpGOVE_ZT1sU21wdkY/root",
        attributes: [VMAttribute(key: "Memory", value: "256MB"),
                     VMAttribute(key: "Disk", value: "8GB"),
                     VMAttribute(key: "Root Username", value: "root"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Not Installed")],
        instructions: "", image: "solaris"),
    VirtualMachine(
        title: "Ubuntu 14.04",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdnA3TF9INS1md0ZLb0JXc1E_ZT02SGxKRXQ/root",
        attributes: [VMAttribute(key: "Memory", value: "512MB"),
                     VMAttribute(key: "Disk", value: "10GB"),
                     VMAttribute(key: "Username", value: "ubuntu"),
                     VMAttribute(key: "Password", value: "ubuntu"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Installed")],
        instructions: "", image: "ubuntu"),
    VirtualMachine(
        title: "Windows 7",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdnB5S055OF9zYm1qRG1UVlE_ZT1UbDdncnM/root",
        attributes: [VMAttribute(key: "Memory", value: "1GB"),
                     VMAttribute(key: "Disk", value: "20GB"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Installed")],
        instructions: "This Virtual Machine needs a Windows 7 installation ISO. A good working image is [en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso](https://archive.org/download/en_windows_7_ultimate_with_sp1_x64_dvd_u_677332_202006/en_windows_7_ultimate_with_sp1_x64_dvd_u_677332.iso) with the SHA1 hash of *36ae90defbad9d9539e649b193ae573b77a71c83*.\nAfter you have downloaded the ISO, select the ISO as the startup disk. Start the VM and go through the installation process. When you are done, download the [SPICE tools ISO](https://github.com/utmapp/qemu/releases/download/v6.2.0-utm/spice-guest-tools-0.164.3.iso). Eject the Windows installation ISO and select the SPICE tools ISO. Run through the installer in the *(D:) QEMU* drive.", image: "windows-9x"),
    VirtualMachine(
        title: "Windows XP",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdnB6ZkZEVVFHUXZOd3ZFZWc_ZT1HUU1CZjE/root",
        attributes: [VMAttribute(key: "Memory", value: "512MB"),
                     VMAttribute(key: "Disk", value: "20GB"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Installed")],
        instructions: "This Virtual Machine needs a Windows XP installation ISO. A good working image is [en_windows_xp_professional_sp3_Nov_2013_Incl_SATA_Drivers.iso](https://archive.org/download/WIndows-XP-Professional-SP3/en_windows_xp_professional_sp3_Nov_2013_Incl_SATA_Drivers.iso) with the SHA1 hash of *6947e45f7eb50c873043af4713aa7cd43027efa7*.\nAfter you have downloaded the ISO, select the ISO as the startup disk. Start the VM and go through the installation process. When you are done, download the [SPICE tools ISO](https://github.com/utmapp/qemu/releases/download/v6.2.0-utm/spice-guest-tools-0.164.3.iso). Eject the Windows installation ISO and select the SPICE tools ISO. Run through the installer in the *(D:) QEMU* drive.", image: "windows-xp"),
]


let originalVirtualMachines: [VirtualMachine] = [
    VirtualMachine(
        title: "Windows 10",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdElidHBEQV8tVmk4NlJhTmc_ZT1nZFFiUlo/root",
        attributes: [VMAttribute(key: "Memory", value: "8GB"),
                     VMAttribute(key: "Disk", value: "64GB"),
                     VMAttribute(key: "Password", value: "windows"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Installed")],
        instructions: "", image: "windows"),
    VirtualMachine(
        title: "Windows 11",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdEljZVR2RTN0WTB2eUdVWFE_ZT1MOGFmMEk/root",
        attributes: [VMAttribute(key: "Memory", value: "8GB"),
                     VMAttribute(key: "Disk", value: "64GB"),
                     VMAttribute(key: "Password", value: "windows"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Installed")],
        instructions: "", image: "windows-11"),
    VirtualMachine(
        title: "macOS 12",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdElmU29IeXczbmRKZEFGQlE_ZT0xNmFia1c/root",
        attributes: [VMAttribute(key: "Memory", value: "8GB"),
                     VMAttribute(key: "Disk", value: "64GB"),
                     VMAttribute(key: "Password", value: "macos"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Not Installed")],
        instructions: "", image: "mac"),
    VirtualMachine(
        title: "Ubuntu Linux",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdElkTmhWQ0ZmZzV3aFpiSVE_ZT1NVGdXUlA/root",
        attributes: [VMAttribute(key: "Memory", value: "8GB"),
                     VMAttribute(key: "Disk", value: "64GB"),
                     VMAttribute(key: "Username", value: "ubuntu"),
                     VMAttribute(key: "Password", value: "ubuntu"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Installed")],
        instructions: "", image: "ubuntu"),
    VirtualMachine(
        title: "Fedora Linux",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdEllVmM0NUFHSkdRdkZKTnc_ZT10cmZEOVk/root",
        attributes: [VMAttribute(key: "Memory", value: "8GB"),
                     VMAttribute(key: "Disk", value: "64GB"),
                     VMAttribute(key: "Username", value: "fedora"),
                     VMAttribute(key: "Password", value: "fedora"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Installed")],
        instructions: "", image: "fedora"),
    VirtualMachine(
        title: "OpenSUSE Linux",
        link: "https://api.onedrive.com/v1.0/shares/u!aHR0cHM6Ly8xZHJ2Lm1zL3UvcyFBbzNpSVRXZV9FWmdwdEloZUxCUlV6d09ZdTRJbnc_ZT1Ea3hORG0/root",
        attributes: [VMAttribute(key: "Memory", value: "8GB"),
                     VMAttribute(key: "Disk", value: "64GB"),
                     VMAttribute(key: "Username", value: "opensuse"),
                     VMAttribute(key: "Password", value: "opensuse"),
                     VMAttribute(key: "SPICE Guest Tools", value: "Installed")],
        instructions: "", image: "suse"),
]


var communityUploadedVirtualMachines: [VirtualMachine] = [
    VirtualMachine(
        title: "Windows 9",
        link: "",
        attributes: [],
        instructions: "This is a dummy VM. It doesn't actually work.",
        image: "windows",
        verified: true),
    VirtualMachine(
        title: "Windows 9X",
        link: "",
        attributes: [],
        instructions: "This is a dummy VM. It doesn't actually work.",
        image: "windows",
        verified: false)
]

var verifiedCommunityUploadedVirtualMachines: [VirtualMachine] {
    return communityUploadedVirtualMachines.filter { $0.verified != false }
}

var unverifiedCommunityUploadedVirtualMachines: [VirtualMachine] {
    return communityUploadedVirtualMachines.filter { $0.verified == false }
}
