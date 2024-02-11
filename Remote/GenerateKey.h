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

#ifndef GenerateKey_h
#define GenerateKey_h

#include <CoreFoundation/CoreFoundation.h>

/// Generate a RSA-4096 key and return a PKCS#12 encoded data
///
/// The password of the blob is `password`. Returns NULL on error.
/// - Parameters:
///   - commonName: CN field of the certificate, max length is 1024 bytes
///   - organizationName: O field of the certificate, max length is 1024 bytes
///   - serial: Serial number of the certificate
///   - days: Validity in days from today
///   - isClient: If 0 then a TLS Server certificate is generated, otherwise a TLS Client certificate is generated
_Nullable CFArrayRef GenerateRSACertificate(CFStringRef _Nonnull commonName, CFStringRef _Nonnull organizationName, CFNumberRef _Nullable serial, CFNumberRef _Nullable days, CFBooleanRef _Nonnull isClient);

#endif /* GenerateKey_h */
