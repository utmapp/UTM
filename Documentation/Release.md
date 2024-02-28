# Release Guide

This document details the release procedure for UTM team members. The release procedure is mostly automated by GitHub Actions. In short, when you submit a new "release" on the GitHub repository, the following happens:

1. If UTM dependencies are not cached from a previous run, build it for {iOS,macOS,iOS-TCI,iOS Simulator} X {arm64,x86_64}.
2. Build UTM for all configurations and architectures.
3. Take the {iOS-arm64,iOS-TCI-arm64} build and package it into a fakesigned IPA and post it as a release asset.
4. Take the iOS-arm64 build and package it into a Cydia DEB and post it as a release asset.
5. Update the Cydia repository.
6. Update the AltStore repository.
7. Combine dependencies for macOS-arm64 and macOS-x86_64 into universal binaries.
8. Build UTM as a macOS universal binary.
9. Take the universal binary and sign and package it into a DMG.
10. Notarize the DMG with App Store Connect and post it as a release asset.
11. Take the universal binary and sign and package it for the Mac App Store.
12. Submit the signed package to App Store Connect.

For more details see the [build.yml](../.github/workflows/build.yml) file.

## Making a release

Once you are ready to make a new release:

1. Modify [Build.xcconfig](../Build.xcconfig) and bump `MARKETING_VERSION` following [semantic versioning][5] and `CURRENT_PROJECT_VERSION` by 1.
2. Commit the change with the commit message `project: bumped version`. Tag the release with `git tag vx.y.z` corresponding to `MARKETING_VERSION`.
3. Push the commit and tag.
4. In GitHub, draft a new release with the template below. Use the title `vx.y.z` or `vx.y.z (Beta)`. Select the tag you just created. Check "This is a pre-release" if it is a beta. Check "Create a discussion for this release" and the "Release" category.
5. When the release is published, the pipeline will run and do everything else.

### Release notes template

Make sure to copy all the changes for all beta releases after the last non-beta release.

```
## Installation
Visit [https://getutm.app/install/][1] for the most up to date installation instructions.

## Highlights
* Key features
* Keep these bullets short

## Notes
* List any important changes here
* Include anything that deviates significantly from previously defined behaviour

## Changes (vx.y.1)
* Third change
* (iOS) iOS only change
* (iOS) Another iOS only change
* (macOS) A macOS only change

## Changes (vx.y.0)
* One change
* Another change

## Issues
Please check the full list on [Github][2] and help report any bug you find that is not listed.

### Known Issues

* Optional section. List any known major issues here in bullet points.

[1]: https://getutm.app/install/
[2]: https://github.com/utmapp/UTM/issues
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
|`IS_SELF_HOSTED_RUNNER`          |Set to `true` to use a self hosted macOS runner set up by the owner                |

### Signing for release

The following certificates (and associated private keys) must be exported from Keychain as a PKCS#12 file (Cmd+click to select multiple and right click to export).

* Developer ID Application
* 3rd Party Mac Developer Application (Mac App Store) or Apple Distribution
* 3rd Party Mac Developer Installer (Mac App Store)

Give a password when prompted and save it to the repository secret `SIGNING_CERTIFICATE_PASSWORD`. Then, in Terminal, convert the PKCS#12 file to Base64 and copy it: `cat Certificates.p12 | base64 | pbcopy` and paste it to `SIGNING_CERTIFICATE_P12_DATA`.

Next you need to get each provisioning profile {3 profiles for macOS} X {1 for Developer ID, 1 for Mac App Store}. Save each UUID of the profile as `*_PROFILE_UUID` and the Base64 encoded data from `cat name.provisionprofile | base64 | pbcopy` as `*_PROFILE_DATA`.

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
