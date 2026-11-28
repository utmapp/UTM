#!/bin/bash
# Mojave guest kit for UTM's "apple-gfx-pci" display (Apple Paravirtualized Graphics).
#
# Builds, from VirtualIntelMacOnAppleSilicon (MIT) at a pinned commit, with its own
# packaging scripts (nothing is compiled):
#   MojaveSupport.iso  - VirtualIntelMac's Mojave guest support disc (graphics payload,
#                        guest-macho/-prepare/-install tools) plus Install.command.
#                        Its GL engine pair carries UTM's packed-vertex fix
#                        (vim-packed-vertex.patch), rebuilt here for x86_64.
# The host side (the ParavirtualizedGraphics donor and Mojave's libLLVM) ships inside
# UTM.app (Contents/Resources/pvg-donor, scripts/build_dependencies.sh), as in VirtualIntelMac.
#
# Run on the Mac host:  ./build-mojave-kit.sh [outdir]
set -euo pipefail

VIM_REPO=https://github.com/nfzerox/VirtualIntelMacOnAppleSilicon.git
VIM_COMMIT=2861da9e265e557aef90319e4451487ed1fed553   # VirtualIntelMac 2.2

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=""
for a in "$@"; do
  case "$a" in
    -*) echo "usage: $0 [output-dir] " >&2; exit 64 ;;
    *) OUT=$a ;;
  esac
done
OUT=${OUT:-"$PWD/MojaveGuestKit"}
[ -e "$OUT" ] && { echo "$OUT already exists" >&2; exit 1; }

# VirtualIntelMac's payload scripts need Python >= 3.12 (tarfile.data_filter).
PY=""
for c in python3.14 python3.13 python3.12 python3; do
  p=$(command -v "$c" || true)
  [ -n "$p" ] && "$p" -c 'import sys; sys.exit(sys.version_info < (3, 12))' && { PY=$p; break; }
done
[ -n "$PY" ] || { echo "Python 3.12 or newer is required (brew install python)" >&2; exit 1; }
command -v xcrun >/dev/null && xcrun -f clang >/dev/null 2>&1 || {
  echo "Xcode or its Command Line Tools are required (xcode-select --install)" >&2; exit 1; }

# Period SDK headers for the guest GL engine (the build targets Mojave's GLI ABI)
SDK_URL=https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX10.9.sdk.tar.xz
SDK_SHA256=fcf88ce8ff0dd3248b97f4eb81c7909f2cc786725de277f4d05a2b935cc49de0

WORK=$(mktemp -d -t mojave-guest-kit)
trap 'rm -rf "$WORK"' EXIT

echo "==> Fetching VirtualIntelMac $VIM_COMMIT (only the files the kit needs)"
git clone -q --filter=blob:none --no-checkout "$VIM_REPO" "$WORK/vim"
git -C "$WORK/vim" checkout -q "$VIM_COMMIT" -- \
  Source/scripts Source/prebuilt/mojave Source/prebuilt/guest-payload.tar.xz \
  Source/prebuilt/iosurface Source/prebuilt/catalina-gl Source/prebuilt/audio Source/prebuilt/bigsur \
  Source/prebuilt/PassthroughOpenGL/mojave Source/prebuilt/tools Source/PassthroughOpenGL \
  Source/vendor/source/VMsvga2 Source/vendor/qemu/include/hw/display Source/vendor/qemu/hw/display/vim-vram-memory.h \
  Source/probes/opengl-packet-journal.inc \
  Source/VirtualIntelMac/Assets.xcassets/mojaveIcon.imageset/art.png LICENSE
SRC="$WORK/vim/Source"

echo "==> Building the Mojave support disc (VirtualIntelMac package-app-guest-payloads.py)"
mkdir -p "$WORK/tools"
for t in guest-macho guest-image-patch guest-prepare guest-install guest-progress codesign_allocate; do
  cp "$SRC/prebuilt/tools/$t" "$WORK/tools/"
done
cp "$SRC/VirtualIntelMac/Assets.xcassets/mojaveIcon.imageset/art.png" "$WORK/tools/mojave-support-icon.png"
"$PY" -I - "$SRC" "$WORK/payloads" "$WORK/tools" <<'PY'
import plistlib, runpy, sys
from pathlib import Path
src, payloads, tools = map(Path, sys.argv[1:])
runpy.run_path(str(src/'scripts/package-app-guest-payloads.py'))['build'](src, payloads)
# Keep Mojave only; the recipe also emits the other modern guests.
manifest = plistlib.loads((payloads/'Payloads.plist').read_bytes())
for guest, record in list(manifest['Guests'].items()):
    if guest != 'mojave':
        (payloads/record['Archive']).unlink()
        del manifest['Guests'][guest]
(payloads/'Payloads.plist').write_bytes(plistlib.dumps(manifest, sort_keys=True))
runpy.run_path(str(src/'scripts/package-guest-support-media.py'))['build'](payloads, tools)
PY

