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
IOS_SDKMINVER="11.0"
MAC_SDKMINVER="10.11"
VISIONOS_SDKMINVER="1.0"

# Build environment
PLATFORM=
CHOST=
SDK=
SDKMINVER=
CLEAN_PATH="$PATH"
DEBUG=

command -v realpath >/dev/null 2>&1 || realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

version_check() {
    [ "$1" = "$(echo "$1\n$2" | sort -V | head -n1)" ]
}

usage () {
    echo "Usage: [VARIABLE...] $(basename $0) [-p platform] [-a architecture] [-q qemu_path] [-d] [-r] [-x]"
    echo ""
    echo "  -p platform      Target platform. Default ios. [ios|ios_simulator|ios-tci|ios_simulator-tci|macos|visionos|visionos_simulator]"
    echo "  -a architecture  Target architecture. Default arm64. [armv7|armv7s|arm64|i386|x86_64]"
    echo "  -q qemu_path     Do not download QEMU, use qemu_path instead."
    echo "  -d, --download   Force re-download of source even if already downloaded."
    echo "  -r, --rebuild    Avoid cleaning build directory."
    echo "  -x, --debug      Build for debug."
    echo ""
    echo "  VARIABLEs are:"
    echo "    NCPU           Number of CPUs to use in 'make', 0 to use all cores."
    echo "    SDKVERSION     Target a specific SDK version."
    echo "    CHOST          Configure host, set if not deducable by ARCH."
    echo ""
    echo "    CFLAGS CPPFLAGS CXXFLAGS LDFLAGS"
    echo ""
    exit 1
}

python_module_test () {
    python3 -c "import $1"
}

