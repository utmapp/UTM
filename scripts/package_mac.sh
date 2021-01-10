#!/bin/sh

set -e
if [ $# -lt 3 ]; then
	echo "usage: $0 [--no-sandbox] UTM.xcarchive outputPath TEAM_ID"
	exit 1
fi

NO_SANDBOX=0
if [ "$1" == "--no-sandbox" ]; then
	NO_SANDBOX=1
	shift
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

# FIXME: until macOS Hypervisor.framework works with sandboxed NSTask, we have to remove it
if [ $NO_SANDBOX -eq 1 ]; then
	INPUT_COPY="/tmp/UTM.xcarchive"
	QEMU_ENTITLEMENTS="/tmp/qemu.entitlements"
	EMPTY_ENTITLEMENTS="/tmp/empty.entitlements"

	cat >"$QEMU_ENTITLEMENTS" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
	<key>com.apple.security.hypervisor</key>
	<true/>
</dict>
</plist>
EOL

	cat >"$EMPTY_ENTITLEMENTS" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOL

	rm -rf "$INPUT_COPY"
	cp -r "$INPUT" "$INPUT_COPY"
	find "$INPUT_COPY/Products/Applications/UTM.app" -path '*/qemu-*' -exec codesign --force --sign - --entitlements "$QEMU_ENTITLEMENTS" --timestamp=none --options runtime \{\} \;
	codesign --force --sign - --entitlements "$EMPTY_ENTITLEMENTS" --timestamp=none --options runtime "$INPUT_COPY/Products/Applications/UTM.app/Contents/MacOS/UTM"
	codesign --force --sign - --entitlements "$EMPTY_ENTITLEMENTS" --timestamp=none --options runtime "$INPUT_COPY/Products/Applications/UTM.app/Contents/XPCServices/QEMUHelper.xpc/Contents/MacOS/QEMUHelper"
	rm "$QEMU_ENTITLEMENTS"
	rm "$EMPTY_ENTITLEMENTS"
	INPUT="$INPUT_COPY"
fi

xcodebuild -exportArchive -exportOptionsPlist "$OPTIONS" -archivePath "$INPUT" -exportPath "$SIGNED"
find "$SIGNED/UTM.app" -type f \( -path '*/Contents/MacOS/*' -or -path '*/Contents/Frameworks/*.dylib' \) -exec chmod +x \{\} \;

rm "$OPTIONS"
if [ ! -z "$INPUT_COPY" ]; then
	rm -rf "$INPUT_COPY"
fi

rm -f "$OUTPUT/UTM.dmg"
hdiutil create -fs HFS+ -srcfolder "$SIGNED/UTM.app" -volname "UTM" "$OUTPUT/UTM.dmg"
