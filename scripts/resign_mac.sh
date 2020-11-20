#!/bin/sh

set -e
if [ $# -ne 3 ]; then
	echo "usage: $0 UTM.xcarchive outputPath TEAM_ID"
	exit 1
fi

INPUT=$1
OUTPUT=$2
TEAM_ID=$3
OPTIONS="/tmp/options.plist"
SIGNED="/tmp/signed"

cat >"$OPTIONS" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>compileBitcode</key>
	<false/>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>thinning</key>
	<string>&lt;none&gt;</string>
</dict>
</plist>
EOL

xcodebuild -exportArchive -exportOptionsPlist "$OPTIONS" -archivePath "$INPUT" -exportPath "$SIGNED"
rm "$OPTIONS"

hdiutil create -fs HFS+ -srcfolder "$SIGNED/UTM.app" -volname "UTM" "$OUTPUT/UTM.dmg"