check_env () {
    command -v brew >/dev/null 2>&1 || { echo >&2 "${RED}Homebrew is required to be installed.${NC}"; exit 1; }
    brew --prefix llvm >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'llvm' from Homebrew.${NC}"; exit 1; }
    command -v python3 >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'python3' on your host machine.${NC}"; exit 1; }
    python_module_test six >/dev/null 2>&1 || { echo >&2 "${RED}'six' not found in your Python 3 installation.${NC}"; exit 1; }
    python_module_test pyparsing >/dev/null 2>&1 || { echo >&2 "${RED}'pyparsing' not found in your Python 3 installation.${NC}"; exit 1; }
    python_module_test distutils >/dev/null 2>&1 || { echo >&2 "${RED}'setuptools' not found in your Python 3 installation.${NC}"; exit 1; }
    python_module_test yaml >/dev/null 2>&1 || { echo >&2 "${RED}'pyyaml' not found in your Python 3 installation.${NC}"; exit 1; }
    python_module_test distlib >/dev/null 2>&1 || { echo >&2 "${RED}'distlib' not found in your Python 3 installation.${NC}"; exit 1; }
    python_module_test mako >/dev/null 2>&1 || { echo >&2 "${RED}'mako' not found in your Python 3 installation.${NC}"; exit 1; }
    command -v meson >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'meson' on your host machine.${NC}"; exit 1; }
    command -v cmake >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'cmake' on your host machine.${NC}"; exit 1; }
    command -v msgfmt >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'gettext' on your host machine.\n\t'msgfmt' needs to be in your \$PATH as well.${NC}"; exit 1; }
    command -v glib-mkenums >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'glib-utils' on your host machine.\n\t'glib-mkenums' needs to be in your \$PATH as well.${NC}"; exit 1; }
    command -v glib-compile-resources >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'glib-utils' on your host machine.\n\t'glib-compile-resources' needs to be in your \$PATH as well.${NC}"; exit 1; }
    command -v gpg-error-config >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'libgpg-error' on your host machine.\n\t'gpg-error-config' needs to be in your \$PATH as well.${NC}"; exit 1; }
    command -v xcrun >/dev/null 2>&1 || { echo >&2 "${RED}'xcrun' is not found. Make sure you are running on OSX."; exit 1; }
    command -v otool >/dev/null 2>&1 || { echo >&2 "${RED}'otool' is not found. Make sure you are running on OSX."; exit 1; }
    command -v install_name_tool >/dev/null 2>&1 || { echo >&2 "${RED}'install_name_tool' is not found. Make sure you are running on OSX."; exit 1; }
    version_check "2.4" "$(bison -V | head -1 | awk '{ print $NF }')" || { echo >&2 "${RED}'bison' >= 2.4 is required. Did you install from Homebrew and updated your \$PATH variable?"; exit 1; }
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
        echo "${GREEN}Downloading ${URL}${NC}"
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

clone () {
    REPO="$1"
    COMMIT="$2"
    SUBDIRS="$3"
    NAME="$(basename $REPO)"
    DIR="$BUILD_DIR/$NAME"
    if [ -d "$DIR" -a -z "$REDOWNLOAD" ]; then
        echo "${GREEN}$DIR already downloaded! Run with -d to force re-download.${NC}"
    else
        rm -rf "$DIR"
        echo "${GREEN}Cloning ${REPO}...${NC}"
        git clone --filter=tree:0 --no-checkout "$REPO" "$DIR"
        if [ ! -z "$SUBDIRS" ]; then
            git -C "$DIR" sparse-checkout init
            git -C "$DIR" sparse-checkout set $SUBDIRS
        fi
    fi
    git -C "$DIR" checkout "$COMMIT"
}

download_all () {
    [ -d "$BUILD_DIR" ] || mkdir -p "$BUILD_DIR"
    download $PKG_CONFIG_SRC
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
    download $TPMS_SRC
    download $SWTPM_SRC
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
    download $ZSTD_SRC
    download $SLIRP_SRC
    download $QEMU_SRC
    if [ -z "$SKIP_USB_BUILD" ]; then
        download $USB_SRC
        download $USBREDIR_SRC
    fi
    clone $WEBKIT_REPO $WEBKIT_COMMIT "$WEBKIT_SUBDIRS"
    clone $EPOXY_REPO $EPOXY_COMMIT
    clone $VULKAN_LOADER_REPO $VULKAN_LOADER_COMMIT
    clone $VIRGLRENDERER_REPO $VIRGLRENDERER_COMMIT
    clone $HYPERVISOR_REPO $HYPERVISOR_COMMIT
    clone $LIBUCONTEXT_REPO $LIBUCONTEXT_COMMIT
    clone $MESA_REPO $MESA_COMMIT
    clone $MOLTENVK_REPO $MOLTENVK_COMMIT
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
    LC_ALL=C sed -i '' -e 's/__UNAVAILABLE_PUBLIC_IOS;/;/g' $(find "$OUTPUT_INCLUDES/IOKit" -type f)
    mkdir -p "$OUTPUT_INCLUDES/libkern"
    cp -r "$OSTYPES_HEADERS_PATH/OSTypes.h" "$OUTPUT_INCLUDES/libkern/OSTypes.h"
}

meson_quote() {
    echo "'$(echo $* | sed "s/ /','/g")'"
}

generate_meson_cross() {
    cross="$1"
    system="$2"
    echo "# Automatically generated - do not modify" > $cross
    echo "[properties]" >> $cross
    echo "needs_exe_wrapper = true" >> $cross
    echo "[built-in options]" >> $cross
    echo "c_args = [${CFLAGS:+$(meson_quote $CFLAGS)}]" >> $cross
    echo "cpp_args = [${CXXFLAGS:+$(meson_quote $CXXFLAGS)}]" >> $cross
    echo "objc_args = [${CFLAGS:+$(meson_quote $CFLAGS)}]" >> $cross
    echo "c_link_args = [${LDFLAGS:+$(meson_quote $LDFLAGS)}]" >> $cross
    echo "cpp_link_args = [${LDFLAGS:+$(meson_quote $LDFLAGS)}]" >> $cross
    echo "objc_link_args = [${LDFLAGS:+$(meson_quote $LDFLAGS)}]" >> $cross
    echo "[binaries]" >> $cross
    echo "c = [$(meson_quote $CC)]" >> $cross
    echo "cpp = [$(meson_quote $CXX)]" >> $cross
    echo "objc = [$(meson_quote $OBJCC)]" >> $cross
    echo "ar = [$(meson_quote $AR)]" >> $cross
    echo "nm = [$(meson_quote $NM)]" >> $cross
    echo "pkgconfig = ['$PREFIX/host/bin/pkg-config']" >> $cross
    echo "ranlib = [$(meson_quote $RANLIB)]" >> $cross
    echo "strip = [$(meson_quote $STRIP), '-x']" >> $cross
    echo "python = ['$(which python3)']" >> $cross
    echo "glib-mkenums = ['$(which glib-mkenums)']" >> $cross
    echo "glib-compile-resources = ['$(which glib-compile-resources)']" >> $cross
    echo "[host_machine]" >> $cross
    if [ "$system" == "auto" ]; then
        case $PLATFORM in
        ios* | visionos* )
            echo "system = 'ios'" >> $cross
            ;;
        macos )
            echo "system = 'darwin'" >> $cross
            ;;
        esac
    else
        echo "system = '$system'" >> $cross
    fi
    case "$ARCH" in
    armv7 | armv7s )
        echo "cpu_family = 'arm'" >> $cross
        ;;
    arm64 )
        echo "cpu_family = 'aarch64'" >> $cross
        ;;
    i386 )
        echo "cpu_family = 'x86'" >> $cross
        ;;
    x86_64 )
        echo "cpu_family = 'x86_64'" >> $cross
        ;;
    *)
        echo "cpu_family = '$ARCH'" >> $cross
        ;;
    esac
    echo "cpu = '$ARCH'" >> $cross
    echo "endian = 'little'" >> $cross
}

