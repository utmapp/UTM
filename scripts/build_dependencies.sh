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

# Printing coloured lines
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Knobs
IOS_SDKMINVER="9.0"
MAC_SDKMINVER="10.11"

# Build environment
PLATFORM=
CHOST=
SDK=
SDKMINVER=
NCPU=$(sysctl -n hw.ncpu)

command -v realpath >/dev/null 2>&1 || realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

usage () {
    echo "Usage: [VARIABLE...] $(basename $0) [-p platform] [-a architecture] [-q qemu_path] [-d] [-r]"
    echo ""
    echo "  -p platform      Target platform. Default ios. [ios|ios_simulator|ios-tci|ios_simulator-tci|macos]"
    echo "  -a architecture  Target architecture. Default arm64. [armv7|armv7s|arm64|i386|x86_64]"
    echo "  -q qemu_path     Do not download QEMU, use qemu_path instead."
    echo "  -d, --download   Force re-download of source even if already downloaded."
    echo "  -r, --rebuild    Avoid cleaning build directory."
    echo ""
    echo "  VARIABLEs are:"
    echo "    SDKVERSION     Target a specific SDK version."
    echo "    CHOST          Configure host, set if not deducable by ARCH."
    echo ""
    echo "    CFLAGS CPPFLAGS CXXFLAGS LDFLAGS PKG_CONFIG_PATH"
    echo ""
    exit 1
}

check_env () {
    command -v gmake >/dev/null 2>&1 || { echo >&2 "${RED}You must install GNU make on your host machine (and link it to 'gmake').${NC}"; exit 1; }
    command -v meson >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'meson' on your host machine.${NC}"; exit 1; }
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
    DATA="$PATCHES_DIR/data/${NAME}"
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
    if [ -d "$DATA" ]; then
        echo "${GREEN}Patching data ${NAME}...${NC}"
        cp -r "$DATA/" "$DIR"
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
    download $JSON_GLIB_SRC
    download $GST_SRC
    download $GST_BASE_SRC
    download $GST_GOOD_SRC
    download $XML2_SRC
    download $SOUP_SRC
    download $PHODAV_SRC
    download $SPICE_CLIENT_SRC
    download $QEMU_SRC
    if [ -z "$SKIP_USB_BUILD" ]; then
        download $USB_SRC
        download $USBREDIR_SRC
    fi
}

