# Release Guide

This document details the release procedure for UTM team members. The release procedure is mostly automated by GitHub Actions. In short, when you create a new release on the GitHub repository, the following happens:

1. If UTM dependencies are not cached from a previous run, build them for every platform (iOS, iOS TCI, iOS Simulator, visionOS, visionOS TCI, visionOS Simulator, macOS) and architecture.
2. Build UTM for every scheme (iOS, iOS SE, iOS Remote, macOS) on each platform and architecture.
3. Package the iOS and visionOS builds into fakesigned IPAs (`UTM.ipa`, `UTM-HV.ipa`, `UTM-SE.ipa`, `UTM-Remote.ipa`, and the `-visionOS` variants) and a jailbreak DEB (`UTM.deb`) and post them as release assets.
4. Dispatch updates to the AltStore and Cydia repositories.
5. Combine dependencies for macOS-arm64 and macOS-x86_64 into universal binaries and build UTM as a macOS universal binary.
6. Sign, package, and notarize the universal build into a DMG and post it as a release asset.
7. Sign and package the universal build for the Mac App Store and submit it to App Store Connect.
8. Sign UTM SE and UTM Remote (iOS and visionOS) and submit them to App Store Connect.

For more details see the [build.yml](../.github/workflows/build.yml) file.

## Making a release

Agents can do all of this with the `/utm-release` skill ([`.agents/skills/utm-release/SKILL.md`](../.agents/skills/utm-release/SKILL.md)), which drafts the release notes and asks for approval before publishing. To do it by hand:

1. Modify [Build.xcconfig](../Build.xcconfig) and bump `MARKETING_VERSION` following [semantic versioning][5] and `CURRENT_PROJECT_VERSION` by 1.
2. Commit only that change with the commit message `project: bumped version`. Tag the commit with `git tag vx.y.z` corresponding to `MARKETING_VERSION`.
3. Push the commit and tag.
4. In GitHub, draft a new release with the template below. Use the title `vx.y.z` or `vx.y.z (Beta)`. Select the tag you just created. Check "Set as a pre-release" if it is a beta. Check "Create a discussion for this release" and select the "Releases" category.
5. When the release is created, the pipeline will run and do everything else.

### Release notes

The app downloads the notes for its own version from the GitHub release and shows them as "What's New" the first time it launches, so the notes are parsed as well as read. See [UTMReleaseHelper.swift](../Platform/UTMReleaseHelper.swift) and [VMReleaseNotesView.swift](../Platform/Shared/VMReleaseNotesView.swift).

* Each `## ` heading starts a section. The **first** section is shown up front without its title, so it must be `## Highlights`. "Highlights" and "Installation" are skipped when the user taps "Show All"; every other section is shown.
* Every line is a `* ` bullet. Other lines (including `### ` headings) are shown as raw text, so do not use sub-headings. Inline Markdown (bold, links, code) is rendered.
* A bullet that starts with a parenthesized prefix, `* (prefix) text`, is shown only on matching builds, with the prefix stripped:

  | Prefix | Shown in |
  |--------|----------|
  | starts with `macOS`, e.g. `(macOS)`, `(macOS 26)` | macOS |
  | starts with `iOS`, e.g. `(iOS)`, `(iOS 17)`, `(iOS Remote)` (but not `(iOS SE)`) | all iOS and visionOS builds, including UTM SE and UTM Remote |
  | `(iOS SE)` exactly | UTM SE only |
  | starts with `visionOS` | visionOS builds only |

  Any other parenthesized prefix, such as `(iPadOS)`, `(AVF)`, or `(iOS, macOS)`, hides the line on **every** platform. Put components after the platform instead: `* (macOS) Settings: ...`. GitHub still shows every line.

#### Versioning the notes

* **New minor or major version (`x.y.0`)**: start fresh notes from the template below.
* **Revision (`x.y.z`, z > 0)**: copy the full notes of the previous release in the same `x.y` series, then add or update highlights and notes, and add a new `## Changes (vx.y.z)` section above the previous ones. The changes for every release in the series stay in the notes, newest first.

#### Writing the notes

