#  UTM
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=master&event=push)][1]

> It is possible to invent a single machine which can be used to compute any computable sequence.

-- <cite>Alan Turing, 1936</cite>

UTM is a full featured system emulator and virtual machine host for iOS and macOS. It is based off of QEMU. In short, it allows you to run Windows, Linux, and more on your Mac, iPhone, and iPad. More information at https://getutm.app/ and https://mac.getutm.app/

![Screenshot of UTM running on iPhone][2]

## Features

* 30+ processors supported including x86_64, ARM64, and RISC-V thanks to qemu as a backend
* Fast native graphics through para-virtualization thanks to SPICE
* Supports attaching USB devices
* JIT based acceleration using qemu TCG
* Frontend designed from scratch for macOS 11 and iOS 11+ using the latest and greatest APIs
* Create, manage, run VMs directly from your device

## Install

UTM for iOS (available on stock iOS 11-13 and on jailbroken iOS 14+): https://getutm.app/install/

UTM is also available for macOS: https://mac.getutm.app/

## Development

### [macOS Development](Documentation/MacDevelopment.md)

### [iOS Development](Documentation/iOSDevelopment.md)

## License

UTM is distributed under the permissive Apache 2.0 license. However, it uses several (L)GPL components. Most are dynamically linked but the gstreamer plugins are statically linked and parts of the code are taken from qemu. Please be aware of this if you intend on redistributing this application.

Some icons made by [Freepik](https://www.freepik.com) from [www.flaticon.com](https://www.flaticon.com/).

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