copy_private_headers() {
    MACOS_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
    IOKIT_HEADERS_PATH="$MACOS_SDK_PATH/System/Library/Frameworks/IOKit.framework/Headers"
    OSTYPES_HEADERS_PATH="$MACOS_SDK_PATH/usr/include/libkern"
    OUTPUT_INCLUDES="$PREFIX/include"
    if [ ! -d "$IOKIT_HEADERS_PATH" ]; then
        echo "${RED}Failed to find IOKit headers in: $IOKIT_HEADERS_PATH${NC}"
        exit 1
    fi
    if [ ! -d "$OSTYPES_HEADERS_PATH" ]; then
        echo "${RED}Failed to find libkern headers in: $OSTYPES_HEADERS_PATH${NC}"
        exit 1
    fi
    echo "${GREEN}Copying private headers...${NC}"
    mkdir -p "$OUTPUT_INCLUDES"
    cp -r "$IOKIT_HEADERS_PATH" "$OUTPUT_INCLUDES/IOKit"
    rm "$OUTPUT_INCLUDES/IOKit/storage/IOMedia.h" # needed to pass QEMU check
    # patch headers
    LC_ALL=C sed -i '' -e 's/#if KERNEL_USER32/#if 0/g' $(find "$OUTPUT_INCLUDES/IOKit" -type f)
    LC_ALL=C sed -i '' -e 's/#if !KERNEL_USER32/#if 1/g' $(find "$OUTPUT_INCLUDES/IOKit" -type f)
    LC_ALL=C sed -i '' -e 's/#if KERNEL/#if 0/g' $(find "$OUTPUT_INCLUDES/IOKit" -type f)
    LC_ALL=C sed -i '' -e 's/#if !KERNEL/#if 1/g' $(find "$OUTPUT_INCLUDES/IOKit" -type f)
    mkdir -p "$OUTPUT_INCLUDES/libkern"
    cp -r "$OSTYPES_HEADERS_PATH/OSTypes.h" "$OUTPUT_INCLUDES/libkern/OSTypes.h"
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
    CROSS_SDK="$SDKNAME$SDKVERSION.sdk" # for openssl
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
    case $PLATFORM in
    ios | ios-tci )
        case $ARCH in
        armv7 | armv7s )
            OPENSSL_CROSS=iphoneos-cross
            ;;
        arm64 )
            OPENSSL_CROSS=ios64-cross
            ;;
        i386 | x86_64 )
            OPENSSL_CROSS=iossimulator64-cross
            ;;
        esac
        ;;
    macos )
        case $ARCH in
        arm64 )
            OPENSSL_CROSS=darwin64-arm64-cc
            ;;
        i386 )
            OPENSSL_CROSS=darwin-i386-cc
            ;;
        x86_64 )
            OPENSSL_CROSS=darwin64-x86_64-cc
            ;;
        esac
        ;;
    esac
    if [ -z "$OPENSSL_CROSS" ]; then
        echo "${RED}Unsupported configuration for OpenSSL $PLATFORM, $ARCH${NC}"
        exit 1
    fi

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
    if [ -z "$SKIP_USB_BUILD" ]; then
        build $USB_SRC
        build $USBREDIR_SRC
    fi
}

build_qemu () {
    pwd="$(pwd)"
    cd "$QEMU_DIR"
    echo "${GREEN}Configuring QEMU...${NC}"
    ./configure --prefix="$PREFIX" --host="$CHOST" --cross-prefix="" $@
    echo "${GREEN}Building QEMU...${NC}"
    gmake "$MAKEFLAGS"
    echo "${GREEN}Installing QEMU...${NC}"
    gmake "$MAKEFLAGS" install
    cd "$pwd"
}

build_libucontext () {
    MESON_CROSS="$(realpath "$QEMU_DIR/build/config-meson.cross")"
    pwd="$(pwd)"

    cd "$QEMU_DIR/subprojects/libucontext"
    echo "${GREEN}Configuring libucontext...${NC}"
    meson build --prefix="/" --buildtype=plain --cross-file "$MESON_CROSS" -Ddefault_library=static -Dfreestanding=true $@
    echo "${GREEN}Building libucontext...${NC}"
    meson compile -C build
    echo "${GREEN}Installing libucontext...${NC}"
    DESTDIR="$PREFIX" meson install -C build
    cd "$pwd"
}

build_spice_client () {
    build $JSON_GLIB_SRC
    build $GST_SRC --enable-static --enable-static-plugins --disable-registry
    build $GST_BASE_SRC --enable-static --disable-fatal-warnings --disable-cocoa
    build $GST_GOOD_SRC --enable-static --disable-osx_video
    build $XML2_SRC --enable-shared=no --without-python
    build $SOUP_SRC --without-gnome --without-krb5-config --enable-shared=no --disable-tls-check
    build $PHODAV_SRC
    build $SPICE_CLIENT_SRC --with-gtk=no
}

