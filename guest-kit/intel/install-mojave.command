#!/bin/bash
# UTM Mojave guest kit: installs VirtualIntelMac's Mojave graphics payload
# (Apple Paravirtualized Graphics drivers) with VirtualIntelMac's own guest tools,
# in the order its app runs them through its guest agent (VIMGuestPreparation.m,
# VIMGuestInstallation.m, VirtualIntelMac 2.2).
#
#   Install.command            prepare + install, then restart
#   Install.command --verify   after the restart: confirm the installation
# Run again on an installed guest, it only updates the GL engine fix (GLFix/:
# VirtualIntelMac's Mojave GL pair with UTM's packed-vertex fix).
# It also installs VirtualIntelMac's clipboard helper (Clipboard/) when missing or changed.
set -euo pipefail
if [ "$(id -u)" != 0 ]; then
  echo "Administrator password needed."
  exec sudo /bin/bash "$0" "$@"
fi
LAST=/private/var/db/UTMMojaveKit.journal
json() { /usr/bin/python -c "import json,sys; print(json.load(sys.stdin).get(\"$1\", \"\"))" 2>/dev/null || true; }   # value from JSON on stdin (Python 2.7 ships with Mojave)
step() { echo; echo "==> $*"; }
DISC=$(cd "$(dirname "$0")" && pwd)
BUNDLE=/System/Library/Frameworks/OpenGL.framework/Versions/A/Resources/GLEngine.bundle
BACKUP="/Library/Application Support/UTM Mojave Kit"

# Replace the installed PassthroughOpenGL engine pair with the disc's fixed one.
gl_fix() {
  [ -f "$DISC/GLFix/GLEngine" ] && [ -f "$BUNDLE/GLEnginePassthrough" ] || return 0
  if cmp -s "$DISC/GLFix/GLEngine" "$BUNDLE/GLEnginePassthrough" &&
     cmp -s "$DISC/GLFix/libVIMPassthroughOpenGL.dylib" "$BUNDLE/libVIMPassthroughOpenGL.dylib"; then
    echo "The OpenGL engine fix is already installed."; return 0
  fi
  step "Installing the OpenGL engine fix"
  mkdir -p "$BACKUP"
  [ -f "$BACKUP/GLEnginePassthrough" ] || cp -p "$BUNDLE/GLEnginePassthrough" "$BUNDLE/libVIMPassthroughOpenGL.dylib" "$BACKUP/"
  cp "$DISC/GLFix/GLEngine" "$BUNDLE/GLEnginePassthrough.new" &&
    cp "$DISC/GLFix/libVIMPassthroughOpenGL.dylib" "$BUNDLE/libVIMPassthroughOpenGL.dylib.new" || {
    rm -f "$BUNDLE/"*.new
    echo "Could not write to the OpenGL framework (System Integrity Protection?)." >&2; exit 1; }
  chown root:wheel "$BUNDLE/"*.new; chmod 755 "$BUNDLE/"*.new
  mv -f "$BUNDLE/libVIMPassthroughOpenGL.dylib.new" "$BUNDLE/libVIMPassthroughOpenGL.dylib"
  mv -f "$BUNDLE/GLEnginePassthrough.new" "$BUNDLE/GLEnginePassthrough"
  echo "OpenGL engine fix installed (originals in $BACKUP). Quit and reopen OpenGL apps."
}

# Put the clipboard helper where UTM's guest agent runs it (UTM: Sharing -> Clipboard Sharing).
CLIP="/Library/Application Support/Virtual Intel Mac/GuestTools"
clipboard_helper() {
  [ -f "$DISC/Clipboard/guest-clipboard" ] || return 0
  cmp -s "$DISC/Clipboard/guest-clipboard" "$CLIP/guest-clipboard" && return 0
  step "Installing the clipboard helper"
  mkdir -p "$CLIP"
  cp "$DISC/Clipboard/guest-clipboard" "$CLIP/guest-clipboard.new"
  chown root:wheel "$CLIP/guest-clipboard.new"; chmod 755 "$CLIP/guest-clipboard.new"
  mv -f "$CLIP/guest-clipboard.new" "$CLIP/guest-clipboard"
  echo "Clipboard helper installed; it starts once you are logged in."
}

# A pending installation from the previous run: this run is the after-restart check.
if [ "${1:-}" = "--verify" ] || { [ -s "$LAST" ] && [ -f "$(cat "$LAST")" ] && \
     [ "$("$(dirname "$(cat "$LAST")")/guest-install" --status "$(cat "$LAST")" | json Phase)" = "awaiting-reboot" ]; }; then
  J=$(cat "$LAST")
  step "Verifying the installation after restart"
  "$(dirname "$J")/guest-install" --verify-after-reboot "$J"; rm -f "$LAST"
  gl_fix
  clipboard_helper
  echo; echo "Done. The Mojave graphics drivers are installed and verified."
  exit 0
fi

# Already installed (and verified): only bring the GL engine fix up to date.
if [ -f "$BUNDLE/GLEnginePassthrough" ]; then
  gl_fix
  clipboard_helper
  exit 0
fi

S=$(mktemp -d /private/var/tmp/VirtualIntelMac.XXXXXX)
echo "Staging: $S"
cp "$DISC/guest-macho" "$DISC/guest-progress" "$S/"
cp "$DISC/SupportIcon.png" "$S/"
chmod 0700 "$S/guest-macho"; chmod 0600 "$S/guest-progress" "$S/SupportIcon.png"

step "Copying and verifying the support files"
R=$("$S/guest-macho" stage-media mojave "$S")
echo "$R"
ARCHIVE=$(echo "$R" | json Archive)
DEV=$(echo "$R" | json MediaDevice)
[ -n "$ARCHIVE" ] || { echo "stage-media failed" >&2; exit 1; }
# VirtualIntelMac releases the disc before anything is unpacked.
[ -n "$DEV" ] && /usr/sbin/diskutil unmount "$DEV" || true

chmod 0700 "$S/guest-prepare" "$S/guest-image-patch" "$S/guest-install" "$S/codesign_allocate"
step "Checking the guest"
"$S/guest-install" --check-environment
step "Unpacking"
"$S/guest-prepare" --extract "$S/$ARCHIVE" "$S/Extracted"
step "Preparing this macOS build's graphics files"
"$S/guest-prepare" / "$S/Extracted/payload" "$S"
step "Planning the installation"
J="$S/InstallTransaction.plist"
"$S/guest-install" --plan / "$S/Extracted/payload" "$J"
step "Installing"
echo "$J" > "$LAST"
"$S/guest-install" --apply "$J" || true
R=$("$S/guest-install" --status "$J")
echo "$R"
if [ "$(echo "$R" | json Phase)" != "awaiting-reboot" ]; then
  echo "Installation did not complete (see above)." >&2; exit 1
fi
clipboard_helper
echo
echo "Installed. Shut down, switch the VM display to apple-gfx-pci in UTM, start it, then open Install.command again."
