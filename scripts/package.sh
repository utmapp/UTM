#!/bin/sh

set -e

usage() {
	echo "usage: $0 MODE inputXcarchive outputPath [PROFILE_NAME TEAM_ID]"
	echo "  MODE is one of:"
	echo "          deb (Cydia DEB)"
	echo "          ipa (unsigned IPA with Psychic paper support)"
	echo "          signedipa (developer signed IPA with valid PROFILE_NAME and TEAM_ID)"
	echo "  inputXcarchive is path to UTM.xcarchive"
	echo "  outputPath is path to an EMPTY output directory for UTM.ipa or UTM.deb"
	echo "  PROFILE_NAME is only used for signedipa and is the name of the signing profile"
	echo "  TEAM_ID is only used for signedipa and is the name of the team matching the profile"
	exit 1
}

if [ $# -lt 2 ]; then
	usage
fi

case $1 in
deb )
	MODE=deb
    shift
    ;;
ipa )
	MODE=ipa
	shift
    ;;
signedipa )
	MODE=signedipa
	shift
	;;
* )
    usage
    ;;
esac

INPUT=$1
INPUT_APP="$INPUT/Products/Applications/UTM.app"
OUTPUT=$2

if [ ! -d "$INPUT_APP" ]; then
	echo "Invalid xcarchive input!"
	usage
fi

if [ -z "$OUTPUT" ]; then
	echo "Invalid output path"
	usage
fi

itunes_sign() {
	INPUT=$1
	OUTPUT=$2
	PROFILE_NAME=$3
	TEAM_ID=$4
	OPTIONS="/tmp/options.plist"

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
	_input=$1
	_output=$2
	_fakeent=$3

	mkdir -p "$_output"
	cp -r "$_input" "$_output/"
	find "$_output" -type f \( -path '*/UTM.app/UTM' -or -path '*/UTM.app/Frameworks/*.dylib' \) -exec chmod +x \{\} \;
	find "$_output" -type f -path '*/Frameworks/*.dylib' -exec ldid -S \{\} \;
	ldid -S${_fakeent} "$_output/Applications/UTM.app/UTM"
}

create_deb() {
	INPUT=$1
	INPUT_APP="$INPUT/Products/Applications/UTM.app"
	OUTPUT=$2
	FAKEENT=$3
	DEB_TMP="$OUTPUT/deb"
	SIZE_KIB=`du -sk "$INPUT_APP"| cut -f 1`
	VERSION=`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INPUT_APP/Info.plist"`

	mkdir -p "$OUTPUT"
	rm -rf "$DEB_TMP"
	mkdir -p "$DEB_TMP/DEBIAN"
cat >"$DEB_TMP/DEBIAN/control" <<EOL
Package: com.utmapp.UTM
Version: ${VERSION}
Section: Productivity
Architecture: iphoneos-arm
Depends: firmware (>=11.0), firmware-sbin
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
	fake_sign "$INPUT/Products/Applications" "$DEB_TMP" "$FAKEENT"
	dpkg-deb -b -Zgzip -z9 "$DEB_TMP" "$OUTPUT/UTM.deb"
	rm -r "$DEB_TMP"
}

create_fake_ipa() {
	INPUT=$1
	OUTPUT=$2
	FAKEENT=$3

	mkdir -p "$OUTPUT"
	rm -rf "$OUTPUT/Applications" "$OUTPUT/Payload" "$OUTPUT/UTM.ipa"
	fake_sign "$INPUT/Products/Applications" "$OUTPUT" "$FAKEENT"
	mv "$OUTPUT/Applications" "$OUTPUT/Payload"
	cd "$OUTPUT"
	zip -r "UTM.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
	rm -r "Payload"
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
	<!-- -->
</dict>
</plist>
EOL
	create_fake_ipa "$INPUT" "$OUTPUT" "$FAKEENT"
    rm "$FAKEENT"
    ;;
signedipa )
	itunes_sign "$INPUT" "$OUTPUT" $3 $4
	;;
esac
