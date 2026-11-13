#!/usr/bin/env python3
"""ScriptingBridge hands utmctl a record-type result as a dictionary keyed by the sdef
property names in camel case ("exited", "exitCode"), not by the Cocoa keys the app
uses ("hasExited"), and a key that is not there reads as nil. This fails when utmctl
reads a record by a Cocoa key that differs from its property's name, or reads a
`result` record by a key that is no record property at all.
Usage: check_utmctl_record_keys.py [sdef] [utmctl source directory]"""
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_scripting_bridge import camel  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SDEF = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "Scripting", "UTM.sdef")
SOURCES = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "utmctl")


def main():
    sdef = ET.parse(SDEF).getroot()
    property_keys = set()
    # Cocoa key -> (record type, the key ScriptingBridge uses)
    cocoa_keys = {}
    for record in sdef.iter("record-type"):
        for prop in record.findall("property"):
            key = camel(prop.get("name"))
            property_keys.add(key)
            cocoa = prop.find("cocoa")
            if cocoa is not None and cocoa.get("key") and cocoa.get("key") != key:
                cocoa_keys[cocoa.get("key")] = (record.get("name"), key)
    problems = []
    files = sorted(glob.glob(os.path.join(SOURCES, "**", "*.swift"), recursive=True))
    for path in files:
        with open(path, encoding="utf-8") as file:
            for number, line in enumerate(file, 1):
                where = f"{os.path.relpath(path, ROOT)}:{number}"
                for used in re.findall(r'\[\s*"(\w+)"\s*\]', line):
                    if used in cocoa_keys:
                        record, key = cocoa_keys[used]
                        problems.append(f"{where}: '{record}' is read by its Cocoa key \"{used}\"; ScriptingBridge uses \"{key}\"")
                for used in re.findall(r'\bresult\[\s*"(\w+)"\s*\]', line):
                    if used not in property_keys and used not in cocoa_keys:
                        problems.append(f"{where}: \"{used}\" is not a property of any record type in the sdef")
    for problem in problems:
        print(problem)
    print(f"check_utmctl_record_keys: {len(files)} files, {len(property_keys)} record properties, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
