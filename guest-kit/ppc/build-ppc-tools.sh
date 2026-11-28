#!/bin/bash
# Builds VirtualIntelMac 2.2's guest agent and clipboard helper (MIT) for Mac OS X 10.4/10.5
# PowerPC, inside ghcr.io/variantxyz/gcc-powerpc-apple-darwin8 (GCC 14.2 + cctools + 10.4u SDK).
# vim-ppc.patch makes the sources GCC-compatible (no clang-only Objective-C syntax) and moves
# them from VMware SVGA/COM ports to the PCI serial ports UTM gives PowerPC Mac guests.
# Usage: build-ppc-tools.sh OUTPUT_DIR
set -euo pipefail
OUT=${1:?output dir}; HERE=$(cd "$(dirname "$0")" && pwd)
VIM_REPO=https://github.com/nfzerox/VirtualIntelMacOnAppleSilicon.git
VIM_COMMIT=2861da9e265e557aef90319e4451487ed1fed553   # VirtualIntelMac 2.2
SDK=/usr/local/MacOSX10.4u.sdk; CC=powerpc-apple-darwin8-gcc
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
git clone -q --filter=blob:none --no-checkout "$VIM_REPO" "$WORK/vim"
git -C "$WORK/vim" checkout -q "$VIM_COMMIT" -- Source/tools Source/vendor/source/JSONKit LICENSE
S="$WORK/vim/Source"
git -C "$WORK/vim" apply "$HERE/vim-ppc.patch"
python3 "$HERE/desugar-objc.py" "$S"/tools/*.m "$S"/tools/*.h
mkdir -p "$OUT" "$WORK/obj"
FLAGS=(-mmacosx-version-min=10.4 -isysroot "$SDK" -O2 -std=gnu11 -fnext-runtime -fobjc-exceptions -fno-common -Wno-deprecated-declarations)
OBJC=(-x objective-c -include "$HERE/utm-ppc-prefix.h" -include "$S/tools/opengl-period-foundation.h")
status=0
c() { echo "+ $*"; "$CC" "$@" || status=1; }
c "${FLAGS[@]}" -x objective-c -w -c "$S/vendor/source/JSONKit/JSONKit.m" -o "$WORK/obj/JSONKit.o"
c "${FLAGS[@]}" "${OBJC[@]}" -c "$S/tools/opengl-period-foundation.m" -o "$WORK/obj/period.o"
c "${FLAGS[@]}" -x objective-c -c "$HERE/utm-ppc-runtime.m" -o "$WORK/obj/runtime.o"
c "${FLAGS[@]}" "${OBJC[@]}" -DUTM_PPC_GUEST=1 -c "$S/tools/opengl-guest-agent.m" -o "$WORK/obj/agent.o"
c "${FLAGS[@]}" "${OBJC[@]}" -DUTM_PPC_GUEST=1 -DVIM_OPENGL_GUEST=1 -c "$S/tools/guest-clipboard.m" -o "$WORK/obj/clipboard.o"
c "${FLAGS[@]}" "${OBJC[@]}" -DUTM_PPC_GUEST=1 -c "$S/tools/opengl-tiger-console.m" -o "$WORK/obj/console.o"
[ $status = 0 ] || { echo "compile failed"; exit 1; }
L=(-mmacosx-version-min=10.4 -isysroot "$SDK")
c "${L[@]}" "$WORK/obj/agent.o" "$WORK/obj/period.o" "$WORK/obj/JSONKit.o" "$WORK/obj/runtime.o" -framework Foundation -framework IOKit \
  -framework CoreFoundation -framework SystemConfiguration -framework DiskArbitration -o "$OUT/opengl-guest-agent"
c "${L[@]}" "$WORK/obj/clipboard.o" "$WORK/obj/period.o" "$WORK/obj/JSONKit.o" "$WORK/obj/runtime.o" -framework AppKit -framework IOKit \
  -framework Foundation -o "$OUT/guest-clipboard"
c "${L[@]}" "$WORK/obj/console.o" "$WORK/obj/period.o" "$WORK/obj/JSONKit.o" "$WORK/obj/runtime.o" -framework Foundation -framework IOKit \
  -o "$OUT/opengl-tiger-console"
[ $status = 0 ] || { echo "link failed"; exit 1; }
cp "$WORK/vim/LICENSE" "$OUT/LICENSE-VirtualIntelMac.txt"
file "$OUT"/*