* **Highlights** are the first thing users see, so use them sparingly: major features or changes only, or a theme that several changes share. Write them for a general audience, in marketing terms rather than technical ones: `* **Feature name**: One or two sentences.` Put a platform prefix before the bold title if the feature is only on one platform.
* **Notes** are for anything users must know or do: changed behaviour, requirements, migration steps, recommendations.
* **Known Issues** list major problems in this release, with a workaround if there is one.
* **Changes** list one bullet per commit, or one per pull request if the commits came from a PR. If several commits make up one feature, write one bullet. Leave out changes users can't see (documentation, CI, agent tooling, refactoring). Format each bullet as:

  `* (Platform) Component: What changed (#issue) (thanks @contributor)`

  * `(Platform)` only if the change affects one platform, or one version of it (`(macOS 26)`); see the prefix table above.
  * `Component:` when the change belongs to one area. Commonly used: Home, Config, Wizard, Settings, Toolbar, Scripting, utmctl, AVF, QEMU, SPICE, CocoaSpice, ANGLE, USB, Downloader, Localization.
  * `(#issue)` is the issue the change fixes or resolves, not the PR number.
  * `(thanks @login)` credits a PR or commit author who is not a UTM maintainer.
  * Translation changes use the `Localization:` component and name each language in English, not by its code: `* Localization: Updated German (thanks @contributor)`, not `de`. Add the region or script in parentheses when it matters: `Chinese (Hong Kong, Simplified)`.
  * Sort each `## Changes` section into groups:
    1. Changes for every platform, then `(iOS…)` changes, then `(visionOS…)` changes, then `(macOS…)` changes. Keep a versioned prefix such as `(macOS 26)` next to the others for that platform.
    2. Within each platform group, bullets with no component first, then one run of bullets per component, so every change for the same component on the same platform sits together.

### Release notes template

`## Notes` and `## Known Issues` are optional; remove them if they are empty. Use the footer (from `## Issues` to the end) verbatim.

```
## Highlights
* **Feature name**: One or two sentences for a general audience.
* (macOS) **Platform-only feature**: Prefix the line if the feature is only on one platform.

## Notes
* List any important changes here.
* Include anything that deviates significantly from previously defined behaviour.

## Known Issues
* List any known major issues here.

## Changes (vx.y.1)
* A change on every platform (#1234)
* Component: A change in one component (thanks @contributor)
* Component: Another change in the same component
* Localization: Updated German (thanks @contributor)
* (iOS) An iOS-only change
* (macOS) A macOS-only change
* (macOS) Component: A macOS-only change in one component

## Changes (vx.y.0)
* One change
* Another change

## Issues
Please check the full list on [Github](https://github.com/utmapp/UTM/issues) and help report any bug you find that is not listed.

## Installation

* [iOS](https://docs.getutm.app/installation/ios/)
* [macOS](https://docs.getutm.app/installation/macos/)

| File | Description | Installation | JIT | Hypervisor | USB |
|------|------------|--------------|-----|-----------|-----|
| UTM.deb | Jailbroken iOS version | Open in Cydia, dpkg, or Sileo | Yes | Yes(1) | Yes |
| UTM.dmg | macOS version | Mounting and copying UTM.app to /Applications | Yes | Yes | Yes |
| UTM.ipa | Non-jailbroken iOS version (sideloading) | AltStore, etc (see guide) | Yes(2) | No | No |
| UTM-HV.ipa | Non-jailbroken iOS version (TrollStore) | TrollStore | Yes | Yes(1) | Yes |
| UTM-SE.ipa | Non-jailbroken iOS version (sideloading) | AltStore, enterprise signing, etc | No | No | No |
| UTM-Remote.ipa | Remote client | Any | No | No | No |

1. Hypervisor on iOS requires an M1 iPad or newer.
2. Enabling JIT may require a separate JIT enabler such as [Jitterbug][2] or Jitstreamer.

[1]: https://getutm.app/install/
[2]: https://github.com/osy/Jitterbug
```

### Beta release

Beta releases will not show up as the "latest version" in the GitHub home page. It also will not be posted to AltStore and Cydia and will not be distributed to the App Store (exception: TestFlight).

### Re-release

In case of issues in post release that warrants a re-release, follow the same steps but do not change `MARKETING_VERSION` (`CURRENT_PROJECT_VERSION` must still be incremented by 1 or App Store Connect rejects the build). The tag should be named `vx.y.z-t` where `t` starts at `2` and increments by 1 for every re-release. Then copy-paste the release notes from the previous release and follow the same steps above. Finally, delete the old release if desired.

## Actions Details

### Secrets

Below is a summary of all the variables and secrets used by GitHub Actions in the release process.

|Secret                           |Description                                                                        |
|---------------------------------|-----------------------------------------------------------------------------------|
|`PERSONAL_ACCESS_TOKEN`          |GitHub personal token with permission for `repository_dispatch`                    |
|`SIGNING_CERTIFICATE_P12_DATA`   |Base64 encoded PKCS#12 format containing certificates and private keys for signing |
|`SIGNING_CERTIFICATE_PASSWORD`   |Password of the PKCS#12 file                                                       |
|`CONNECT_KEY`                    |App Store Connect API key for notarizing and submission (base64 encoded .p8)       |

