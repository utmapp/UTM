# IOServiceAuthorize Usage Notes

## Local References
- `JailbreakInterposer/JailbreakInterposer.c:35` hooks `IOServiceAuthorize` so the interposer can call `_IOServiceSetAuthorizationID` directly on iOS. This bypasses the missing `IOServiceAuthorizeAgent` XPC endpoint and requires the `com.apple.private.iokit.IOServiceSetAuthorizationID` entitlement to succeed at runtime.

## Upstream Discussions
- [utmapp/UTM#6672](https://github.com/utmapp/UTM/issues/6672) (open, updated 2025-06-21) — iPad Pro M2 users report USB passthrough failures with `libusb` emitting `IOServiceAuthorize: unknown error (0xe00002c7)` and the VM unable to claim interfaces.
- [utmapp/UTM#6666](https://github.com/utmapp/UTM/issues/6666) (closed 2024-09-13) — duplicate of #6672 capturing the same `IOServiceAuthorize` error path when attaching USB devices on iPadOS 16.6.1.
- [utmapp/UTM#6036](https://github.com/utmapp/UTM/issues/6036) (closed 2024-02-26) — iOS build failure because the SDK marks `IOServiceAuthorize` unavailable. This surfaces when compiling `JailbreakInterposer.c`.
- [utmapp/UTM#5718](https://github.com/utmapp/UTM/issues/5718) (closed 2023-09-19) — earlier report of the same compilation error triggered by the `IOServiceAuthorize` reference during iOS builds.

No open upstream pull requests mention `IOServiceAuthorize` as of 2025-06-22.

## Notes & Follow-Up Ideas
- Ensure the entitlement documented above is present for jailbreak-focused distributions; without it, the runtime call will continue to fail with `kIOReturnNotPrivileged` style errors such as `0xe00002c7`.
- Building against newer iOS SDKs continues to flag `IOServiceAuthorize` as unavailable. Keeping the interposer restricted to non-simulator targets (current setup) avoids compile errors, but additional guards or conditional compilation may be needed if the file is ever shared with simulator builds.
- USB passthrough issues reported in #6672/#6666 may indicate the entitlement is missing on TrollStore deployments or that iPadOS kernel changes broke the `_IOServiceSetAuthorizationID` path. Reproducing on current firmware and confirming entitlement presence should be prioritized before considering code changes.
