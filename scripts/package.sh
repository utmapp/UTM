#!/bin/bash

set -e

command -v realpath >/dev/null 2>&1 || realpath() {
	[[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
BASEDIR="$(dirname "$(realpath $0)")"

usage() {
	echo "usage: $0 MODE inputXcarchive outputPath [TEAM_ID PROFILE_NAME SIGNING_METHOD]"
	echo "  MODE is one of:"
	echo "          deb (Cydia DEB)"
	echo "          ipa (unsigned IPA of full build with all entitlements)"
	echo "          ipa-se (unsigned IPA of SE build)"
	echo "          ipa-remote (unsigned IPA of Remote build)"
	echo "          ipa-hv (unsigned IPA of full build without JIT entitlement)"
	echo "          ipa-[se-|remote-]signed (signed IPA with valid PROFILE_NAME and TEAM_ID)"
	echo "  inputXcarchive is path to UTM.xcarchive"
	echo "  outputPath is path to an EMPTY output directory for UTM.ipa or UTM.deb"
	echo "  TEAM_ID is only used for ipa-signed and is the name of the team matching the profile"
	echo "  PROFILE_NAME is only used for ipa-signed and is the name of the signing profile"
	echo "  SIGNING_METHOD is only used for ipa-signed and is either 'development' (default) or 'app-store'"
	exit 1
}

if [ $# -lt 2 ]; then
	usage
fi

MODE=$1
INPUT=$2
OUTPUT=$3
BUNDLE_ID=

case $MODE in
deb | ipa | ipa-hv | ipa-signed )
	NAME="UTM"
	BUNDLE_ID="com.utmapp.UTM"
	INPUT_APP="$INPUT/Products/Applications/UTM.app"
	;;
ipa-se | ipa-se-signed )
	NAME="UTM SE"
	BUNDLE_ID="com.utmapp.UTM-SE"
	INPUT_APP="$INPUT/Products/Applications/UTM SE.app"
	;;
ipa-remote | ipa-remote-signed )
	NAME="UTM Remote"
	BUNDLE_ID="com.utmapp.UTM-Remote"
	INPUT_APP="$INPUT/Products/Applications/UTM Remote.app"
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
	local SIGNING_METHOD=$5
	local OPTIONS="/tmp/options.$$.plist"

	if [ -z "$PROFILE_NAME" -o -z "$TEAM_ID" ]; then
		echo "Invalid profile name or team id!"
		usage
	fi
	if [ -z "$SIGNING_METHOD" ]; then
		SIGNING_METHOD="development"
	fi

	cat >"$OPTIONS" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>compileBitcode</key>
	<false/>
	<key>method</key>
	<string>${SIGNING_METHOD}</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BUNDLE_ID}</key>
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
	local _bundle_id=$2
	local _input=$3
	local _output=$4
	local _fakeent=$5

	mkdir -p "$_output"
	cp -a "$_input" "$_output/"
	find "$_output" -type d -path '*/Frameworks/*.framework' -exec ldid -S \{\} \;
	if [ ! -z "${_fakeent}" ]; then
		ldid -S${_fakeent} -I${_bundle_id} "$_output/Applications/$_name.app/$_name"
	fi
}

create_deb() {
	local INPUT=$1
	local INPUT_APP="$INPUT/Products/Applications/UTM.app"
	local OUTPUT=$2
	local FAKEENT=$3
	local DEB_TMP="$OUTPUT/deb"
	local IPA_PATH="$DEB_TMP/var/tmp/com.utmapp.UTM"
	local SIZE_KIB=`du -sk "$INPUT_APP"| cut -f 1`
	local VERSION=`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INPUT_APP/Info.plist"`

	mkdir -p "$OUTPUT"
	rm -rf "$DEB_TMP"
	mkdir -p "$DEB_TMP/DEBIAN"
cat >"$DEB_TMP/DEBIAN/control" <<EOL
Package: com.utmapp.UTM
Version: ${VERSION}
Section: Productivity
Architecture: all
Depends: firmware (>=14.0), net.angelxwind.appsyncunified
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
Tags: compatible_min::ios14.0
EOL
	xcrun -sdk iphoneos clang -arch arm64 -fobjc-arc -miphoneos-version-min=11.0 "$BASEDIR/deb/postinst.m" "$BASEDIR/deb/MobileCoreServices.tbd" -o "$DEB_TMP/DEBIAN/postinst"
	strip "$DEB_TMP/DEBIAN/postinst"
	ldid -S"$BASEDIR/deb/postinst.xml" "$DEB_TMP/DEBIAN/postinst"
	xcrun -sdk iphoneos clang -arch arm64 -fobjc-arc -miphoneos-version-min=11.0 "$BASEDIR/deb/prerm.m" "$BASEDIR/deb/MobileCoreServices.tbd" -o "$DEB_TMP/DEBIAN/prerm"
	strip "$DEB_TMP/DEBIAN/prerm"
	ldid -S"$BASEDIR/deb/prerm.xml" "$DEB_TMP/DEBIAN/prerm"
	mkdir -p "$IPA_PATH"
	create_fake_ipa "UTM" "com.utmapp.UTM" "$INPUT" "$IPA_PATH" "$FAKEENT"
	dpkg-deb -b -Zgzip -z9 "$DEB_TMP" "$OUTPUT/UTM.deb"
	rm -r "$DEB_TMP"
}

