"""
QAPI command marshaller generator

Copyright IBM, Corp. 2011
Copyright (C) 2014-2018 Red Hat, Inc.
Copyright (c) 2019 osy

Authors:
 Anthony Liguori <aliguori@us.ibm.com>
 Michael Roth <mdroth@linux.vnet.ibm.com>
 Markus Armbruster <armbru@redhat.com>
 osy <dev@getutm.app>

This work is licensed under the terms of the GNU GPL, version 2.
See the COPYING file in the top-level directory.
"""

from typing import (
    Dict,
    List,
    Optional,
    Set,
)

from .common import c_name, mcgen
from .gen import (
    QAPIGenC,
    QAPIGenCCode,
    QAPISchemaModularCVisitor,
    build_params,
    ifcontext,
)
from .schema import (
    QAPISchema,
    QAPISchemaFeature,
    QAPISchemaObjectType,
    QAPISchemaType,
)
from .source import QAPISourceInfo


def gen_command_decl(name: str,
                     arg_type: Optional[QAPISchemaObjectType],
                     boxed: bool,
                     ret_type: Optional[QAPISchemaType],
                     proto: bool = True) -> str:
    return mcgen('''
%(c_type)s qmp_%(c_name)s(%(params)s)%(proto)s
''',
                 proto=';' if proto else '', 
                 c_type=(ret_type and ret_type.c_type()) or 'void',
                 c_name=c_name(name),
                 params=build_params(arg_type, boxed, 'Error **errp, void *ctx'))


def gen_marshal_rpc(ret_type: QAPISchemaType) -> str:
    return mcgen('''

static %(c_type)s qmp_marshal_rpc_%(c_name)s(CFDictionaryRef args, Error **errp, void *ctx)
{
    Error *err = NULL;
    Visitor *v;
    CFDictionaryRef cfret;
    %(c_type)s ret = {0};

    qmp_rpc_call(args, &cfret, &err, ctx);
    if (err) {
        error_propagate(errp, err);
        return ret;
    }
    v = cf_input_visitor_new(cfret);
    visit_start_struct(v, "command", NULL, 0, &err);
    if (err) {
        error_propagate(errp, err);
        return ret;
    }
    visit_type_%(c_name)s(v, "return", &ret, &err);
    error_propagate(errp, err);
    visit_end_struct(v, NULL);
    visit_free(v);
    CFRelease(cfret);
    return ret;
}
''',
                 c_type=ret_type.c_type(), c_name=ret_type.c_name())


