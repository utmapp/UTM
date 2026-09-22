#!/bin/sh
#
# Copyright © 2026 Turing Software, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Wraps dylibs from a sysroot's lib/ into the sysroot's Frameworks/ so they can
# be embedded in the app. Safe to re-run on a sysroot that was already fixed up,
# which lets a single rebuilt dependency be repackaged without a full rebuild.
set -e

GREEN='\033[0;32m'
NC='\033[0m'

usage () {
    echo "Usage: $(basename $0) -p platform -s sysroot [-m minver] [-i] file..."
    echo ""
    echo "  -p platform  Target platform, as passed to build_dependencies.sh. Only 'macos' changes the layout."
    echo "  -s sysroot   Sysroot to write Frameworks/ into and to resolve imports against."
    echo "  -m minver    MinimumOSVersion to use when the binary does not record one."
    echo "  -i           Only rewrite the imports of each file in place (for executables)."
    echo ""
    echo "  Each file becomes <sysroot>/Frameworks/<name>.framework, where <name> is"
    echo "  the file name without the 'lib' prefix and the last extension."
    exit 1
}

# rewrites imports of sysroot libraries to their frameworks
fixup_imports () {
    _file=$1
    _list=$(otool -L "$_file" | tail -n +2 | cut -d ' ' -f 1 | awk '{$1=$1};1')
    for g in $_list
    do
        base=$(basename "$g")
        basefilename=${base%.*}
        libname=${basefilename#lib*}
        dir=$(dirname "$g")
        case "$g" in
        /usr/lib/* | /System/* )
            continue
            ;;
        esac
        # a sysroot staged from elsewhere (such as a CI artifact) records its
        # own absolute path in install names, so also match by file name
        if [ "$dir" == "$PREFIX/lib" ] || [ "$dir" == "@rpath" ] || [ -f "$PREFIX/lib/$base" ] || [ -d "$PREFIX/Frameworks/$libname.framework" ]; then
            if [ "$PLATFORM" == "macos" ]; then
                newname="@rpath/$libname.framework/Versions/A/$libname"
            else
                newname="@rpath/$libname.framework/$libname"
            fi
            install_name_tool -change "$g" "$newname" "$_file"
        fi
    done
}

plist_set () {
    /usr/libexec/PlistBuddy -c "Set :$1 $3" "$4" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :$1 $2 $3" "$4"
}

fixup_dylib () {
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
    mkdir -p "$FRAMEWORKPATH"
    mkdir -p "$INFOPATH"
    cp -a "$FILE" "$NEWFILE"
    MINOSVER=$(vtool -show-build-version "$FILE" 2>/dev/null | awk '/minos/ {print $2; exit}')
    [ -n "$MINOSVER" ] || MINOSVER="$SDKMINVER"
    if [ -z "$MINOSVER" ]; then
        echo "$FILE does not record a minimum OS version, pass one with -m" >&2
        exit 1
    fi
    plist_set CFBundleExecutable string "$LIBNAME" "$INFOPATH/Info.plist"
    plist_set CFBundleIdentifier string "$BUNDLE_ID" "$INFOPATH/Info.plist"
    plist_set MinimumOSVersion string "$MINOSVER" "$INFOPATH/Info.plist"
    plist_set CFBundleVersion string 1 "$INFOPATH/Info.plist"
    plist_set CFBundleShortVersionString string 1.0 "$INFOPATH/Info.plist"
    if [ "$PLATFORM" == "macos" ]; then
        # -h replaces an existing symlink instead of creating a link inside its target
        ln -sfh "A" "$BASEFRAMEWORKPATH/Versions/Current"
        ln -sfh "Versions/Current/Resources" "$BASEFRAMEWORKPATH/Resources"
        ln -sfh "Versions/Current/$LIBNAME" "$BASEFRAMEWORKPATH/$LIBNAME"
    fi
    install_name_tool -id "@rpath/$FRAMEWORKNAME/$LIBNAME" "$NEWFILE"
    fixup_imports "$NEWFILE"
}

PLATFORM=
PREFIX=
SDKMINVER=
IMPORTS_ONLY=
while getopts "p:s:m:i" opt; do
    case $opt in
    p )
        PLATFORM=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')
        ;;
    s )
        PREFIX=$(cd "$OPTARG" && pwd)
        ;;
    m )
        SDKMINVER="$OPTARG"
        ;;
    i )
        IMPORTS_ONLY=y
        ;;
    * )
        usage
        ;;
    esac
done
shift $((OPTIND - 1))
if [ -z "$PLATFORM" ] || [ -z "$PREFIX" ] || [ $# -eq 0 ]; then
    usage
fi

OLDIFS=$IFS
IFS=$'\n'
for f in "$@"
do
    echo "${GREEN}Fixing up $f...${NC}"
    if [ -z "$IMPORTS_ONLY" ]; then
        fixup_dylib "$f"
    else
        fixup_imports "$f"
    fi
done
IFS=$OLDIFS
