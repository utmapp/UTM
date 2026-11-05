#!/usr/bin/env python3
"""Check Scripting/UTM.sdef for four-character code collisions.

Cocoa Scripting resolves terms by code. A property that reuses a class's code
(as "UTM version" once did with "virtual machine") breaks every script that touches
either. Codes must be unique within their namespace:

  * types and properties: class, record-type, enumeration, value-type and property
    codes share one namespace;
  * parameters within one command;
  * enumerators within one enumeration;
  * command codes (eight characters) across the dictionary.

Reuse of a code across different commands or enumerations is reported as a
warning only, since the resolver is scoped there.
"""
import collections
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SDEF = os.path.join(ROOT, "Scripting", "UTM.sdef")
TYPE_TAGS = {"class", "record-type", "enumeration", "value-type"}


def main():
    tree = ET.parse(SDEF)
    problems, warnings = [], []
    global_ns = collections.defaultdict(set)
    commands = collections.defaultdict(set)
    enumerators = collections.defaultdict(set)
    cross = collections.defaultdict(set)

    for el in tree.iter():
        code = el.get("code")
        if not code:
            continue
        name = el.get("name") or el.get("type") or "?"
        tag = el.tag
        expected = 8 if tag == "command" else 4
        if len(code) != expected:
            problems.append(f"{tag} {name!r}: code {code!r} is not {expected} characters")
        if tag in TYPE_TAGS or tag == "property" or tag == "command":
            global_ns[code].add((tag, name))
        elif tag in ("parameter", "enumerator"):
            cross[code].add((tag, name))

    for cmd in tree.iter("command"):
        for p in cmd.iter("parameter"):
            commands[(cmd.get("name"), p.get("code"))].add(p.get("name"))
    for enum in tree.iter("enumeration"):
        for e in enum.iter("enumerator"):
            enumerators[(enum.get("name"), e.get("code"))].add(e.get("name"))

    for code, users in sorted(global_ns.items()):
        names = {n for _, n in users}
        if len(names) > 1:
            problems.append(f"code {code!r} is shared by {sorted(users)}")
    for (cmd, code), names in sorted(commands.items()):
        if len(names) > 1:
            problems.append(f"command {cmd!r}: parameter code {code!r} is shared by {sorted(names)}")
    for (enum, code), names in sorted(enumerators.items()):
        if len(names) > 1:
            problems.append(f"enumeration {enum!r}: enumerator code {code!r} is shared by {sorted(names)}")
    for code, users in sorted(cross.items()):
        names = {n for _, n in users}
        if len(names) > 1:
            warnings.append(f"code {code!r} is reused across scopes by {sorted(users)}")

    if "--no-sdp" not in sys.argv:
        with tempfile.TemporaryDirectory() as tmp:
            try:
                run = subprocess.run(["sdp", "-fh", "--basename", "UTMScripting", "-o", tmp, SDEF],
                                     capture_output=True, text=True)
            except FileNotFoundError:
                problems.append("sdp not found; install the Xcode command line tools or pass --no-sdp")
            else:
                if run.returncode != 0:
                    problems.append(f"sdp failed: {run.stderr.strip()}")
                elif run.stderr.strip():
                    warnings.append(f"sdp: {run.stderr.strip()}")

    for w in warnings:
        print(f"warning: {w}")
    print("\n".join(problems))
    print(f"check_sdef_codes: {sum(len(v) for v in global_ns.values())} definitions, {len(problems)} problems, {len(warnings)} warnings")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
