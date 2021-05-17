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
from typing import List, Optional, TypeVar


class QAPISchemaPragma:
    # Replace with @dataclass in Python 3.7+
    # pylint: disable=too-few-public-methods

    def __init__(self) -> None:
        # Are documentation comments required?
        self.doc_required = False
        # Commands whose names may use '_'
        self.command_name_exceptions: List[str] = []
        # Commands allowed to return a non-dictionary
        self.command_returns_exceptions: List[str] = []
        # Types whose member names may violate case conventions
        self.member_name_exceptions: List[str] = []


class QAPISourceInfo:
    T = TypeVar('T', bound='QAPISourceInfo')

    def __init__(self, fname: str, line: int,
                 parent: Optional['QAPISourceInfo']):
        self.fname = fname
        self.line = line
        self.parent = parent
        self.pragma: QAPISchemaPragma = (
            parent.pragma if parent else QAPISchemaPragma()
        )
        self.defn_meta: Optional[str] = None
        self.defn_name: Optional[str] = None

    def set_defn(self, meta: str, name: str) -> None:
        self.defn_meta = meta
        self.defn_name = name

    def next_line(self: T) -> T:
        info = copy.copy(self)
        info.line += 1
        return info

    def loc(self) -> str:
        if self.fname is None:
            return sys.argv[0]
        ret = self.fname
        if self.line is not None:
            ret += ':%d' % self.line
        return ret

    def in_defn(self) -> str:
        if self.defn_name:
            return "%s: In %s '%s':\n" % (self.fname,
                                          self.defn_meta, self.defn_name)
        return ''

    def include_path(self) -> str:
        ret = ''
        parent = self.parent
        while parent:
            ret = 'In file included from %s:\n' % parent.loc() + ret
            parent = parent.parent
        return ret

    def __str__(self) -> str:
        return self.include_path() + self.in_defn() + self.loc()