generate_cmake_toolchain() {
    toolchain="$1"

    # Extract compiler executables
    CC_BIN="${CC%% *}"
    CXX_BIN="${CXX%% *}"
    OBJC_BIN="${OBJCC%% *}"

    echo "# Automatically generated - do not modify" > "$toolchain"
    echo "" >> "$toolchain"
    echo "cmake_minimum_required(VERSION 3.28)" >> "$toolchain"
    echo "" >> "$toolchain"

    #
    # Target platform
    #
    case $PLATFORM in
    ios_simulator* )
        echo "set(CMAKE_SYSTEM_NAME iOS)" >> "$toolchain"
        echo "set(CMAKE_OSX_SYSROOT iphonesimulator)" >> "$toolchain"
        ;;
    ios* )
        echo "set(CMAKE_SYSTEM_NAME iOS)" >> "$toolchain"
        echo "set(CMAKE_OSX_SYSROOT iphoneos)" >> "$toolchain"
        ;;
    visionos_simulator* )
        echo "set(CMAKE_SYSTEM_NAME visionOS)" >> "$toolchain"
        echo "set(CMAKE_OSX_SYSROOT xrsimulator)" >> "$toolchain"
        ;;
    visionos* )
        echo "set(CMAKE_SYSTEM_NAME visionOS)" >> "$toolchain"
        echo "set(CMAKE_OSX_SYSROOT xros)" >> "$toolchain"
        ;;
    macos )
        echo "set(CMAKE_SYSTEM_NAME Darwin)" >> "$toolchain"
        ;;
    esac
    echo "" >> "$toolchain"

    #
    # Architecture
    #
    echo "set(CMAKE_SYSTEM_PROCESSOR \"$ARCH\")" >> "$toolchain"
    echo "set(CMAKE_OSX_ARCHITECTURES \"$ARCH\")" >> "$toolchain"
    echo "set(CMAKE_MACOSX_BUNDLE OFF CACHE BOOL \"\")" >> "$toolchain"
    echo "" >> "$toolchain"

    #
    # Deployment target (derive from -m* flags if present, otherwise leave unset)
    #
    case "$PLATFORM" in
    ios* )
        echo "set(CMAKE_OSX_DEPLOYMENT_TARGET \"$IOS_SDKMINVER\")" >> "$toolchain"
        ;;
    visionos* )
        echo "set(CMAKE_OSX_DEPLOYMENT_TARGET \"$VISIONOS_SDKMINVER\")" >> "$toolchain"
        ;;
    macos )
        echo "set(CMAKE_OSX_DEPLOYMENT_TARGET \"$MAC_SDKMINVER\")" >> "$toolchain"
        ;;
    esac
    echo "" >> "$toolchain"

    #
    # Compilers
    #
    echo "set(CMAKE_C_COMPILER \"$CC_BIN\")" >> "$toolchain"
    echo "set(CMAKE_CXX_COMPILER \"$CXX_BIN\")" >> "$toolchain"
    echo "set(CMAKE_OBJC_COMPILER \"$OBJC_BIN\")" >> "$toolchain"
    echo "" >> "$toolchain"

    #
    # Binutils
    #
    echo "set(CMAKE_AR \"$AR\")" >> "$toolchain"
    echo "set(CMAKE_NM \"$NM\")" >> "$toolchain"
    echo "set(CMAKE_RANLIB \"$RANLIB\")" >> "$toolchain"
    echo "set(CMAKE_STRIP \"$STRIP\")" >> "$toolchain"
    echo "" >> "$toolchain"

    #
    # Flags
    #
    if [ -n "$CFLAGS" ]; then
        echo "set(CMAKE_C_FLAGS \"$CFLAGS\" CACHE STRING \"\" FORCE)" >> "$toolchain"
        echo "set(CMAKE_OBJC_FLAGS \"$CFLAGS\" CACHE STRING \"\" FORCE)" >> "$toolchain"
    fi

    if [ -n "$CXXFLAGS" ]; then
        echo "set(CMAKE_CXX_FLAGS \"$CXXFLAGS\" CACHE STRING \"\" FORCE)" >> "$toolchain"
    fi

    if [ -n "$LDFLAGS" ]; then
        echo "set(CMAKE_EXE_LINKER_FLAGS \"$LDFLAGS\" CACHE STRING \"\" FORCE)" >> "$toolchain"
        echo "set(CMAKE_SHARED_LINKER_FLAGS \"$LDFLAGS\" CACHE STRING \"\" FORCE)" >> "$toolchain"
        echo "set(CMAKE_MODULE_LINKER_FLAGS \"$LDFLAGS\" CACHE STRING \"\" FORCE)" >> "$toolchain"
    fi
    echo "" >> "$toolchain"

    #
    # pkg-config (critical for Apple cross builds)
    #
    echo "set(ENV{PKG_CONFIG} \"$PREFIX/host/bin/pkg-config\")" >> "$toolchain"
    echo "set(ENV{PKG_CONFIG_SYSROOT_DIR} \"$PREFIX\")" >> "$toolchain"
    echo "set(ENV{PKG_CONFIG_PATH} \"$PREFIX/host/lib/pkgconfig:$PREFIX/host/share/pkgconfig\")" >> "$toolchain"
    echo "" >> "$toolchain"

    #
    # Python (for find_package(Python3))
    #
    echo "set(Python3_EXECUTABLE \"$(which python3)\")" >> "$toolchain"
    echo "" >> "$toolchain"

    #
    # Cross-compile search behavior
    #
    echo "set(CMAKE_FIND_ROOT_PATH \"$PREFIX\")" >> "$toolchain"
    echo "set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)" >> "$toolchain"
    echo "set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)" >> "$toolchain"
    echo "set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)" >> "$toolchain"
    echo "set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)" >> "$toolchain"
}

