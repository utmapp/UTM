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

#if os(macOS)
import XCTest
import Virtualization
@testable import UTM

/// How the sound settings of an Apple Virtualization VM become sound devices.
final class UTMAppleConfigurationAudioTests: XCTestCase {
    /// The streams of each sound device the configuration creates, in order.
    private func soundDevices(input: Bool, output: Bool, isMacOSGuest: Bool) throws -> [[String]] {
        var virtualization = UTMAppleConfigurationVirtualization()
        virtualization.hasAudioInput = input
        virtualization.hasAudio = output
        let vzconfig = VZVirtualMachineConfiguration()
        try virtualization.fillVZConfiguration(vzconfig, isMacOSGuest: isMacOSGuest)
        return try vzconfig.audioDevices.map { device in
            try XCTUnwrap(device as? VZVirtioSoundDeviceConfiguration).streams.map { stream in
                stream is VZVirtioSoundDeviceInputStreamConfiguration ? "input" : "output"
            }
        }
    }

    /// A Linux guest's sound server only uses the first stream of a sound device: with both
    /// streams on one device it had a microphone and no output.
    func testLinuxGuestGetsADeviceForEachStream() throws {
        XCTAssertEqual(try soundDevices(input: true, output: true, isMacOSGuest: false), [["input"], ["output"]])
    }

    /// A macOS guest keeps both streams on one device, so that it has one clock to follow.
    func testMacOSGuestGetsOneDeviceForBothStreams() throws {
        XCTAssertEqual(try soundDevices(input: true, output: true, isMacOSGuest: true), [["input", "output"]])
    }

    func testOnlyTheEnabledStreamsGetADevice() throws {
        for isMacOSGuest in [false, true] {
            XCTAssertEqual(try soundDevices(input: false, output: true, isMacOSGuest: isMacOSGuest), [["output"]])
            XCTAssertEqual(try soundDevices(input: true, output: false, isMacOSGuest: isMacOSGuest), [["input"]])
            XCTAssertEqual(try soundDevices(input: false, output: false, isMacOSGuest: isMacOSGuest), [])
        }
    }
}
#endif