|Variable                         |Description                                                                        |
|---------------------------------|-----------------------------------------------------------------------------------|
|`DISPATCH_ALTSTORE_REPO_NAME`    |`username/repo` path to a [altstore-github][1] repository                          |
|`DISPATCH_CYDIA_REPO_NAME`       |`username/repo` path to a [silica-package-github][2] repository                    |
|`SIGNING_TEAM_ID`                |Team ID associated with signing certificates                                       |
|`CONNECT_ISSUER_ID`              |App Store Connect API issuer id                                                    |
|`CONNECT_KEY_ID`                 |App Store Connect API key id                                                       |
|`PROFILE_DATA`                   |Base64 encoded provisioning profile of main application                            |
|`PROFILE_UUID`                   |UUID of provisioning profile above                                                 |
|`HELPER_PROFILE_DATA`            |Base64 encoded provisioning profile of QEMUHelper                                  |
|`HELPER_PROFILE_UUID`            |UUID of provisioning profile above                                                 |
|`LAUNCHER_PROFILE_DATA`          |Base64 encoded provisioning profile of QEMULauncher                                |
|`LAUNCHER_PROFILE_UUID`          |UUID of provisioning profile above                                                 |
|`APP_STORE_PROFILE_DATA`         |Base64 encoded provisioning profile of main application for App Store submission   |
|`APP_STORE_PROFILE_UUID`         |UUID of provisioning profile above                                                 |
|`APP_STORE_HELPER_PROFILE_DATA`  |Base64 encoded provisioning profile of QEMUHelper for App Store submission         |
|`APP_STORE_HELPER_PROFILE_UUID`  |UUID of provisioning profile above                                                 |
|`APP_STORE_LAUNCHER_PROFILE_DATA`|Base64 encoded provisioning profile of QEMULauncher for App Store submission       |
|`APP_STORE_LAUNCHER_PROFILE_UUID`|UUID of provisioning profile above                                                 |
|`IOS_REMOTE_PROFILE_DATA`        |Base64 encoded provisioning profile of iOS Remote for App Store submission         |
|`IOS_REMOTE_PROFILE_UUID`        |UUID of provisioning profile above                                                 |
|`IOS_SE_PROFILE_DATA`            |Base64 encoded provisioning profile of iOS SE for App Store submission             |
|`IOS_SE_PROFILE_UUID`            |UUID of provisioning profile above                                                 |
|`IOS_SE_HELPER_PROFILE_DATA`     |Base64 encoded provisioning profile of the iOS SE helper extension for App Store   |
|`IOS_SE_HELPER_PROFILE_UUID`     |UUID of provisioning profile above                                                 |
|`IS_SELF_HOSTED_RUNNER`          |Set to `true` to use a self hosted macOS runner set up by the owner                |

### Signing for release

The following certificates (and associated private keys) must be exported from Keychain as a PKCS#12 file (Cmd+click to select multiple and right click to export).

* Developer ID Application
* 3rd Party Mac Developer Application (Mac App Store) or Apple Distribution
* 3rd Party Mac Developer Installer (Mac App Store)

Give a password when prompted and save it to the repository secret `SIGNING_CERTIFICATE_PASSWORD`. Then, in Terminal, convert the PKCS#12 file to Base64 and copy it: `cat Certificates.p12 | base64 | pbcopy` and paste it to `SIGNING_CERTIFICATE_P12_DATA`.

Next you need to get each provisioning profile {3 profiles for macOS} X {1 for Developer ID, 1 for Mac App Store} plus the App Store profiles for iOS: UTM SE, its helper extension (`com.utmapp.UTM-SE.iOSHelper`) and UTM Remote. Save each UUID of the profile as `*_PROFILE_UUID` and the Base64 encoded data from `cat name.provisionprofile | base64 | pbcopy` as `*_PROFILE_DATA`.

### AltStore Repository

The AltStore repository is generated by [altstore-github][1]. The repository [utmapp/altstore-repo](https://github.com/utmapp/altstore-repo) is created which contains its own GitHub Actions that is triggered on a `repository_dispatch` event. When the event is dispatched by the main repository's release Actions, the other repository will use altstore-github to generate an AltStore compatible JSON repository file from GitHub releases containing the release notes and download links to all the recent releases. The resulting repository file is hosted on GitHub Pages.

### Cydia Repository

The Cydia repository is generated by [silica-package-github][2]. The repository [utmapp/cydia-repo](https://github.com/utmapp/cydia-repo) has its own GitHub Actions triggered by a `repository_dispatch` event sent from the main repository during the release GitHub Actions. It generates the repository index and HTML pages and uses GitHub Pages to host everything.

### Debugging release pipeline

Go to the [Build workflow][4] and click the "Run workflow" button. Type "true" for "Test release?" and you can test out changes to the release pipeline without making a release. The built assets will be provided as artifacts instead of as release assets.

[1]: https://github.com/osy/altstore-github
[2]: https://github.com/osy/silica-package-github
[3]: https://support.apple.com/en-us/HT204397
[4]: https://github.com/utmapp/UTM/actions/workflows/build.yml
[5]: https://semver.org
