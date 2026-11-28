# PowerPC Mac OS X guest kit (Tiger, Leopard)

VirtualIntelMac's guest agent and text clipboard helper
([VirtualIntelMacOnAppleSilicon](https://github.com/nfzerox/VirtualIntelMacOnAppleSilicon), MIT,
release 2.2), built for Mac OS X 10.4/10.5 PowerPC. The workflow `ppc-guest-tools.yml` builds
them; nothing is compiled on the Mac.

## How it is built

- Toolchain: the `ghcr.io/variantxyz/gcc-powerpc-apple-darwin8` image (GCC 14.2 with
  Objective-C, cctools-port, Mac OS X 10.4u SDK) on a Linux runner.
- `desugar-objc.py` rewrites the clang-only Objective-C syntax in VirtualIntelMac's sources
  (object literals, boxed expressions, `@autoreleasepool`, class dot syntax) into classic
  Objective-C that GCC accepts. `utm-ppc-prefix.h` and `utm-ppc-runtime.m` supply what that
  needs, plus the property accessors Tiger's runtime lacks.
- `vim-ppc.patch` moves the helpers from VMware SVGA and the PC COM ports to the PCI serial
  ports UTM adds (QEMU `pci-serial`, vendor 1b36:0002). On PowerPC the PCI properties are
  big-endian.

## How it connects

UTM gives Radeon 9700 (Mac OS X 10.3–10.5) VMs two PCI serial ports. Tiger and Leopard load
Apple16X50Serial for them and name them `/dev/cu.pci-serialNN`, where NN is the decimal PCI
slot:

| Slot | Device | Use |
|------|--------|-----|
| 0x1d | `/dev/cu.pci-serial29` | guest agent (QGA protocol), always present |
| 0x1e | `/dev/cu.pci-serial30` | clipboard, with *Sharing → Clipboard Sharing* on |

This works with any VM network mode. Mac OS X 10.2 (and earlier) has no PCI serial driver, so
the helpers can't run there. 10.3 is untested.

## Install

Mount `GuestTools.iso`, open **Install.command**, and enter your password. Undo it with
`sudo sh Install.command --uninstall`.