# Prevent contamination from host pkg-config files by building our own
build_pkg_config() {
    FILE="$(basename $PKG_CONFIG_SRC)"
    NAME="${FILE%.tar.*}"
    DIR="$BUILD_DIR/$NAME"
    pwd="$(pwd)"

    cd "$DIR"
    if [ -z "$REBUILD" ]; then
        echo "${GREEN}Configuring ${NAME}...${NC}"
        env -i CFLAGS="-Wno-error=int-conversion" ./configure --prefix="$PREFIX" --bindir="$PREFIX/host/bin" --with-internal-glib $@
    fi
    echo "${GREEN}Building ${NAME}...${NC}"
    make -j$NCPU
    echo "${GREEN}Installing ${NAME}...${NC}"
    make install
    cd "$pwd"

    export PATH="$PREFIX/host/bin:$PATH"
    export PKG_CONFIG="$PREFIX/host/bin/pkg-config"
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
    visionos_simulator )
        OPENSSL_CROSS=visionos-sim-cross-$ARCH
        ;;
    visionos* )
        OPENSSL_CROSS=visionos-cross-$ARCH
        ;;
    esac
    if [ -z "$OPENSSL_CROSS" ]; then
        echo "${RED}Unsupported configuration for OpenSSL $PLATFORM, $ARCH${NC}"
        exit 1
    fi

    if [ ! -z "$DEBUG" ]; then
        DEBUG_FLAGS="--debug"
    fi

    cd "$DIR"
    if [ -z "$REBUILD" ]; then
        echo "${GREEN}Configuring ${NAME}...${NC}"
        ./Configure $OPENSSL_CROSS no-dso no-hw no-engine --prefix="$PREFIX" $DEBUG_FLAGS $@
    fi
    echo "${GREEN}Building ${NAME}...${NC}"
    make -j$NCPU
    echo "${GREEN}Installing ${NAME}...${NC}"
    make install
    cd "$pwd"
}

build () {
    if [ -d "$1" ]; then
        DIR="$1"
        NAME="$(basename "$DIR")"
    else
        URL=$1
        shift 1
        FILE="$(basename $URL)"
        NAME="${FILE%.tar.*}"
        DIR="$BUILD_DIR/$NAME"
    fi
    pwd="$(pwd)"

    cd "$DIR"
    if [ -z "$REBUILD" ]; then
        echo "${GREEN}Configuring ${NAME}...${NC}"
        ./configure --prefix="$PREFIX" --host="$CHOST" $@
    fi
    echo "${GREEN}Building ${NAME}...${NC}"
    make -j$NCPU
    echo "${GREEN}Installing ${NAME}...${NC}"
    make install
    cd "$pwd"
}