def gen_rpc_call(name: str,
                 arg_type: Optional[QAPISchemaObjectType],
                 boxed: bool,
                 ret_type: Optional[QAPISchemaType]) -> str:
    have_args = boxed or (arg_type and not arg_type.is_empty())

    ret = mcgen('''

%(proto)s
{
    const char *cmdname = "%(name)s";
    CFDictionaryRef cfargs;
    Error *err = NULL;
    Visitor *v = NULL;
''',
                name=name, proto=gen_command_decl(name, arg_type, boxed, ret_type, proto=False))

    if ret_type:
        ret += mcgen('''
    %(c_type)s ret = {0};
''',
                     c_type=ret_type.c_type())

    if have_args:
        if boxed:
            visit_type = ('visit_type_%s(v, "arguments", &argp, &err);'
                             % arg_type.c_name())
            ret += mcgen('''
    %(c_name)s *argp = arg;
''',
                     c_name=arg_type.c_name())
        else:
            visit_type = ('visit_type_%s(v, "arguments", &argp, &err);'
                             % arg_type.c_name())
            ret += mcgen('''
    %(c_name)s _arg = {
''',
                     c_name=arg_type.c_name())
            if arg_type:
                assert not arg_type.variants
                for memb in arg_type.members:
                    if memb.optional:
                        ret += mcgen('''
        .has_%(c_name)s = has_%(c_name)s,
''',
                                     c_name=c_name(memb.name))
                    ret += mcgen('''
        .%(c_name)s = %(cast)s%(c_name)s,
''',
                                     cast='(char *)' if memb.type.name == 'str' else '', c_name=c_name(memb.name))
            ret += mcgen('''
    };
    %(c_name)s *argp = &_arg;
''',
                                     c_name=arg_type.c_name())
    else:
        visit_type = ''
        ret += mcgen('''

''')

    ret += mcgen('''
    v = cf_output_visitor_new((CFTypeRef *)&cfargs);
    visit_start_struct(v, "command", NULL, 0, &err);
    if (err) {
        goto out;
    }
    visit_type_str(v, "execute", (char **)&cmdname, &err);
    if (err) {
        goto out;
    }
    %(visit_type)s
    if (err) {
        goto out;
    }
    visit_end_struct(v, NULL);
    visit_complete(v, &cfargs);
''',
                 visit_type=visit_type)

    if ret_type:
        ret += mcgen('''
    ret = qmp_marshal_rpc_%(c_type)s(cfargs, &err, ctx);
''',
                    c_type=ret_type.c_name())
    else:
        ret += mcgen('''
    qmp_rpc_call(cfargs, NULL, &err, ctx);
''')

    ret += mcgen('''
    CFRelease(cfargs);

out:
    error_propagate(errp, err);
    visit_free(v);
''')

    if ret_type:
        ret += mcgen('''
    return ret;
''')

    ret += mcgen('''
}
''')
    return ret


class QAPISchemaGenCommandVisitor(QAPISchemaModularCVisitor):
    def __init__(self, prefix: str):
        super().__init__(
            prefix, 'qapi-commands',
            ' * Schema-defined QAPI/QMP commands', None, __doc__)
        self._visited_ret_types: Dict[QAPIGenC, Set[QAPISchemaType]] = {}

    def _begin_user_module(self, name: str) -> None:
        self._visited_ret_types[self._genc] = set()
        commands = self._module_basename('qapi-commands', name)
        types = self._module_basename('qapi-types', name)
        visit = self._module_basename('qapi-visit', name)
        self._genc.add(mcgen('''
#include "qemu-compat.h"
#include "cf-output-visitor.h"
#include "cf-input-visitor.h"
#include "dealloc-visitor.h"
#include "error.h"
#include "%(visit)s.h"
#include "%(commands)s.h"

''',
                             commands=commands, visit=visit))
        self._genh.add(mcgen('''
#include "%(types)s.h"

''',
                             types=types))

    def visit_command(self,
                      name: str,
                      info: QAPISourceInfo,
                      ifcond: List[str],
                      features: List[QAPISchemaFeature],
                      arg_type: Optional[QAPISchemaObjectType],
                      ret_type: Optional[QAPISchemaType],
                      gen: bool,
                      success_response: bool,
                      boxed: bool,
                      allow_oob: bool,
                      allow_preconfig: bool,
                      coroutine: bool) -> None:
        if not gen:
            return
        # FIXME: If T is a user-defined type, the user is responsible
        # for making this work, i.e. to make T's condition the
        # conjunction of the T-returning commands' conditions.  If T
        # is a built-in type, this isn't possible: the
        # qmp_marshal_output_T() will be generated unconditionally.
        if ret_type and ret_type not in self._visited_ret_types[self._genc]:
            self._visited_ret_types[self._genc].add(ret_type)
            with ifcontext(ret_type.ifcond,
                           self._genh, self._genc):
                self._genc.add(gen_marshal_rpc(ret_type))
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_command_decl(name, arg_type, boxed, ret_type))
            self._genc.add(gen_rpc_call(name, arg_type, boxed, ret_type))


def gen_commands(schema: QAPISchema,
                 output_dir: str,
                 prefix: str) -> None:
    vis = QAPISchemaGenCommandVisitor(prefix)
    schema.visit(vis)
    vis.write(output_dir)
