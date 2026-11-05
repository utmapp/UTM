#!/bin/sh
# Runs every static check. Exit status is non-zero if any check fails.
#   --no-sdp   skip checks that need macOS developer tools (for Linux CI)
#   --sdp-only run only those checks
set -u
cd "$(dirname "$0")" || exit 1
mode="${1:-all}"
status=0
run() {
    echo "===== $1"
    python3 -I "$@" || status=1
}
case "$mode" in
    --sdp-only)
        run check_sdef_codes.py ;;
    --no-sdp)
        run check_l10n_format.py
        run check_settings_bundle.py
        run check_pbxproj_refs.py
        run check_sdef_codes.py --no-sdp ;;
    all)
        run check_l10n_format.py
        run check_settings_bundle.py
        run check_pbxproj_refs.py
        run check_sdef_codes.py ;;
    *)
        echo "usage: $0 [--no-sdp | --sdp-only]" >&2
        exit 2 ;;
esac
exit $status
