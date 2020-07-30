# -*- coding: utf-8 -*-
#
# QAPI error classes
#
# Copyright (c) 2017-2019 Red Hat Inc.
#
# Authors:
#  Markus Armbruster <armbru@redhat.com>
#  Marc-André Lureau <marcandre.lureau@redhat.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.


class QAPIError(Exception):
    def __init__(self, info, col, msg):
        Exception.__init__(self)
        self.info = info
        self.col = col
        self.msg = msg

    def __str__(self):
        loc = str(self.info)
        if self.col is not None:
            assert self.info.line is not None
            loc += ':%s' % self.col
        return loc + ': ' + self.msg


class QAPIParseError(QAPIError):
    def __init__(self, parser, msg):
        col = 1
        for ch in parser.src[parser.line_pos:parser.pos]:
            if ch == '\t':
                col = (col + 7) % 8 + 1
            else:
                col += 1
        super().__init__(parser.info, col, msg)


class QAPISemError(QAPIError):
    def __init__(self, info, msg):
        super().__init__(info, None, msg)
