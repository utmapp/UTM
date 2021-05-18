#!/bin/sh
set -e

command -v realpath >/dev/null 2>&1 || realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
BASEDIR="$(dirname "$(realpath $0)")"

usage () {
    echo "Usage: $(basename $0) [-p platform] [-a architecture] [-t targetversion] [-o output]"
    echo ""
    echo "  -p platform      Target platform. Default ios. [ios|ios_simulator|ios-tci|ios_simulator-tci|macos]"
    echo "  -a architecture  Target architecture. Default arm64. [armv7|armv7s|arm64|i386|x86_64]"
    echo "  -o output        Output archive path. Default is current directory."
    echo ""
    exit 1
}

ARCH=arm64
PLATFORM=ios
OUTPUT=$PWD
SDK=
SCHEME=

while [ "x$1" != "x" ]; do
    case $1 in
    -a )
        ARCH=$2
        shift
        ;;
    -p )
        PLATFORM=$2
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

case $PLATFORM in
ios | ios_simulator )
    SCHEME="iOS"
    ;;
*-tci )
    SCHEME="iOS-TCI"
    ;;
macos )
    SCHEME="macOS"
    ;;
* )
    usage
    ;;
esac

case $PLATFORM in
ios | ios-tci )
    SDK=iphoneos
    ;;
*simulator* )
    SDK=iphonesimulator
    ;;
macos )
    SDK=macosx
    ;;
* )
    usage
    ;;
esac

ARCH_ARGS=$(echo $ARCH | xargs printf -- "-arch %s ")

xcodebuild archive -archivePath "$OUTPUT" -scheme "$SCHEME" -sdk "$SDK" $ARCH_ARGS -configuration Release CODE_SIGNING_ALLOWED=NO
