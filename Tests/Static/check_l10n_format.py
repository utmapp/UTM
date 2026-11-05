#!/usr/bin/env python3
"""Check that every localized string keeps the format specifiers of its key.

Catches translations that drop or mistype a placeholder (for example "$@" instead
of "%@"), which crash or show garbage at runtime. Covers .strings files (the key is
the English source text) and .stringsdict plural rules.
"""
import collections
import os
import plistlib
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SKIP_DIRS = {"sysroot", "build", "External", "UTM.xcarchive", "triage", "DerivedData", ".git"}
# %[flags][width][.precision][length]type, with optional positional "n$".
# The space flag is left out so a literal "80% of" is not read as "% o".
SPEC_RE = re.compile(r"%(?:(\d+)\$)?[-+#0]*\d*(?:\.\d+)?(hh|h|ll|l|q|L|z|t|j)?([@diouxXfFeEgGaAcsSpn%])")
# A '$' or '%' that is not part of a valid specifier, e.g. "$@" or "% d"
TYPO_RE = re.compile(r"(?<!\d)\$[@dlsu]|%(?![-+#0-9.$hlqLztj]*[@diouxXfFeEgGaAcsSpn%])(?! )")


def specifiers(text):
    """Return the (position, length, type) specifiers of a format string, in order.

    position is None when the specifier is not positional; "%%" is skipped.
    """
    out = []
    for pos, length, kind in SPEC_RE.findall(text):
        if kind != "%":
            out.append((int(pos) if pos else None, length or "", kind))
    return out


def mismatch(key, value):
    """Explain why value's specifiers do not match key's, or return None.

    Non-positional specifiers must appear in the same order and with the same
    types; positional ones must each refer to an argument of the key with the
    same type, and a value cannot mix the two forms.
    """
    want = [(l, k) for _, l, k in specifiers(key)]
    got = specifiers(value)
    if not any(p is not None for p in (g[0] for g in got)):
        got_plain = [(l, k) for _, l, k in got]
        return None if got_plain == want else f"key has {want}, value has {got_plain}"
    if any(p is None for p, _, _ in got):
        return "value mixes positional and non-positional specifiers"
    for pos, length, kind in got:
        if pos < 1 or pos > len(want):
            return f"value refers to argument {pos} but key has {len(want)}"
        if want[pos - 1] != (length, kind):
            return f"argument {pos} is %{''.join(want[pos - 1])} in key but %{length}{kind} in value"
    return None


STRINGS_RE = re.compile(r"""
    \s*
    (?:"((?:[^"\\]|\\.)*)"|([A-Za-z0-9_.\-]+))   # quoted or bare key
    \s*=\s*
    "((?:[^"\\]|\\.)*)"                          # quoted value
    \s*;
""", re.S | re.X)
ESCAPE_RE = re.compile(r"\\(U[0-9A-Fa-f]{4}|[0-7]{3}|.)", re.S)


def unescape(text):
    def sub(m):
        esc = m.group(1)
        if esc[0] == "U":
            return chr(int(esc[1:], 16))
        if esc.isdigit():
            return chr(int(esc, 8))
        return {"n": "\n", "t": "\t", "r": "\r"}.get(esc, esc)
    return ESCAPE_RE.sub(sub, text)


def load_strings(path):
    """Parse an old-style .strings file without plutil, so it also runs on Linux."""
    with open(path, "rb") as fh:
        raw = fh.read()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        text = raw.decode("utf-16")
    else:
        text = raw.decode("utf-8-sig")
    # Strip comments outside of string literals.
    stripped = re.sub(r'"(?:[^"\\]|\\.)*"|/\*.*?\*/|//[^\n]*', lambda m: m.group(0) if m.group(0).startswith('"') else "", text, flags=re.S)
    table, pos = {}, 0
    for m in STRINGS_RE.finditer(stripped):
        gap = stripped[pos:m.start()].strip()
        if gap:
            raise ValueError(f"unparsed text near offset {pos}: {gap[:40]!r}")
        table[unescape(m.group(1) if m.group(1) is not None else m.group(2))] = unescape(m.group(3))
        pos = m.end()
    if stripped[pos:].strip():
        raise ValueError(f"unparsed trailing text: {stripped[pos:].strip()[:40]!r}")
    return table


def walk():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if not any(d.startswith(s) for s in SKIP_DIRS)]
        for name in filenames:
            if name.endswith((".strings", ".stringsdict")):
                yield os.path.join(dirpath, name)


def check_strings(path, problems):
    try:
        table = load_strings(path)
    except ValueError as err:
        problems.append(f"{path}: cannot parse: {err}")
        return
    for key, value in table.items():
        why = mismatch(key, value)
        if why:
            problems.append(f"{path}: {key!r}: {why}")
        typo = TYPO_RE.search(value)
        if typo and not TYPO_RE.search(key):
            problems.append(f"{path}: {key!r}: suspicious placeholder {typo.group(0)!r} in value")


def check_stringsdict(path, problems):
    with open(path, "rb") as fh:
        table = plistlib.load(fh)
    for key, entry in table.items():
        fmt = entry.get("NSStringLocalizedFormatKey", "")
        for var in re.findall(r"%#@(\w+)@", fmt):
            rule = entry.get(var)
            if not isinstance(rule, dict):
                problems.append(f"{path}: {key!r}: variable {var!r} has no rule")
                continue
            value_type = rule.get("NSStringFormatValueTypeKey", "")
            # A variant is a format string over the original arguments, so it may
            # use the counted value (with the declared type) and any specifier the key uses.
            allowed = collections.Counter((l, k) for _, l, k in specifiers(key))
            allowed.update((l, k) for _, l, k in specifiers("%" + value_type))
            for category in ("zero", "one", "two", "few", "many", "other"):
                if category not in rule:
                    continue
                got = collections.Counter((l, k) for _, l, k in specifiers(rule[category]))
                extra = got - allowed
                if extra:
                    problems.append(f"{path}: {key!r}[{var}.{category}]: unexpected specifiers {dict(extra)}")
            if "other" not in rule:
                problems.append(f"{path}: {key!r}[{var}]: missing 'other' variant")


def main():
    problems = []
    count = 0
    for path in sorted(walk()):
        count += 1
        if path.endswith(".stringsdict"):
            check_stringsdict(path, problems)
        else:
            check_strings(path, problems)
    rel = [p.replace(ROOT + os.sep, "") for p in problems]
    print("\n".join(rel))
    print(f"check_l10n_format: {count} files, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
