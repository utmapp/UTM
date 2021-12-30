# -*- coding: utf-8 -*-
#
# Copyright (c) 2017-2019 Red Hat Inc.
#
# Authors:
#  Markus Armbruster <armbru@redhat.com>
#  Marc-André Lureau <marcandre.lureau@redhat.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.

"""
QAPI error classes

Common error classes used throughout the package.  Additional errors may
be defined in other modules.  At present, `QAPIParseError` is defined in
parser.py.
"""

from typing import Optional

from .source import QAPISourceInfo


class QAPIError(Exception):
    """Base class for all exceptions from the QAPI package."""


class QAPISourceError(QAPIError):
    """Error class for all exceptions identifying a source location."""
    def __init__(self,
                 info: Optional[QAPISourceInfo],
                 msg: str,
                 col: Optional[int] = None):
        super().__init__()
        self.info = info
        self.msg = msg
        self.col = col

    def __str__(self) -> str:
        assert self.info is not None
        loc = str(self.info)
        if self.col is not None:
            assert self.info.line is not None
            loc += ':%s' % self.col
        return loc + ': ' + self.msg


class QAPISemError(QAPISourceError):
    """Error class for semantic QAPI errors."""
