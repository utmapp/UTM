#!/bin/sh
set -e

command -v realpath >/dev/null 2>&1 || realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
BASEDIR="$(dirname "$(realpath $0)")"

if [ ! -d "$BASEDIR/SwiftScripting" ]; then
    echo "Cloning SwiftScripting..." >&2
    git clone --depth 1 https://github.com/tingraldi/SwiftScripting.git "$BASEDIR/SwiftScripting"
fi

pwd="$(pwd)"
cd "$BASEDIR/SwiftScripting"
pyenv local 2.7 || echo "Warning: pyenv not installed or failed to set to 2.7, the script may not work" >&2
sdp -fh --basename "UTMScripting" "$BASEDIR/../Scripting/UTM.sdef"
./sbhc.py "UTMScripting.h"
mv UTMScripting.swift UTMScriptingProtocols.swift
./sbsc.py "$BASEDIR/../Scripting/UTM.sdef"

cat <<EOL
//
// Copyright © 2022 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// !! THIS FILE IS GENERATED FROM bridge-gen.sh, DO NOT MODIFY MANUALLY !!

EOL

cat "UTMScripting.swift"
echo ""
cat "UTMScriptingProtocols.swift"

rm "UTMScripting.swift"
rm "UTMScriptingProtocols.swift"
rm "UTMScripting.h"

cd "$pwd"
