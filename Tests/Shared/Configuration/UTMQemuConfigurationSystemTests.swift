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

import XCTest
@testable import UTM

/// The rules behind the memory and CPU entries of the system settings.
final class UTMQemuConfigurationSystemTests: XCTestCase {
    private func system(memory: Int, jit: Int = 0) -> UTMQemuConfigurationSystem {
        var system = UTMQemuConfigurationSystem()
        system.memorySize = memory
        system.jitCacheSize = jit
        return system
    }

    func testMemoryBelowTheMinimumIsCleared() {
        var system = system(memory: UTMQemuConfigurationSystem.minimumMemorySizeMib - 1)
        XCTAssertFalse(system.clampMemorySettings())
        XCTAssertEqual(system.memorySize, 0)
    }

    func testTheMinimumMemoryIsKept() {
        var system = system(memory: UTMQemuConfigurationSystem.minimumMemorySizeMib)
        XCTAssertTrue(system.clampMemorySettings())
        XCTAssertEqual(system.memorySize, UTMQemuConfigurationSystem.minimumMemorySizeMib)
    }

    func testANegativeJitCacheIsCleared() {
        var system = system(memory: 1024, jit: -1)
        XCTAssertFalse(system.clampMemorySettings())
        XCTAssertEqual(system.jitCacheSize, 0)
        XCTAssertEqual(system.memorySize, 1024)
    }

    func testBothInvalidEntriesAreClearedTogether() {
        var system = system(memory: 16, jit: -5)
        XCTAssertFalse(system.clampMemorySettings())
        XCTAssertEqual(system.memorySize, 0)
        XCTAssertEqual(system.jitCacheSize, 0)
    }

    func testValidMemorySettingsAreLeftAlone() {
        var system = system(memory: 1024, jit: 256)
        XCTAssertTrue(system.clampMemorySettings())
        XCTAssertEqual(system.memorySize, 1024)
        XCTAssertEqual(system.jitCacheSize, 256)
    }

    func testTheDefaultJitCacheIsAQuarterOfTheMemoryAndIsMirroredWithoutTheEntitlement() {
        let system = system(memory: 1024)
        XCTAssertEqual(system.effectiveJitCacheSizeMib, 256)
        XCTAssertEqual(system.estimatedMemoryUsageMib(hasJitEntitlements: true), 1024 + 256 + 128)
        XCTAssertEqual(system.estimatedMemoryUsageMib(hasJitEntitlements: false), 1024 + 512 + 128)
    }

    func testAnExplicitJitCacheSizeIsUsedAsIs() {
        let system = system(memory: 1024, jit: 100)
        XCTAssertEqual(system.effectiveJitCacheSizeMib, 100)
        XCTAssertEqual(system.estimatedMemoryUsageMib(hasJitEntitlements: true), 1024 + 100 + 128)
        XCTAssertEqual(system.estimatedMemoryUsageMib(hasJitEntitlements: false), 1024 + 200 + 128)
    }

    func testUsageWithinTheThresholdIsNotFlagged() {
        let system = system(memory: 1024)
        XCTAssertFalse(system.isMemoryOverallocated(totalDeviceMemoryMib: 2048, hasJitEntitlements: false), "1024 + 512 + 128 is under 90% of 2048")
    }

    func testUsageOverTheThresholdIsFlagged() {
        let system = system(memory: 1200)
        XCTAssertTrue(system.isMemoryOverallocated(totalDeviceMemoryMib: 2048, hasJitEntitlements: false), "1200 + 600 + 128 is over 90% of 2048")
        XCTAssertFalse(system.isMemoryOverallocated(totalDeviceMemoryMib: 2048, hasJitEntitlements: true), "1200 + 300 + 128 is under 90% of 2048")
    }

    func testAHugeEntryDoesNotTrap() {
        let system = system(memory: Int.max / 8)
        XCTAssertTrue(system.isMemoryOverallocated(totalDeviceMemoryMib: 65536, hasJitEntitlements: false))
    }

    func testANegativeCoreCountMeansTheDefault() {
        var system = UTMQemuConfigurationSystem()
        system.cpuCount = -3
        system.clampCpuCount()
        XCTAssertEqual(system.cpuCount, 0)
        system.cpuCount = 4
        system.clampCpuCount()
        XCTAssertEqual(system.cpuCount, 4)
    }
}
