#!/bin/bash
set -euo pipefail

SCHEME=${SCHEME:-macOS}
SDK=${SDK:-macosx}
ARCHS=${ARCHS:-arm64}
ARCHIVE_PATH=${ARCHIVE_PATH:-UTM}
CONFIGURATION=${CONFIGURATION:-Release}
TEAM_IDENTIFIER=${TEAM_IDENTIFIER:-}
XCODE_PATH=${XCODE_PATH:-}

cd /workspace

if [[ -n "$XCODE_PATH" && -d "$XCODE_PATH" ]]; then
    DEVELOPER_DIR="$XCODE_PATH/Contents/Developer"
    if [[ -d "$DEVELOPER_DIR" ]]; then
        echo "Selecting developer directory at $DEVELOPER_DIR"
        if command -v sudo >/dev/null 2>&1; then
            sudo xcode-select -s "$DEVELOPER_DIR"
        else
            xcode-select -s "$DEVELOPER_DIR"
        fi
        export DEVELOPER_DIR
    fi
fi

ARGS=()
if [[ -n "$TEAM_IDENTIFIER" ]]; then
    ARGS+=("-t" "$TEAM_IDENTIFIER")
fi
ARGS+=("-k" "$SDK")
ARGS+=("-s" "$SCHEME")
ARGS+=("-a" "$ARCHS")
ARGS+=("-o" "$ARCHIVE_PATH")

echo "Running build: scheme=${SCHEME}, sdk=${SDK}, archs=${ARCHS}, archive=${ARCHIVE_PATH}"
./scripts/build_utm.sh "${ARGS[@]}"
