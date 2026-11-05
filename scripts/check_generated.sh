#!/bin/sh
# Regenerate the committed generated sources and report whether they are current.
#
# Scripting/UTMScripting.swift comes from scripts/bridge-gen.sh, which needs sdp
# and a python 2.7 from pyenv, clones SwiftScripting into scripts/SwiftScripting
# on first use (ignored by git) and writes its .python-version there. Its
# Standard Suite part is taken from the host's CocoaStandard.sdef, so compare on
# the macOS the release is built on: a difference confined to the standard
# commands (open, print, quit, exists, close, delete, duplicate) is the host,
# not drift. Tests/Static/check_scripting_bridge.py is the host-independent
# check of the UTM part and runs in CI; this script is the exact comparison.
#
# Configuration/QEMUConstantGenerated.swift comes from scripts/const-gen.py and
# needs a QEMU build directory holding the qemu-system-*-unsigned executables,
# so it is only checked when one is given.
#
# Exit status: 0 current, 1 a file is out of date, 2 a file could not be
# regenerated (and none was found out of date).
#
# Usage: scripts/check_generated.sh [--qemu-build <dir>]

set -u
cd "$(dirname "$0")/.."

QEMU_BUILD=""
while [ $# -gt 0 ]; do
    case "$1" in
        --qemu-build)
            if [ $# -lt 2 ]; then echo "usage: $0 [--qemu-build <dir>]" >&2; exit 2; fi
            QEMU_BUILD="$2"; shift 2 ;;
        -h|--help) echo "usage: $0 [--qemu-build <dir>]"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; echo "usage: $0 [--qemu-build <dir>]" >&2; exit 2 ;;
    esac
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
stale=0
unchecked=0

compare() {
    # compare <committed file> <regenerated file> <how to regenerate>
    if diff -u "$1" "$2" > "$TMP/diff"; then
        echo "$1 is current"
    else
        echo "$1 is out of date; regenerate it with: $3"
        cat "$TMP/diff"
        stale=1
    fi
}

if command -v pyenv >/dev/null 2>&1 && pyenv versions --bare 2>/dev/null | grep -q '^2\.7'; then
    echo "regenerating Scripting/UTMScripting.swift"
    # bridge-gen.sh selects python 2.7 through pyenv, which needs its shims on the path
    if PATH="$(pyenv root)/shims:$PATH" sh scripts/bridge-gen.sh > "$TMP/UTMScripting.swift" 2> "$TMP/bridge-gen.log"; then
        compare Scripting/UTMScripting.swift "$TMP/UTMScripting.swift" "scripts/bridge-gen.sh > Scripting/UTMScripting.swift"
    else
        echo "could not regenerate Scripting/UTMScripting.swift:" >&2
        cat "$TMP/bridge-gen.log" >&2
        unchecked=1
    fi
else
    echo "skipping Scripting/UTMScripting.swift: scripts/bridge-gen.sh needs pyenv with python 2.7" >&2
    unchecked=1
fi

if [ -n "$QEMU_BUILD" ]; then
    echo "regenerating Configuration/QEMUConstantGenerated.swift from $QEMU_BUILD"
    if python3 scripts/const-gen.py "$QEMU_BUILD" > "$TMP/QEMUConstantGenerated.swift" 2> "$TMP/const-gen.log"; then
        compare Configuration/QEMUConstantGenerated.swift "$TMP/QEMUConstantGenerated.swift" "scripts/const-gen.py $QEMU_BUILD > Configuration/QEMUConstantGenerated.swift"
    else
        echo "could not regenerate Configuration/QEMUConstantGenerated.swift (is $QEMU_BUILD a QEMU build directory?):" >&2
        cat "$TMP/const-gen.log" >&2
        unchecked=1
    fi
else
    echo "skipping Configuration/QEMUConstantGenerated.swift: pass --qemu-build <dir> to check it" >&2
fi

if [ $stale -ne 0 ]; then exit 1; fi
if [ $unchecked -ne 0 ]; then exit 2; fi
exit 0
