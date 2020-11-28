//
// Copyright © 2020 osy. All rights reserved.
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

#ifndef UTMQcow2_h
#define UTMQcow2_h

#include <stdbool.h>
#include <CoreFoundation/CoreFoundation.h>

CF_IMPLICIT_BRIDGING_ENABLED
#pragma clang assume_nonnull begin

bool GenerateDefaultQcow2File(CFURLRef path, size_t sizeInMib);

#pragma clang assume_nonnull end
CF_IMPLICIT_BRIDGING_DISABLED

#endif /* UTMQcow2_h */
