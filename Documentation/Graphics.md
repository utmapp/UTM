# Graphics

The graphics architecture of UTM involves many separate translation layers.

### GPU Acceleration
```
                             ┌────────────────────────────────────────────────┐
                             │  Host                                          │
                             │ ┌────────────────────────────────┬───────────┐ │
                          ┌──┼─► virglrenderer       │ +Venus†  │ gfxstream†│ │
                          │  │ │                     │          │           │ │
                          │  │ ├──────────┬──────────┬──────────┴───────────┤ │
┌─────────────────────┐   │  │ │ ANGLE    │ ANGLE    │ MoltenVK†            │ │
│ Guest               │   Q  │ │ Metal    │ OpenGL   │                      │ │
│ ┌─────────────────┐ │   E  │ ├──────────┴──────────┴──────────────────────┤ │
│ │ Userland 3D API │ │   M  │ │ CocoaSpice Metal Renderer                  │ │
│ │ (e.g. Mesa)     │ │   U  │ │                                            │ │
│ ├─────────────────┤ │   │  │ ├────────────────────────────────────────────┤ │
│ │ Kernel Driver   │ │   │  │ │ Metal Device                               │ │
│ │ (virtio-gpu)    ├─┼───┘  │ │                                            │ │
│ └─────────────────┘ │      │ └────────────────────────────────────────────┘ │
│                     │      │                                                │
└─────────────────────┘      └────────────────────────────────────────────────┘
```

†: Future work that is not currently in UTM.

### No GPU Acceleration
```
                             ┌───────────────────────────────┐
                             │  Host                         │
                             │ ┌─────────────┬─────────────┐ │
┌─────────────────────┐   ┌──┼─► pixman      │ pixman      │ │
│ Guest               │   │  │ │ EGL Canvas  │ Pixel Buffer│ │
│                     │   Q  │ ├─────────────┴─────────────┤ │
│                     │   E  │ │ CocoaSpice Metal Renderer │ │
│                     │   M  │ │                           │ │
│ ┌─────────────────┐ │   U  │ ├───────────────────────────┤ │
│ │ Framebuffer     │ │   │  │ │ Metal Device              │ │
│ │                 ├─┼───┘  │ │                           │ │
│ └─────────────────┘ │      │ └───────────────────────────┘ │
│                     │      │                               │
└─────────────────────┘      └───────────────────────────────┘
```

## Guest Side

When GPU acceleration is available, the guest userland will translate the graphics API (OpenGL, Vulkan, etc) to kernel driver commands. The commands goes through QEMU through the VirtIO interface to be decoded by the host.

If GPU acceleration is not available, it is typically due to one or more of the following:
* The VirtIO GPU device is not used or is not available on the guest architecture
* The guest drivers for VirtIO GPU are not available or are incomplete (as is the case with Windows)
* The guest userland component (e.g. Mesa) is incompatible with the host side libraries (due to a bug or a missing feature)
* The guest application attempts to use a graphics API feature that is not supported by the host side libraries

When GPU acceleration is missing, if a `-gl` display hardware is used, then QEMU will handle the blit operations directly to a EGL canvas. This will be slight faster and have lower latency than the alternative, which is for CocoaSpice to do the blit operation AND render to screen. This is why it is worth selecting a `-gl` device even if there is no guest driver support.

## virglrenderer

[virglrenderer][1] is the host side library that decodes the draw commands from the guest and calls into OpenGL (on the host side). [Venus][2] is a newer addition to virglrenderer that allows the guest to pass Vulkan commands to the host.

## gfxstream

[gfxstream][3] is an alternative library that allows the guest to serialize OpenGL and Vulkan commands, pass them through a communication channel ("pipe") to the host, and the host will deserialize and evaluate the calls. It differs from virglrenderer in that there is no intermediate translation (guest Mesa -> virgl commands -> host OpenGL). Currently this technology is used for Google's Android emulator and not by mainline QEMU so it will take some time for UTM to adopt the code.

## ANGLE

[ANGLE][4] is an implementation of OpenGL ES on top of other graphics APIs. UTM uses three ANGLE backends:
1. On macOS, the `cgl` (Core OpenGL) backend is provided
2. On iOS, the `eagl` backend is provided
3. For both macOS and iOS, the `metal` backend is provided

The three backends have differing compatibility and there is no "best" backend. QEMU uses ANGLE to draw into an IOSurface instead of directly to screen.

## MoltenVK

[MoltenVK][5] is used to translate Vulkan to Metal because Apple devices do not support Vulkan natively. MoltenVK is currently not used in UTM.

## CocoaSpice

[CocoaSpice][6] renders the IOSurface as a texture directly to screen with Metal APIs. It also controls the frame time by synchronizing to the display's vblank signal to reduce tearing. As an optimization, CocoaSpice renderer will only draw the last update before a vblank which means that if the guest is drawing multiple times per monitor refresh, the host will consolidate the draws to a single Metal call. On macOS, the IOSurface is passed from QEMULauncher (rendered in a separate process) through a global `IOSurfaceID`. On iOS, because there is no process separation, the IOSurface reference is passed directly from QEMU to CocoaSpice.

UTM uses SPICE as a QEMU frontend, which means that all input/output goes through SPICE. SPICE was designed to work remotely over the network but when operating remotely, GPU acceleration is not supported. Instead, all pixel buffer updates must be sent from QEMU which is why it is slower than the EGL canvas rendering.

# Debugging Tips

ANGLE has an option to enable tracing all GL calls. You can modify `scripts/build_dependencies.sh` to add the following arguments to the ANGLE build:
```
--args angle_enable_trace=true angle_enable_trace_events=true
```
By default, the trace logs are set to the device syslog. If you want it to show up in stderr (especially to sync with log items from other components), modify `src/common/debug.cpp` and change the line `#elif defined(ANGLE_PLATFORM_APPLE)` to `#elif defined(ANGLE_PLATFORM_APPLE_NOT_DEFINED)` as well as the `fprintf` after it to `fprintf(stderr, "%s: %s\n", LogSeverityName(severity),` (in order to force stderr to always be used).

virglrenderer also can print debug output. In order to enable it, modify `scripts/build_dependencies.sh` to include `--buildtype debug` to the Meson call. Then you have to add the environment variable `VREND_DEBUG=all` to the process. The easiest way to do that is to modify `UTMQemuSystem.m` and add it to the `setRendererBackend:` method.

To enable MoltenVK debug output, modify `scripts/build_dependencies.sh` and change the call to `make $platform` in `build_moltenvk()` to `make ${platform}-debug`.

[1]: https://gitlab.freedesktop.org/virgl/virglrenderer
[2]: https://www.collabora.com/news-and-blog/blog/2021/11/26/venus-on-qemu-enabling-new-virtual-vulkan-driver/
[3]: https://android.googlesource.com/device/generic/vulkan-cereal/
[4]: https://chromium.googlesource.com/angle/angle
[5]: https://github.com/KhronosGroup/MoltenVK
[6]: https://github.com/utmapp/CocoaSpice