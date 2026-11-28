#!/usr/bin/env python3
"""Rewrite clang-only Objective-C syntax into classic Objective-C that GCC accepts.

GCC's Objective-C front end (NeXT runtime, Mac OS X 10.4/10.5 PowerPC) has no object
literals and no @autoreleasepool. This rewrites, outside strings and comments:
  @{k: v, ...}        -> [NSDictionary dictionaryWithObjectsAndKeys:v, k, ..., nil]
  @[a, b, ...]        -> [NSArray arrayWithObjects:a, b, ..., nil]
  @(expr)             -> UTMBox(expr)          (utm-ppc-prefix.h: _Generic by type)
  @YES / @NO / @123   -> [NSNumber numberWithBool:YES] / ... / [NSNumber numberWithInt:123]
  @autoreleasepool {  -> { NSAutoreleasePool *utm_pool_N UTM_POOL_CLEANUP = [NSAutoreleasePool new];
  NSClass.method      -> [NSClass method]      (class dot syntax)
The pool is drained when its scope ends, including return/break/continue.
Usage: desugar-objc.py FILE...   (rewrites in place)
"""
import re
import sys

OPEN = {'(': ')', '[': ']', '{': '}'}


def skip_literal(s, i):
    """i at a quote or comment start; return the index just past it."""
    if s.startswith('//', i):
        j = s.find('\n', i)
        return len(s) if j < 0 else j
    if s.startswith('/*', i):
        return s.index('*/', i + 2) + 2
    q = s[i]
    i += 1
    while s[i] != q:
        i += 2 if s[i] == '\\' else 1
    return i + 1


def is_literal_start(s, i):
    return s[i] in '"\'' or s.startswith('//', i) or s.startswith('/*', i)


def match(s, i):
    """i at an opening bracket; return the index of its matching close."""
    stack = [OPEN[s[i]]]
    i += 1
    while stack:
        if is_literal_start(s, i):
            i = skip_literal(s, i)
            continue
        c = s[i]
        if c in OPEN:
            stack.append(OPEN[c])
        elif c == stack[-1]:
            stack.pop()
        elif c in ')]}':
            raise ValueError('unbalanced brackets near: ' + s[max(0, i - 60):i + 20])
        i += 1
    return i - 1


def split_top(s, seps):
    """Split s at top-level characters in seps; a ':' that closes a top-level '?' is kept."""
    parts, depth, start, ternary, i = [], 0, 0, 0, 0
    while i < len(s):
        if is_literal_start(s, i):
            i = skip_literal(s, i)
            continue
        c = s[i]
        if c in OPEN:
            depth += 1
        elif c in ')]}':
            depth -= 1
        elif depth == 0 and c == '?':
            ternary += 1
        elif depth == 0 and c == ':' and ternary:
            ternary -= 1
        elif depth == 0 and c in seps:
            parts.append(s[start:i])
            start = i + 1
        i += 1
    parts.append(s[start:])
    return [p.strip() for p in parts if p.strip()]


class Rewriter:
    def __init__(self):
        self.pools = 0

    def rewrite(self, s):
        out, i = [], 0
        while i < len(s):
            if is_literal_start(s, i):
                j = skip_literal(s, i)
                out.append(s[i:j])
                i = j
                continue
            if s[i] != '@':
                m = re.match(r'(NS[A-Z]\w*)\.([a-z]\w*)', s[i:])
                if m and (i == 0 or not (s[i - 1].isalnum() or s[i - 1] in '_.')):
                    out.append('[%s %s]' % (m.group(1), m.group(2)))
                    i += m.end()
                    continue
                out.append(s[i])
                i += 1
                continue
            nxt = s[i + 1] if i + 1 < len(s) else ''
            if nxt in '{[':
                end = match(s, i + 1)
                inner = self.rewrite(s[i + 2:end])
                if nxt == '[':
                    items = split_top(inner, ',')
                    out.append('[NSArray arrayWithObjects:%s]' % ', '.join(items + ['nil']))
                else:
                    pairs = []
                    for entry in split_top(inner, ','):
                        kv = split_top(entry, ':')
                        if len(kv) != 2:
                            raise ValueError('bad dictionary entry: ' + entry)
                        pairs += ['(%s)' % kv[1], '(%s)' % kv[0]]
                    out.append('[NSDictionary dictionaryWithObjectsAndKeys:%s]' % ', '.join(pairs + ['nil']))
                i = end + 1
                continue
            if nxt == '(':
                end = match(s, i + 1)
                out.append('UTMBox(%s)' % self.rewrite(s[i + 2:end]))
                i = end + 1
                continue
            m = re.match(r'@(YES|NO)\b', s[i:])
            if m:
                out.append('[NSNumber numberWithBool:%s]' % m.group(1))
                i += m.end()
                continue
            m = re.match(r'@(\d+)\b', s[i:])
            if m:
                out.append('[NSNumber numberWithInt:%s]' % m.group(1))
                i += m.end()
                continue
            m = re.match(r'@autoreleasepool\s*\{', s[i:])
            if m:
                self.pools += 1
                out.append('{ NSAutoreleasePool *utm_pool_%d UTM_POOL_CLEANUP = [NSAutoreleasePool new];' % self.pools)
                i += m.end()
                continue
            out.append('@')
            i += 1
        return ''.join(out)


def main():
    for path in sys.argv[1:]:
        text = open(path, encoding='utf-8').read()
        new = Rewriter().rewrite(text)
        if new != text:
            open(path, 'w', encoding='utf-8').write(new)
            print('desugared', path)


if __name__ == '__main__':
    main()
