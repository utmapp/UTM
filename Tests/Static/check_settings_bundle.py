#!/usr/bin/env python3
"""Check Platform/iOS/Settings.bundle/Root.plist for type mismatches.

A PSMultiValueSpecifier whose Values mix types (or whose DefaultValue has a
different type from its Values) silently breaks the setting: the app reads one
type and the Settings app writes another.
"""
import os
import plistlib
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PLIST = os.path.join(ROOT, "Platform", "iOS", "Settings.bundle", "Root.plist")


def kind(value):
    return "bool" if isinstance(value, bool) else type(value).__name__


def main():
    with open(PLIST, "rb") as fh:
        specs = plistlib.load(fh)["PreferenceSpecifiers"]
    problems = []
    for spec in specs:
        key = spec.get("Key")
        if not key:
            continue
        values = spec.get("Values")
        default = spec.get("DefaultValue")
        if values is not None:
            kinds = {kind(v) for v in values}
            if len(kinds) > 1:
                problems.append(f"{key}: Values mix types {sorted(kinds)}")
            if default is not None and kind(default) not in kinds:
                problems.append(f"{key}: DefaultValue is {kind(default)}, Values are {sorted(kinds)}")
            titles = spec.get("Titles")
            if titles is not None and len(titles) != len(values):
                problems.append(f"{key}: {len(titles)} Titles for {len(values)} Values")
        if spec.get("Type") == "PSToggleSwitchSpecifier" and default is not None and kind(default) not in ("bool", "int"):
            problems.append(f"{key}: toggle DefaultValue is {kind(default)}")
    print("\n".join(problems))
    print(f"check_settings_bundle: {len(specs)} specifiers, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