meson_cross_build () {
    CROSS="$1"
    SRCDIR="$2"
    shift 2
    FILE="$(basename $SRCDIR)"
    NAME="${FILE%.tar.*}"
    case $SRCDIR in
    http* | ftp* )
        SRCDIR="$BUILD_DIR/$NAME"
        ;;
    esac
    MESON_CROSS="$(realpath "$BUILD_DIR")/meson-$CROSS.cross"
    if [ ! -f "$MESON_CROSS" ]; then
        generate_meson_cross "$MESON_CROSS" "$CROSS"
    fi
    pwd="$(pwd)"

    if [ -z "$DEBUG" ]; then
        buildtype="release"
    else
        buildtype="debug"
    fi

    cd "$SRCDIR"
    if [ -z "$REBUILD" ]; then
        rm -rf utm_build
        echo "${GREEN}Configuring ${NAME}...${NC}"
        meson utm_build --prefix="$PREFIX" --buildtype="$buildtype" --cross-file "$MESON_CROSS" "$@"
    fi
    echo "${GREEN}Building ${NAME}...${NC}"
    meson compile -C utm_build -j $NCPU
    echo "${GREEN}Installing ${NAME}...${NC}"
    meson install -C utm_build
    cd "$pwd"
}

meson_build () {
    meson_cross_build auto $@
}

meson_darwin_build () {
    meson_cross_build darwin $@
}

cmake_build () {
    SRCDIR="$1"
    shift 1
    FILE="$(basename $SRCDIR)"
    NAME="${FILE%.tar.*}"
    BUILDDIR="utm_build"

    case $SRCDIR in
    http* | ftp* )
        SRCDIR="$BUILD_DIR/$NAME"
        ;;
    esac
    CMAKE_TOOLCHAIN="$(realpath "$BUILD_DIR")/cross.cmake"
    if [ ! -f "$CMAKE_TOOLCHAIN" ]; then
        generate_cmake_toolchain "$CMAKE_TOOLCHAIN"
    fi
    pwd="$(pwd)"

    cd "$SRCDIR"

    if [ -z "$REBUILD" ]; then
        rm -rf "$BUILDDIR"
        mkdir -p "$BUILDDIR"

        echo "${GREEN}Configuring ${NAME}...${NC}"
        cmake -S . -B "$BUILDDIR" \
            -DCMAKE_INSTALL_PREFIX="$PREFIX" \
            -DCMAKE_BUILD_TYPE="$BUILD_CONFIGURATION" \
            -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
            "$@"
    fi

    echo "${GREEN}Building ${NAME}...${NC}"
    cmake --build "$BUILDDIR" --parallel "$NCPU"

    echo "${GREEN}Installing ${NAME}...${NC}"
    cmake --install "$BUILDDIR"

    cd "$pwd"
}

build_angle () {
    OLD_PATH=$PATH
    export PATH="$(realpath "$BUILD_DIR/depot_tools.git"):$OLD_PATH"
    pwd="$(pwd)"
    cd "$BUILD_DIR/WebKit.git/Source/ThirdParty/ANGLE"
    env -i PATH=$PATH xcodebuild archive -archivePath "ANGLE" \
                                         -scheme "ANGLE" \
                                         -sdk $SDK \
                                         -arch $ARCH \
                                         -configuration "$BUILD_CONFIGURATION" \
                                         WEBCORE_LIBRARY_DIR="/usr/local/lib" \
                                         NORMAL_UMBRELLA_FRAMEWORKS_DIR="" \
                                         CODE_SIGNING_ALLOWED=NO \
                                         IPHONEOS_DEPLOYMENT_TARGET="14.0" \
                                         MACOSX_DEPLOYMENT_TARGET="11.0" \
                                         XROS_DEPLOYMENT_TARGET="1.0"
    # FIXME: update minver and remove this hack
    if [ "$SDK" == "iphoneos" ]; then
        find "ANGLE.xcarchive/Products/usr/local/lib/" -name '*.dylib' -exec xcrun vtool -set-version-min ios $SDKMINVER 17.2 -replace -output \{\} \{\} \;
    fi
    rsync -a "ANGLE.xcarchive/Products/usr/local/lib/" "$PREFIX/lib"
    rsync -a "include/" "$PREFIX/include"
    cd "$pwd"
    export PATH=$OLD_PATH
}

build_hypervisor () {
    OLD_PATH=$PATH
    export PATH="$(realpath "$BUILD_DIR/depot_tools.git"):$OLD_PATH"
    pwd="$(pwd)"
    cd "$BUILD_DIR/Hypervisor.git"

    case $PLATFORM in
    *simulator* )
        scheme="HypervisorSimulator"
        ;;
    * )
        scheme="Hypervisor"
        ;;
    esac

    echo "${GREEN}Building Hypervisor...${NC}"
    env -i PATH=$PATH xcodebuild archive -archivePath "Hypervisor" -scheme "$scheme" -sdk $SDK -configuration "$BUILD_CONFIGURATION"

    rsync -a "Hypervisor.xcarchive/Products/Library/Frameworks/" "$PREFIX/Frameworks"
    cd "$pwd"
    export PATH=$OLD_PATH
}

