#
# QAPI frontend source file info
#
# Copyright (c) 2019 Red Hat Inc.
#
# Authors:
#  Markus Armbruster <armbru@redhat.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.

import copy
import sys


class QAPISchemaPragma:
    def __init__(self):
        # Are documentation comments required?
        self.doc_required = False
        # Whitelist of commands allowed to return a non-dictionary
        self.returns_whitelist = []
        # Whitelist of entities allowed to violate case conventions
        self.name_case_whitelist = []


class QAPISourceInfo:
    def __init__(self, fname, line, parent):
        self.fname = fname
        self.line = line
        self.parent = parent
        self.pragma = parent.pragma if parent else QAPISchemaPragma()
        self.defn_meta = None
        self.defn_name = None

    def set_defn(self, meta, name):
        self.defn_meta = meta
        self.defn_name = name

    def next_line(self):
        info = copy.copy(self)
        info.line += 1
        return info

    def loc(self):
        if self.fname is None:
            return sys.argv[0]
        ret = self.fname
        if self.line is not None:
            ret += ':%d' % self.line
        return ret

    def in_defn(self):
        if self.defn_name:
            return "%s: In %s '%s':\n" % (self.fname,
                                          self.defn_meta, self.defn_name)
        return ''

    def include_path(self):
        ret = ''
        parent = self.parent
        while parent:
            ret = 'In file included from %s:\n' % parent.loc() + ret
            parent = parent.parent
        return ret

    def __str__(self):
        return self.include_path() + self.in_defn() + self.loc()
