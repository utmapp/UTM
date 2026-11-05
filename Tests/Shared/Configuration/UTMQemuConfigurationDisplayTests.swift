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

/// The rules behind the display settings.
final class UTMQemuConfigurationDisplayTests: XCTestCase {
    private func display(_ hardware: QEMUDisplayDevice_x86_64) -> UTMQemuConfigurationDisplay {
        var display = UTMQemuConfigurationDisplay()
        display.hardware = hardware
        return display
    }

    func testOnlyGlCardsSupportGpuAcceleration() {
        for hardware in [QEMUDisplayDevice_x86_64.virtio_vga_gl, .virtio_gpu_gl_pci, .virtio_gpu_gl_device, .virtio_ramfb_gl] {
            XCTAssertTrue(display(hardware).isGLSupported, "\(hardware)")
        }
        for hardware in [QEMUDisplayDevice_x86_64.virtio_vga, .virtio_gpu_pci, .virtio_ramfb, .qxl_vga, .VGA, .ramfb, .bochs_display] {
            XCTAssertFalse(display(hardware).isGLSupported, "\(hardware)")
        }
    }

    func testOnlyVgaCompatibleCardsHaveAVideoMemorySetting() {
        for hardware in [QEMUDisplayDevice_x86_64.VGA, .cirrus_vga, .isa_vga, .qxl_vga, .ati_vga, .secondary_vga, .virtio_vga, .virtio_vga_gl, .vmware_svga] {
            XCTAssertTrue(display(hardware).hasVgaRamSetting, "\(hardware)")
        }
        for hardware in [QEMUDisplayDevice_x86_64.qxl, .ramfb, .bochs_display, .virtio_gpu_pci, .virtio_gpu_gl_pci, .virtio_ramfb] {
            XCTAssertFalse(display(hardware).hasVgaRamSetting, "\(hardware)")
        }
    }
}
