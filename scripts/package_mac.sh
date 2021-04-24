#!/bin/sh

set -e

command -v realpath >/dev/null 2>&1 || realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
BASEDIR="$(dirname "$(realpath $0)")"

if [ $# -lt 2 ]; then
	echo "usage: $0 UTM.xcarchive outputPath [TEAM_ID PROFILE_NAME]"
	echo "  uses ad-hoc signing if TEAM_ID and PROFILE_NAME is missing"
	echo "  uses distribution signing if both TEAM_ID and PROFILE_NAME are specified"
	exit 1
fi

INPUT=$1
OUTPUT=$2
TEAM_ID=$3
PROFILE_NAME=$4
DISTRIBUTION=0
OPTIONS="/tmp/options.plist"
SIGNED="/tmp/signed"
UTM_ENTITLEMENTS="/tmp/utm.entitlements"
LAUNCHER_ENTITLEMENTS="/tmp/launcher.entitlements"
HELPER_ENTITLEMENTS="/tmp/helper.entitlements"
INPUT_COPY="/tmp/UTM.xcarchive"

if [ ! -z "$TEAM_ID" -a -z "$PROFILE_NAME" ]; then
	echo "You must specify a provisioning profile name for distribution signing!"
	exit 1
elif [ ! -z "$TEAM_ID" -a ! -z "$PROFILE_NAME" ]; then
	DISTRIBUTION=1
fi

cat >"$OPTIONS" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>compileBitcode</key>
	<false/>
	<key>method</key>
	<string>developer-id</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.utmapp.UTM</key>
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

cp "$BASEDIR/../Platform/macOS/macOS.entitlements" "$UTM_ENTITLEMENTS"
cp "$BASEDIR/../QEMULauncher/QEMULauncher.entitlements" "$LAUNCHER_ENTITLEMENTS"
cp "$BASEDIR/../QEMUHelper/QEMUHelper.entitlements" "$HELPER_ENTITLEMENTS"

if [ $DISTRIBUTION -eq 0 ]; then
	/usr/libexec/PlistBuddy -c "Delete :com.apple.vm.device-access" "$UTM_ENTITLEMENTS"
	/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$UTM_ENTITLEMENTS"
	/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$LAUNCHER_ENTITLEMENTS"
	/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$HELPER_ENTITLEMENTS"
fi

# ad-hoc sign with the right entitlements
rm -rf "$INPUT_COPY"
cp -r "$INPUT" "$INPUT_COPY"
find "$INPUT_COPY/Products/Applications/UTM.app" -type f \( -path '*/Contents/MacOS/*' -or -path '*/Contents/Frameworks/*.dylib' \) -exec chmod +x \{\} \;
find "$INPUT_COPY/Products/Applications/UTM.app" -path '*/Contents/Frameworks/*.dylib' -exec codesign --force --sign - --timestamp=none \{\} \;
codesign --force --sign - --entitlements "$LAUNCHER_ENTITLEMENTS" --timestamp=none --options runtime "$INPUT_COPY/Products/Applications/UTM.app/Contents/XPCServices/QEMUHelper.xpc/Contents/MacOS/QEMULauncher"
codesign --force --sign - --entitlements "$HELPER_ENTITLEMENTS" --timestamp=none --options runtime "$INPUT_COPY/Products/Applications/UTM.app/Contents/XPCServices/QEMUHelper.xpc/Contents/MacOS/QEMUHelper"
codesign --force --sign - --entitlements "$UTM_ENTITLEMENTS" --timestamp=none --options runtime "$INPUT_COPY/Products/Applications/UTM.app/Contents/MacOS/UTM"

# re-sign with certificate and profile if requested
if [ $DISTRIBUTION -eq 0 ]; then
	mv "$INPUT_COPY/Products/Applications" "$SIGNED"
else
	xcodebuild -exportArchive -exportOptionsPlist "$OPTIONS" -archivePath "$INPUT_COPY" -exportPath "$SIGNED"
fi

rm "$OPTIONS"
rm "$UTM_ENTITLEMENTS"
rm "$LAUNCHER_ENTITLEMENTS"
rm "$HELPER_ENTITLEMENTS"
rm -rf "$INPUT_COPY"

rm -f "$OUTPUT/UTM.dmg"
hdiutil create -fs HFS+ -srcfolder "$SIGNED/UTM.app" -volname "UTM" "$OUTPUT/UTM.dmg"
rm -rf "$SIGNED"
