#!/bin/sh
# Based off of https://github.com/szanni/ios-autotools/blob/master/iconfigure
# Copyright (c) 2014, Angelo Haller
# 
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
set -e

# Include URL list
source "$(dirname $0)/sources"

# Printing coloured lines
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Build environment
CHOST=
SDK=
SDKMINVER="9.0"
NCPU=$(sysctl -n hw.ncpu)

command -v realpath >/dev/null 2>&1 || realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

usage () {
    echo "Usage: [VARIABLE...] $(basename $0) [-a architecture] [-d] [-r] [-q]"
    echo ""
    echo "  -a architecture  Target architecture. Default arm64. [armv7|armv7s|arm64|i386|x86_64]"
    echo "  -d, --download   Force re-download of source even if already downloaded."
    echo "  -r, --rebuild    Build only. Do not download, patch, configure."
    echo "  -q, --qemu       Build qemu only. Do not build other projects."
    echo ""
    echo "  VARIABLEs are:"
    echo "    SDKVERSION     Target a specific SDK version."
    echo "    CHOST          Configure host, set if not deducable by ARCH."
    echo "    SDK            SDK target, set if not deducable by ARCH. [iphoneos|iphonesimulator]"
    echo ""
    echo "    CFLAGS CPPFLAGS CXXFLAGS LDFLAGS PKG_CONFIG_PATH"
    echo ""
    exit 1
}

check_env () {
    command -v pkg-config >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'pkg-config' on your host machine.${NC}"; exit 1; }
    command -v msgfmt >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'gettext' on your host machine.\n\t'msgfmt' needs to be in your \$PATH as well.${NC}"; exit 1; }
    command -v glib-mkenums >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'glib' on your host machine.\n\t'glib-mkenums' needs to be in your \$PATH as well.${NC}"; exit 1; }
    command -v gpg-error-config >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'libgpg-error' on your host machine.\n\t'gpg-error-config' needs to be in your \$PATH as well.${NC}"; exit 1; }
    command -v xcrun >/dev/null 2>&1 || { echo >&2 "${RED}'xcrun' is not found. Make sure you are running on OSX."; exit 1; }
    command -v otool >/dev/null 2>&1 || { echo >&2 "${RED}'otool' is not found. Make sure you are running on OSX."; exit 1; }
    command -v install_name_tool >/dev/null 2>&1 || { echo >&2 "${RED}'install_name_tool' is not found. Make sure you are running on OSX."; exit 1; }
    # TODO: check bison version >= 2.4
}

download () {
    URL=$1
    FILE="$(basename $URL)"
    NAME="${FILE%.tar.*}"
    TARGET="$BUILD_DIR/$FILE"
    DIR="$BUILD_DIR/$NAME"
    PATCH="$PATCHES_DIR/${NAME}.patch"
    if [ -f "$TARGET" -a -z "$REDOWNLOAD" ]; then
        echo "${GREEN}$TARGET already downloaded! Run with -d to force re-download.${NC}"
    else
        echo "${GREEN}Downloading ${URL}...${NC}"
        curl -L -O "$URL"
        mv "$FILE" "$TARGET"
    fi
    if [ -d "$DIR" ]; then
        echo "${GREEN}Deleting existing build directory ${DIR}...${NC}"
        rm -rf "$DIR"
    fi
    echo "${GREEN}Unpacking ${NAME}...${NC}"
    tar -xf "$TARGET" -C "$BUILD_DIR"
    if [ -f "$PATCH" ]; then
        echo "${GREEN}Patching ${NAME}...${NC}"
        patch -d "$DIR" -p1 < "$PATCH"
    fi
}

download_all () {
    [ -d "$BUILD_DIR" ] || mkdir -p "$BUILD_DIR"
    download $FFI_SRC
    download $ICONV_SRC
    download $GETTEXT_SRC
    download $PNG_SRC
    download $JPEG_TURBO_SRC
    download $GLIB_SRC
    download $GPG_ERROR_SRC
    download $GCRYPT_SRC
    download $PIXMAN_SRC
    download $OPENSSL_SRC
    download $OPUS_SRC
    download $SPICE_PROTOCOL_SRC
    download $SPICE_SERVER_SRC
    download $NCURSES_SRC
    download $JSON_GLIB_SRC
    download $GST_SRC
    download $GST_BASE_SRC
    download $GST_GOOD_SRC
    download $SPICE_CLIENT_SRC
    download $QEMU_SRC
}

