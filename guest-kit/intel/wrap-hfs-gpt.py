#!/usr/bin/env python3
"""Wrap an HFS+ volume in a GPT disk image, as VirtualIntelMac 2.2 does for
installers whose recovery image uses an Apple partition map
(VIMInstallerAssembly.m: extractWorkingHFSVolume + VIMWrapHFSInstallerDisk):
the volume bytes and UUID are kept, and the partition gets the Apple_HFS type
so OVMF/OpenCore and the 10.x kernel find it as a boot disk.

  wrap-hfs-gpt.py SOURCE OFFSET SIZE OUTPUT
SOURCE: raw image holding the volume at byte OFFSET with SIZE bytes.
"""
import struct, sys, uuid, zlib

SECTOR = 512
FIRST = 40  # Apple's first partition LBA
HFS_TYPE = uuid.UUID("48465300-0000-11AA-AA11-00306543ECAC")


def header(lba, alt, first_usable, last_usable, disk_guid, entries_lba, entries_crc):
    fields = [b"EFI PART", 0x00010000, 92, 0, 0, lba, alt, first_usable, last_usable,
              disk_guid.bytes_le, entries_lba, 128, 128, entries_crc]
    raw = struct.pack("<8sIIIIQQQQ16sQIII", *fields)
    fields[3] = zlib.crc32(raw) & 0xFFFFFFFF
    raw = struct.pack("<8sIIIIQQQQ16sQIII", *fields)
    return raw.ljust(SECTOR, b"\0")


def main():
    src, offset, size, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    if size % SECTOR or offset % SECTOR:
        sys.exit("offset and size must be sector multiples")
    vol_sectors = size // SECTOR
    last_part = FIRST + vol_sectors - 1
    total = last_part + 1 + 33 + 7  # backup entries + header, small tail
    last_lba = total - 1
    disk_guid, part_guid = uuid.uuid4(), uuid.uuid4()

    entry = struct.pack("<16s16sQQQ72s", HFS_TYPE.bytes_le, part_guid.bytes_le,
                        FIRST, last_part, 0, "Install OS X".encode("utf-16-le"))
    entries = entry.ljust(128 * 128, b"\0")
    ecrc = zlib.crc32(entries) & 0xFFFFFFFF

    mbr = bytearray(SECTOR)
    mbr[446:462] = struct.pack("<B3sB3sII", 0, b"\0\x02\0", 0xEE, b"\xff\xff\xff",
                               1, min(total - 1, 0xFFFFFFFF))
    mbr[510:512] = b"\x55\xaa"

    with open(src, "rb") as s, open(out, "wb") as o:
        o.write(mbr)
        o.write(header(1, last_lba, 34, last_lba - 33, disk_guid, 2, ecrc))
        o.write(entries)
        o.write(b"\0" * ((FIRST - 34) * SECTOR))
        s.seek(offset)
        left = size
        while left:
            chunk = s.read(min(left, 64 << 20))
            if not chunk:
                sys.exit("source ended early")
            o.write(chunk)
            left -= len(chunk)
        o.write(b"\0" * ((last_lba - 33 - last_part) * SECTOR))
        o.write(entries)
        o.write(header(last_lba, 1, 34, last_lba - 33, disk_guid, last_lba - 32, ecrc))
    print(f"{out}: GPT, Apple_HFS at LBA {FIRST}, {vol_sectors} sectors, {total} total")


if __name__ == "__main__":
    main()
