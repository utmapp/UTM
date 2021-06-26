#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> It is possible to invent a single machine which can be used to compute any computable sequence.

-- <cite>Alan Turing, 1936</cite>

UTM is a full featured system emulator and virtual machine host for iOS and macOS. It is based off of QEMU. In short, it allows you to run Windows, Linux, and more on your Mac, iPhone, and iPad. More information at https://getutm.app/ and https://mac.getutm.app/

![Screenshot of UTM running on iPhone][2]

## Features

* Full system emulation (MMU, devices, etc) using QEMU
* 30+ processors supported including x86_64, ARM64, and RISC-V
* VGA graphics mode using SPICE and QXL
* Text terminal mode
* USB devices
* JIT based acceleration using QEMU TCG
* Frontend designed from scratch for macOS 11 and iOS 11+ using the latest and greatest APIs
* Create, manage, run VMs directly from your device

## UTM SE

UTM/QEMU requires dynamic code generation (JIT) for maximum performance. JIT on iOS devices require either a jailbroken device, or one of the various workarounds found for specific versions of iOS (see "Install" for more details).

UTM SE ("slow edition") uses a [threaded interpreter][3] which performs better than a traditional interpreter but still slower than JIT. This technique is similar to what [iSH][4] does for dynamic execution. As a result, UTM SE does not require jailbreaking or any JIT workarounds and can be sideloaded as a regular app.

To optimize for size and build times, only the following architectures are included in UTM SE: ARM, PPC, RISC-V, and x86 (all with both 32-bit and 64-bit variants).

## Install

UTM (SE) for iOS: https://getutm.app/install/

UTM is also available for macOS: https://mac.getutm.app/

## Development

### [macOS Development](Documentation/MacDevelopment.md)

### [iOS Development](Documentation/iOSDevelopment.md)

## Related

* [iSH][4]: emulates a usermode Linux terminal interface for running x86 Linux applications on iOS
* [a-shell][5]: packages common Unix commands and utilities built natively for iOS and accessible through a terminal interface

## License

UTM is distributed under the permissive Apache 2.0 license. However, it uses several (L)GPL components. Most are dynamically linked but the gstreamer plugins are statically linked and parts of the code are taken from qemu. Please be aware of this if you intend on redistributing this application.

Some icons made by [Freepik](https://www.freepik.com) from [www.flaticon.com](https://www.flaticon.com/).

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