fixup () {
    FILE=$1
    BASE=$(basename "$FILE")
    BASEFILENAME=${BASE%.*}
    LIBNAME=${BASEFILENAME#lib*}
    BUNDLE_ID="com.utmapp.${LIBNAME//_/-}"
    FRAMEWORKNAME="$LIBNAME.framework"
    BASEFRAMEWORKPATH="$PREFIX/Frameworks/$FRAMEWORKNAME"
    if [ "$PLATFORM" == "macos" ]; then
        FRAMEWORKPATH="$BASEFRAMEWORKPATH/Versions/A"
        INFOPATH="$FRAMEWORKPATH/Resources"
    else
        FRAMEWORKPATH="$BASEFRAMEWORKPATH"
        INFOPATH="$FRAMEWORKPATH"
    fi
    NEWFILE="$FRAMEWORKPATH/$LIBNAME"
    LIST=$(otool -L "$FILE" | tail -n +2 | cut -d ' ' -f 1 | awk '{$1=$1};1')
    OLDIFS=$IFS
    IFS=$'\n'
    echo "${GREEN}Fixing up $FILE...${NC}"
    mkdir -p "$FRAMEWORKPATH"
    mkdir -p "$INFOPATH"
    cp -a "$FILE" "$NEWFILE"
    /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $LIBNAME" "$INFOPATH/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$INFOPATH/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string $SDKMINVER" "$INFOPATH/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$INFOPATH/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0" "$INFOPATH/Info.plist"
    if [ "$PLATFORM" == "macos" ]; then
        ln -sf "A" "$BASEFRAMEWORKPATH/Versions/Current"
        ln -sf "Versions/Current/Resources" "$BASEFRAMEWORKPATH/Resources"
        ln -sf "Versions/Current/$LIBNAME" "$BASEFRAMEWORKPATH/$LIBNAME"
    fi
    newname="@rpath/$FRAMEWORKNAME/$LIBNAME"
    install_name_tool -id "$newname" "$NEWFILE"
    for g in $LIST
    do
        base=$(basename "$g")
        basefilename=${base%.*}
        libname=${basefilename#lib*}
        dir=$(dirname "$g")
        if [ "$dir" == "$PREFIX/lib" ]; then
            newname="@rpath/$libname.framework/$libname"
            install_name_tool -change "$g" "$newname" "$NEWFILE"
        fi
    done
    IFS=$OLDIFS
}

fixup_all () {
    OLDIFS=$IFS
    IFS=$'\n'
    FILES=$(find "$SYSROOT_DIR/lib" -type f -name "*.dylib")
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
    python3 "$BASEDIR/qapi-gen.py" -b -o "$SYSROOT_DIR/qapi" "$APIS"
}

# parse args
ARCH=
REBUILD=
QEMU_DIR=
REDOWNLOAD=
PLATFORM_FAMILY_NAME=
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
        QEMU_DIR="$2"
        shift
        ;;
    -p )
        PLATFORM=$2
        shift
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

if [ "x$PLATFORM" == "x" ]; then
    PLATFORM=ios
fi

# Export supplied CHOST or deduce by ARCH
if [ -z "$CHOST" ]; then
    case $ARCH in
    armv7 | armv7s )
        CPU=arm
        ;;
    arm64 )
        CPU=aarch64
        ;;
    i386 | x86_64 )
        CPU=$ARCH
        ;;
    * )
        usage
        ;;
    esac
fi
CHOST=$CPU-apple-darwin
export CHOST

case $PLATFORM in
ios* )
    if [ -z "$SDKMINVER" ]; then
        SDKMINVER="$IOS_SDKMINVER"
    fi
    case $PLATFORM in
    *simulator* )
        SDK=iphonesimulator
        CFLAGS_MINVER="-mios-simulator-version-min=$SDKMINVER"
        PLATFORM_FAMILY_PREFIX="iOS_Simulator"
        ;;
    * )
        SDK=iphoneos
        CFLAGS_MINVER="-miphoneos-version-min=$SDKMINVER"
        PLATFORM_FAMILY_PREFIX="iOS"
        ;;
    esac
    CFLAGS_TARGET=
    case $PLATFORM in
    *-tci )
        if [ "$ARCH" == "arm64" ]; then
            TCI_BUILD_FLAGS="--enable-tcg-tcti --target-list=aarch64-softmmu,arm-softmmu,i386-softmmu,ppc-softmmu,ppc64-softmmu,riscv32-softmmu,riscv64-softmmu,x86_64-softmmu"
        else
            TCI_BUILD_FLAGS="--enable-tcg-interpreter"
        fi
        PLATFORM_FAMILY_NAME="$PLATFORM_FAMILY_PREFIX-TCI"
        SKIP_USB_BUILD=1
        ;;
    * )
        PLATFORM_FAMILY_NAME="$PLATFORM_FAMILY_PREFIX"
        ;;
    esac
    QEMU_PLATFORM_BUILD_FLAGS="--disable-debug-info --enable-shared-lib --disable-hvf --disable-cocoa --disable-curl --disable-slirp-smbd --with-coroutine=libucontext $TCI_BUILD_FLAGS"
    ;;
