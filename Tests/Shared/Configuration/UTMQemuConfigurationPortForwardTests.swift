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

import XCTest
@testable import UTM

/// Port forwards were written with camel-case keys before UTM 4.4 by mistake and
/// with capitalized keys after (bb619889); both must decode and only the
/// capitalized form is written.
final class UTMQemuConfigurationPortForwardTests: XCTestCase {
    private func decode(_ plist: String) throws -> UTMQemuConfigurationPortForward {
        try PropertyListDecoder().decode(UTMQemuConfigurationPortForward.self, from: Data(plist.utf8))
    }

    private let capitalized = """
    <plist version="1.0"><dict>
    <key>Protocol</key><string>UDP</string>
    <key>HostAddress</key><string>127.0.0.1</string>
    <key>HostPort</key><integer>2222</integer>
    <key>GuestAddress</key><string>10.0.2.15</string>
    <key>GuestPort</key><integer>22</integer>
    </dict></plist>
    """

    private let camelCase = """
    <plist version="1.0"><dict>
    <key>protocol</key><string>UDP</string>
    <key>hostAddress</key><string>127.0.0.1</string>
    <key>hostPort</key><integer>2222</integer>
    <key>guestAddress</key><string>10.0.2.15</string>
    <key>guestPort</key><integer>22</integer>
    </dict></plist>
    """

    func testDecodesCapitalizedKeys() throws {
        let forward = try decode(capitalized)
        XCTAssertEqual(forward.protocol, .udp)
        XCTAssertEqual(forward.hostAddress, "127.0.0.1")
        XCTAssertEqual(forward.hostPort, 2222)
        XCTAssertEqual(forward.guestAddress, "10.0.2.15")
        XCTAssertEqual(forward.guestPort, 22)
    }

    func testDecodesLegacyCamelCaseKeys() throws {
        let forward = try decode(camelCase)
        XCTAssertEqual(forward.protocol, .udp)
        XCTAssertEqual(forward.hostPort, 2222)
        XCTAssertEqual(forward.guestPort, 22)
    }

    func testEncodesCapitalizedKeysOnly_bb619889() throws {
        let forward = try decode(camelCase)
        let data = try PropertyListEncoder().encode(forward)
        let dict = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(Set(dict.keys), ["Protocol", "HostAddress", "HostPort", "GuestAddress", "GuestPort"])
        let again = try PropertyListDecoder().decode(UTMQemuConfigurationPortForward.self, from: data)
        XCTAssertEqual(again.hostPort, forward.hostPort)
        XCTAssertEqual(again.guestAddress, forward.guestAddress)
    }

    func testMissingPortIsAnError() {
        XCTAssertThrowsError(try decode("<plist version=\"1.0\"><dict><key>Protocol</key><string>TCP</string></dict></plist>"))
    }
}
