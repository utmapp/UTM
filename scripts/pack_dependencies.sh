#!/bin/sh
set -e

usage () {
    echo "Usage: $(basename $0) basedir platform arch1 arch2 [arch...]"
    echo ""
    echo "  basedir     Root directory of all sysroots."
    echo "  platform    Target platform. [ios|macos]"
    echo "  archN       List of architectures to pack. [armv7|armv7s|arm64|i386|x86_64]"
    echo ""
    exit 1
}

if [ $# -lt 4 ]; then
    usage
fi

BASEDIR="$1"
PLATFORM=$2
MAIN_ARCH=$3
shift 2
ALL_ARCHS=$*

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

pack_all_objs() {
    BASEDIR="$1"
    FIND="$2"
    MAIN_DIR="$BASEDIR/sysroot-$SCHEME-$MAIN_ARCH"
    LIST=$(find "$MAIN_DIR" -path "$FIND" -type f)
    OLDIFS=$IFS
    IFS=$'\n'
    for f in $LIST
    do
        NAME=$(basename "$f")
        if [ "$NAME" == "Info.plist" ]; then
            continue # skip Info.plist
        fi
        FILE=${f/"$MAIN_DIR"/}
        INPUTS=$(echo $ALL_ARCHS | xargs printf -- "$BASEDIR/sysroot-$SCHEME-%s$FILE\n")
        OUTPUT="$BASEDIR/sysroot-$SCHEME-${ALL_ARCHS/ /_}$FILE"
        OUTPUT_DIR="$(dirname "$OUTPUT")"
        if [ ! -d "$OUTPUT_DIR" ]; then
            mkdir -p "$OUTPUT_DIR"
        fi
        echo "Packing $FILE"
        echo $ALL_ARCHS | xargs printf -- "$BASEDIR/sysroot-$SCHEME-%s$FILE\n" | xargs lipo -output "$OUTPUT" -create
    done
    IFS=$OLDIFS
}

pack_dir() {
    BASEDIR="$1"
    DIR="$2"
    SRC="$BASEDIR/sysroot-$SCHEME-$MAIN_ARCH"
    TGT="$BASEDIR/sysroot-$SCHEME-${ALL_ARCHS/ /_}"
    rm -rf "$TGT/$DIR"
    if [ ! -d "$(dirname "$TGT/$DIR")" ]; then
        mkdir -p "$(dirname "$TGT/$DIR")"
    fi
    echo "Packing /$DIR"
    cp -a "$SRC/$DIR" "$TGT/$DIR"
}

pack_all_objs "$BASEDIR" "*/bin/qemu-*"
pack_all_objs "$BASEDIR" "*/lib/*.dylib"
pack_all_objs "$BASEDIR" "*/lib/*.a"
pack_dir "$BASEDIR" "Frameworks" # for all the Info.plist
pack_all_objs "$BASEDIR" "*/Frameworks/*.framework/*"
pack_dir "$BASEDIR" "include"
pack_dir "$BASEDIR" "lib/glib-2.0/include"
pack_dir "$BASEDIR" "share/qemu"
pack_dir "$BASEDIR" "share/vulkan"
