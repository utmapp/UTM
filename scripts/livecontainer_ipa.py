#!/usr/bin/env python3
"""Prepare a UTM IPA for LiveContainer's randomized bundle identifier.

LiveContainer changes the host bundle identifier at install time but may not
rewrite the embedded ExtensionKit helper's identifier. iOS then rejects the
app because the extension ID is not prefixed by the rewritten host ID.

This compatibility variant omits the helper. Disk operations requiring
iOSHelper (snapshots, resize, conversion) may not work.
"""
import argparse
import pathlib
import plistlib
import sys
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=pathlib.Path, help="Original UTM IPA")
    parser.add_argument("output", type=pathlib.Path, help="Patched IPA path")
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error("Input and output must differ")
    with zipfile.ZipFile(args.input) as source:
        names = source.namelist()
        app_plists = [n for n in names if n.startswith("Payload/") and n.count("/") == 2 and n.endswith(".app/Info.plist")]
        if len(app_plists) != 1:
            parser.error("Expected exactly one Payload/*.app/Info.plist")
        app_dir = app_plists[0].removesuffix("Info.plist")
        bundle = plistlib.loads(source.read(app_plists[0]))
        if bundle.get("CFBundleIdentifier") not in ("com.utmapp.UTM", "com.utmapp.UTM-SE"):
            parser.error("Not a recognized UTM IPA")
        prefix = app_dir + "Extensions/"
        alt_prefix = app_dir + "PlugIns/"
        helper_dirs = [
            p for p in (prefix + "iOSHelper.appex/", prefix + "iOSHelper-SE.appex/",
                        alt_prefix + "iOSHelper.appex/", alt_prefix + "iOSHelper-SE.appex/")
            if any(n.startswith(p) for n in names)
        ]
        if not helper_dirs:
            parser.error("No iOSHelper extension found; IPA may already be patched")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.output, "w") as target:
            for entry in source.infolist():
                if any(entry.filename.startswith(p) for p in helper_dirs):
                    continue
                target.writestr(entry, source.read(entry.filename))
    print(f"Created {args.output}")
    print("WARNING: Re-sign/reinstall as required by LiveContainer.")
    print("WARNING: iOSHelper disk management functions may be unavailable.")


if __name__ == "__main__":
    main()
