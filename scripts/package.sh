#!/bin/bash

set -e

command -v realpath >/dev/null 2>&1 || realpath() {
	[[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
BASEDIR="$(dirname "$(realpath $0)")"

usage() {
	echo "usage: $0 MODE inputXcarchive outputPath [TEAM_ID PROFILE_NAME]"
	echo "  MODE is one of:"
	echo "          deb (Cydia DEB)"
	echo "          ipa (unsigned IPA with Psychic paper support)"
	echo "          ipa-se (unsigned IPA with no entitlements)"
	echo "          signedipa (developer signed IPA with valid PROFILE_NAME and TEAM_ID)"
	echo "  inputXcarchive is path to UTM.xcarchive"
	echo "  outputPath is path to an EMPTY output directory for UTM.ipa or UTM.deb"
	echo "  TEAM_ID is only used for signedipa and is the name of the team matching the profile"
	echo "  PROFILE_NAME is only used for signedipa and is the name of the signing profile"
	exit 1
}

if [ $# -lt 2 ]; then
	usage
fi

MODE=$1
INPUT=$2
OUTPUT=$3

case $MODE in
deb | ipa | signedipa )
	NAME="UTM"
	INPUT_APP="$INPUT/Products/Applications/UTM.app"
	;;
ipa-se )
	NAME="UTM SE"
	INPUT_APP="$INPUT/Products/Applications/UTM SE.app"
	;;
* )
	usage
	;;
esac

if [ ! -d "$INPUT_APP" ]; then
	echo "Invalid xcarchive input!"
	usage
fi

if [ -z "$OUTPUT" ]; then
	echo "Invalid output path"
	usage
fi

itunes_sign() {
	local INPUT=$1
	local OUTPUT=$2
	local TEAM_ID=$3
	local PROFILE_NAME=$4
	local OPTIONS="/tmp/options.plist"

	if [ -z "$PROFILE_NAME" || -z "$TEAM_ID" ]; then
		echo "Invalid profile name or team id!"
		usage
	fi

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

	xcodebuild -exportArchive -exportOptionsPlist "$OPTIONS" -archivePath "$INPUT" -exportPath "$OUTPUT"
	rm "$OPTIONS"
}

fake_sign() {
	local _name=$1
	local _input=$2
	local _output=$3
	local _fakeent=$4

	mkdir -p "$_output"
	cp -a "$_input" "$_output/"
	find "$_output" -type f \( -path '*/Frameworks/*.framework/*' -and -not -name 'Info.plist' \) -exec ldid -S \{\} \;
	ldid -S${_fakeent} "$_output/Applications/$_name.app/$_name"
}

create_deb() {
	local INPUT=$1
	local INPUT_APP="$INPUT/Products/Applications/UTM.app"
	local OUTPUT=$2
	local FAKEENT=$3
	local DEB_TMP="$OUTPUT/deb"
	local IPA_PATH="$DEB_TMP/Library/Caches/com.utmapp.UTM"
	local SIZE_KIB=`du -sk "$INPUT_APP"| cut -f 1`
	local VERSION=`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INPUT_APP/Info.plist"`

	mkdir -p "$OUTPUT"
	rm -rf "$DEB_TMP"
	mkdir -p "$DEB_TMP/DEBIAN"
cat >"$DEB_TMP/DEBIAN/control" <<EOL
Package: com.utmapp.UTM
Version: ${VERSION}
Section: Productivity
Architecture: iphoneos-arm
Depends: firmware (>=11.0), firmware-sbin, net.angelxwind.appsyncunified
Installed-Size: ${SIZE_KIB}
Maintainer: osy <dev@getutm.app>
Description: Virtual machines for iOS
Homepage: https://getutm.app/
Name: UTM
Author: osy
Depiction: https://cydia.getutm.app/depiction/web/com.utmapp.UTM.html
Icon: https://cydia.getutm.app/assets/com.utmapp.UTM/icon.png
Moderndepiction: https://cydia.getutm.app/depiction/native/com.utmapp.UTM.json
Sileodepiction: https://cydia.getutm.app/depiction/native/com.utmapp.UTM.json
Tags: compatible_min::ios11.0
EOL
	xcrun -sdk iphoneos clang -arch arm64 -fobjc-arc "$BASEDIR/deb/postinst.m" "$BASEDIR/deb/CoreServices.tbd" -o "$DEB_TMP/DEBIAN/postinst"
	strip "$DEB_TMP/DEBIAN/postinst"
	ldid -S"$BASEDIR/deb/postinst.xml" "$DEB_TMP/DEBIAN/postinst"
	xcrun -sdk iphoneos clang -arch arm64 -fobjc-arc "$BASEDIR/deb/prerm.m" "$BASEDIR/deb/CoreServices.tbd" -o "$DEB_TMP/DEBIAN/prerm"
	strip "$DEB_TMP/DEBIAN/prerm"
	ldid -S"$BASEDIR/deb/prerm.xml" "$DEB_TMP/DEBIAN/prerm"
	mkdir -p "$IPA_PATH"
	create_fake_ipa "UTM" "$INPUT" "$IPA_PATH" "$FAKEENT"
	dpkg-deb -b -Zgzip -z9 "$DEB_TMP" "$OUTPUT/UTM.deb"
	rm -r "$DEB_TMP"
}

create_fake_ipa() {
	local NAME=$1
	local INPUT=$2
	local OUTPUT=$3
	local FAKEENT=$4

	pwd="$(pwd)"
	mkdir -p "$OUTPUT"
	rm -rf "$OUTPUT/Applications" "$OUTPUT/Payload" "$OUTPUT/UTM.ipa"
	fake_sign "$NAME" "$INPUT/Products/Applications" "$OUTPUT" "$FAKEENT"
	mv "$OUTPUT/Applications" "$OUTPUT/Payload"
	cd "$OUTPUT"
	zip -r "$NAME.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
	rm -r "Payload"
	cd "$pwd"
}

case $MODE in
deb )
	FAKEENT="/tmp/fakeent.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>dynamic-codesigning</key>
	<true/>
	<key>com.apple.private.iokit.IOServiceSetAuthorizationID</key>
	<true/>
	<key>com.apple.security.exception.iokit-user-client-class</key>
	<array>
		<string>AppleUSBHostDeviceUserClient</string>
		<string>AppleUSBHostInterfaceUserClient</string>
	</array>
	<key>com.apple.system.diagnostics.iokit-properties</key>
	<true/>
	<key>com.apple.vm.device-access</key>
	<true/>
</dict>
</plist>
EOL
	create_deb "$INPUT" "$OUTPUT" "$FAKEENT"
	rm "$FAKEENT"
	;;
ipa )
	FAKEENT="/tmp/fakeent.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>get-task-allow</key>
	<true/>
	<!-- https://siguza.github.io/psychicpaper/ -->
	<!---><!-->
	<key>dynamic-codesigning</key>
	<true/>
	<key>com.apple.private.iokit.IOServiceSetAuthorizationID</key>
	<true/>
	<key>com.apple.security.exception.iokit-user-client-class</key>
	<array>
		<string>AppleUSBHostDeviceUserClient</string>
		<string>AppleUSBHostInterfaceUserClient</string>
	</array>
	<key>com.apple.system.diagnostics.iokit-properties</key>
	<true/>
	<key>com.apple.vm.device-access</key>
	<true/>
	<!-- -->
</dict>
</plist>
EOL
	create_fake_ipa "$NAME" "$INPUT" "$OUTPUT" "$FAKEENT"
	rm "$FAKEENT"
	;;
ipa-se )
	create_fake_ipa "$NAME" "$INPUT" "$OUTPUT"
	;;
signedipa )
	itunes_sign "$INPUT" "$OUTPUT" $4 $5
	;;
esac
