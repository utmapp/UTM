#!/bin/sh
# UTM guest kit for Mac OS X 10.4 Tiger / 10.5 Leopard on PowerPC.
# Installs VirtualIntelMac's guest agent and text clipboard helper (MIT; UTM's PowerPC build),
# used by UTM's Clipboard Sharing through two PCI serial ports UTM adds to these VMs.
# Usage: double-click (asks for your password), or: sudo sh Install.command [--uninstall]
if [ "$(id -u)" != 0 ]; then
  echo "Administrator password needed to install the UTM guest helpers."
  exec sudo /bin/sh "$0" "$@"
fi
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
TOOLS="/Library/Application Support/Virtual Intel Mac/GuestTools"
PLIST=/Library/LaunchDaemons/com.utmapp.ppc-guest-agent.plist
case "$(sw_vers -productVersion)" in
  10.4|10.4.*|10.5|10.5.*) ;;
  *) echo "This kit is for Mac OS X 10.4 or 10.5; this Mac runs $(sw_vers -productVersion)."; exit 1 ;;
esac
[ "$(uname -p)" = powerpc ] || { echo "This kit is for PowerPC Macs."; exit 1; }

if [ "${1:-}" = "--uninstall" ]; then
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST" "$TOOLS/opengl-guest-agent" "$TOOLS/guest-clipboard" "$TOOLS/opengl-tiger-console"
  rm -rf /private/var/db/com.virtualintelmac.clipboard
  echo "UTM guest helpers removed."
  exit 0
fi

mkdir -p "$TOOLS"
chown root:admin "/Library/Application Support/Virtual Intel Mac" 2>/dev/null || true
for f in opengl-guest-agent guest-clipboard opengl-tiger-console; do
  cp "$KIT/Payload/$f" "$TOOLS/$f"
  chown root:wheel "$TOOLS/$f"; chmod 755 "$TOOLS/$f"
  cmp -s "$KIT/Payload/$f" "$TOOLS/$f" || { echo "Verification failed: $f"; exit 1; }
done
launchctl unload "$PLIST" 2>/dev/null || true
cp "$KIT/Payload/com.utmapp.ppc-guest-agent.plist" "$PLIST"
chown root:wheel "$PLIST"; chmod 644 "$PLIST"
launchctl load "$PLIST"
echo "Installed. In UTM, turn on Sharing -> Clipboard Sharing for this VM; text is copied"
echo "both ways once you are logged in."
echo "Undo with: sudo sh \"$0\" --uninstall"