create_fake_ipa() {
	local NAME=$1
	local BUNDLE_ID=$2
	local INPUT=$3
	local OUTPUT=$4
	local FAKEENT=$5

	pwd="$(pwd)"
	mkdir -p "$OUTPUT"
	rm -rf "$OUTPUT/Applications" "$OUTPUT/Payload" "$OUTPUT/UTM.ipa"
	fake_sign "$NAME" "$BUNDLE_ID" "$INPUT/Products/Applications" "$OUTPUT" "$FAKEENT"
	mv "$OUTPUT/Applications" "$OUTPUT/Payload"
	cd "$OUTPUT"
	zip -r "$NAME.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
	rm -r "Payload"
	cd "$pwd"
}

case $MODE in
deb )
	FAKEENT="/tmp/fakeent.$$.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
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
	<key>com.apple.private.hypervisor</key>
	<true/>
	<key>com.apple.private.memorystatus</key>
	<true/>
</dict>
</plist>
EOL
	create_deb "$INPUT" "$OUTPUT" "$FAKEENT"
	rm "$FAKEENT"
	;;
ipa )
	FAKEENT="/tmp/fakeent.$$.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>get-task-allow</key>
	<true/>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
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
	<key>com.apple.private.hypervisor</key>
	<true/>
	<key>com.apple.private.memorystatus</key>
	<true/>
</dict>
</plist>
EOL
	create_fake_ipa "$NAME" "$BUNDLE_ID" "$INPUT" "$OUTPUT" "$FAKEENT"
	rm "$FAKEENT"
	;;
ipa-hv )
	FAKEENT="/tmp/fakeent.$$.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>get-task-allow</key>
	<true/>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
	<key>com.apple.private.iokit.IOServiceSetAuthorizationID</key>
	<true/>
	<key>com.apple.security.exception.iokit-user-client-class</key>
	<array>
		<string>AGXCommandQueue</string>
		<string>AGXDevice</string>
		<string>AGXDeviceUserClient</string>
		<string>AGXSharedUserClient</string>
		<string>AppleUSBHostDeviceUserClient</string>
		<string>AppleUSBHostInterfaceUserClient</string>
		<string>IOSurfaceRootUserClient</string>
		<string>IOAccelContext</string>
		<string>IOAccelContext2</string>
		<string>IOAccelDevice</string>
		<string>IOAccelDevice2</string>
		<string>IOAccelSharedUserClient</string>
		<string>IOAccelSharedUserClient2</string>
		<string>IOAccelSubmitter2</string>
	</array>
	<key>com.apple.system.diagnostics.iokit-properties</key>
	<true/>
	<key>com.apple.vm.device-access</key>
	<true/>
	<key>com.apple.private.hypervisor</key>
	<true/>
	<key>com.apple.private.memorystatus</key>
	<true/>
	<key>com.apple.private.security.no-sandbox</key>
	<true/>
	<key>com.apple.private.security.storage.AppDataContainers</key>
	<true/>
	<key>com.apple.private.security.storage.MobileDocuments</key>
	<true/>
	<key>platform-application</key>
	<true/>
</dict>
</plist>
EOL
	create_fake_ipa "$NAME" "$BUNDLE_ID" "$INPUT" "$OUTPUT" "$FAKEENT"
	rm "$FAKEENT"
	;;
ipa-se )
	FAKEENT="/tmp/fakeent.$$.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
</dict>
</plist>
EOL
	create_fake_ipa "$NAME" "$BUNDLE_ID" "$INPUT" "$OUTPUT" "$FAKEENT"
	;;
ipa-remote )
	create_fake_ipa "$NAME" "$BUNDLE_ID" "$INPUT" "$OUTPUT"
	;;
ipa-signed | ipa-se-signed )
	FAKEENT="/tmp/fakeent.$$.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
</dict>
</plist>
EOL
	TMPINPUT="/tmp/UTM.$$.xcarchive"
	cp -a "$INPUT" "$TMPINPUT"
	BUILT_PATH=$(find "$TMPINPUT" -name '*.app' -type d | head -1)
	PLATFORM="$(/usr/libexec/PlistBuddy -c "Print :DTPlatformName" "$BUILT_PATH/Info.plist")"
	if [ "$PLATFORM" != "xros" ]; then
		codesign --force --sign - --entitlements "$FAKEENT" --timestamp=none "$BUILT_PATH"
	fi
	itunes_sign "$TMPINPUT" "$OUTPUT" $4 $5 $6
	rm -rf "$TMPINPUT"
	;;
ipa-remote-signed )
	itunes_sign "$INPUT" "$OUTPUT" $4 $5 $6
	;;
esac
