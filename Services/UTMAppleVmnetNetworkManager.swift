//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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
import vmnet

/// Manages the vmnet networks used by Apple Virtualization guests.
///
/// Configurations and runtime devices retain their attachments, which own the native networks.
/// Keeping a weak attachment per mode lets guests share a network for its actual lifetime,
/// including when a failed operation leaves a virtual machine alive after UTM reports it stopped.
@available(macOS 26, *)
@MainActor final class UTMAppleVmnetNetworkManager {
    static let shared = UTMAppleVmnetNetworkManager()

    private struct Entry {
        weak var attachment: VZVmnetNetworkDeviceAttachment?
    }

    private var entries: [vmnet_mode_t: Entry] = [:]

    private init() {
    }

    /// Returns an owning attachment, sharing the network with any existing users of `mode`.
    func attachment(for mode: vmnet_mode_t) throws -> VZVmnetNetworkDeviceAttachment {
        if let attachment = entries[mode]?.attachment {
            return attachment
        }
        let network = try createNetwork(mode: mode)
        defer {
            Unmanaged<CFTypeRef>.fromOpaque(UnsafeRawPointer(network)).release()
        }
        let attachment = VZVmnetNetworkDeviceAttachment(network: network)
        entries[mode] = Entry(attachment: attachment)
        return attachment
    }

    /// Subnet to request for a mode.
    ///
    /// Left alone, vmnet hands out the lowest free subnet from the ranges that NAT attachments and
    /// QEMU also draw from, so addresses would depend on what else is running when the network is
    /// (re)created. A subnet outside of those ranges keeps guest addresses stable.
    private func preferredSubnet(for mode: vmnet_mode_t) -> in_addr? {
        switch mode {
        case .VMNET_SHARED_MODE: return in_addr(s_addr: inet_addr("192.168.96.1"))
        case .VMNET_HOST_MODE: return in_addr(s_addr: inet_addr("192.168.160.1"))
        default: return nil
        }
    }

    private func createNetwork(mode: vmnet_mode_t) throws -> vmnet_network_ref {
        if let subnet = preferredSubnet(for: mode) {
            do {
                return try createNetwork(mode: mode, subnet: subnet)
            } catch {
                // the subnet is taken by something else, let vmnet pick a free one
                logger.debug("vmnet subnet \(String(cString: inet_ntoa(subnet))) unavailable: \(error.localizedDescription)")
            }
        }
        return try createNetwork(mode: mode, subnet: nil)
    }

    private func createNetwork(mode: vmnet_mode_t, subnet: in_addr?) throws -> vmnet_network_ref {
        var status = vmnet_return_t.VMNET_SUCCESS
        guard let configuration = vmnet_network_configuration_create(mode, &status) else {
            throw UTMAppleVmnetNetworkError.creationFailed(status)
        }
        defer {
            Unmanaged<CFTypeRef>.fromOpaque(UnsafeRawPointer(configuration)).release()
        }
        if var subnet = subnet {
            var mask = in_addr(s_addr: inet_addr("255.255.255.0"))
            status = vmnet_network_configuration_set_ipv4_subnet(configuration, &subnet, &mask)
            guard status == .VMNET_SUCCESS else {
                throw UTMAppleVmnetNetworkError.creationFailed(status)
            }
        }
        guard let network = vmnet_network_create(configuration, &status) else {
            throw UTMAppleVmnetNetworkError.creationFailed(status)
        }
        return network
    }
}

enum UTMAppleVmnetNetworkError: Error {
    case creationFailed(vmnet_return_t)
}

extension UTMAppleVmnetNetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .creationFailed(let status):
            return String.localizedStringWithFormat(NSLocalizedString("Failed to create the virtual network (vmnet error %@).", comment: "UTMAppleVmnetNetworkManager"), String(status.rawValue))
        }
    }
}
