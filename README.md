#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> It is possible to invent a single machine which can be used to compute any computable sequence.

-- <cite>Alan Turing, 1936</cite>

UTM is a full featured virtual machine host for iOS. In short, it allows you to run Windows, Android, and more on your iPhone and iPad. More information at https://getutm.app/

![Screenshot of UTM running on iPhone][4]

## Features

* 30+ processors supported including x86_64, ARM64, and RISC-V thanks to qemu as a backend
* Fast native graphics through para-virtualization thanks to SPICE
* JIT based acceleration using qemu TCG
* Frontend designed from scratch for iOS11+ using the latest and greatest APIs
* Create, manage, run VMs directly from your device
* No jailbreak required for iOS 11-13! (required for iOS 14+)

## Install

If you just want to use UTM on iOS 11-13 or on jailbroken iOS 14, this is not the right place! Visit https://getutm.app/install/ for directions.

## Building (iOS)

To run UTM without a jailbreak on iOS 14 (as well as to develop UTM on any iOS version), [you must run with the Xcode debugger attached](Documentation/TetheredLaunch.md).

### Easy

The recommended way to obtain the dependencies is to use the built artifacts from [Github Actions][5]. Look for the latest release build and download the Sysroot artifact from either the arm64 build (for iOS) or x86_64 build (for iOS Simulator). Then unzip the artifact to the root directory of UTM. You can then open `UTM.xcodeproj`, select your signing certificate, and then run UTM from Xcode.

### Advanced

If you want to build the dependencies yourself, it is highly recommended that you start with a fresh macOS VM. This is because some of the dependencies attempt to use `/usr/local/lib` even though the architecture does not match. Certain installed libraries like `libusb` and `gawk` will break the build.

1. Install Xcode command line and the following build prerequisites
    `brew install bison pkg-config gettext glib libgpg-error nasm make meson`
   Make sure to add `bison` to your `$PATH` environment!
2. `git submodule update --init --recursive` if you haven't already
3. Run `./scripts/build_dependencies.sh` to start the build. If building for the simulator, run `./scripts/build_dependencies.sh -p ios -a x86_64` instead.
4. Open `UTM.xcodeproj` and select your signing certificate
5. Select iOS as the target, build and deploy from Xcode

## Building (macOS)

Mostly the same as for iOS but with the following changes:

* For building dependencies on Intel platforms, run `./scripts/build_dependencies.sh -p macos -a x86_64`
* For building dependencies on Apple Silicon platforms, run `./scripts/build_dependencies.sh -p macos -a arm64`

You may also download the prebuilt dependencies from Github instead.

## Signing (iOS)

### Signing Release

The `ipa` [releases][3] are fake-signed. If you are jailbroken, you should NOT sign it. You can install directly with Filza.

If you want to sign the release for stock devices, there are a variety of ways. The recommended way is with [iOS App Signer][2]. Note there are known issues with many "cloud" signing services such as AppCake and they do not work with UTM. If you get a crash while trying to launch a VM, then your signing certificate was invalid.

In more technical detail, there are two kinds of signing certificates: "development" and "distribution". UTM requires "development" which has the `get-task-allow` entitlement.

### Signing Development Build

If you want to sign an `xcarchive` such as from a [Github Actions][1] built artifact, you can use the following command:

```
./scripts/resign.sh UTM.xcarchive outputPath PROFILE_NAME TEAM_ID
```

Where `PROFILE_NAME` is the name of the provisioning profile and `TEAM_ID` is the identifier next to the team name in the provisioning profile. Make sure the signing key is imported into your keychain and the provision profile is installed on your iOS device.

If you have a jailbroken device, you can also fake-sign it (with `ldid` installed):

```
./scripts/resign.sh UTM.xcarchive outputPath
```

## Why isn't this in the AppStore?

Apple does not permit any apps that have interpreted or generated code therefore it is unlikely that UTM will ever be allowed. However, there are various ways people on the internet have come up to sideload apps without requiring a jailbreak. We do not condone or support any of these methods.

## License

UTM is distributed under the permissive Apache 2.0 license. However, it uses several (L)GPL components. Most are dynamically linked but the gstreamer plugins are statically linked and parts of the code are taken from qemu. Please be aware of this if you intend on redistributing this application.

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: https://dantheman827.github.io/ios-app-signer/
  [3]: https://github.com/utmapp/UTM/releases
  [4]: screen.png
  [5]: https://github.com/utmapp/UTM/actions?query=workflow%3ABuild+event%3Arelease+is%3Asuccess
