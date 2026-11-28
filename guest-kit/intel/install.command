#!/bin/sh
# Installs VirtualIntelMac's PassthroughOpenGL guest payload into this Mac OS X guest.
# Same file layout as VirtualIntelMac's opengl-install-bootstrap (Installed()):
#   GLEngine.bundle/GLEngine + libVIMPassthroughOpenGL.dylib  <- PassthroughOpenGL engine
#   GLEngineStock.bundle/GLEngineStock                       <- Apple's original engine (software fallback)
#   /System/Library/Extensions/VMsvga2GA.plugin                <- 2D acceleration plugin
#   VirtualIntelMac's display-density agent (Mavericks): 2x mode after a window resize
# Usage: double-click (asks for your password), or: sudo sh Install.command [--uninstall]
GUEST=@GUEST@
VERSION=@VERSION@

if [ "$(id -u)" != 0 ]; then
  echo "Administrator password needed to install the graphics drivers."
  exec sudo /bin/sh "$0" "$@"
fi
# Trace every step into a log, so a failure never goes unexplained.
LOG="/Library/Logs/UTM Guest Kit Install.log"
if [ -z "${UTM_KIT_TRACED:-}" ]; then
  echo "=== $(date) $0 $*" >>"$LOG"
  UTM_KIT_TRACED=1 /bin/sh -x "$0" "$@" 2>>"$LOG"
  rc=$?
  [ "$rc" = 0 ] || echo "Installation FAILED (status $rc). Details: $LOG"
  exit "$rc"
fi
set -e
KIT=$(cd "$(dirname "$0")" && pwd)
RES=/System/Library/Frameworks/OpenGL.framework/Versions/A/Resources
ENG=$RES/GLEngine.bundle
STOCK=$RES/GLEngineStock.bundle
GA=/System/Library/Extensions/VMsvga2GA.plugin
STATE="/Library/Application Support/UTM Intel Guest Kit"
BUILD=$(sw_vers -buildVersion)
BACKUP="$STATE/OriginalGraphics/$BUILD/GLEngine"

case "$(sw_vers -productVersion)" in
  "$VERSION"|"$VERSION".*) ;;
  *) echo "This kit is for Mac OS X $VERSION ($GUEST); this Mac runs $(sw_vers -productVersion)."; exit 1 ;;
esac

sha() { [ -f "$1" ] && /usr/bin/openssl dgst -sha256 "$1" | awk '{print $NF}'; }
# The OpenCore disk holds only an EFI System Partition. Disk Arbitration has no
# filesystem for that partition type and reports the disk as unreadable at
# every boot. Like VirtualIntelMac's opengl-install-bootstrap ("registering the
# native non-mounting EFI filesystem probe"), add an msdos.fs media type for the
# ESP content hint: a copy of DOS_FAT_32 with autodiskmount off.
# VirtualIntelMac's display-density agent, at VirtualIntelMac's own path and label.
AGENT_DIR="/Library/Application Support/Virtual Intel Mac/GuestTools"
AGENT_PLIST=/Library/LaunchAgents/com.virtualintelmac.opengl-display.plist
# VirtualIntelMac's root agent and clipboard helper (UTM: Sharing -> Clipboard Sharing)
GUEST_AGENT_PLIST=/Library/LaunchDaemons/com.utmapp.intel-guest-agent.plist
MSDOS=/System/Library/Filesystems/msdos.fs/Contents/Info.plist
MSDOS_BACKUP="$STATE/OriginalFilesystemMetadata/msdos-Info.plist"
ESP=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
PB=/usr/libexec/PlistBuddy
register_esp_probe() {
  $PB -c "Print :FSMediaTypes:$ESP" "$MSDOS" >/dev/null 2>&1 && return 0
  [ "$($PB -c "Print :FSMediaTypes:DOS_FAT_32:FSMediaProperties:Content\ Hint" "$MSDOS" 2>/dev/null)" = DOS_FAT_32 ] || {
    echo "msdos.fs has no standard DOS_FAT_32 media type; EFI probe not registered."; return 0; }
  if [ ! -f "$MSDOS_BACKUP" ]; then
    mkdir -p "$(dirname "$MSDOS_BACKUP")"
    cp "$MSDOS" "$MSDOS_BACKUP"
  fi
  $PB -c "Copy :FSMediaTypes:DOS_FAT_32 :FSMediaTypes:$ESP" \
      -c "Set :FSMediaTypes:$ESP:FSMediaProperties:Content\ Hint $ESP" \
      -c "Add :FSMediaTypes:$ESP:autodiskmount bool false" "$MSDOS" >/dev/null
  chown root:wheel "$MSDOS"; chmod 644 "$MSDOS"
  [ "$($PB -c "Print :FSMediaTypes:$ESP:autodiskmount" "$MSDOS")" = false ] || {
    cp "$MSDOS_BACKUP" "$MSDOS"; echo "Verification failed: EFI probe"; exit 1; }
}
rebuild_caches() {
  touch /System/Library/Extensions
  /usr/sbin/kextcache -system-caches >/dev/null 2>&1 || true
}

