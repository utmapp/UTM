#!/usr/bin/env python3
"""Lower LC_LOAD_DYLIB compatibility versions that a newer SDK stub recorded above what
Snow Leopard ships (ApplicationServices 64.0.0 vs 1.0.0). Patches every x86_64/i386 slice in place."""
import struct, sys
FIX = {b"/System/Library/Frameworks/ApplicationServices.framework/Versions/A/ApplicationServices": 0x10000}
def thin(buf, off):
    magic, = struct.unpack_from("<I", buf, off)
    is64 = magic == 0xfeedfacf
    assert magic in (0xfeedface, 0xfeedfacf)
    ncmds, = struct.unpack_from("<I", buf, off + 16)
    p = off + (32 if is64 else 28)
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", buf, p)
        if cmd in (0xc, 0x18 | 0x80000000, 0x1f | 0x80000000):
            name_off, _, cur, compat = struct.unpack_from("<IIII", buf, p + 8)
            name = bytes(buf[p + name_off:p + size]).split(b"\0")[0]
            if name in FIX and compat > FIX[name]:
                struct.pack_into("<I", buf, p + 20, FIX[name]); print("fixed", name.decode(), hex(compat), "->", hex(FIX[name]))
        p += size
for path in sys.argv[1:]:
    buf = bytearray(open(path, "rb").read())
    if struct.unpack_from(">I", buf, 0)[0] == 0xcafebabe:
        n, = struct.unpack_from(">I", buf, 4)
        for i in range(n):
            _, _, off, _, _ = struct.unpack_from(">IIIII", buf, 8 + 20 * i); thin(buf, off)
    else: thin(buf, 0)
    open(path, "wb").write(buf)
