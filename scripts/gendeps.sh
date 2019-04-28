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

# Source files for qemu
FFI_SRC="https://sourceware.org/ftp/libffi/libffi-3.2.1.tar.gz"
ICONV_SRC="https://ftp.gnu.org/gnu/libiconv/libiconv-1.15.tar.gz"
GETTEXT_SRC="https://ftp.gnu.org/gnu/gettext/gettext-0.19.8.1.tar.gz"
PNG_SRC="https://ftp.osuosl.org/pub/blfs/conglomeration/libpng/libpng-1.6.36.tar.xz"
JPEG_TURBO_SRC="https://ftp.osuosl.org/pub/blfs/conglomeration/libjpeg-turbo/libjpeg-turbo-1.5.3.tar.gz"
GLIB_SRC="ftp://ftp.gnome.org/pub/GNOME/sources/glib/2.55/glib-2.55.2.tar.xz"
GPG_ERROR_SRC="https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.36.tar.gz"
GCRYPT_SRC="https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.8.4.tar.gz"
PIXMAN_SRC="https://www.cairographics.org/releases/pixman-0.38.0.tar.gz"
OPENSSL_SRC="https://www.openssl.org/source/openssl-1.1.1b.tar.gz"
OPUS_SRC="https://archive.mozilla.org/pub/opus/opus-1.3.tar.gz"
SPICE_PROTOCOL_SRC="https://www.spice-space.org/download/releases/spice-protocol-0.12.15.tar.bz2"
SPICE_SERVER_SRC="https://www.spice-space.org/download/releases/spice-server/spice-0.14.1.tar.bz2"
NCURSES_SRC="https://invisible-mirror.net/archives/ncurses/ncurses-6.1.tar.gz"
QEMU_SRC="https://download.qemu.org/qemu-4.0.0.tar.xz"
QEMU_GIT="https://github.com/halts/qemu.git"

# Source files for spice-client
JSON_GLIB_SRC="https://ftp.gnome.org/pub/GNOME/sources/json-glib/1.2/json-glib-1.2.8.tar.xz"
GST_SRC="https://gstreamer.freedesktop.org/src/gstreamer/gstreamer-1.15.2.tar.xz"
GST_BASE_SRC="https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.15.2.tar.xz"
GST_GOOD_SRC="https://gstreamer.freedesktop.org/src/gst-plugins-good/gst-plugins-good-1.15.2.tar.xz"
SPICE_CLIENT_SRC="https://www.spice-space.org/download/gtk/spice-gtk-0.36.tar.bz2"

# Directories
BUILD_DIR="build"
PATCHES_DIR="patches"
SYSROOT_DIR="sysroot"

# Printing coloured lines
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Build environment
ARCH=$1
CHOST=
SDK=
SDKMINVER="8.0"
NCPU=$(sysctl -n hw.ncpu)

command -v realpath >/dev/null 2>&1 || realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

[ -d "$SYSROOT_DIR" ] || mkdir -p "$SYSROOT_DIR"
PREFIX="$(realpath "$SYSROOT_DIR")"

usage () {
    echo "Usage: [VARIABLE...] $(basename $0) [architecture]"
    echo ""
    echo "  architecture   Target architecture. Default arm64. [armv7|armv7s|arm64|i386|x86_64]"
    echo ""
    echo "  VARIABLEs are:"
    echo "    SDKVERSION   Target a specific SDK version."
    echo "    CHOST        Configure host, set if not deducable by ARCH."
    echo "    SDK          SDK target, set if not deducable by ARCH. [iphoneos|iphonesimulator]"
    echo ""
    echo "    CFLAGS CPPFLAGS CXXFLAGS LDFLAGS PKG_CONFIG_PATH"
    echo ""
    exit 1
}

check_env () {
    command -v pkg-config >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'pkg-config' on your host machine.${NC}"; exit 1; }
    command -v msgfmt >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'gettext' on your host machine.\n\t'msgfmt' needs to be in your \$PATH as well.${NC}"; exit 1; }
    command -v glib-mkenums >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'glib' on your host machine.\n\t'glib-mkenums' needs to be in your \$PATH as well.${NC}"; exit 1; }
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
    if [ -f "$TARGET" ]; then
        echo "${GREEN}$TARGET already downloaded! Delete it to re-download.${NC}"
    else
        echo "${GREEN}Downloading ${URL}...${NC}"
        curl -L -O "$URL"
        mv "$FILE" "$TARGET"
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
    echo "${GREEN}Configuring ${NAME}...${NC}"
    ./Configure $OPENSSL_CROSS no-dso no-hw no-engine --prefix="$PREFIX" $@
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
    echo "${GREEN}Configuring ${NAME}...${NC}"
    ./configure --prefix="$PREFIX" --host="$CHOST" $@
    echo "${GREEN}Building ${NAME}...${NC}"
    make "$MAKEFLAGS"
    echo "${GREEN}Installing ${NAME}...${NC}"
    make "$MAKEFLAGS" install
    cd "$pwd"
}

build_qemu_dependencies () {
    build $FFI_SRC
    build $ICONV_SRC
    build $GETTEXT_SRC
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
    cp "$BUILD_DIR/qemu/libucontext/libucontext.a" "$PREFIX/lib/libucontext.a"
    cp "$BUILD_DIR/qemu/libucontext/include/libucontext.h" "$PREFIX/include/libucontext.h"
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
    install_name_tool -id "@rpath/$(basename "$FILE")" "$FILE"
    for f in $LIST
    do
        base=$(basename "$f")
        dir=$(dirname "$f")
        if [ "$dir" == "$PREFIX/lib" ]; then
            install_name_tool -change "$f" "@rpath/$base" "$FILE"
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
download_all
build_qemu_dependencies
build_qemu
steal_libucontext # should be a better way...
build_spice_client
fixup_all
remove_shared_gst_plugins # another hack...
echo "${GREEN}All done!${NC}"
