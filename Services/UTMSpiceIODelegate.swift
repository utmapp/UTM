//
// Copyright © 2023 osy. All rights reserved.
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
#if WITH_QEMU_TCI
import CocoaSpiceNoUsb
#else
import CocoaSpice
#endif

@objc protocol UTMSpiceIODelegate {
    func spiceDidCreateInput(_ input: CSInput)
    func spiceDidDestroyInput(_ input: CSInput)
    func spiceDidCreateDisplay(_ display: CSDisplay)
    func spiceDidDestroyDisplay(_ display: CSDisplay)
    func spiceDidUpdateDisplay(_ display: CSDisplay)
    func spiceDidCreateSerial(_ serial: CSPort)
    func spiceDidDestroySerial(_ serial: CSPort)
    #if !WITH_QEMU_TCI
    func spiceDidChangeUsbManager(_ usbManager: CSUSBManager?)
    #endif
    @objc optional func spiceDynamicResolutionSupportDidChange(_ supported: Bool)
}
