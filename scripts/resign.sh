#!/bin/sh

set -e
if [ $# -ne 2 ] && [ $# -ne 4 ]; then
	echo "usage: $0 UTM.xcarchive outputPath [PROFILE_NAME TEAM_ID]"
	exit 1
fi

INPUT=$1
OUTPUT=$2
PROFILE_NAME=$3
TEAM_ID=$4
OPTIONS="/tmp/options.plist"
FAKEENT="/tmp/fakeent.plist"

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

cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>get-task-allow</key>
	<true/>
	<key>dynamic-codesigning</key>
	<true/>
</dict>
</plist>
EOL

if [ $# -eq 2 ]; then
	mkdir -p "$OUTPUT"
	rm -rf "$OUTPUT/Payload" "$OUTPUT/UTM.ipa"
	cp -r "$INPUT/Products/Applications" "$OUTPUT/Payload"
	find "$OUTPUT/Payload" -type f -path '*/Frameworks/*.dylib' -exec ldid -S \{\} \;
	ldid -S${FAKEENT} "$OUTPUT/Payload/UTM.app/UTM"
	cd "$OUTPUT"
	zip -r "UTM.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
	rm -r "$OUTPUT/Payload"
else
	xcodebuild -exportArchive -exportOptionsPlist "$OPTIONS" -archivePath "$INPUT" -exportPath "$OUTPUT"
fi

rm "$OPTIONS"
rm "$FAKEENT"
