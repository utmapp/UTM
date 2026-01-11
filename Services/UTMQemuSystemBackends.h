//
// Copyright © 2024 osy. All rights reserved.
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

#ifndef UTMQemuSystemBackends_h
#define UTMQemuSystemBackends_h

/// Specify the backend renderer for this VM
typedef NS_ENUM(NSInteger, UTMQEMURendererBackend) {
    kQEMURendererBackendDefault = 0,
    kQEMURendererBackendAngleGL = 1,
    kQEMURendererBackendAngleMetal = 2,
    kQEMURendererBackendCGL = 3,
    kQEMURendererBackendMax = 4,
};

/// Specify the sound backend for this VM
typedef NS_ENUM(NSInteger, UTMQEMUSoundBackend) {
    kQEMUSoundBackendDefault = 0,
    kQEMUSoundBackendSPICE = 1,
    kQEMUSoundBackendCoreAudio = 2,
    kQEMUSoundBackendMax = 3,
};

/// Specify the Vulkan driver for this VM
typedef NS_ENUM(NSInteger, UTMQEMUVulkanDriver) {
    kQEMUVulkanDriverDefault = 0,
    kQEMUVulkanDriverDisabled = 1,
    kQEMUVulkanDriverMoltenVK = 2,
    kQEMUVulkanDriverKosmicKrisp = 3,
};

#endif /* UTMQemuSystemBackends_h */
