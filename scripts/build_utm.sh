#!/bin/sh
set -e

usage () {
    echo "Usage: $(basename $0) [-p platform] [-a architecture] [-t targetversion] [-o output]"
    echo ""
    echo "  -p platform      Target platform. Default ios. [ios|macos]"
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
ios )
    SCHEME="iOS"
    ;;
macos )
    SCHEME="macOS"
    ;;
* )
    usage
    ;;
esac

case $PLATFORM in
ios )
    case $ARCH in
    arm* )
        SDK=iphoneos
        ;;
    i386 | x86_64 )
        SDK=iphonesimulator
        ;;
    * )
        usage
        ;;
    esac
    PLATFORM_FAMILY_NAME="iOS"
    ;;
macos )
    SDK=macosx
    PLATFORM_FAMILY_NAME="macOS"
    ;;
* )
    usage
    ;;
esac

xcodebuild archive -archivePath "$OUTPUT" -scheme "$SCHEME" -sdk "$SDK" -arch "$ARCH" -configuration Release CODE_SIGNING_ALLOWED=NO