build_openssl() {
    URL=$1
    shift 1
    FILE="$(basename $URL)"
    NAME="${FILE%.tar.*}"
    DIR="$BUILD_DIR/$NAME"
    pwd="$(pwd)"

    TOOLCHAIN_PATH="$(dirname $(xcrun --sdk $SDK -find clang))"
    PATH="$PATH:$TOOLCHAIN_PATH"
    CROSS_TOP="$(xcrun --sdk $SDK --show-sdk-platform-path)/Developer" # for openssl
    CROSS_SDK="$SDKNAME.$SDKVERSION.sdk" # for openssl
    export CROSS_TOP
    export CROSS_SDK
    export PATH
    case $ARCH in
    armv7 | armv7s )
        OPENSSL_CROSS=iphoneos-cross
        ;;
    arm64 )
        OPENSSL_CROSS=ios64-cross
        ;;
    i386 )
        OPENSSL_CROSS=darwin-i386-cc
        ;;
    x86_64 )
        OPENSSL_CROSS=darwin64-x86_64-cc
        ;;
    esac

    cd "$DIR"
    if [ -z "$REBUILD" ]; then
        echo "${GREEN}Configuring ${NAME}...${NC}"
        ./Configure $OPENSSL_CROSS no-dso no-hw no-engine --prefix="$PREFIX" $@
    fi
    echo "${GREEN}Building ${NAME}...${NC}"
    make "$MAKEFLAGS"
    echo "${GREEN}Installing ${NAME}...${NC}"
    make "$MAKEFLAGS" install
    cd "$pwd"
}

build () {
    URL=$1
    shift 1
    FILE="$(basename $URL)"
    NAME="${FILE%.tar.*}"
    DIR="$BUILD_DIR/$NAME"
    pwd="$(pwd)"

    cd "$DIR"
    if [ -z "$REBUILD" ]; then
        echo "${GREEN}Configuring ${NAME}...${NC}"
        ./configure --prefix="$PREFIX" --host="$CHOST" $@
    fi
    echo "${GREEN}Building ${NAME}...${NC}"
    make "$MAKEFLAGS"
    echo "${GREEN}Installing ${NAME}...${NC}"
    make "$MAKEFLAGS" install
    cd "$pwd"
}

build_qemu_dependencies () {
    build $FFI_SRC
    build $ICONV_SRC
    build $GETTEXT_SRC --disable-java
    build $PNG_SRC
    build $JPEG_TURBO_SRC
    build $GLIB_SRC glib_cv_stack_grows=no glib_cv_uscore=no --with-pcre=internal
    build $GPG_ERROR_SRC
    build $GCRYPT_SRC
    build $PIXMAN_SRC
    build_openssl $OPENSSL_SRC
    build $OPUS_SRC
    build $SPICE_PROTOCOL_SRC
    build $SPICE_SERVER_SRC
    build $NCURSES_SRC --without-debug --enable-overwrite --enable-widec --with-ospeed=int16_t --without-progs --without-tack --without-tests
}

build_qemu () {
    #QEMU_DIR="$BUILD_DIR/qemu"
    #if [ ! -d "$QEMU_DIR" ]; then
    #    echo "${GREEN}Cloning qemu...${NC}"
    #    git clone --depth 1 --recursive --shallow-submodules "$QEMU_GIT" "$QEMU_DIR"
    #fi
    QEMU_CFLAGS="$CFLAGS"
    QEMU_CXXFLAGS="$CXXFLAGS"
    QEMU_LDFLAGS="$LDFLAGS"
    export QEMU_CFLAGS
    export QEMU_CXXFLAGS
    export QEMU_LDFLAGS
    CFLAGS=
    CXXFLAGS=
    LDFLAGS=
    build $QEMU_SRC --enable-shared-lib
    CFLAGS="$QEMU_CFLAGS"
    CXXFLAGS="$QEMU_CXXFLAGS"
    LDFLAGS="$QEMU_LDFLAGS"
}

steal_libucontext () {
    # HACK: use the libucontext built by qemu
    FILE="$(basename $QEMU_SRC)"
    NAME="${FILE%.tar.*}"
    cp "$BUILD_DIR/$NAME/libucontext/libucontext.a" "$PREFIX/lib/libucontext.a"
    cp "$BUILD_DIR/$NAME/libucontext/include/libucontext.h" "$PREFIX/include/libucontext.h"
}

build_spice_client () {
    build $JSON_GLIB_SRC
    build $GST_SRC --enable-static --enable-static-plugins --disable-registry
    build $GST_BASE_SRC --enable-static --disable-fatal-warnings
    build $GST_GOOD_SRC --enable-static
    build $SPICE_CLIENT_SRC --with-gtk=no
}

fixup () {
    FILE=$1
    LIST=$(otool -L "$FILE" | tail -n +3 | cut -d ' ' -f 1 | awk '{$1=$1};1')
    OLDIFS=$IFS
    IFS=$'\n'
    echo "${GREEN}Fixing up $FILE...${NC}"
    install_name_tool -id "@executable_path/Frameworks/$(basename "$FILE")" "$FILE"
    for f in $LIST
    do
        base=$(basename "$f")
        dir=$(dirname "$f")
        if [ "$dir" == "$PREFIX/lib" ]; then
            install_name_tool -change "$f" "@executable_path/Frameworks/$base" "$FILE"
        fi
    done
    IFS=$OLDIFS
}

fixup_all () {
    FILES=$(find "$SYSROOT_DIR/lib" -type f -name "*.dylib")
    OLDIFS=$IFS
    IFS=$'\n'
    for f in $FILES
    do
        fixup $f
    done
    IFS=$OLDIFS
}

