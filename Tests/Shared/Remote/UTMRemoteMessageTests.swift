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

#if WITH_SERVER
import XCTest
@testable import UTM

/// The messages exchanged between UTM Remote and the server survive the binary
/// encoding both sides use. The Codable messages resolve to the synchronous
/// encode and decode overloads; the protocol itself lives in SwiftConnect.
///
/// The server side exists only in the macOS app, so the iOS bundle leaves this out.
final class UTMRemoteMessageTests: XCTestCase {
    func testServerHandshakeRoundTrips() throws {
        let request = UTMRemoteMessageServer.ServerHandshake.Request(version: 1, password: "secret")
        let decodedRequest = try UTMRemoteMessageServer.ServerHandshake.Request.decode(try request.encode())
        XCTAssertEqual(decodedRequest.version, 1)
        XCTAssertEqual(decodedRequest.password, "secret")

        let reply = UTMRemoteMessageServer.ServerHandshake.Reply(version: 1, isAuthenticated: true, capabilities: [.isAarch64, .hasHypervisorSupport], model: "Mac14,6")
        let decodedReply = try UTMRemoteMessageServer.ServerHandshake.Reply.decode(try reply.encode())
        XCTAssertTrue(decodedReply.isAuthenticated)
        XCTAssertEqual(decodedReply.capabilities, [.isAarch64, .hasHypervisorSupport])
        XCTAssertEqual(decodedReply.model, "Mac14,6")
    }

    func testOptionalPasswordRoundTripsAsNil() throws {
        let request = UTMRemoteMessageServer.ServerHandshake.Request(version: 2, password: nil)
        let decoded = try UTMRemoteMessageServer.ServerHandshake.Request.decode(try request.encode())
        XCTAssertNil(decoded.password)
    }

    func testVirtualMachineInformationRoundTrips() throws {
        let id = UUID()
        let info = UTMRemoteMessageServer.VirtualMachineInformation(id: id, name: "VM", path: "/VMs/VM.utm", isShortcut: true, isSuspended: false, isTakeoverAllowed: true, backend: .qemu, state: .paused, mountedDrives: ["drive0": "disc.iso"])
        let reply = UTMRemoteMessageServer.GetVirtualMachineInformation.Reply(informations: [info])
        let decoded = try UTMRemoteMessageServer.GetVirtualMachineInformation.Reply.decode(try reply.encode())
        let result = try XCTUnwrap(decoded.informations.first)
        XCTAssertEqual(result.id, id)
        XCTAssertEqual(result.name, "VM")
        XCTAssertEqual(result.backend, .qemu)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.mountedDrives, ["drive0": "disc.iso"])
        XCTAssertTrue(result.isShortcut && result.isTakeoverAllowed && !result.isSuspended)
    }

    func testEmptyMessagesRoundTrip() throws {
        _ = try UTMRemoteMessageServer.ListVirtualMachines.Request.decode(try UTMRemoteMessageServer.ListVirtualMachines.Request().encode())
        let reply = UTMRemoteMessageServer.ListVirtualMachines.Reply(ids: [UUID(), UUID()])
        let decoded = try UTMRemoteMessageServer.ListVirtualMachines.Reply.decode(try reply.encode())
        XCTAssertEqual(decoded.ids, reply.ids)
    }

    /// A whole QEMU configuration travels inside a reply, decoded without a bundle on disk.
    @MainActor func testQemuConfigurationRoundTrips() throws {
        let config = UTMQemuConfiguration()
        config.information.name = "Remote"
        config.system.architecture = .aarch64
        config.system.target = QEMUTarget_aarch64.virt
        config.reset(forArchitecture: .aarch64, target: QEMUTarget_aarch64.virt)
        config.system.memorySize = 2048
        var drive = UTMQemuConfigurationDrive(forArchitecture: .aarch64, target: QEMUTarget_aarch64.virt)
        drive.sizeMib = 1024
        config.drives = [drive]
        let reply = UTMRemoteMessageServer.GetQEMUConfiguration.Reply(configuration: config)
        let decoded = try UTMRemoteMessageServer.GetQEMUConfiguration.Reply.decode(try reply.encode())
        XCTAssertEqual(decoded.configuration.information.name, "Remote")
        XCTAssertEqual(decoded.configuration.system.memorySize, 2048)
        XCTAssertEqual(decoded.configuration.drives.count, 1)
        XCTAssertEqual(decoded.configuration.drives.first?.id, drive.id)
    }
}
#endif
