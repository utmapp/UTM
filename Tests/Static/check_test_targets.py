#!/usr/bin/env python3
"""Every test source under Tests/Shared and every fixture under Tests/Fixtures must be a
member of both app-hosted unit-test bundles, UTMTests and UTMTests-iOS, so a test cannot
run on one platform only. Usage: check_test_targets.py [project.pbxproj]"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PBXPROJ = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "UTM.xcodeproj", "project.pbxproj")
TARGETS = ("UTMTests", "UTMTests-iOS")


def phase_files(project, target, phase):
    """Basenames listed in the named build phase of the target."""
    match = re.search(r'/\* %s \*/ = \{\n\t\t\tisa = PBXNativeTarget;(?:.*\n)*?\t\t\tbuildPhases = \(\n((?:\t\t\t\t.*\n)*?)\t\t\t\);' % re.escape(target), project)
    if not match:
        return None
    phase_id = re.search(r'([0-9A-F]{24}) /\* %s \*/' % phase, match.group(1))
    if not phase_id:
        return set()
    block = re.search(r'\t\t%s /\* %s \*/ = \{\n(?:.*\n)*?\t\t\tfiles = \(\n((?:\t\t\t\t.*\n)*?)\t\t\t\);' % (phase_id.group(1), phase), project)
    return set(re.findall(r'/\* (.*?) in %s \*/' % phase, block.group(1))) if block else set()


def main():
    project = open(PBXPROJ, encoding="utf-8").read()
    tracked = subprocess.check_output(["git", "-C", ROOT, "ls-files", "--", "Tests/Shared", "Tests/Fixtures"], text=True).splitlines()
    sources = [os.path.basename(f) for f in tracked if f.startswith("Tests/Shared/") and f.endswith(".swift")]
    fixtures = [os.path.basename(f) for f in tracked if f.startswith("Tests/Fixtures/")]
    problems = 0
    for target in TARGETS:
        for phase, expected in (("Sources", sources), ("Resources", fixtures)):
            members = phase_files(project, target, phase)
            if members is None:
                print(f"target {target} not found")
                problems += 1
                continue
            for name in expected:
                if name not in members:
                    print(f"{name} is not in the {phase} of {target}")
                    problems += 1
    print(f"check_test_targets: {len(sources)} sources, {len(fixtures)} fixtures, {len(TARGETS)} targets, {problems} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
