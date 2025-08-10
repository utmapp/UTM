//
// Copyright © 2025 osy. All rights reserved.
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
import CocoaSpice

final class UTMUSBManager {
    struct USBDevice: Codable, Hashable {
        var usbVendorId: Int
        var usbProductId: Int
        var usbManufacturerName: String?
        var usbProductName: String?
        var usbSerial: String?

        fileprivate init(_ device: CSUSBDevice) {
            usbVendorId = device.usbVendorId
            usbProductId = device.usbProductId
            usbManufacturerName = device.usbManufacturerName
            usbProductName = device.usbProductName
            usbSerial = device.usbSerial
        }
    }

    static let shared = UTMUSBManager()
    @Setting("SavedUsbDevices") private var savedUsbDevices: Data? = nil
    lazy var usbDevices: [USBDevice: UUID] = loadUsbDevices() {
        didSet {
            saveUsbDevices(usbDevices)
        }
    }

    private init() {}

    private func loadUsbDevices() -> [USBDevice: UUID] {
        let decoder = PropertyListDecoder()
        if let data = savedUsbDevices {
            if let decoded = try? decoder.decode([USBDevice: UUID].self, from: data) {
                return decoded
            }
        }
        // default entry
        return [:]
    }

    private func saveUsbDevices(_ usbDevices: [USBDevice: UUID]) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        if let data = try? encoder.encode(usbDevices) {
            savedUsbDevices = data
        }
    }
}

extension UTMVirtualMachine {
    func isAutoConnect(for device: CSUSBDevice) -> Bool {
        let usbDevice = UTMUSBManager.USBDevice(device)
        return UTMUSBManager.shared.usbDevices[usbDevice] == self.id
    }

    func setAutoConnect(_ autoConnect: Bool, for device: CSUSBDevice) {
        let usbDevice = UTMUSBManager.USBDevice(device)
        if autoConnect {
            UTMUSBManager.shared.usbDevices[usbDevice] = self.id
        } else {
            UTMUSBManager.shared.usbDevices.removeValue(forKey: usbDevice)
        }
    }
}
