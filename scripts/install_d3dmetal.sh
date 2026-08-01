#!/bin/sh
set -e

usage () {
    echo "Usage: $(basename $0) sysroot-dir [dmg-url]"
    echo ""
    echo "  sysroot-dir  Sysroot to install into, e.g. sysroot-macOS-arm64_x86_64."
    echo "  dmg-url      D3DMetal distribution DMG, either a URL or a local path."
    echo ""
    echo "Installs D3DMetal.framework into <sysroot-dir>/Frameworks, rebranded to"
    echo "BUNDLE_ID below and ad-hoc signed. Does nothing if no URL is given."
    echo ""
    exit 1
}

# D3DMetal loads its own default.metallib through
#     [NSBundle bundleWithIdentifier:@"com.apple.D3DMetal"]
# using that identifier as a literal compiled into the framework binary. We must
# not ship a com.apple.* bundle, so the identifier is rewritten in BOTH the
# Info.plist and the binary -- rewriting only one makes the lookup return nil and
# every D3DMetal process aborts in -[MTLDevice newLibraryWithFile:nil error:].
APPLE_BUNDLE_ID=com.apple.D3DMetal
BUNDLE_ID=com.elppa.D3DMetal

if [ $# -lt 1 ]; then
    usage
fi

SYSROOT_DIR="$1"
DMG_URL="$2"

if [ -z "$DMG_URL" ]; then
    echo "note: no D3DMetal DMG URL given, skipping"
    exit 0
fi

if [ ${#APPLE_BUNDLE_ID} -ne ${#BUNDLE_ID} ]; then
    echo "error: $BUNDLE_ID must be ${#APPLE_BUNDLE_ID} bytes to patch in place" >&2
    exit 1
fi

FRAMEWORK="$SYSROOT_DIR/Frameworks/D3DMetal.framework"
MOUNT="$PWD/d3dmetal-mount"
DMG="$PWD/d3dmetal.dmg"

# Rewrite every occurrence of $1 with $2 in the binary $3, in place. Fails if the
# identifier is absent, so a future D3DMetal that drops it cannot ship silently.
patch_binary_identifier () {
    LC_ALL=C perl -0777 -i -pe '
        BEGIN { $old = shift @ARGV; $new = shift @ARGV }
        $found += s/\Q$old\E/$new/g;
        END { die "error: $old not found in $ARGV\n" unless $found }
    ' "$1" "$2" "$3"
}

if [ -f "$DMG_URL" ]; then
    DMG="$DMG_URL"
else
    curl -f -L -o "$DMG" "$DMG_URL"
fi

# The distribution DMG carries a license agreement, which hdiutil prompts for on
# stdin unless we answer it.
mkdir -p "$MOUNT"
yes | PAGER=cat hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$MOUNT" "$DMG"
trap 'hdiutil detach "$MOUNT" -quiet || true' EXIT

mkdir -p "$SYSROOT_DIR/Frameworks"
rm -rf "$FRAMEWORK"
ditto "$MOUNT/redist/lib/external/D3DMetal.framework" "$FRAMEWORK"
xattr -drs com.apple.quarantine "$FRAMEWORK"

patch_binary_identifier "$APPLE_BUNDLE_ID" "$BUNDLE_ID" "$FRAMEWORK/Versions/A/D3DMetal"
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$FRAMEWORK/Resources/Info.plist"

# Signs after the rewrite so the signing identifier is derived from the new
# Info.plist and the two agree.
codesign --force --sign - "$FRAMEWORK"

echo "installed D3DMetal $(plutil -extract CFBundleShortVersionString raw "$FRAMEWORK/Resources/version.plist") as $BUNDLE_ID into $FRAMEWORK"
