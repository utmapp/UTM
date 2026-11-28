# Intel Mac guest kit (Snow Leopard … High Sierra)

UTM itself only offers the **OpenGL Passthrough** switch on the *VMware SVGA II* display
card and ships the host side of it. The guest side — an OpenCore boot disk and the guest
OpenGL drivers — comes from this kit, which you build yourself from
[VirtualIntelMacOnAppleSilicon](https://github.com/nfzerox/VirtualIntelMacOnAppleSilicon)
(MIT), pinned to release 2.2 (`2861da9e26`). The kit reuses VirtualIntelMac's prebuilt
files and its own firmware generator; for Retina guests it recompiles only `VMsvga2.kext`
(see *Display resolution*).

## Build (on the Mac host)

```sh
./build-kit.sh snowleopard      # or: lion, mountainlion, mavericks, yosemite, elcapitan, sierra, highsierra
```

Needs `git`, `hdiutil` and Python 3.11+ (`brew install python`). Output folder
`IntelGuestKit-<guest>/`:

| File | Use |
|------|-----|
| `EFI.img` | OpenCore boot disk (VMsvga2 + VMsvga2Accel with the guest's renderer profile, QemuUSBTablet, VoodooHDA audio, MacPro5,1 SMBIOS) |
| `GuestTools.iso` | Guest OpenGL engine + 2D plugin and `Install.command` |
| `CODE.fd`, `VARS.fd` | VirtualIntelMac's UEFI firmware pair — optional, UTM's own UEFI boots `EFI.img` too |

## VM setup in UTM

1. New VM → **Emulate** → Other / x86_64, machine `q35`, **UEFI boot** on.
2. Display: **VMware SVGA II**, turn on **OpenGL Passthrough**.
3. Drives: import `EFI.img` as an **IDE** disk and move it to the top of the boot order;
   then the Mac OS X system disk (IDE).
4. Sound: Intel HD Audio. Input: USB tablet (absolute pointer — clicks land correctly).
5. Boot, pick the Mac OS X disk in the OpenCore picker.

## Display resolution (native panel)

The guest's VMsvga2 driver publishes one **native panel** mode, which QEMU reports to it.
macOS runs the desktop in that mode, and apps can switch away from it and back (fullscreen
games, `vid_restart`, resolution menus). A desktop resolution larger than the native panel
works, but it is missing from CoreGraphics' list of selectable modes. An app that saves
it and restores it later then fails (`displaySetMode: unable to find mode dict in array`
in the guest's system.log), so fullscreen games lose their display.

UTM sets the panel to the **host display's resolution** when the VM starts (a Retina host
gives a HiDPI guest with the same "looks like" size). The boot panel is limited to
2560×1600; on a larger host, the guest switches to the host size once its driver has
started (VRAM above 256 MB, e.g. 512 MB). Snow Leopard has no HiDPI: add
`-global vmware-svga.passthrough-opengl-hidpi=off` in *QEMU → Arguments*, so it uses the
host's "looks like" size at scale 1.

**Changing the resolution of a Retina guest (Lion 10.7.4+ … High Sierra):** pick a size in
System Preferences → Displays → *Scaled*, as on a real Retina Mac. VirtualIntelMac's driver
offers only the host-requested size there (one Retina mode, and after the host's size is
applied it publishes no other mode). The kit therefore rebuilds `VMsvga2.kext` from
VirtualIntelMac's source with `vmsvga2-hidpi-modes.patch`:
- on a 2x panel, every mode of at least 2048×1440 pixels is also a Retina mode, with added
  2x sizes up to 3840×2400 ("looks like" 1440×900 … 1920×1200);
- the full mode list stays published after a host-requested size change;
- the host's size is the display's default ("Best (Retina)").

On a Mac with a notch, the host size UTM passes should be the full-screen area below the
notch, e.g. `-global vmware-svga.passthrough-opengl-host-width=3600` and
`-global vmware-svga.passthrough-opengl-host-height=2262` for a 1800×1169 "looks like"
screen; otherwise full screen shows thin side bars.

The build needs Xcode or its Command Line Tools and downloads one checksum-pinned period
SDK. Its kernel imports match VirtualIntelMac's prebuilt driver for each guest. Mavericks is
tested; the other versions are built the same way but untested. The kit's display agent
(VirtualIntelMac's `opengl-display-agent`) still applies a new host size, for example after
a window resize with *Resize display to window size* on, at 2x. For a Displays list of 1x
resolutions instead, use `hidpi=off` as above.

To use another panel instead, set it in the VM's QEMU arguments; these override UTM's
values. For example, for 1680×1050:

```
-global vmware-svga.passthrough-opengl-panel-width=1680
-global vmware-svga.passthrough-opengl-panel-height=1050
-global vmware-svga.passthrough-opengl-ui-scale=1
-global vmware-svga.passthrough-opengl-host-width=0
```

Limits of the boot panel: width 640–2560 and height 400–1600; `passthrough-opengl-ui-scale=2`
(HiDPI) needs at least 2048×1536.

Two display properties tune how guest software updates and the host GPU frames share the
window. The defaults suit normal use.

| Property | Default | Meaning |
|----------|---------|---------|
| `vmware-svga.gpu-software-after-ms` | `250` | Software (VRAM) updates take the window back after this many ms without GPU frames. A captured fullscreen OpenGL app publishes through VRAM. `0` keeps VirtualIntelMac's strict latch, so fullscreen games show black. |
| `vmware-svga.gpu-latest-wins` | `off` | `on`: the newest update always wins, software or GPU. |

## Install the guest drivers

Mount `GuestTools.iso` in the VM's CD drive, open the *UTM Guest Kit* disc in the guest,
double-click **Install.command**, enter your password, restart.

The installer keeps Apple's original `GLEngine` (backup under
`/Library/Application Support/UTM Intel Guest Kit/` and as `GLEngineStock`, which
VirtualIntelMac's engine uses for software fallback). Undo with
`sudo sh /Volumes/UTM\ Guest\ Kit/Install.command --uninstall`.

## Clipboard sharing

Install.command also installs two of VirtualIntelMac's guest helpers:

- its root guest agent (`opengl-guest-agent`, started by
  `/Library/LaunchDaemons/com.utmapp.intel-guest-agent.plist`), which answers UTM on COM2;
- its text clipboard helper (`guest-clipboard`).

With **Sharing → Clipboard Sharing** on, UTM waits until a user is logged in, then asks the
agent to start the clipboard helper in that user's session. Plain text is copied both ways
(up to 1 MB) while UTM is the active app. Snow Leopard … High Sierra here; Mojave gets
VirtualIntelMac's modern helper from its own kit (see below).

The guest-side helpers are Intel builds only.

## File sharing

Not included. Earlier kits prepared the guest's SMB server for a UTM "Mac File Sharing"
option that has been removed; running this kit's Install.command (or `--uninstall`) puts
Apple's own `smbd` back and deletes those files.

## Not included (yet)

VirtualIntelMac's Remote Login, display power and automated setup helpers are not used.

## Machine settings UTM applies (as VirtualIntelMac)

For Intel Mac guests UTM sets:

- guest RAM in shared memory;
- no S3/S4 sleep states (Install.command also turns system sleep off with `pmset`);
- an Apple USB keyboard with the host keyboard's physical layout (ANSI, ISO or JIS);
- for Snow Leopard … High Sierra, a 1066 MHz DIMM speed in SMBIOS.

A `-usbdevice keyboard` in *QEMU → Arguments* adds a second, generic keyboard; remove it.

## Mojave (Apple Paravirtualized Graphics)

Mojave uses the **apple-gfx-pci** display instead of VMware SVGA, as in VirtualIntelMac 2.2.
The installer itself runs on VMware SVGA (the VirtualIntelMac `mojave` OpenCore disk).

```sh
./build-mojave-kit.sh [outdir]
```

Output `MojaveGuestKit/`: `MojaveSupport.iso` (VirtualIntelMac's Mojave support disc plus
`Install.command`). The host side ships inside UTM.app, as in VirtualIntelMac:
`Contents/Resources/pvg-donor` holds the ParavirtualizedGraphics binary that still speaks the
Intel guest protocol and Mojave's libLLVM shader repair (`scripts/build_dependencies.sh`).
The display helper is x86_64 and needs Rosetta.

1. Install Mojave with the VMware SVGA display; reach the desktop.
2. Insert `MojaveSupport.iso` in the removable CD drive, open **Install.command** in the guest,
   enter your password. It prepares, plans and installs VirtualIntelMac's graphics payload
   (several minutes under emulation).
3. Shut down, set the display to **apple-gfx-pci**, start the VM, open **Install.command**
   again: it verifies the installation on the paravirtualized device.

The disc also carries a fixed build of VirtualIntelMac's Mojave OpenGL engine (`GLFix/`,
built by the kit from VirtualIntelMac's sources with `vim-packed-vertex.patch`): without it,
GL 3.3/4.1 games that use packed vertex formats (SuperTuxKart 1.5) lose their 3D models.
Install.command installs it; on a guest that is already installed, running it again only
updates this engine and the clipboard helper. The disc carries VirtualIntelMac's modern text
clipboard helper (`Clipboard/guest-clipboard`); with **Sharing → Clipboard Sharing** on, UTM
adds a VirtIO console port `org.vim.clipboard` and starts the helper through the guest agent
once a user is logged in. The kit build needs Xcode or its Command Line Tools, and downloads the
macOS 10.9 SDK headers (checksum-pinned) for the guest engine's period ABI.

With apple-gfx-pci, UTM also adds VirtualIntelMac's OpenGL command transport
(`vim-gl-headless`), which the guest's GL engine selector uses for OpenGL. The guest starts
at the host display's resolution and offers common Mac sizes that fit in it
(System Preferences → Displays, Option-click *Scaled*).
