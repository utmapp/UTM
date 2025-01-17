#  UTM (UTMRemote-iOS14)
[![Build](https://github.com/utmapp/UTM/workflows/Build/badge.svg?branch=main&event=push)][1]

## The Problem

The UTM Remote application on the App Store and Github build has a crash problem (the latest build experienced is 4.6.4) when attempting to connect to the UTM Server. There is no problem with pairing and saving the UTM Server. The problem is possibly occurring on iOS 14, devices on iOS 15 do not seem to crash. The initially experienced device is iPad Air 2 on iOS 14.5.1

To detect the problem, the first method was to look at the logs from the iPad and run the Console on Mac to see possible messages regarding the crash. In the Console, "Fatal error: No ObservableObject of type UTMRemoteData found. A View.environmentObject(_:) for UTMRemoteData may be missing as an ancestor of this view." message was found as a possible cause for the crash. The [issue][6] was opened in the Github repository.

* Missing Environment Object: The ServerConnectView without specifying the environment object of UTMRemoteData in the view call results in a crash.
* Awaiting Behaviour Difference: For the function of connecting to the server, iOS 14 handles the awaiting situation differently in multithreading, returning nil for the environment object even if the ServerConnectView data was previously set in the view call.

## The Solution

Attempting to fix the problem was hard because of many issues such as building dependencies, Xcode support for the Simulator, and unsupported Swift Tools. Firstly, a macOS virtual machine was installed to develop the application securely. Then, some frameworks required version 10.0.0 for Swift tools. The virtual machine was updated to the latest macOS version, followed by Xcode. The dependencies were built and the application could be built successfully but the lowest iOS support for Simulator was iOS 15.0. The device support was at iOS 13.0 but the virtual machine did not have USB passthrough, making it impossible to develop at iOS 14. The final attempt was to install Xcode 16.4 on the real device and move the project files from the virtual machine to the real device. When the project was opened with Xcode 16.4, a framework had ambiguity errors, they were fixed by unlocking the file and adding specifying statements in the code. The changes in the framework were reverted when building UTM with the script. The real device test was made possible.

The changes in the code were added with "if #available" statements.

* Missing Environment Object: The ServerConnectView call was specified with the environment object of UTMRemoteData.
* Awaiting Behaviour Difference: The function of connecting to the server was enclosed with Task. The priority was set to userInteractive so, the flow was changed not to be called when the environment object is nil.

## Final

The application on the device did not crash after applying the changes, proceeding to the view of virtual machines. The virtual machines were running with no problem.


> It is possible to invent a single machine which can be used to compute any computable sequence.

-- <cite>Alan Turing, 1936</cite>

UTM is a full featured system emulator and virtual machine host for iOS and macOS. It is based off of QEMU. In short, it allows you to run Windows, Linux, and more on your Mac, iPhone, and iPad. More information at https://getutm.app/ and https://mac.getutm.app/

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
* Frontend designed from scratch for macOS 11 and iOS 11+ using the latest and greatest APIs
* Create, manage, run VMs directly from your device

## Additional macOS Features

* Hardware accelerated virtualization using Hypervisor.framework and QEMU
* Boot macOS guests with Virtualization.framework on macOS 12+

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

Additionally, UTM frontend depends on the following MIT/BSD License components:

* [IQKeyboardManager](https://github.com/hackiftekhar/IQKeyboardManager)
* [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
* [ZIP Foundation](https://github.com/weichsel/ZIPFoundation)
* [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit)

Continuous integration hosting is provided by [MacStadium](https://www.macstadium.com/opensource)

[<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="MacStadium logo" width="250">](https://www.macstadium.com)

  [1]: https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild
  [2]: screen.png
  [3]: https://github.com/ktemkin/qemu/blob/with_tcti/tcg/aarch64-tcti/README.md
  [4]: https://github.com/ish-app/ish
  [5]: https://github.com/holzschu/a-shell
  [6]: https://github.com/utmapp/UTM/issues/6970
