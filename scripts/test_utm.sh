#!/bin/sh
# Run the UTMTests unit tests hosted by the macOS app.
#
# The host is built as com.utmapp.test.UTM with ad-hoc signing, so it has its
# own sandbox container and defaults and never touches an installed UTM. A dSYM
# is generated because XCTest symbolicates failures against the host, which
# takes minutes without one. Any extra arguments go to xcodebuild, for example
# -only-testing:UTMTests/QEMUArgumentFragmentTests.
#
# Usage: ./scripts/test_utm.sh [-d derived-data-path] [-r result-bundle-path] [xcodebuild args...]

set -e
cd "$(dirname "$0")/.."

DERIVED_DATA="build/tests"
RESULT_BUNDLE=""
while [ $# -gt 0 ]; do
    case "$1" in
        -d) DERIVED_DATA="$2"; shift 2 ;;
        -r) RESULT_BUNDLE="$2"; shift 2 ;;
        -h) echo "usage: $0 [-d derived-data-path] [-r result-bundle-path] [xcodebuild args...]"; exit 0 ;;
        --) shift; break ;;
        *) break ;;
    esac
done

if [ -n "$RESULT_BUNDLE" ]; then
    set -- -resultBundlePath "$RESULT_BUNDLE" "$@"
fi

exec xcodebuild test \
    -project UTM.xcodeproj -scheme macOS -destination "platform=macOS,arch=$(uname -m)" \
    -only-testing:UTMTests -skipPackagePluginValidation -derivedDataPath "$DERIVED_DATA" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
    "$@" \
    PRODUCT_BUNDLE_PREFIX=com.utmapp.test CODE_SIGN_IDENTITY_MAC=- DEVELOPER_ACCOUNT_VM_ACCESS=NO \
    PROVISIONING_PROFILE_SPECIFIER_MAC= PROVISIONING_PROFILE_SPECIFIER_HELPER= PROVISIONING_PROFILE_SPECIFIER_LAUNCHER= \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
