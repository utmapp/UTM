#!/usr/bin/env python3
"""Unpack a MacBinary file into a macOS file with both forks and Finder type/creator, so
hdiutil makehybrid -hfs puts a real Mac OS 9 file (resource fork, type 'shlb') on the ISO."""
import subprocess
import sys

src, dst = sys.argv[1], sys.argv[2]
raw = open(src, 'rb').read()
if raw[0] != 0 or raw[74] != 0 or not 1 <= raw[1] <= 63:
    sys.exit('not a MacBinary file: ' + src)
ftype, creator = raw[65:69], raw[69:73]
flags = (raw[73] << 8) | raw[101]
dlen = int.from_bytes(raw[83:87], 'big')
rlen = int.from_bytes(raw[87:91], 'big')
pad = lambda n: (n + 127) // 128 * 128
data = raw[128:128 + dlen]
rsrc = raw[128 + pad(dlen):128 + pad(dlen) + rlen]
open(dst, 'wb').write(data)
# FinderInfo: type, creator, flags, location (zeros), rest zeros
finfo = ftype + creator + (flags & 0xFEFF).to_bytes(2, 'big') + bytes(32 - 10)
subprocess.check_call(['xattr', '-wx', 'com.apple.FinderInfo', finfo.hex(), dst])
if rlen:
    subprocess.check_call(['xattr', '-wx', 'com.apple.ResourceFork', rsrc.hex(), dst])
print('%s: type %r creator %r data %d rsrc %d' % (dst, ftype, creator, dlen, rlen))