build_qemu_dependencies () {
    build $FFI_SRC
    build $ICONV_SRC
    gl_cv_onwards_func_strchrnul=future build $GETTEXT_SRC --disable-java
    build $PNG_SRC
    build $JPEG_TURBO_SRC
    meson_build $GLIB_SRC -Dtests=false -Ddtrace=disabled
    build $GPG_ERROR_SRC
    build $GCRYPT_SRC
    build $PIXMAN_SRC
    build_openssl $OPENSSL_SRC
    build $TPMS_SRC --disable-shared
    build $SWTPM_SRC --enable-shared-lib
    build $OPUS_SRC
    ZSTD_BASENAME="$(basename $ZSTD_SRC)"
    meson_build "$BUILD_DIR/${ZSTD_BASENAME%.tar.*}/build/meson"
    meson_build $GST_SRC -Dtests=disabled -Ddefault_library=both -Dregistry=false
    meson_build $GST_BASE_SRC -Dtests=disabled -Ddefault_library=both -Dgl=disabled
    meson_build $GST_GOOD_SRC -Dtests=disabled -Ddefault_library=both
    meson_build $SPICE_PROTOCOL_SRC
    meson_build $SPICE_SERVER_SRC -Dlz4=false -Dsasl=false
    meson_darwin_build $SLIRP_SRC
    # USB support
    if [ -z "$SKIP_USB_BUILD" ]; then
        build $USB_SRC
        meson_build $USBREDIR_SRC
    fi
    # GPU support
    build_angle
    meson_build $EPOXY_REPO -Dtests=false -Dglx=no -Degl=yes
    cmake_build $VULKAN_LOADER_REPO -D UPDATE_DEPS=On
    # strip the minor versions
    VULKAN_DYLIB="$PREFIX/lib/libvulkan.1.dylib"
    mv "$(dirname $VULKAN_DYLIB)/$(readlink $VULKAN_DYLIB)" "$VULKAN_DYLIB"
    meson_darwin_build $VIRGLRENDERER_REPO -Dtests=false -Dcheck-gl-errors=false -Dvenus=true -Dvulkan-dload=false -Drender-server-worker=thread
    # Hypervisor for iOS
    if [ "$PLATFORM" == "ios" ] || [ "$PLATFORM" == "ios_simulator" ]; then
        build_hypervisor
    fi
}

build_spice_client () {
    meson_build $LIBUCONTEXT_REPO -Ddefault_library=static -Dfreestanding=true
    meson_build $JSON_GLIB_SRC -Dintrospection=disabled
    build $XML2_SRC --enable-shared=no --without-python
    meson_build $SOUP_SRC -Dsysprof=disabled -Dtls_check=false -Dintrospection=disabled
    meson_build $PHODAV_SRC
    meson_build $SPICE_CLIENT_SRC -Dcoroutine=libucontext
}

patch_vulkan_icd() {
    local icd_file="$1"


    if [ "$PLATFORM" == "macos" ]; then
        sed -i '' -E '
            s|("library_path"[[:space:]]*:[[:space:]]*")[^"]*/lib([^"/]+)\.dylib(")|\1../../../Frameworks/\2.framework/Versions/Current/\2\3|
        ' "$icd_file"
    else
        sed -i '' -E '
            s|("library_path"[[:space:]]*:[[:space:]]*")[^"]*/lib([^"/]+)\.dylib(")|\1../../Frameworks/\2.framework/\2\3|
        ' "$icd_file"
    fi
}

build_moltenvk() {
    pushd "$BUILD_DIR/MoltenVK.git"
    # for xcpretty if installed
    if which ruby >/dev/null && which gem >/dev/null; then
        PATH="$(ruby -r rubygems -e 'puts Gem.user_dir')/bin:$PATH"
    fi
    if [ ! -z "$DEBUG" ]; then
        DEBUG_FLAGS="-debug"
    fi
    case $PLATFORM in
    ios_simulator* )
        MVK_PLATFORM="iossim"
        ;;
    ios* )
        MVK_PLATFORM="ios"
        ;;
    visionos_simulator* )
        MVK_PLATFORM="visionossim"
        ;;
    visionos* )
        MVK_PLATFORM="visionos"
        ;;
    macos )
        MVK_PLATFORM="macos"
        ;;
    esac
    env -i PATH=$PATH HOME=$HOME LANG=en_US.UTF-8 ./fetchDependencies --$MVK_PLATFORM -v
    env -i PATH=$PATH HOME=$HOME LANG=en_US.UTF-8 make $MVK_PLATFORM$DEBUG_FLAGS
    if [ "$PLATFORM" == "macos" ]; then
        $(xcrun --sdk $SDK --find lipo) "Package/$BUILD_CONFIGURATION/MoltenVK/dylib/macOS/libMoltenVK.dylib" -extract $ARCH -output "$PREFIX/lib/libMoltenVK.dylib"
    else
        find "Package/$BUILD_CONFIGURATION/MoltenVK/dynamic/MoltenVK.xcframework" -name "MoltenVK.framework" -exec cp -a \{\} "$PREFIX/Frameworks/" \;
    fi
    cp -a "MoltenVK/icd/MoltenVK_icd.json" "$PREFIX/share/vulkan/icd.d/"
    popd
}

