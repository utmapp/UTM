#  UTM
[![Build](https://github.com/utmapp/UTM/actions/workflows/build.yml/badge.svg?branch=main&event=push)][1]
[![Mac App Store](https://img.shields.io/badge/Mac_App_Store-UTM-0D96F6?logo=appstore&logoColor=white)](https://apps.apple.com/us/app/utm-virtual-machines/id1538878817)
[![App Store](https://img.shields.io/badge/App_Store-UTM_SE-0D96F6?logo=appstore&logoColor=white)](https://apps.apple.com/us/app/utm-se-retro-pc-emulator/id1564628856)
[![Download](https://img.shields.io/badge/Download-UTM.dmg-24292F?logo=github&logoColor=white)](https://github.com/utmapp/UTM/releases/latest/download/UTM.dmg)

> It is possible to invent a single machine which can be used to compute any computable sequence.

-- <cite>Alan Turing, 1936</cite>

UTM is a full featured system emulator and virtual machine host for iOS, macOS, and visionOS. It is based off of QEMU. In short, it allows you to run Windows, Linux, and more on your Mac, iPhone, and iPad. More information at https://getutm.app/ and https://mac.getutm.app/

<p align="center">
  <img width="450px" alt="UTM running on an iPhone" src="screen.png">
  <br>
  <img width="450px" alt="UTM running on a MacBook" src="screenmac.png">
</p>

## Features

* Full system emulation (MMU, devices, etc) using QEMU
* 30+ processors supported including x86_64, ARM64, and RISC-V
* VGA graphics mode using SPICE and QXL
* Text terminal mode
* USB devices
* JIT based acceleration using QEMU TCG
* Frontend designed from scratch for macOS 12+ and iOS 15+ using the latest and greatest APIs
* Create, manage, run VMs directly from your device

## Additional macOS Features

* Hardware accelerated virtualization using Hypervisor.framework and QEMU
* Boot macOS guests with Virtualization.framework

## UTM SE

UTM/QEMU requires dynamic code generation (JIT) for maximum performance. JIT on iOS devices require either a jailbroken device, or one of the various workarounds found for specific versions of iOS (see "Install" for more details).

UTM SE ("slow edition") uses a [threaded interpreter][3] which performs better than a traditional interpreter but still slower than JIT. This technique is similar to what [iSH][4] does for dynamic execution. As a result, UTM SE does not require jailbreaking or any JIT workarounds and can be sideloaded as a regular app.

To optimize for size and build times, only the following architectures are included in UTM SE: ARM, PPC, RISC-V, and x86 (all with both 32-bit and 64-bit variants).

## Install

UTM (SE) for iOS: https://docs.getutm.app/installation/ios/

UTM is also available for macOS: https://docs.getutm.app/installation/macos/

## Development

### [macOS Development](Documentation/MacDevelopment.md)

### [iOS Development](Documentation/iOSDevelopment.md)

## Related

* [iSH][4]: emulates a usermode Linux terminal interface for running x86 Linux applications on iOS
* [a-shell][5]: packages common Unix commands and utilities built natively for iOS and accessible through a terminal interface

## License

UTM is distributed under the permissive Apache 2.0 license. However, it uses several (L)GPL components. Most are dynamically linked but the gstreamer plugins are statically linked and parts of the code are taken from qemu. Please be aware of this if you intend on redistributing this application.

Some icons made by [Freepik](https://www.freepik.com) from [www.flaticon.com](https://www.flaticon.com/).

Additionally, UTM frontend depends on the following MIT/BSD License components:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Continuous integration hosting is provided by [MacStadium](https://macstadium.com/company/opensource)

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
