#!/usr/bin/env python3
"""Scripting/UTMScripting.swift is generated from Scripting/UTM.sdef by scripts/bridge-gen.sh
and committed. This checks the two agree without running the generator (which needs
python 2): every class, property, element, command and enumeration in the sdef has its
Swift counterpart with the same description, type, parameters or code, and the Swift
file keeps nothing the sdef no longer defines. Usage: check_scripting_bridge.py [sdef] [swift]"""
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SDEF = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "Scripting", "UTM.sdef")
SWIFT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "Scripting", "UTMScripting.swift")
# the standard suite, which the generator takes from the host's CocoaStandard.sdef
STANDARD_TYPES = {"Application", "Document", "Window", "GenericMethods", "SaveOptions", "PrintingErrorHandling"}
STANDARD_APPLICATION_MEMBERS = {"documents", "windows", "name", "frontmost", "version", "open", "print", "quitSaving", "exists"}
SWIFT_TYPES = {"text": "String", "boolean": "Bool", "integer": "Int", "real": "Double", "file": "URL",
               "date": "Date", "record": "[AnyHashable : Any]", "any": "Any", "specifier": "SBObject"}


def pascal(name):
    return "".join(w[0].upper() + w[1:] for w in name.split())


def camel(name):
    words = name.split()
    return words[0] + "".join(w[0].upper() + w[1:] for w in words[1:])


def case_name(name):
    """The generator lowercases a leading run of capitals, keeping its last letter when a
    lowercase one follows: IDE -> ide, WebDAV -> webDAV, NVMe -> nvMe, PFlash -> pFlash."""
    words = name.split()
    first = words[0]
    match = re.match(r"^([A-Z]+)(.*)$", first)
    if match:
        run, rest = match.groups()
        if len(run) > 1 and rest[:1].islower():
            first = run[:-1].lower() + run[-1] + rest
        else:
            first = run.lower() + rest
    return first + "".join(w[0].upper() + w[1:] for w in words[1:])


def normalize(text):
    return " ".join((text or "").split())


def swift_type(node, enumerations, classes):
    """The Swift type the generator uses for a property or parameter, or None when unsure."""
    nested = node.find("type")
    name = nested.get("type") if nested is not None else node.get("type")
    if name is None:
        return None
    if name in SWIFT_TYPES:
        inner = SWIFT_TYPES[name]
    elif name in enumerations or name in classes:
        inner = "UTMScripting" + pascal(name)
    else:
        return None
    return f"[{inner}]" if nested is not None and nested.get("list") == "yes" else inner


