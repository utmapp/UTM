#!/bin/sh
# Run the UTMTests unit tests hosted by the macOS app.
#
# The host is built as com.utmapp.test.UTM with ad-hoc signing, so it has its
# own sandbox container and defaults and never touches an installed UTM. A dSYM
# is generated because XCTest symbolicates failures against the host, which
# takes minutes without one. Any extra arguments go to xcodebuild, for example
# -only-testing:UTMTests/QEMUArgumentFragmentTests (UTMTests-iOS/... under -s), or
# -only-testing:UTMUITests for the UI tests, which need a logged-in desktop session.
#
# With -s the same tests run in the UTMTests-iOS bundle hosted by the iOS app
# on a simulator: the newest runtime's first iPhone, or the device named with -s.
#
# With -v the VM lifecycle tests run (UTMTests/VMLifecycleTests): they start real
# QEMU virtual machines inside the host, so the host is signed with the
# development identity and team of the local CodeSigning.xcconfig (the hypervisor
# and the app group need it) under its own bundle prefix, the QEMU launcher is
# signed again without the sandbox exceptions a test build adds, and the run
# should start from a desktop session.
#
# Usage: ./scripts/test_utm.sh [-d derived-data-path] [-r result-bundle-path] [-s [simulator-name]] [-v] [xcodebuild args...]

set -e
cd "$(dirname "$0")/.."

DERIVED_DATA="build/tests"
RESULT_BUNDLE=""
SIMULATOR=""
VM_TIER=""
while [ $# -gt 0 ]; do
    case "$1" in
        -d) DERIVED_DATA="$2"; shift 2 ;;
        -r) RESULT_BUNDLE="$2"; shift 2 ;;
        -v) VM_TIER=1; shift ;;
        -s) SIMULATOR="iPhone"; shift
            case "${1:-}" in -*|"") ;; *) SIMULATOR="$1"; shift ;; esac ;;
        -h) echo "usage: $0 [-d derived-data-path] [-r result-bundle-path] [-s [simulator-name]] [-v] [xcodebuild args...]"; exit 0 ;;
        --) shift; break ;;
        *) break ;;
    esac
done

if [ -n "$SIMULATOR" ] && [ -n "$VM_TIER" ]; then
    echo "the VM lifecycle tests run on macOS only; -s and -v cannot be combined" >&2; exit 1
fi
# the VM tier builds and tests in two steps and names the result bundle in the second
if [ -n "$RESULT_BUNDLE" ] && [ -z "$VM_TIER" ]; then
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
elif [ -n "$VM_TIER" ]; then
    SCHEME=macOS
    DESTINATION="platform=macOS,arch=$ARCH"
    BUNDLE=UTMTests/VMLifecycleTests
    TEAM=$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' CodeSigning.xcconfig 2>/dev/null | head -1)
    [ -n "$TEAM" ] || { echo "the VM tests need DEVELOPMENT_TEAM in CodeSigning.xcconfig: the host must be signed for the hypervisor and its app group" >&2; exit 1; }
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

if [ -z "$VM_TIER" ]; then
    exec xcodebuild test \
        -project UTM.xcodeproj -scheme "$SCHEME" -destination "$DESTINATION" \
        -skipPackagePluginValidation -derivedDataPath "$DERIVED_DATA" \
        -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
        "$@" \
        DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
fi

# The VM host is signed with the development identity but without the provisioning
# profiles, which name the real bundle identifiers, and under a prefix of its own:
# macOS keeps a container per bundle identifier and asks before a build signed by
# someone else ("differs from previously opened versions") may use it, which would
# block the helper that launches QEMU if the prefix were the unsigned unit-test host's.
xcodebuild build-for-testing \
    -project UTM.xcodeproj -scheme "$SCHEME" -destination "$DESTINATION" \
    -skipPackagePluginValidation -derivedDataPath "$DERIVED_DATA" \
    "$@" \
    PRODUCT_BUNDLE_PREFIX=com.utmapp.test.vm "CODE_SIGN_IDENTITY_MAC=Apple Development" "DEVELOPMENT_TEAM=$TEAM" \
    DEVELOPER_ACCOUNT_VM_ACCESS=NO PROVISIONING_PROFILE_SPECIFIER_MAC= PROVISIONING_PROFILE_SPECIFIER_HELPER= PROVISIONING_PROFILE_SPECIFIER_LAUNCHER= \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym

# Xcode's test actions add two sandbox exceptions, read access to "/" and the
# testmanagerd mach services, to the entitlements of every sandboxed product of the
# build so that a sandboxed test host can reach the test runner. QEMULauncher and
# QEMURenderServer inherit the helper's sandbox, and a process that inherits a sandbox
# may not carry any other sandbox exception: it is trapped as it launches, and every
# VM dies with "QEMU exited with code 5". So sign those two with their own
# entitlements again, re-seal the bundles that contain them, and test without building.
PRODUCTS="$DERIVED_DATA/Build/Products"
APP="$PRODUCTS/Debug/UTM.app"
HELPER="$APP/Contents/XPCServices/QEMUHelper.xpc"
SCRATCH=$(mktemp -d -t utm-vm-tests)
trap 'rm -rf "$SCRATCH"' EXIT
# the identity by the hash of the certificate the host was signed with: a name can be ambiguous
codesign -d --extract-certificates="$SCRATCH/cert" "$APP" 2>/dev/null
IDENTITY=$(openssl x509 -inform DER -in "$SCRATCH/cert0" -noout -fingerprint -sha1 2>/dev/null | sed 's/^.*=//; s/://g')
[ -n "$IDENTITY" ] || { echo "the VM host at $APP is not signed with a certificate" >&2; exit 1; }
for child in QEMULauncher QEMURenderServer; do
    CHILD="$HELPER/Contents/MacOS/$child.app"
    ENTITLEMENTS="$SCRATCH/$child.plist"
    codesign -d --entitlements - --xml "$CHILD" > "$ENTITLEMENTS" 2>/dev/null
    plutil -lint -s "$ENTITLEMENTS" || { echo "cannot read the entitlements of $child.app" >&2; exit 1; }
    for key in 'com\.apple\.security\.temporary-exception\.files\.absolute-path\.read-only' 'com\.apple\.security\.temporary-exception\.mach-lookup\.global-name'; do
        if plutil -extract "$key" raw -o /dev/null "$ENTITLEMENTS" 2>/dev/null; then
            plutil -remove "$key" "$ENTITLEMENTS"
        fi
    done
    codesign -f -s "$IDENTITY" --preserve-metadata=flags --entitlements "$ENTITLEMENTS" "$CHILD"
    if codesign -d --entitlements - --xml "$CHILD" 2>/dev/null | grep -q "temporary-exception"; then
        echo "$child.app still has a sandbox exception; it would be trapped at launch" >&2; exit 1
    fi
done
codesign -f -s "$IDENTITY" --preserve-metadata=entitlements,flags "$HELPER"
codesign -f -s "$IDENTITY" --preserve-metadata=entitlements,flags "$APP"

XCTESTRUN=$(ls -t "$PRODUCTS"/"$SCHEME"_*.xctestrun | head -1)
rm -rf "$SCRATCH"
# a VM boot and a clean stop take longer than a unit test's allowance
exec xcodebuild test-without-building -xctestrun "$XCTESTRUN" -destination "$DESTINATION" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600 \
    ${RESULT_BUNDLE:+-resultBundlePath} ${RESULT_BUNDLE:+"$RESULT_BUNDLE"} \
    "$@"