build_mesa_host () {
    pushd "$BUILD_DIR/mesa.git"

    HOST_PATH="$(brew --prefix llvm)/bin:$CLEAN_PATH"
    env -i PATH="$HOST_PATH" meson host_build --prefix="$PREFIX/host" --buildtype=release \
        -Dllvm=enabled -Dstrip=true -Dopengl=false -Dgallium-drivers= -Dvulkan-drivers= -Dmesa-clc=enabled -Dinstall-mesa-clc=true
    env -i PATH="$HOST_PATH" meson compile -C host_build -j $NCPU
    env -i PATH="$HOST_PATH" meson install -C host_build

    popd
}

build_vulkan_drivers () {
    mkdir -p "$PREFIX/share/vulkan/icd.d"
    build_mesa_host
    meson_darwin_build $MESA_REPO -Dmesa-clc=system -Dgallium-drivers= -Dvulkan-drivers=kosmickrisp -Dplatforms=macos
    patch_vulkan_icd "$PREFIX/share/vulkan/icd.d/kosmickrisp_mesa_icd.$ARCH.json"
    mv "$PREFIX/share/vulkan/icd.d/kosmickrisp_mesa_icd.$ARCH.json" "$PREFIX/share/vulkan/icd.d/kosmickrisp_mesa_icd.json"
    build_moltenvk
    patch_vulkan_icd "$PREFIX/share/vulkan/icd.d/MoltenVK_icd.json"
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
        if [ "$dir" == "$PREFIX/lib" ] || [ "$dir" == "@rpath" ]; then
            if [ "$PLATFORM" == "macos" ]; then
                newname="@rpath/$libname.framework/Versions/A/$libname"
            else
                newname="@rpath/$libname.framework/$libname"
            fi
            install_name_tool -change "$g" "$newname" "$NEWFILE"
        fi
    done
    IFS=$OLDIFS
}

fixup_all () {
    OLDIFS=$IFS
    IFS=$'\n'
    FILES=$(find "$SYSROOT_DIR/lib" -type f -maxdepth 1 -name "*.dylib")
    for f in $FILES
    do
        fixup $f
    done
    IFS=$OLDIFS
}

remove_shared_gst_plugins () {
    find "$SYSROOT_DIR/lib/gstreamer-1.0" -name '*.dylib' -exec rm \{\} \;
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
        ARCH=$(echo "$2" | tr '[:upper:]' '[:lower:]')
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
        PLATFORM=$(echo "$2" | tr '[:upper:]' '[:lower:]')
        shift
        ;;
    -x | --debug )
        DEBUG=1
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
ios* | visionos* )
    if [ -z "$SDKMINVER" ]; then
        case $PLATFORM in
        ios* )
            SDKMINVER="$IOS_SDKMINVER"
            ;;
        visionos* )
            SDKMINVER="$VISIONOS_SDKMINVER"
            ;;
        esac
    fi
    HVF_FLAGS="--disable-hvf"
    case $PLATFORM in
    ios_simulator* )
        SDK=iphonesimulator
        CFLAGS_TARGET="-target $ARCH-apple-ios$SDKMINVER-simulator"
        PLATFORM_FAMILY_PREFIX="iOS_Simulator"
        ;;
    ios* )
        SDK=iphoneos
        CFLAGS_TARGET="-target $ARCH-apple-ios$SDKMINVER"
        PLATFORM_FAMILY_PREFIX="iOS"
        HVF_FLAGS="--enable-hvf-private"
        ;;
    visionos_simulator* )
        SDK=xrsimulator
        CFLAGS_TARGET="-target $ARCH-apple-xros$SDKMINVER-simulator"
        PLATFORM_FAMILY_PREFIX="visionOS_Simulator"
        ;;
    visionos* )
        SDK=xros
        CFLAGS_TARGET="-target $ARCH-apple-xros$SDKMINVER"
        PLATFORM_FAMILY_PREFIX="visionOS"
        ;;
    esac
    case $PLATFORM in
    *-tci )
        if [ "$ARCH" == "arm64" ]; then
            TCI_BUILD_FLAGS="--enable-tcg-threaded-interpreter --target-list=aarch64-softmmu,i386-softmmu,ppc-softmmu,ppc64-softmmu,riscv64-softmmu,x86_64-softmmu,m68k-softmmu --extra-cflags=-Wno-unused-command-line-argument --extra-ldflags=-Wl,-no_deduplicate --extra-ldflags=-Wl,-random_uuid --extra-ldflags=-Wl,-no_compact_unwind"
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
    QEMU_PLATFORM_BUILD_FLAGS="--enable-shared-lib --disable-cocoa --disable-coreaudio --disable-slirp-smbd --enable-ucontext --with-coroutine=libucontext $HVF_FLAGS $TCI_BUILD_FLAGS"
    ;;
