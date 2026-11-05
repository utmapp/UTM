#!/usr/bin/env python3
"""Check that tracked source files and file references in UTM.xcodeproj agree.

A source file that exists but is not referenced never gets compiled; a reference
whose file is missing breaks the build. Both happen after bad merges or when a
dependency update accidentally reverts project changes. Files are compared by
basename count, since the project refers to files by basename and nine sources
(for example UTMApp.swift) exist once per platform.
"""
import collections
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PBXPROJ = os.path.join(ROOT, "UTM.xcodeproj", "project.pbxproj")
SOURCE_DIRS = ["Configuration", "Services", "Scripting", "Remote", "Intents", "Platform",
               "QEMUHelper", "QEMULauncher", "iOSHelper", "JailbreakInterposer", "utmctl"]
EXTENSIONS = (".swift", ".m", ".c", ".h", ".sdef")
REF_RE = re.compile(r'isa = PBXFileReference;.*?path = "?([^";]+)"?;')


def main():
    with open(PBXPROJ, encoding="utf-8") as fh:
        text = fh.read()
    referenced = collections.Counter(os.path.basename(m.group(1)) for m in REF_RE.finditer(text))
    tracked = subprocess.run(["git", "-C", ROOT, "ls-files", "--", *SOURCE_DIRS],
                             capture_output=True, text=True, check=True).stdout.split("\n")
    sources = collections.defaultdict(list)
    for rel in tracked:
        if rel.endswith(EXTENSIONS) and not any(part.endswith((".lproj", ".bundle", ".xcassets")) for part in rel.split("/")):
            sources[os.path.basename(rel)].append(rel)
    problems = []
    for name, paths in sorted(sources.items()):
        missing = len(paths) - referenced[name]
        if missing > 0:
            problems.append(f"{missing} of {len(paths)} not referenced in project: {', '.join(paths)}")
    for name, count in sorted(referenced.items()):
        if name.endswith(EXTENSIONS) and count > len(sources.get(name, [])):
            problems.append(f"referenced {count}x but tracked {len(sources.get(name, []))}x: {name}")
    print("\n".join(problems))
    print(f"check_pbxproj_refs: {sum(len(p) for p in sources.values())} sources, {sum(referenced.values())} references, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
