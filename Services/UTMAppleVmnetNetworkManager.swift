//
// Copyright © 2026 osy. All rights reserved.
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
final class UTMAppleVmnetNetworkManager {
    static let shared = UTMAppleVmnetNetworkManager()

    /// Operating mode of a managed network.
    enum Mode {
        /// Guests share a network and reach the outside world through the host (NAT).
        case shared
        /// Guests share a network that only the host can reach.
        case host

        fileprivate var operatingMode: vmnet_mode_t {
            switch self {
            case .shared: return .VMNET_SHARED_MODE
            case .host: return .VMNET_HOST_MODE
            }
        }
    }

    private struct Entry {
        weak var attachment: VZVmnetNetworkDeviceAttachment?
    }

    private let lock = NSLock()
    private var entries: [Mode: Entry] = [:]

    private init() {
    }

    /// Mode of a network managed here, or nil for any other network.
    func mode(of network: vmnet_network_ref) -> Mode? {
        lock.lock()
        defer { lock.unlock() }
        return entries.first(where: { $0.value.attachment?.network == network })?.key
    }

    /// Returns an owning attachment, sharing the network with any existing users of `mode`.
    ///
    /// The weak reference is promoted while locked, so a concurrent teardown cannot invalidate
    /// the returned attachment. No explicit release or virtual machine state bookkeeping is needed.
    func attachment(for mode: Mode) throws -> VZVmnetNetworkDeviceAttachment {
        lock.lock()
        defer { lock.unlock() }
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

    private func createNetwork(mode: Mode) throws -> vmnet_network_ref {
        var status = vmnet_return_t.VMNET_SUCCESS
        guard let configuration = vmnet_network_configuration_create(mode.operatingMode, &status) else {
            throw UTMAppleVmnetNetworkError.creationFailed(status)
        }
        defer {
            Unmanaged<CFTypeRef>.fromOpaque(UnsafeRawPointer(configuration)).release()
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
            return String.localizedStringWithFormat(NSLocalizedString("Failed to create the virtual network (vmnet error %d).", comment: "UTMAppleVmnetNetworkManager"), status.rawValue)
        }
    }
}
