#!/bin/sh

set -e

command -v realpath >/dev/null 2>&1 || realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
BASEDIR="$(dirname "$(realpath $0)")"

if [ $# -lt 3 ]; then
	echo "usage: $0 MODE UTM.xcarchive outputPath [TEAM_ID PROFILE_NAME HELPER_PROFILE_NAME]"
	echo "  MODE is one of:"
	echo "          unsigned (unsigned DMG)"
	echo "          developer-id (signed DMG)"
	echo "          app-store (Mac App Store package)"
	echo "  TEAM_ID is required if not unsigned"
	echo "  PROFILE_NAME is required if not unsigned, can be the name or UUID"
	echo "  HELPER_PROFILE_NAME is required if not unsigned, can be the name or UUID"
	exit 1
fi

MODE=$1
INPUT=$2
OUTPUT=$3
TEAM_ID=$4
PROFILE_NAME=$5
HELPER_PROFILE_NAME=$6
OPTIONS="/tmp/options.plist"
SIGNED="/tmp/signed"
UTM_ENTITLEMENTS="/tmp/utm.entitlements"
LAUNCHER_ENTITLEMENTS="/tmp/launcher.entitlements"
HELPER_ENTITLEMENTS="/tmp/helper.entitlements"
INPUT_COPY="/tmp/UTM.xcarchive"

cat >"$OPTIONS" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>compileBitcode</key>
	<false/>
	<key>installerSigningCertificate</key>
	<string>3rd Party Mac Developer Installer</string>
	<key>method</key>
	<string>${MODE}</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.utmapp.UTM</key>
		<string>${PROFILE_NAME}</string>
		<key>com.utmapp.QEMUHelper</key>
		<string>${HELPER_PROFILE_NAME}</string>
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

cp "$BASEDIR/../Platform/macOS/macOS.entitlements" "$UTM_ENTITLEMENTS"
cp "$BASEDIR/../QEMULauncher/QEMULauncher.entitlements" "$LAUNCHER_ENTITLEMENTS"
cp "$BASEDIR/../QEMUHelper/QEMUHelper.entitlements" "$HELPER_ENTITLEMENTS"

if [ "$MODE" == "unsigned" ]; then
	/usr/libexec/PlistBuddy -c "Delete :com.apple.vm.device-access" "$UTM_ENTITLEMENTS"
	/usr/libexec/PlistBuddy -c "Delete :com.apple.vm.networking" "$HELPER_ENTITLEMENTS"
	/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$UTM_ENTITLEMENTS"
	/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$LAUNCHER_ENTITLEMENTS"
	/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$HELPER_ENTITLEMENTS"
fi

# ad-hoc sign with the right entitlements
rm -rf "$INPUT_COPY"
cp -a "$INPUT" "$INPUT_COPY"
find "$INPUT_COPY/Products/Applications/UTM.app" -type d -path '*/Frameworks/*.framework' -exec codesign --force --sign - --timestamp=none \{\} \;
codesign --force --sign - --entitlements "$LAUNCHER_ENTITLEMENTS" --timestamp=none --options runtime "$INPUT_COPY/Products/Applications/UTM.app/Contents/XPCServices/QEMUHelper.xpc/Contents/MacOS/QEMULauncher"
codesign --force --sign - --entitlements "$HELPER_ENTITLEMENTS" --timestamp=none --options runtime "$INPUT_COPY/Products/Applications/UTM.app/Contents/XPCServices/QEMUHelper.xpc/Contents/MacOS/QEMUHelper"
codesign --force --sign - --entitlements "$UTM_ENTITLEMENTS" --timestamp=none --options runtime "$INPUT_COPY/Products/Applications/UTM.app/Contents/MacOS/UTM"

# re-sign with certificate and profile if requested
if [ "$MODE" == "unsigned" ]; then
	mv "$INPUT_COPY/Products/Applications" "$SIGNED"
else
	xcodebuild -exportArchive -exportOptionsPlist "$OPTIONS" -archivePath "$INPUT_COPY" -exportPath "$SIGNED"
fi

rm "$OPTIONS"
rm "$UTM_ENTITLEMENTS"
rm "$LAUNCHER_ENTITLEMENTS"
rm "$HELPER_ENTITLEMENTS"
rm -rf "$INPUT_COPY"

if [ "$MODE" == "app-store" ]; then
	cp "$SIGNED/UTM.pkg" "$OUTPUT/UTM.pkg"
else
	rm -f "$OUTPUT/UTM.dmg"
	hdiutil create -fs HFS+ -srcfolder "$SIGNED/UTM.app" -volname "UTM" "$OUTPUT/UTM.dmg"
fi
rm -rf "$SIGNED"
