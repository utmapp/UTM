# -*- coding: utf-8 -*-
#
# QAPI code generation
#
# Copyright (c) 2015-2019 Red Hat Inc.
#
# Authors:
#  Markus Armbruster <armbru@redhat.com>
#  Marc-André Lureau <marcandre.lureau@redhat.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.

from contextlib import contextmanager
import os
import re
from typing import (
    Dict,
    Iterator,
    Optional,
    Sequence,
    Tuple,
)

from .common import (
    c_fname,
    c_name,
    gen_endif,
    gen_if,
    guardend,
    guardstart,
    mcgen,
)
from .schema import (
    QAPISchemaModule,
    QAPISchemaObjectType,
    QAPISchemaVisitor,
)
from .source import QAPISourceInfo


class QAPIGen:
    def __init__(self, fname: str):
        self.fname = fname
        self._preamble = ''
        self._body = ''

    def preamble_add(self, text: str) -> None:
        self._preamble += text

    def add(self, text: str) -> None:
        self._body += text

    def get_content(self) -> str:
        return self._top() + self._preamble + self._body + self._bottom()

    def _top(self) -> str:
        # pylint: disable=no-self-use
        return ''

    def _bottom(self) -> str:
        # pylint: disable=no-self-use
        return ''

    def write(self, output_dir: str) -> None:
        # Include paths starting with ../ are used to reuse modules of the main
        # schema in specialised schemas. Don't overwrite the files that are
        # already generated for the main schema.
        if self.fname.startswith('../'):
            return
        pathname = os.path.join(output_dir, self.fname)
        odir = os.path.dirname(pathname)

        if odir:
            os.makedirs(odir, exist_ok=True)

        # use os.open for O_CREAT to create and read a non-existant file
        fd = os.open(pathname, os.O_RDWR | os.O_CREAT, 0o666)
        with os.fdopen(fd, 'r+', encoding='utf-8') as fp:
            text = self.get_content()
            oldtext = fp.read(len(text) + 1)
            if text != oldtext:
                fp.seek(0)
                fp.truncate(0)
                fp.write(text)


def _wrap_ifcond(ifcond: Sequence[str], before: str, after: str) -> str:
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


def build_params(arg_type: Optional[QAPISchemaObjectType],
                 boxed: bool,
                 extra: Optional[str] = None) -> str:
    ret = ''
    sep = ''
    if boxed:
        assert arg_type
        ret += '%s arg' % arg_type.c_param_type()
        sep = ', '
    elif arg_type:
        assert not arg_type.variants
        for memb in arg_type.members:
            ret += sep
            sep = ', '
            if memb.optional:
                ret += 'bool has_%s, ' % c_name(memb.name)
            ret += '%s %s' % (memb.type.c_param_type(),
                              c_name(memb.name))
    if extra:
        ret += sep + extra
    return ret if ret else 'void'


class QAPIGenCCode(QAPIGen):
    def __init__(self, fname: str):
        super().__init__(fname)
        self._start_if: Optional[Tuple[Sequence[str], str, str]] = None

    def start_if(self, ifcond: Sequence[str]) -> None:
        assert self._start_if is None
        self._start_if = (ifcond, self._body, self._preamble)

    def end_if(self) -> None:
        assert self._start_if is not None
        self._body = _wrap_ifcond(self._start_if[0],
                                  self._start_if[1], self._body)
        self._preamble = _wrap_ifcond(self._start_if[0],
                                      self._start_if[2], self._preamble)
        self._start_if = None

    def get_content(self) -> str:
        assert self._start_if is None
        return super().get_content()


class QAPIGenC(QAPIGenCCode):
    def __init__(self, fname: str, blurb: str, pydoc: str):
        super().__init__(fname)
        self._blurb = blurb
        self._copyright = '\n * '.join(re.findall(r'^Copyright .*', pydoc,
                                                  re.MULTILINE))

    def _top(self) -> str:
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

    def _bottom(self) -> str:
        return mcgen('''

/* Dummy declaration to prevent empty .o file */
char qapi_dummy_%(name)s;
''',
                     name=c_fname(self.fname))


class QAPIGenH(QAPIGenC):
    def _top(self) -> str:
        return super()._top() + guardstart(self.fname)

    def _bottom(self) -> str:
        return guardend(self.fname)