macos )
    if [ -z "$SDKMINVER" ]; then
        SDKMINVER="$MAC_SDKMINVER"
    fi
    SDK=macosx
    CFLAGS_TARGET="-target $ARCH-apple-macos$SDKMINVER"
    PLATFORM_FAMILY_NAME="macOS"
    QEMU_PLATFORM_BUILD_FLAGS="--enable-shared-lib --disable-cocoa --cpu=$CPU"
    ;;
* )
    usage
    ;;
esac

if [ -z "$DEBUG" ]; then
    QEMU_DEBUG_FLAGS="--disable-debug-info"
fi

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
else
    QEMU_DIR="$(realpath "$QEMU_DIR")"
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

# Set NCPU
if [ -z "$NCPU" ] || [ $NCPU -eq 0 ]; then
    NCPU="$(sysctl -n hw.ncpu)"
fi
export NCPU

# Export tools
CC="$(xcrun --sdk $SDK --find gcc) $CFLAGS_TARGET"
CPP=$(xcrun --sdk $SDK --find gcc)" -E"
CXX=$(xcrun --sdk $SDK --find g++)
OBJCC=$(xcrun --sdk $SDK --find clang)
LD=$(xcrun --sdk $SDK --find ld)
AR=$(xcrun --sdk $SDK --find ar)
NM=$(xcrun --sdk $SDK --find nm)
RANLIB=$(xcrun --sdk $SDK --find ranlib)
STRIP=$(xcrun --sdk $SDK --find strip)
export CC
export CPP
export CXX
export OBJCC
export LD
export AR
export NM
export RANLIB
export STRIP
export PREFIX

if [ -z "$DEBUG" ]; then
    DEBUG_FLAGS=
    BUILD_CONFIGURATION="Release"
else
    DEBUG_FLAGS="-g -O0"
    BUILD_CONFIGURATION="Debug"
fi

# Flags
CFLAGS="$CFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include -F$PREFIX/Frameworks $DEBUG_FLAGS"
CPPFLAGS="$CPPFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include -F$PREFIX/Frameworks $CFLAGS_TARGET $DEBUG_FLAGS"
CXXFLAGS="$CXXFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include -F$PREFIX/Frameworks $CFLAGS_TARGET $DEBUG_FLAGS"
OBJCFLAGS="$OBJCFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include -F$PREFIX/Frameworks $CFLAGS_TARGET $DEBUG_FLAGS"
LDFLAGS="$LDFLAGS -arch $ARCH -isysroot $SDKROOT -L$PREFIX/lib -F$PREFIX/Frameworks $CFLAGS_TARGET $DEBUG_FLAGS"
export CFLAGS
export CPPFLAGS
export CXXFLAGS
export OBJCFLAGS
export LDFLAGS

check_env
echo "${GREEN}Starting build for ${PLATFORM_FAMILY_NAME} ${ARCH} [${NCPU} jobs]${NC}"

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
rm -f "$BUILD_DIR/meson*.cross"
rm -f "$BUILD_DIR/cross.cmake"
mkdir -p "$PREFIX/Frameworks"
copy_private_headers
build_pkg_config
build_qemu_dependencies
build $QEMU_DIR --cross-prefix="" $QEMU_PLATFORM_BUILD_FLAGS $QEMU_DEBUG_FLAGS
build_spice_client
build_vulkan_drivers
fixup_all
remove_shared_gst_plugins # another hack...
echo "${GREEN}All done!${NC}"
touch "$BUILD_DIR/BUILD_SUCCESS"
