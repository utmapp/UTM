#!/bin/sh
set -e

command -v realpath >/dev/null 2>&1 || realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
BASEDIR="$(dirname "$(realpath $0)")"

usage () {
    echo "Usage: $(basename $0)  [-t teamid] [-k SDK] [-s scheme] [-a architecture] [-o output]"
    echo ""
    echo "  -t teamid        Team Identifier for app groups. Optional for iOS. Required for macOS."
    echo "  -k sdk           Target SDK. Default iphoneos. [iphoneos|iphonesimulator|xros|xrsimulator|macosx]"
    echo "  -s scheme        Target scheme. Default iOS/macOS depending on platform. [iOS|iOS-TCI|iOS-Remote|macOS]"
    echo "  -a architecture  Target architecture. Default arm64. [arm64|x86_64]"
    echo "  -o output        Output archive path. Default is current directory."
    echo ""
    exit 1
}

PRODUCT_BUNDLE_PREFIX="com.utmapp"
TEAM_IDENTIFIER=
ARCH=arm64
OUTPUT=$PWD
SDK=iphoneos
SCHEME=

while [ "x$1" != "x" ]; do
    case $1 in
    -t )
        TEAM_IDENTIFIER=$2
        shift
        ;;
    -a )
        ARCH=$2
        shift
        ;;
    -k )
        SDK=$2
        shift
        ;;
    -s )
        SCHEME=$2
        shift
        ;;
    -o )
        OUTPUT=$2
        shift
        ;;
    * )
        usage
        ;;
    esac
    shift
done

case $SDK in
macos )
    SCHEME="macOS"
    ;;
* )
    if [ -z "$SCHEME" ]; then
        SCHEME="iOS"
    fi
    ;;
esac

ARCH_ARGS=$(echo $ARCH | xargs printf -- "-arch %s ")
if [ ! -z "$TEAM_IDENTIFIER" ]; then
    TEAM_IDENTIFIER_PREFIX="TeamIdentifierPrefix=${TEAM_IDENTIFIER}."
fi

xcodebuild archive -archivePath "$OUTPUT" -scheme "$SCHEME" -sdk "$SDK" $ARCH_ARGS -configuration Release CODE_SIGNING_ALLOWED=NO $TEAM_IDENTIFIER_PREFIX
BUILT_PATH=$(find $OUTPUT.xcarchive -name '*.app' -type d | head -1)
# Only retain the target architecture to address < iOS 15 crash & save disk space
if [ "$SDK" == "iphoneos" ]; then
    find "$BUILT_PATH" -type f -path '*/Frameworks/*.dylib' | while read FILE; do
        if [[ $(lipo -info "$FILE") =~ "Architectures in the fat file" ]]; then
            lipo -thin $ARCH "$FILE" -output "$FILE"
        fi
    done
    find "$BUILT_PATH" -type d -path '*/Frameworks/*.framework' | while read FRAMEWORK; do
        FILE="${FRAMEWORK}"/$(basename "${FRAMEWORK%.*}")
        if [[ $(lipo -info "$FILE") =~ "Architectures in the fat file" ]]; then
            lipo -thin $ARCH "$FILE" -output "$FILE"
        fi
    done
fi
find "$BUILT_PATH" -type d -path '*/Frameworks/*.framework' -exec codesign --force --sign - --timestamp=none \{\} \;
if [ "$SDK" == "macosx" ]; then
    # always build with vm entitlements, package_mac.sh can strip it later
    # this way we can import into Xcode and re-sign from there
    UTM_ENTITLEMENTS="/tmp/utm.$$.entitlements"
    LAUNCHER_ENTITLEMENTS="/tmp/launcher.$$.entitlements"
    HELPER_ENTITLEMENTS="/tmp/helper.$$.entitlements"
    CLI_ENTITLEMENTS="/tmp/cli.$$.entitlements"
    cp "$BASEDIR/../Platform/macOS/macOS.entitlements" "$UTM_ENTITLEMENTS"
    cp "$BASEDIR/../QEMULauncher/QEMULauncher.entitlements" "$LAUNCHER_ENTITLEMENTS"
    cp "$BASEDIR/../QEMUHelper/QEMUHelper.entitlements" "$HELPER_ENTITLEMENTS"
    cp "$BASEDIR/../utmctl/utmctl.entitlements" "$CLI_ENTITLEMENTS"
    if [ ! -z "$TEAM_IDENTIFIER" ]; then
        TEAM_ID_PREFIX="${TEAM_IDENTIFIER}."
    fi

    /usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 ${TEAM_ID_PREFIX}${PRODUCT_BUNDLE_PREFIX}.UTM" "$UTM_ENTITLEMENTS"
    /usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 ${TEAM_ID_PREFIX}${PRODUCT_BUNDLE_PREFIX}.UTM" "$HELPER_ENTITLEMENTS"
    /usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 ${TEAM_ID_PREFIX}${PRODUCT_BUNDLE_PREFIX}.UTM" "$CLI_ENTITLEMENTS"
    codesign --force --sign - --entitlements "$LAUNCHER_ENTITLEMENTS" --timestamp=none --options runtime "$BUILT_PATH/Contents/XPCServices/QEMUHelper.xpc/Contents/MacOS/QEMULauncher.app/Contents/MacOS/QEMULauncher"
    codesign --force --sign - --entitlements "$HELPER_ENTITLEMENTS" --timestamp=none --options runtime "$BUILT_PATH/Contents/XPCServices/QEMUHelper.xpc/Contents/MacOS/QEMUHelper"
    codesign --force --sign - --entitlements "$CLI_ENTITLEMENTS" --timestamp=none --options runtime "$BUILT_PATH/Contents/MacOS/utmctl"
    codesign --force --sign - --entitlements "$UTM_ENTITLEMENTS" --timestamp=none --options runtime "$BUILT_PATH/Contents/MacOS/UTM"
    rm "$UTM_ENTITLEMENTS"
    rm "$LAUNCHER_ENTITLEMENTS"
    rm "$HELPER_ENTITLEMENTS"
    rm "$CLI_ENTITLEMENTS"
fi
