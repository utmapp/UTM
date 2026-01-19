//
// Copyright © 2022 osy. All rights reserved.
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

@objc protocol VMDisplayViewControllerDelegate {
    var qemuInputLegacy: Bool { get }
    var qemuDisplayUpscaler: MTLSamplerMinMagFilter { get }
    var qemuDisplayDownscaler: MTLSamplerMinMagFilter { get }
    var qemuDisplayIsDynamicResolution: Bool { get }
    var qemuDisplayIsNativeResolution: Bool { get }
    var qemuHasClipboardSharing: Bool { get }
    var displayOrigin: CGPoint { get set }
    var displayScale: CGFloat { get set }
    var displayViewSize: CGSize { get set }
    var displayIsZoomLocked: Bool { get set }

    func displayDidAssertUserInteraction()
    func displayDidAppear()
    func display(_ display: CSDisplay, didResizeTo size: CGSize)
    func serialDidError(_ error: String)
    func requestInputTablet(_ tablet: Bool)
}