# Earlier UTM kits prepared the guest's SMB server for UTM's Mac File Sharing (since removed).
# Put Apple's own smbd back and drop those files; nothing to do on a Mac that never had them.
remove_file_sharing() {
  # Snow Leopard: VirtualIntelMac's opengl-file-sharing replaced smbd and odsam.dylib and kept
  # Apple's originals, by OS build and SHA-256, in its LegacySetup state folder.
  FSSTATE=/private/var/db/VirtualIntelMac/LegacySetup
  FSJOB=/Library/LaunchDaemons/com.virtualintelmac.snowleopard-smb-compat.plist
  if [ -f "$FSJOB" ]; then
    launchctl unload "$FSJOB" 2>/dev/null || true
    rm -f "$FSJOB"
  fi
  if [ -f "$FSSTATE/FileSharing.plist" ]; then
    loaded=0
    launchctl list org.samba.smbd >/dev/null 2>&1 && loaded=1
    [ "$loaded" = 1 ] && launchctl unload /System/Library/LaunchDaemons/smbd.plist 2>/dev/null || true
    restored=1
    for pair in snowleopard-smbd:/usr/sbin/smbd snowleopard-odsam.dylib:/usr/lib/samba/auth/odsam.dylib; do
      name=${pair%%:*}; target=${pair#*:}
      build=$($PB -c "Print :Components:$name:OriginalSourceBuild" "$FSSTATE/FileSharing.plist" 2>/dev/null) || build=
      want=$($PB -c "Print :Components:$name:OriginalSHA256" "$FSSTATE/FileSharing.plist" 2>/dev/null) || want=
      orig="$FSSTATE/OriginalFileSharing/$build/$name"
      if [ -n "$build" ] && [ -n "$want" ] && [ "$(sha "$orig")" = "$want" ]; then
        cp "$orig" "$target"; chown root:wheel "$target"; chmod 755 "$target"
        [ "$(sha "$target")" = "$want" ] || restored=0
      else
        restored=0
      fi
    done
    [ "$loaded" = 1 ] && launchctl load /System/Library/LaunchDaemons/smbd.plist 2>/dev/null || true
    if [ "$restored" = 1 ]; then
      rm -rf "$FSSTATE/FileSharing.plist" "$FSSTATE/OriginalFileSharing" "$FSSTATE/Ownership.plist"
    else
      echo "Apple's SMB server could not be restored; its saved copy stays in $FSSTATE."
    fi
  fi
  rm -f "$AGENT_DIR/opengl-file-sharing" "$AGENT_DIR/snowleopard-smbd" "$AGENT_DIR/snowleopard-odsam.dylib" \
        "$AGENT_DIR/SnowLeopardSMB.plist" "$AGENT_DIR/Samba-COPYING.txt"
  # Mavericks: mavericks-smb-compat replaced smbd, keeping Apple's signed original as a hard link
  # next to it (/usr/sbin/.vim-smbd.XXXXXX.original).
  set -- /usr/sbin/.vim-smbd.*.original
  if [ "$#" = 1 ] && [ -f "$1" ]; then
    mv -f "$1" /usr/sbin/smbd
    launchctl stop com.apple.smbd 2>/dev/null || true
  elif [ -f "$1" ]; then
    echo "Several saved SMB servers in /usr/sbin; Apple's smbd was not restored."
  fi
  rm -f "$AGENT_DIR/mavericks-smb-compat" "$AGENT_DIR/codesign_allocate"
}

if [ "${1:-}" = "--uninstall" ]; then
  [ -f "$BACKUP" ] || { echo "No saved Apple GLEngine for build $BUILD; nothing restored."; exit 1; }
  cp "$BACKUP" "$ENG/GLEngine"
  rm -f "$ENG/libVIMPassthroughOpenGL.dylib"
  rm -rf "$GA" "$STOCK"
  rm -f "$AGENT_PLIST" "$AGENT_DIR/opengl-display-agent"
  if [ -f "$GUEST_AGENT_PLIST" ]; then
    launchctl unload "$GUEST_AGENT_PLIST" 2>/dev/null || true
    rm -f "$GUEST_AGENT_PLIST"
  fi
  rm -f "$AGENT_DIR/opengl-guest-agent" "$AGENT_DIR/guest-clipboard"
  rm -rf /private/var/db/com.virtualintelmac.clipboard
  remove_file_sharing
  pmset -a disablesleep 0 >/dev/null 2>&1 || true
  [ "$GUEST" = snowleopard ] && defaults delete /Library/Preferences/.GlobalPreferences QuartzGLEnable 2>/dev/null || true
  [ -f "$MSDOS_BACKUP" ] && cp "$MSDOS_BACKUP" "$MSDOS" && chown root:wheel "$MSDOS" && chmod 644 "$MSDOS"
  rebuild_caches
  echo "Apple's OpenGL engine restored. Restart the Mac."
  exit 0
fi

# 1. Keep Apple's original engine: once in our backup folder, and as GLEngineStock
#    (VirtualIntelMac's GLEngine falls back to it for software rendering).
CUR=$(sha "$ENG/GLEngine")
OURS=$(sha "$KIT/Payload/GLEngine")
[ -n "$CUR" ] || { echo "GLEngine is missing from $ENG"; exit 1; }
if [ ! -f "$BACKUP" ]; then
  mkdir -p "$(dirname "$BACKUP")"
  if ! grep -q libVIMPassthroughOpenGL "$ENG/GLEngine"; then
    cp "$ENG/GLEngine" "$BACKUP"                # Apple's engine is still in place
  elif [ -f "$STOCK/GLEngineStock" ] && ! grep -q libVIMPassthroughOpenGL "$STOCK/GLEngineStock"; then
    cp "$STOCK/GLEngineStock" "$BACKUP"         # earlier PassthroughOpenGL install kept it here
  else
    echo "A PassthroughOpenGL engine is installed but Apple's original GLEngine was not found."
    echo "Reinstall Apple's GLEngine (e.g. from the OS installer) before running this kit."
    exit 1
  fi
  chmod 600 "$BACKUP"
fi
mkdir -p "$STOCK"
cp "$BACKUP" "$STOCK/GLEngineStock"
chmod 755 "$STOCK/GLEngineStock"

# 2. 2D plugin.
mkdir -p "$GA/Contents/MacOS"
cp "$KIT/Payload/VMsvga2GA.plugin/Contents/Info.plist" "$GA/Contents/Info.plist"
cp "$KIT/Payload/VMsvga2GA.plugin/Contents/MacOS/VMsvga2GA" "$GA/Contents/MacOS/VMsvga2GA"
chmod 644 "$GA/Contents/Info.plist"; chmod 755 "$GA/Contents/MacOS/VMsvga2GA"

# 3. Dependency first, public engine last (same order as VirtualIntelMac).
cp "$KIT/Payload/libVIMPassthroughOpenGL.dylib" "$ENG/libVIMPassthroughOpenGL.dylib"
cp "$KIT/Payload/GLEngine" "$ENG/GLEngine"
chmod 755 "$ENG/libVIMPassthroughOpenGL.dylib" "$ENG/GLEngine"
chown -R root:wheel "$GA" "$STOCK" "$ENG/GLEngine" "$ENG/libVIMPassthroughOpenGL.dylib"

[ "$(sha "$ENG/GLEngine")" = "$OURS" ] || { echo "Verification failed: GLEngine"; exit 1; }
[ "$(sha "$ENG/libVIMPassthroughOpenGL.dylib")" = "$(sha "$KIT/Payload/libVIMPassthroughOpenGL.dylib")" ] || { echo "Verification failed: libVIMPassthroughOpenGL"; exit 1; }

# 4. Display-density agent (only in kits whose guest has one).
if [ -f "$KIT/Payload/opengl-display-agent" ]; then
  mkdir -p "$AGENT_DIR"
  cp "$KIT/Payload/opengl-display-agent" "$AGENT_DIR/opengl-display-agent"
  cp "$KIT/Payload/com.virtualintelmac.opengl-display.plist" "$AGENT_PLIST"
  chown root:wheel "$AGENT_DIR/opengl-display-agent" "$AGENT_PLIST"
  chmod 755 "$AGENT_DIR/opengl-display-agent"; chmod 644 "$AGENT_PLIST"
  [ "$(sha "$AGENT_DIR/opengl-display-agent")" = "$(sha "$KIT/Payload/opengl-display-agent")" ] || {
    echo "Verification failed: display agent"; exit 1; }
fi

# 5. Guest agent + clipboard helper (UTM's Clipboard Sharing). The agent answers UTM on
#    COM2; UTM asks it to start the clipboard helper in the logged-in user's session.
if [ -f "$KIT/Payload/opengl-guest-agent" ]; then
  mkdir -p "$AGENT_DIR"
  for f in opengl-guest-agent guest-clipboard; do
    cp "$KIT/Payload/$f" "$AGENT_DIR/$f"
    chown root:wheel "$AGENT_DIR/$f"; chmod 755 "$AGENT_DIR/$f"
    [ "$(sha "$AGENT_DIR/$f")" = "$(sha "$KIT/Payload/$f")" ] || { echo "Verification failed: $f"; exit 1; }
  done
  launchctl unload "$GUEST_AGENT_PLIST" 2>/dev/null || true
  cp "$KIT/Payload/com.utmapp.intel-guest-agent.plist" "$GUEST_AGENT_PLIST"
  chown root:wheel "$GUEST_AGENT_PLIST"; chmod 644 "$GUEST_AGENT_PLIST"
  launchctl load "$GUEST_AGENT_PLIST" 2>/dev/null || true
fi

# 6. Undo the File Sharing setup of earlier kits.
remove_file_sharing

# 7. Keep the OpenCore disk's EFI partition from showing as an unreadable disk.
register_esp_probe

# 8. As VirtualIntelMac: no system sleep. The VM offers no reliable S3/S4 resume (UTM
#    turns both off); display sleep is unchanged.
pmset -a sleep 0 >/dev/null 2>&1 || true
pmset -a disablesleep 1 >/dev/null 2>&1 || true

# 9. Earlier kits turned Quartz GL off for every app on Snow Leopard (a workaround for the
#    pulsing default button). The kit's GLEngine now fixes the cause (vim-guest-padded-self-view
#    .patch), so apps that ask for Quartz GL get it again.
if [ "$GUEST" = snowleopard ]; then
  defaults delete /Library/Preferences/.GlobalPreferences QuartzGLEnable 2>/dev/null || true
fi

rebuild_caches
echo "Installed. Restart the Mac to use PassthroughOpenGL (Quartz Extreme + OpenGL)."
echo "The restart rebuilds the system's kernel cache first; under emulation that can keep"
echo "a grey screen for several minutes. Let it finish; do not force the Mac off."
echo "Undo with: sudo sh \"$0\" --uninstall"