macos )
    if [ -z "$SDKMINVER" ]; then
        SDKMINVER="$MAC_SDKMINVER"
    fi
    SDK=macosx
    CFLAGS_MINVER="-mmacos-version-min=$SDKMINVER"
    CFLAGS_TARGET="-target $ARCH-apple-macos"
    PLATFORM_FAMILY_NAME="macOS"
    QEMU_PLATFORM_BUILD_FLAGS="--disable-debug-info --enable-shared-lib --disable-cocoa --disable-curl --cpu=$CPU"
    ;;
* )
    usage
    ;;
esac
export SDK
export SDKMINVER

# Setup directories
BASEDIR="$(dirname "$(realpath $0)")"
BUILD_DIR="build-$PLATFORM_FAMILY_NAME-$ARCH"
SYSROOT_DIR="sysroot-$PLATFORM_FAMILY_NAME-$ARCH"
PATCHES_DIR="$BASEDIR/../patches"

# Include URL list
source "$PATCHES_DIR/sources"

if [ -z "$QEMU_DIR" ]; then
    FILE="$(basename $QEMU_SRC)"
    QEMU_DIR="$BUILD_DIR/${FILE%.tar.*}"
elif [ ! -d "$QEMU_DIR" ]; then
    echo "${RED}Cannot find: ${QEMU_DIR}...${NC}"
    exit 1
fi

[ -d "$SYSROOT_DIR" ] || mkdir -p "$SYSROOT_DIR"
PREFIX="$(realpath "$SYSROOT_DIR")"

# Export supplied SDKVERSION or use system default
SDKNAME=$(basename $(xcrun --sdk $SDK --show-sdk-platform-path) .platform)
if [ ! -z "$SDKVERSION" ]; then
    SDKROOT=$(xcrun --sdk $SDK --show-sdk-platform-path)"/Developer/SDKs/$SDKNAME$SDKVERSION.sdk"
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
CFLAGS="$CFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include $CFLAGS_MINVER $CFLAGS_TARGET"
CPPFLAGS="$CPPFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include $CFLAGS_MINVER $CFLAGS_TARGET"
CXXFLAGS="$CXXFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include $CFLAGS_MINVER $CFLAGS_TARGET"
LDFLAGS="$LDFLAGS -arch $ARCH -isysroot $SDKROOT -L$PREFIX/lib $CFLAGS_MINVER $CFLAGS_TARGET"
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
    if [ ! -z "$REBUILD" ]; then
        echo "${RED}Error, no previous successful build found.${NC}"
        exit 1
    fi
fi

if [ -z "$REBUILD" ]; then
    download_all
fi
echo "${GREEN}Deleting old sysroot!${NC}"
rm -rf "$PREFIX/"*
rm -f "$BUILD_DIR/BUILD_SUCCESS"
copy_private_headers
build_qemu_dependencies
build_qemu $QEMU_PLATFORM_BUILD_FLAGS
build_libucontext
build_spice_client
fixup_all
remove_shared_gst_plugins # another hack...
generate_qapi $QEMU_SRC
echo "${GREEN}All done!${NC}"
touch "$BUILD_DIR/BUILD_SUCCESS"
