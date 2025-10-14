# Agents Behaviour Design Notes

Context: Automation agents occasionally propose code for iOS and macOS
repositories. This file outlines the behavioural contract they should follow.

Objectives:
- Maintain deterministic builds by keeping Xcode project state reproducible.
- Preserve platform specific assets (icons, intents, entitlements) and confirm
  bundle identifiers remain untouched unless explicitly requested.
- Keep shared Swift modules compiling on both platforms and run unit tests when
  available.

Operational Guidance:
- Prefer editing `.xcconfig`, `.plist`, and scheme files through scripted tools
  to avoid introducing opaque Xcode state changes.
- When modifying SwiftUI or storyboard resources, provide before/after
  snapshots or GIFs to aid human review.
- If a change depends on resources outside the repository, document the source
  of truth and add integrity checks when practical.

Dependency Safety:
- Announce new package dependencies, pin versions, and update the dependency
  mirrors used by the CI pipeline.
- For binary frameworks, include hash fingerprints and storage locations so the
  build cache remains verifiable.

ParentDirectory Handling:
- Detect the absence of the `ParentDirectory` symlink during setup scripts and
  guide maintainers to recreate it with `ln -s .. ParentDirectory`.
- Avoid committing the resolved path of the symlink; it must stay a relative
  link so cloned checkouts behave the same.
