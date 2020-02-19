#!/bin/sh

if [ $# -ne 4 ]; then
    echo "usage: $0 UTM.xcarchive PROFILE_NAME TEAM_ID outputPath"
    exit 1
fi

INPUT=$1
PROFILE_NAME=$2
TEAM_ID=$3
OUTPUT=$4
OPTIONS="/tmp/options.plist"

cat >"$OPTIONS" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>compileBitcode</key>
  <false/>
  <key>method</key>
  <string>development</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.osy86.UTM</key>
    <string>${PROFILE_NAME}</string>
  </dict>
  <key>signingStyle</key>
  <string>manual</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>thinning</key>
  <string>&lt;none&gt;</string>
</dict>
</plist>
EOL

xcodebuild -exportArchive -exportOptionsPlist "$OPTIONS" -archivePath "$INPUT" -exportPath "$OUTPUT"
rm "$OPTIONS"
