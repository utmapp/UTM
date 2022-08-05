# Architecture

UTM is built upon several pieces of technology, layered to provide compatibility across various host configurations. Below is a simplified diagram of key pieces of UTM with additional details provided below.

```
┌────────────────────┬──────────────────────┐
│   iOS VM Display   │   macOS VM Display   │
├────────────────────┴──────────────────────┤
│                  SwiftUI                  │
├───────────────────────────────────────────┤
│             UTMVirtualMachine             │
├────────────────┬──────────────────────────┤
│   CocoaSpice   │                          │
├────────────────┤ Virtualization.framework │
│ QEMU (TCG/HVF) │                          │
└────────────────┴──────────────────────────┘
```

## QEMU

The backbone of UTM is QEMU, which provides the emulation and virtualization engine. We run a custom [fork][1] which includes several features such as:

* Building QEMU as a shared library
* APRR support for jailbroken iOS
* ARM64 TCTI from @ktemkin (JIT-less iOS support)
* SPICE ANGLE backend for hardware GL acceleration

These features, along with several others (which are undergoing code review and may not have made the latest stable release), allow our fork to be optimized for Darwin.

### Hypervisor.framework

QEMU includes support for the `hvf` accelerator which provides same architecture virtualization (x86 -> x86 or ARM64 -> ARM64) on macOS. This framework is not available on iOS.

### UTMQemu

QEMU is linked as a shared library. On iOS, there is no ability to use `fork`, XPC (directly), or any other way of launching a new process. As a result, we run the QEMU main loop in a pthread which for all intents and purposes work like normal (the key exception being that you cannot spawn multiple instances of QEMU and since QEMU does not properly clean up resources, you cannot re-launch QEMU). On macOS, XPC is used to launch QEMU in a new process. `UTMQemu` manages the pthread or XPC implementation.

#### XPC Helper

On macOS, spawning new processes is permitted but due to App Sandbox security requirements, we need some additional "bootstrapping" code to launch QEMU properly. The added benefit is that we only have to provide a single bundle identifier for the "launcher" executable rather than a different identifier for each QEMU executable (required for App Sandbox).

`QEMUHelper` is an XPC helper with its own App Sandbox separate from the UTM main application. This improves security by providing an additional layer of separation. However, due to this extra care has to be taken when passing file handles and other system resources from the main app. For example, the Unix socket file used to communicate with SPICE is stored in a shared App Group directory. For disk images and shared directories that cannot be stored in the App Group, we have to do a complicated sandbox dance to get the right access permissions.

1. The main application opens a `NSOpenPanel`, allowing the user to select a file/directory outside the sandbox. This returns a `NSURL` with the right security scope attached. If we take a regular bookmark of `NSURL` and pass it through XPC, the XPC process should also have access once it reads the bookmark back into a `NSURL`.
2. However, the access to that file is only valid while the app is open. As soon as you close it, the app loses those permissions and must either prompt the user to select the file again or store a "security scoped bookmark." The issue here is that a security scoped bookmark is only valid for the sandbox that created it. If we take a security scoped bookmark and pass it directly to the XPC process, it cannot get back a `NSURL`.
3. So the solution is to take a *standard* bookmark, pass it to the XPC process, have the XPC process then create a *security scoped* bookmark and pass it back to the main process. The main process can now store this bookmark and have it work as intended when it passes it to the XPC process next launch.

The XPC helper spawns `QEMULauncher` with an inherited sandbox. This means it can access files that are accessible to the helper XPC. The launcher process is what runs QEMU. When a new file is opened (for example a new disk image is mounted), the main application will pass a bookmark to the helper XPC where it will call `-startAccessingSecurityScopedResource` which also applies to the child process (`QEMULauncher`). This way, QEMU does not have to have any knowledge of the App Sandbox.

### UTMConfiguration

VM configuration is stored in a PLIST format. This PLIST maps to either a `UTMQemuConfiguration` or `UTMAppleConfiguration` structure which stores the underlying configuration data in a `Codable` interface for easy serialization.

