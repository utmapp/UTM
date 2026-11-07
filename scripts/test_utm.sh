#!/bin/sh
# Run the UTMTests unit tests hosted by the macOS app.
#
# The host is built as com.utmapp.test.UTM with ad-hoc signing, so it has its
# own sandbox container and defaults and never touches an installed UTM. A dSYM
# is generated because XCTest symbolicates failures against the host, which
# takes minutes without one. Any extra arguments go to xcodebuild, for example
# -only-testing:UTMTests/QEMUArgumentFragmentTests (UTMTests-iOS/... under -s).
#
# With -s the same tests run in the UTMTests-iOS bundle hosted by the iOS app
# on a simulator: the newest runtime's first iPhone, or the device named with -s.
#
# Usage: ./scripts/test_utm.sh [-d derived-data-path] [-r result-bundle-path] [-s [simulator-name]] [xcodebuild args...]

set -e
cd "$(dirname "$0")/.."

DERIVED_DATA="build/tests"
RESULT_BUNDLE=""
SIMULATOR=""
while [ $# -gt 0 ]; do
    case "$1" in
        -d) DERIVED_DATA="$2"; shift 2 ;;
        -r) RESULT_BUNDLE="$2"; shift 2 ;;
        -s) SIMULATOR="iPhone"; shift
            case "${1:-}" in -*|"") ;; *) SIMULATOR="$1"; shift ;; esac ;;
        -h) echo "usage: $0 [-d derived-data-path] [-r result-bundle-path] [-s [simulator-name]] [xcodebuild args...]"; exit 0 ;;
        --) shift; break ;;
        *) break ;;
    esac
done

if [ -n "$RESULT_BUNDLE" ]; then
    set -- -resultBundlePath "$RESULT_BUNDLE" "$@"
fi

ARCH=$(uname -m)
if [ -n "$SIMULATOR" ]; then
    # the newest available simulator runtime; the device named exactly, else the first whose name starts with it
    UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
runtimes = sorted((r for r in devices if ".iOS-" in r), key=lambda r: [int(x) for x in r.rsplit("iOS-", 1)[1].split("-")])
for runtime in reversed(runtimes):
    exact = [d for d in devices[runtime] if d["name"] == name]
    prefixed = [d for d in devices[runtime] if d["name"].startswith(name)]
    for device in exact + prefixed:
        print(device["udid"]); sys.exit(0)
sys.exit(1)' "$SIMULATOR") || { echo "no available iOS simulator named $SIMULATOR" >&2; exit 1; }
    # a simulator app that opens a file under Documents, Desktop or Downloads is held on the
    # privacy consent prompt, and dyld opens the DYLD_*_PATH entries that point into the
    # derived data, so the host hangs before XCTest connects: keep the build elsewhere
    case "$DERIVED_DATA" in
        /*) DERIVED_DATA_ABSOLUTE="$DERIVED_DATA" ;;
        *) DERIVED_DATA_ABSOLUTE="$PWD/$DERIVED_DATA" ;;
    esac
    case "$DERIVED_DATA_ABSOLUTE" in
        "$HOME/Documents"*|"$HOME/Desktop"*|"$HOME/Downloads"*)
            DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/$(basename "$DERIVED_DATA_ABSOLUTE")-simulator"
            echo "simulator runs cannot use derived data under Documents, Desktop or Downloads; using $DERIVED_DATA" >&2 ;;
    esac
    SCHEME=iOS
    DESTINATION="platform=iOS Simulator,id=$UDID"
    BUNDLE=UTMTests-iOS
    set -- "$@" PRODUCT_BUNDLE_PREFIX=com.utmapp.test ARCHS="$ARCH" CODE_SIGNING_ALLOWED=NO
else
    SCHEME=macOS
    DESTINATION="platform=macOS,arch=$ARCH"
    BUNDLE=UTMTests
    set -- "$@" PRODUCT_BUNDLE_PREFIX=com.utmapp.test CODE_SIGN_IDENTITY_MAC=- DEVELOPER_ACCOUNT_VM_ACCESS=NO \
        PROVISIONING_PROFILE_SPECIFIER_MAC= PROVISIONING_PROFILE_SPECIFIER_HELPER= PROVISIONING_PROFILE_SPECIFIER_LAUNCHER=
fi

# run the whole bundle unless the caller selects tests (a -skip-testing only narrows the bundle)
SELECTS=""
for arg in "$@"; do
    case "$arg" in
        -only-testing:*) SELECTS=1 ;;
    esac
done
if [ -z "$SELECTS" ]; then
    set -- "-only-testing:$BUNDLE" "$@"
fi

exec xcodebuild test \
    -project UTM.xcodeproj -scheme "$SCHEME" -destination "$DESTINATION" \
    -skipPackagePluginValidation -derivedDataPath "$DERIVED_DATA" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
    "$@" \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