@contextmanager
def ifcontext(ifcond: Sequence[str], *args: QAPIGenCCode) -> Iterator[None]:
    """
    A with-statement context manager that wraps with `start_if()` / `end_if()`.

    :param ifcond: A sequence of conditionals, passed to `start_if()`.
    :param args: any number of `QAPIGenCCode`.

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


class QAPISchemaMonolithicCVisitor(QAPISchemaVisitor):
    def __init__(self,
                 prefix: str,
                 what: str,
                 blurb: str,
                 pydoc: str):
        self._prefix = prefix
        self._what = what
        self._genc = QAPIGenC(self._prefix + self._what + '.c',
                              blurb, pydoc)
        self._genh = QAPIGenH(self._prefix + self._what + '.h',
                              blurb, pydoc)

    def write(self, output_dir: str) -> None:
        self._genc.write(output_dir)
        self._genh.write(output_dir)


class QAPISchemaModularCVisitor(QAPISchemaVisitor):
    def __init__(self,
                 prefix: str,
                 what: str,
                 user_blurb: str,
                 builtin_blurb: Optional[str],
                 pydoc: str):
        self._prefix = prefix
        self._what = what
        self._user_blurb = user_blurb
        self._builtin_blurb = builtin_blurb
        self._pydoc = pydoc
        self._current_module: Optional[str] = None
        self._module: Dict[str, Tuple[QAPIGenC, QAPIGenH]] = {}
        self._main_module: Optional[str] = None

    @property
    def _genc(self) -> QAPIGenC:
        assert self._current_module is not None
        return self._module[self._current_module][0]

    @property
    def _genh(self) -> QAPIGenH:
        assert self._current_module is not None
        return self._module[self._current_module][1]

    @staticmethod
    def _module_dirname(name: str) -> str:
        if QAPISchemaModule.is_user_module(name):
            return os.path.dirname(name)
        return ''

    def _module_basename(self, what: str, name: str) -> str:
        ret = '' if QAPISchemaModule.is_builtin_module(name) else self._prefix
        if QAPISchemaModule.is_user_module(name):
            basename = os.path.basename(name)
            ret += what
            if name != self._main_module:
                ret += '-' + os.path.splitext(basename)[0]
        else:
            assert QAPISchemaModule.is_system_module(name)
            ret += re.sub(r'-', '-' + name[2:] + '-', what)
        return ret

    def _module_filename(self, what: str, name: str) -> str:
        return os.path.join(self._module_dirname(name),
                            self._module_basename(what, name))

    def _add_module(self, name: str, blurb: str) -> None:
        if QAPISchemaModule.is_user_module(name):
            if self._main_module is None:
                self._main_module = name
        basename = self._module_filename(self._what, name)
        genc = QAPIGenC(basename + '.c', blurb, self._pydoc)
        genh = QAPIGenH(basename + '.h', blurb, self._pydoc)
        self._module[name] = (genc, genh)
        self._current_module = name

    @contextmanager
    def _temp_module(self, name: str) -> Iterator[None]:
        old_module = self._current_module
        self._current_module = name
        yield
        self._current_module = old_module

    def write(self, output_dir: str, opt_builtins: bool = False) -> None:
        for name in self._module:
            if QAPISchemaModule.is_builtin_module(name) and not opt_builtins:
                continue
            (genc, genh) = self._module[name]
            genc.write(output_dir)
            genh.write(output_dir)

    def _begin_builtin_module(self) -> None:
        pass

    def _begin_user_module(self, name: str) -> None:
        pass

    def visit_module(self, name: str) -> None:
        if QAPISchemaModule.is_builtin_module(name):
            if self._builtin_blurb:
                self._add_module(name, self._builtin_blurb)
                self._begin_builtin_module()
            else:
                # The built-in module has not been created.  No code may
                # be generated.
                self._current_module = None
        else:
            assert QAPISchemaModule.is_user_module(name)
            self._add_module(name, self._user_blurb)
            self._begin_user_module(name)

    def visit_include(self, name: str, info: Optional[QAPISourceInfo]) -> None:
        relname = os.path.relpath(self._module_filename(self._what, name),
                                  os.path.dirname(self._genh.fname))
        self._genh.preamble_add(mcgen('''
#include "%(relname)s.h"
''',
                                      relname=relname))