# VirtualIntelMac's guest GL engine sizes packed vertex attributes
# (GL_INT_2_10_10_10_REV) as zero and rejects draws that use them, so GL 3.3/4.1
# games such as SuperTuxKart lose their 3D meshes. Rebuild the x86_64 slice of
# the Mojave GL pair with the fix (VIM's build-opengl-guest-gl-pair steps); the
# i386 slice stays VIM's own.
echo "==> Building the Mojave GL engine fix (x86_64)"
curl -sfL -o "$WORK/sdk.tar.xz" "$SDK_URL"
echo "$SDK_SHA256  $WORK/sdk.tar.xz" | shasum -a 256 -c - >/dev/null || { echo "10.9 SDK checksum mismatch" >&2; exit 1; }
tar -xf "$WORK/sdk.tar.xz" -C "$WORK"
patch -s -d "$WORK/vim" -p1 < "$HERE/vim-packed-vertex.patch"
PAIR="$WORK/glpair"; mkdir -p "$PAIR"
"$PY" -I "$SRC/scripts/generate-passthrough-opengl.py" "$WORK/MacOSX10.9.sdk" "$PAIR" >/dev/null
"$PY" -I "$SRC/scripts/generate-opengl-gli.py" "$PAIR/passthrough-opengl-gli-map.json" \
  "$PAIR/passthrough-opengl-gli-generated.inc" --runtime-dispatch-count 975 >/dev/null
grep -Fxq '#define VIM_GLI_DISPATCH_COUNT 975' "$PAIR/passthrough-opengl-gli-generated.inc" || {
  echo "unexpected Mojave GLI dispatch layout" >&2; exit 1; }
CC=$(xcrun -f clang)
GLFLAGS=(-O2 -g -fno-omit-frame-pointer -Wno-deprecated-declarations -Wno-unused-function -arch x86_64
  -isysroot "$WORK/MacOSX10.9.sdk" -mmacosx-version-min=10.14 -I "$PAIR" -I "$PAIR/PeriodABI")
"$CC" "${GLFLAGS[@]}" -dynamiclib "$SRC/PassthroughOpenGL/passthrough-opengl-client.c" \
  -Wl,-install_name,@rpath/libVIMPassthroughOpenGL.dylib -framework IOKit -framework CoreFoundation \
  -o "$PAIR/libVIMPassthroughOpenGL.dylib"
"$CC" "${GLFLAGS[@]}" -DVIM_PASSTHROUGH_OPENGL_BACKEND=1 -dynamiclib -fvisibility=hidden \
  "$SRC/PassthroughOpenGL/passthrough-opengl-gli.c" "$PAIR/libVIMPassthroughOpenGL.dylib" \
  -Wl,-install_name,@rpath/libVIMGLI.dylib -Wl,-exported_symbols_list,"$SRC/PassthroughOpenGL/gli.exports" \
  -Wl,-rpath,@loader_path -framework CoreFoundation -framework CoreGraphics -framework IOKit -framework IOSurface \
  -o "$PAIR/GLEngine"
install_name_tool -change @rpath/libVIMPassthroughOpenGL.dylib @loader_path/libVIMPassthroughOpenGL.dylib "$PAIR/GLEngine"
mkdir -p "$WORK/glfix"
for f in GLEngine libVIMPassthroughOpenGL.dylib; do
  lipo "$SRC/prebuilt/PassthroughOpenGL/mojave/GuestTools/$f" -replace x86_64 "$PAIR/$f" -output "$WORK/glfix/$f"
  codesign --force --sign - --digest-algorithm=sha1,sha256 "$WORK/glfix/$f"
done

# VirtualIntelMac inserts the disc and drives the tools through its guest agent;
# here Install.command (run by the user in the guest) issues the same commands.
echo "==> Adding Install.command"
DISC="$WORK/disc"; mkdir -p "$DISC"
M=$(hdiutil attach -readonly -nobrowse "$WORK/payloads/mojave.iso" | awk -F'\t' '/Volumes/{print $NF}')
ditto "$M" "$DISC"; hdiutil detach -quiet "$M"
cp "$HERE/install-mojave.command" "$DISC/Install.command"; chmod 755 "$DISC/Install.command"
cp "$WORK/vim/LICENSE" "$DISC/LICENSE-VirtualIntelMac.txt"
mkdir -p "$DISC/GLFix"; cp "$WORK/glfix/"* "$DISC/GLFix/"
# VirtualIntelMac's text clipboard helper for modern guests (VirtIO console port
# org.vim.clipboard); UTM provisions it through the guest agent, as VirtualIntelMac does.
mkdir -p "$DISC/Clipboard"; cp "$SRC/prebuilt/tools/guest-clipboard" "$DISC/Clipboard/"
chmod 755 "$DISC/Clipboard/guest-clipboard"
hdiutil makehybrid -quiet -hfs -iso -joliet -hfs-volume-name 'Virtual Intel Mac Support' \
  -o "$WORK/MojaveSupport.iso" "$DISC"

mkdir -p "$OUT"
mv "$WORK/MojaveSupport.iso" "$OUT/"
echo "$VIM_COMMIT" > "$OUT/VirtualIntelMac-commit.txt"
echo "==> Done: $OUT"
ls -l "$OUT"
