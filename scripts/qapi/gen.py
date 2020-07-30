# -*- coding: utf-8 -*-
#
# QAPI code generation
#
# Copyright (c) 2018-2019 Red Hat Inc.
#
# Authors:
#  Markus Armbruster <armbru@redhat.com>
#  Marc-André Lureau <marcandre.lureau@redhat.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.


import errno
import os
import re
from contextlib import contextmanager

from qapi.common import *
from qapi.schema import QAPISchemaVisitor


class QAPIGen:

    def __init__(self, fname):
        self.fname = fname
        self._preamble = ''
        self._body = ''

    def preamble_add(self, text):
        self._preamble += text

    def add(self, text):
        self._body += text

    def get_content(self):
        return self._top() + self._preamble + self._body + self._bottom()

    def _top(self):
        return ''

    def _bottom(self):
        return ''

    def write(self, output_dir):
        # Include paths starting with ../ are used to reuse modules of the main
        # schema in specialised schemas. Don't overwrite the files that are
        # already generated for the main schema.
        if self.fname.startswith('../'):
            return
        pathname = os.path.join(output_dir, self.fname)
        odir = os.path.dirname(pathname)
        if odir:
            try:
                os.makedirs(odir)
            except os.error as e:
                if e.errno != errno.EEXIST:
                    raise
        fd = os.open(pathname, os.O_RDWR | os.O_CREAT, 0o666)
        f = open(fd, 'r+', encoding='utf-8')
        text = self.get_content()
        oldtext = f.read(len(text) + 1)
        if text != oldtext:
            f.seek(0)
            f.truncate(0)
            f.write(text)
        f.close()


def _wrap_ifcond(ifcond, before, after):
    if before == after:
        return after   # suppress empty #if ... #endif

    assert after.startswith(before)
    out = before
    added = after[len(before):]
    if added[0] == '\n':
        out += '\n'
        added = added[1:]
    out += gen_if(ifcond)
    out += added
    out += gen_endif(ifcond)
    return out


class QAPIGenCCode(QAPIGen):

    def __init__(self, fname):
        super().__init__(fname)
        self._start_if = None

    def start_if(self, ifcond):
        assert self._start_if is None
        self._start_if = (ifcond, self._body, self._preamble)

    def end_if(self):
        assert self._start_if
        self._wrap_ifcond()
        self._start_if = None

    def _wrap_ifcond(self):
        self._body = _wrap_ifcond(self._start_if[0],
                                  self._start_if[1], self._body)
        self._preamble = _wrap_ifcond(self._start_if[0],
                                      self._start_if[2], self._preamble)

    def get_content(self):
        assert self._start_if is None
        return super().get_content()


class QAPIGenC(QAPIGenCCode):

    def __init__(self, fname, blurb, pydoc):
        super().__init__(fname)
        self._blurb = blurb
        self._copyright = '\n * '.join(re.findall(r'^Copyright .*', pydoc,
                                                  re.MULTILINE))

    def _top(self):
        return mcgen('''
/* AUTOMATICALLY GENERATED, DO NOT MODIFY */

/*
%(blurb)s
 *
 * %(copyright)s
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.1 or later.
 * See the COPYING.LIB file in the top-level directory.
 */

''',
                     blurb=self._blurb, copyright=self._copyright)

    def _bottom(self):
        return mcgen('''

/* Dummy declaration to prevent empty .o file */
char qapi_dummy_%(name)s;
''',
                     name=c_fname(self.fname))


class QAPIGenH(QAPIGenC):

    def _top(self):
        return super()._top() + guardstart(self.fname)

    def _bottom(self):
        return guardend(self.fname)


@contextmanager
def ifcontext(ifcond, *args):
    """A 'with' statement context manager to wrap with start_if()/end_if()

    *args: any number of QAPIGenCCode

    Example::

        with ifcontext(ifcond, self._genh, self._genc):
            modify self._genh and self._genc ...

    Is equivalent to calling::

        self._genh.start_if(ifcond)
        self._genc.start_if(ifcond)
        modify self._genh and self._genc ...
        self._genh.end_if()
        self._genc.end_if()
    """
    for arg in args:
        arg.start_if(ifcond)
    yield
    for arg in args:
        arg.end_if()


class QAPIGenDoc(QAPIGen):

    def _top(self):
        return (super()._top()
                + '@c AUTOMATICALLY GENERATED, DO NOT MODIFY\n\n')


class QAPISchemaMonolithicCVisitor(QAPISchemaVisitor):

    def __init__(self, prefix, what, blurb, pydoc):
        self._prefix = prefix
        self._what = what
        self._genc = QAPIGenC(self._prefix + self._what + '.c',
                              blurb, pydoc)
        self._genh = QAPIGenH(self._prefix + self._what + '.h',
                              blurb, pydoc)

    def write(self, output_dir):
        self._genc.write(output_dir)
        self._genh.write(output_dir)


class QAPISchemaModularCVisitor(QAPISchemaVisitor):

    def __init__(self, prefix, what, user_blurb, builtin_blurb, pydoc):
        self._prefix = prefix
        self._what = what
        self._user_blurb = user_blurb
        self._builtin_blurb = builtin_blurb
        self._pydoc = pydoc
        self._genc = None
        self._genh = None
        self._module = {}
        self._main_module = None

    @staticmethod
    def _is_user_module(name):
        return name and not name.startswith('./')

    @staticmethod
    def _is_builtin_module(name):
        return not name

    def _module_dirname(self, what, name):
        if self._is_user_module(name):
            return os.path.dirname(name)
        return ''

    def _module_basename(self, what, name):
        ret = '' if self._is_builtin_module(name) else self._prefix
        if self._is_user_module(name):
            basename = os.path.basename(name)
            ret += what
            if name != self._main_module:
                ret += '-' + os.path.splitext(basename)[0]
        else:
            name = name[2:] if name else 'builtin'
            ret += re.sub(r'-', '-' + name + '-', what)
        return ret

    def _module_filename(self, what, name):
        return os.path.join(self._module_dirname(what, name),
                            self._module_basename(what, name))

    def _add_module(self, name, blurb):
        basename = self._module_filename(self._what, name)
        genc = QAPIGenC(basename + '.c', blurb, self._pydoc)
        genh = QAPIGenH(basename + '.h', blurb, self._pydoc)
        self._module[name] = (genc, genh)
        self._genc, self._genh = self._module[name]

    def _add_user_module(self, name, blurb):
        assert self._is_user_module(name)
        if self._main_module is None:
            self._main_module = name
        self._add_module(name, blurb)

    def _add_system_module(self, name, blurb):
        self._add_module(name and './' + name, blurb)

    def write(self, output_dir, opt_builtins=False):
        for name in self._module:
            if self._is_builtin_module(name) and not opt_builtins:
                continue
            (genc, genh) = self._module[name]
            genc.write(output_dir)
            genh.write(output_dir)

    def _begin_system_module(self, name):
        pass

    def _begin_user_module(self, name):
        pass

    def visit_module(self, name):
        if name is None:
            if self._builtin_blurb:
                self._add_system_module(None, self._builtin_blurb)
                self._begin_system_module(name)
            else:
                # The built-in module has not been created.  No code may
                # be generated.
                self._genc = None
                self._genh = None
        else:
            self._add_user_module(name, self._user_blurb)
            self._begin_user_module(name)

    def visit_include(self, name, info):
        relname = os.path.relpath(self._module_filename(self._what, name),
                                  os.path.dirname(self._genh.fname))
        self._genh.preamble_add(mcgen('''
#include "%(relname)s.h"
''',
                                      relname=relname))