### UTMQemuSystem

`UTMQemuSystem` maps `UTMQemuConfiguration` to command line arguments used to launch QEMU.

### UTMQemuManager

After a VM is launched, `UTMQemuManager` provides run-time services though the QMP protocol. These services include stopping/pausing/resuming the VM, taking snapshots, switching between mouse and tablet, mounting removable disk images, and more. The underlying transport for QMP is JSON (over a socket), so `UTMJSONStream` marshals the data to and from `NSDictionary` objects.

#### QAPI

QMP protocol is defined by the QAPI schema which is provided as a set of JSON files in QEMU. QEMU uses these JSON files to generate wrapper C functions for internal usage. UTM includes a modified function generator derived from QEMU's own script (`qapi-gen.py`) along with modified QAPI C visitors (for `NSDictionary`). This allows UTM to use the same commands, structures, and events that QEMU uses in a transparent way.

For example, when UTM makes a call to some QAPI command such as `qmp_blockdev_change_medium`, the generated C functions will automatically marshal the function arguments into a `NSDictionary` object which `UTMJSONStream` converts into JSON and sends it over the QMP socket. When a response is received, `UTMJSONStream` converts the JSON into a `NSDictionary` object, which goes through the generated C functions to unmarshal into some C structure which is returned from `qmp_blockdev_change_medium`. This is all transparent to the caller as long as they understand that the function call will block until the response is received so it must not be called from the main thread.

## Virtualization.framework

On Apple Silicon Macs running macOS 12 or later, `Virtualization.framework` is provided by Apple to run macOS 12 guests.

### UTMAppleConfiguration

As the backend is different, the configuration format UTM uses is also different and is represented in `UTMAppleConfiguration`. As this configuration is handed in Swift, the Codable protocol is used for serialization instead of a `NSDictionary` backing used in `UTMQemuConfiguration`. The Codable backing is more extendible as it allows more complex data to be represented without a lot of boilerplate.

## CocoaSpice

UTM uses the SPICE front-end with QEMU because it has more versatility than VNC to handle things like USB forwarding, multiple displays, and the ability to use a SPICE agent running on the guest to share clipboard and change the resolution. [CocoaSpice][2] is provided as a Swift package and acts as Cocoa/Objective-C bindings for SPICE GTK. CocoaSpice also provides a bridge between the Pixman framebuffer that SPICE uses and Metal textures that is used by MetalKit to render to screen.

### UTMSpiceIO

`UTMSpiceIO` connects `CocoaSpice` to UTM and is used by `UTMQemuVirtualMachine` to control the SPICE client and respond to client events.

## UTMVirtualMachine

`UTMVirtualMachine` provides file I/O operations for creating and saving .utm VM bundles as well as controls for the platform-specific layer above to do high level tasks like starting and stopping the VM. It is highest level of the "backend", providing a platform independent view of UTM virtual machines.

### UTMQemuVirtualMachine

This subclass manages QEMU+CocoaSpice backend VMs.

### UTMAppleVirtualMachine

This subclass manages Apple Virtualization.framework backend VMs.

## Frontend

### SwiftUI

The frontend for UTM is designed mostly in SwiftUI 2.0. That means the minimum supported operating system is iOS 14 and macOS 11 and is the main reason there are no plans to back-port UTM to earlier versions. Most views are designed to work on both macOS and iOS.

#### UTMData

`UTMData` is a SwiftUI `ObservableObject` that contains the "state" and is the "single source of truth" for the home view. It stores the list of VMs and functions to create, modify, move, etc VMs on that list. `UTMConfigurable` provides the state for VM configuration views.

### iOS VM Display

The VM display uses UIKit as SwiftUI is not mature enough to do everything UTM needs. This includes the custom keyboard accessory view implemented in a NIB for emulating keys that are not available on the standard iOS keyboard.

### macOS VM Display

On macOS, the VM display uses AppKit for similar reasons above.

[1]: https://github.com/utmapp/qemu
[2]: https://github.com/utmapp/CocoaSpice