remove_shared_gst_plugins () {
    find "$SYSROOT_DIR/lib/gstreamer-1.0" \( -name '*.so' -or -name '*.la' \) -exec rm \{\} \;
}

generate_qapi () {
    FILE="$(basename $1)"
    NAME="${FILE%.tar.*}"
    DIR="$BUILD_DIR/$NAME"
    APIS="$DIR/qapi/qapi-schema.json"

    echo "${GREEN}Generating qapi sources from ${APIS}...${NC}"
    python "$BASEDIR/qapi-gen.py" -b -o "$SYSROOT_DIR/qapi" "$APIS"
}

# parse args
ARCH=
REBUILD=
QEMU_ONLY=
REDOWNLOAD=
while [ "x$1" != "x" ]; do
    case $1 in
    -a )
        ARCH=$2
        shift
        ;;
    -d | --download )
        REDOWNLOAD=y
        ;;
    -r | --rebuild )
        REBUILD=y
        ;;
    -q | --qemu )
        QEMU_ONLY=y
        ;;
    * )
        usage
        ;;
    esac
    shift
done

if [ "x$ARCH" == "x" ]; then
    ARCH=arm64
fi
export ARCH

# Export supplied CHOST or deduce by ARCH
if [ -z "$CHOST" ]; then
    case $ARCH in
    armv7 | armv7s )
        CHOST=arm-apple-darwin
        ;;
    arm64 )
        CHOST=aarch64-apple-darwin
        ;;
    i386 | x86_64 )
        CHOST=$ARCH-apple-darwin
        ;;
    * )
        usage
        ;;
    esac
fi
export CHOST

# Export supplied SDK or deduce by ARCH
if [ -z "$SDK" ]; then
    case $ARCH in
    armv7 | armv7s | arm64 )
        SDK=iphoneos
        ;;
    i386 | x86_64 )
        SDK=iphonesimulator
        ;;
    * )
        usage
        ;;
    esac
fi

# Setup directories
BUILD_DIR="build-$ARCH"
PATCHES_DIR="patches"
SYSROOT_DIR="sysroot-$ARCH"

[ -d "$SYSROOT_DIR" ] || mkdir -p "$SYSROOT_DIR"
PREFIX="$(realpath "$SYSROOT_DIR")"
BASEDIR="$(dirname "$(realpath $0)")"

# Export supplied SDKVERSION or use system default
if [ ! -z "$SDKVERSION" ]; then
    SDKNAME=$(basename $(xcrun --sdk $SDK --show-sdk-platform-path) .platform)
    SDKROOT=$(xcrun --sdk $SDK --show-sdk-platform-path)"/Developer/SDKs/$SDKNAME.$SDKVERSION.sdk"
else
    SDKVERSION=$(xcrun --sdk $SDK --show-sdk-version) # current version
    SDKROOT=$(xcrun --sdk $SDK --show-sdk-path) # current version
fi

if [ -z "$SDKMINVER" ]; then
    SDKMINVER="$SDKVERSION"
fi

# Export tools
CC=$(xcrun --sdk $SDK --find gcc)
CPP=$(xcrun --sdk $SDK --find gcc)" -E"
CXX=$(xcrun --sdk $SDK --find g++)
LD=$(xcrun --sdk $SDK --find ld)
export CC
export CPP
export CXX
export LD
export PREFIX

# Flags
CFLAGS="$CFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include -miphoneos-version-min=$SDKMINVER"
CPPFLAGS="$CPPFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include -miphoneos-version-min=$SDKMINVER"
CXXFLAGS="$CXXFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include"
LDFLAGS="$LDFLAGS -arch $ARCH -isysroot $SDKROOT -L$PREFIX/lib"
MAKEFLAGS="-j$NCPU"
PKG_CONFIG_PATH="$PKG_CONFIG_PATH":"$SDKROOT/usr/lib/pkgconfig":"$PREFIX/lib/pkgconfig":"$PREFIX/share/pkgconfig"
PKG_CONFIG_LIBDIR=""
export CFLAGS
export CPPFLAGS
export CXXFLAGS
export LDFLAGS
export MAKEFLAGS
export PKG_CONFIG_PATH
export PKG_CONFIG_LIBDIR

check_env

if [ ! -f "$BUILD_DIR/BUILD_SUCCESS" ]; then
    if [ ! -z "$REBUILD" -o ! -z "$QEMU_ONLY" ]; then
        echo "${RED}Error, no previous successful build found.${NC}"
        exit 1
    fi
fi

if [ -z "$REBUILD" ]; then
    download_all
fi
if [ -z "$QEMU_ONLY" ]; then
    echo "${GREEN}Deleting old sysroot!${NC}"
    rm -rf "$PREFIX/"*
    rm -f "$BUILD_DIR/BUILD_SUCCESS"
    build_qemu_dependencies
fi
build_qemu
if [ -z "$QEMU_ONLY" ]; then
    steal_libucontext # should be a better way...
    build_spice_client
fi
fixup_all
remove_shared_gst_plugins # another hack...
generate_qapi $QEMU_SRC
echo "${GREEN}All done!${NC}"
touch "$BUILD_DIR/BUILD_SUCCESS"