def main():
    problems = []
    sdef = ET.parse(SDEF).getroot()
    swift = open(SWIFT, encoding="utf-8").read()
    protocols = {m.group(1): m.group(2) for m in re.finditer(r"@objc public protocol (UTMScripting\w+)[^{]*\{\n(.*?)\n\}", swift, re.S)}
    enums = {m.group(1): m.group(2) for m in re.finditer(r"@objc public enum (UTMScripting\w+) : AEKeyword \{\n(.*?)\n\}", swift, re.S)}
    classes = {c.get("name") for c in sdef.iter("class")}
    enumerations = {e.get("name") for e in sdef.iter("enumeration")}
    plurals = {c.get("name"): c.get("plural") or c.get("name") + "s" for c in sdef.iter("class")}

    def member_lines(body):
        """(name, line) for every var and func of a protocol body."""
        found = []
        for line in body.split("\n"):
            match = re.search(r"(?:var|func) `?(\w+)`?", line)
            if match:
                found.append((match.group(1), line))
        return found

    def comment(line):
        parts = line.split(" // ", 1)
        return normalize(parts[1]) if len(parts) == 2 else ""

    # what the sdef says each protocol must contain: {protocol: {member: (kind, node)}}
    expected = {("UTMScripting" + pascal(c)): {} for c in classes}
    expected["UTMScriptingApplication"] = {}
    for node in list(sdef.iter("class")) + list(sdef.iter("class-extension")):
        cls = node.get("name") or node.get("extends")
        protocol = "UTMScripting" + pascal(cls)
        members = expected.setdefault(protocol, {})
        for prop in node.findall("property"):
            ident = camel(prop.get("name"))
            members[ident] = ("property", prop)
            if prop.get("access", "rw") != "r":
                members["set" + ident[0].upper() + ident[1:]] = ("setter", prop)
        for element in node.findall("element"):
            members[camel(plurals.get(element.get("type"), element.get("type") + "s"))] = ("element", element)
    commands = []
    for command in sdef.iter("command"):
        if command.get("name") == "make":
            continue  # the standard make command is not part of the generated protocols
        parameters = command.findall("parameter")
        method = camel(command.get("name"))
        if parameters:
            first = camel(parameters[0].get("name"))
            method += first[0].upper() + first[1:]
        commands.append((method, command, parameters))
    command_methods = {method for method, _, _ in commands}

    # every protocol the sdef implies, with its properties, elements and setters
    for protocol, members in expected.items():
        body = protocols.get(protocol)
        if body is None:
            problems.append(f"protocol {protocol} is missing")
            continue
        lines = dict(member_lines(body))
        for ident, (kind, node) in members.items():
            line = lines.get(ident)
            if line is None:
                problems.append(f"{protocol}: {kind} '{node.get('name') or node.get('type')}' has no member {ident}")
                continue
            if kind == "property":
                if normalize(node.get("description")) != comment(line):
                    problems.append(f"{protocol}: description of '{node.get('name')}' differs from the sdef: {comment(line)!r}")
                expected_type = swift_type(node, enumerations, classes)
                if expected_type and f" {ident}: {expected_type} " not in line and f"-> {expected_type}" not in line:
                    problems.append(f"{protocol}: '{node.get('name')}' is not typed {expected_type}: {line.strip()}")
        # nothing the sdef does not define, apart from the standard suite
        standard = STANDARD_APPLICATION_MEMBERS if protocol == "UTMScriptingApplication" else set()
        for ident, line in lines.items():
            if ident in members or ident in standard or ident in command_methods:
                continue
            problems.append(f"{protocol}: member {ident} has no property, element or command in the sdef")
    # commands: the method the generator names after the first parameter, the other labels, the description
    all_lines = [line for body in protocols.values() for _, line in member_lines(body)]
    for method, command, parameters in commands:
        candidates = [line for line in all_lines if re.search(rf"func `?{re.escape(method)}`?\(", line)]
        if not candidates:
            problems.append(f"command '{command.get('name')}' has no func {method}")
            continue
        labels = [camel(p.get("name")) for p in parameters[1:]]
        # a label that is a Swift keyword is written as `label` or label_
        matching = [line for line in candidates if all(re.search(rf"[ (]`?{re.escape(label)}`?_?:", line) for label in labels)]
        if not matching:
            problems.append(f"command '{command.get('name')}': no func {method} with the parameters {labels}")
        elif normalize(command.get("description")) not in {comment(line) for line in matching}:
            problems.append(f"command '{command.get('name')}': description differs from the sdef: {comment(matching[0])!r}")
    # enumerations: every enumerator with its code, and no extra case
    for enumeration in sdef.iter("enumeration"):
        name = "UTMScripting" + pascal(enumeration.get("name"))
        body = enums.get(name)
        if body is None:
            problems.append(f"enumeration '{enumeration.get('name')}': enum {name} is missing")
            continue
        cases = dict(re.findall(r"case `?(\w+)`? = 0x[0-9a-f]+ /\* '(.{4})' \*/", body))
        for enumerator in enumeration.findall("enumerator"):
            case = case_name(enumerator.get("name"))
            if cases.get(case) != enumerator.get("code"):
                problems.append(f"{name}: enumerator '{enumerator.get('name')}' ({enumerator.get('code')}) is missing or has another code")
        for case in set(cases) - {case_name(e.get("name")) for e in enumeration.findall("enumerator")}:
            problems.append(f"{name}: case {case} has no enumerator in the sdef")
    # types the sdef does not define
    for name in list(protocols) + list(enums):
        if name not in expected and name[len("UTMScripting"):] not in STANDARD_TYPES and name.replace("UTMScripting", "", 1) not in {pascal(e) for e in enumerations}:
            problems.append(f"{name} has no class or enumeration in the sdef")
    for problem in problems:
        print(problem)
    print(f"check_scripting_bridge: {len(classes)} classes, {len(commands)} commands, {len(enumerations)} enumerations, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
