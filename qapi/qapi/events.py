"""
QAPI event generator

Copyright (c) 2014 Wenchao Xia
Copyright (c) 2015-2018 Red Hat Inc.

Authors:
 Wenchao Xia <wenchaoqemu@gmail.com>
 Markus Armbruster <armbru@redhat.com>

This work is licensed under the terms of the GNU GPL, version 2.
See the COPYING file in the top-level directory.
"""

from qapi.common import *


def build_event_send_proto(name, arg_type, boxed):
    return 'void qapi_event_send_%(c_name)s(%(param)s)' % {
        'c_name': c_name(name.lower()),
        'param': build_params(arg_type, boxed)}


def gen_event_send_decl(name, arg_type, boxed):
    return mcgen('''

%(proto)s;
''',
                 proto=build_event_send_proto(name, arg_type, boxed))


# Declare and initialize an object 'qapi' using parameters from build_params()
def gen_param_var(typ):
    assert not typ.variants
    ret = mcgen('''
    %(c_name)s param = {
''',
                c_name=typ.c_name())
    sep = '        '
    for memb in typ.members:
        ret += sep
        sep = ', '
        if memb.optional:
            ret += 'has_' + c_name(memb.name) + sep
        if memb.type.name == 'str':
            # Cast away const added in build_params()
            ret += '(char *)'
        ret += c_name(memb.name)
    ret += mcgen('''

    };
''')
    if not typ.is_implicit():
        ret += mcgen('''
    %(c_name)s *arg = &param;
''',
                     c_name=typ.c_name())
    return ret


def gen_event_send(name, arg_type, boxed, event_enum_name, event_emit):
    # FIXME: Our declaration of local variables (and of 'errp' in the
    # parameter list) can collide with exploded members of the event's
    # data type passed in as parameters.  If this collision ever hits in
    # practice, we can rename our local variables with a leading _ prefix,
    # or split the code into a wrapper function that creates a boxed
    # 'param' object then calls another to do the real work.
    ret = mcgen('''

%(proto)s
{
    QDict *qmp;
''',
                proto=build_event_send_proto(name, arg_type, boxed))

    if arg_type and not arg_type.is_empty():
        ret += mcgen('''
    QObject *obj;
    Visitor *v;
''')
        if not boxed:
            ret += gen_param_var(arg_type)
    else:
        assert not boxed

    ret += mcgen('''

    qmp = qmp_event_build_dict("%(name)s");

''',
                 name=name)

    if arg_type and not arg_type.is_empty():
        ret += mcgen('''
    v = qobject_output_visitor_new(&obj);
''')
        if not arg_type.is_implicit():
            ret += mcgen('''
    visit_type_%(c_name)s(v, "%(name)s", &arg, &error_abort);
''',
                         name=name, c_name=arg_type.c_name())
        else:
            ret += mcgen('''

    visit_start_struct(v, "%(name)s", NULL, 0, &error_abort);
    visit_type_%(c_name)s_members(v, &param, &error_abort);
    visit_check_struct(v, &error_abort);
    visit_end_struct(v, NULL);
''',
                         name=name, c_name=arg_type.c_name())
        ret += mcgen('''

    visit_complete(v, &obj);
    qdict_put_obj(qmp, "data", obj);
''')

    ret += mcgen('''
    %(event_emit)s(%(c_enum)s, qmp);

''',
                 event_emit=event_emit,
                 c_enum=c_enum_const(event_enum_name, name))

    if arg_type and not arg_type.is_empty():
        ret += mcgen('''
    visit_free(v);
''')
    ret += mcgen('''
    qobject_unref(qmp);
}
''')
    return ret


class QAPISchemaGenEventVisitor(QAPISchemaModularCVisitor):

    def __init__(self, prefix):
        QAPISchemaModularCVisitor.__init__(
            self, prefix, 'qapi-events',
            ' * Schema-defined QAPI/QMP events', __doc__)
        self._event_enum_name = c_name(prefix + 'QAPIEvent', protect=False)
        self._event_enum_members = []
        self._event_emit_name = c_name(prefix + 'qapi_event_emit')

    def _begin_user_module(self, name):
        events = self._module_basename('qapi-events', name)
        types = self._module_basename('qapi-types', name)
        visit = self._module_basename('qapi-visit', name)
        self._genc.add(mcgen('''
#include "qemu/osdep.h"
#include "qemu-common.h"
#include "%(prefix)sqapi-emit-events.h"
#include "%(events)s.h"
#include "%(visit)s.h"
#include "qapi/error.h"
#include "qapi/qmp/qdict.h"
#include "qapi/qobject-output-visitor.h"
#include "qapi/qmp-event.h"

''',
                             events=events, visit=visit,
                             prefix=self._prefix))
        self._genh.add(mcgen('''
#include "qapi/util.h"
#include "%(types)s.h"
''',
                             types=types))

    def visit_end(self):
        self._add_system_module('emit', ' * QAPI Events emission')
        self._genc.preamble_add(mcgen('''
#include "qemu/osdep.h"
#include "%(prefix)sqapi-emit-events.h"
''',
                                      prefix=self._prefix))
        self._genh.preamble_add(mcgen('''
#include "qapi/util.h"
'''))
        self._genh.add(gen_enum(self._event_enum_name,
                                self._event_enum_members))
        self._genc.add(gen_enum_lookup(self._event_enum_name,
                                       self._event_enum_members))
        self._genh.add(mcgen('''

void %(event_emit)s(%(event_enum)s event, QDict *qdict);
''',
                             event_emit=self._event_emit_name,
                             event_enum=self._event_enum_name))

    def visit_event(self, name, info, ifcond, arg_type, boxed):
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_event_send_decl(name, arg_type, boxed))
            self._genc.add(gen_event_send(name, arg_type, boxed,
                                          self._event_enum_name,
                                          self._event_emit_name))
        # Note: we generate the enum member regardless of @ifcond, to
        # keep the enumeration usable in target-independent code.
        self._event_enum_members.append(QAPISchemaMember(name))


def gen_events(schema, output_dir, prefix):
    vis = QAPISchemaGenEventVisitor(prefix)
    schema.visit(vis)
    vis.write(output_dir)
