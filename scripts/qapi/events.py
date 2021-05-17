"""
QAPI event generator

Copyright (c) 2014 Wenchao Xia
Copyright (c) 2015-2018 Red Hat Inc.
Copyright (c) 2019 osy

Authors:
 Wenchao Xia <wenchaoqemu@gmail.com>
 Markus Armbruster <armbru@redhat.com>
 osy <dev@getutm.app>

This work is licensed under the terms of the GNU GPL, version 2.
See the COPYING file in the top-level directory.
"""

from typing import List

from .common import c_enum_const, c_name, mcgen, gen_if, gen_endif
from .gen import QAPISchemaModularCVisitor, build_params, ifcontext
from .schema import (
    QAPISchema,
    QAPISchemaEnumMember,
    QAPISchemaFeature,
    QAPISchemaObjectType,
)
from .source import QAPISourceInfo
from .types import gen_enum, gen_enum_lookup


def build_handler_name(name: str) -> str:
    return 'qapi_%s_handler' % name.lower()


def build_event_handler_proto(name: str,
                              arg_type: QAPISchemaObjectType,
                              boxed: bool) -> str:
    return 'typedef void (*%(handler)s)(%(param)s)' % {
        'handler': build_handler_name(name),
        'param': build_params(arg_type, boxed, extra='void *ctx')}


def gen_event_dispatch_decl(name: str,
                            arg_type: QAPISchemaObjectType,
                            boxed: bool) -> str:
    return mcgen('''

%(proto)s;
void qapi_event_dispatch_%(name)s(%(handler_type)s handler, CFDictionaryRef data, void *ctx);
''',
                 proto=build_event_handler_proto(name, arg_type, boxed),
                 name=name,
                 handler_type=build_handler_name(name))


# Calling the handler
def gen_call_handler(typ: QAPISchemaObjectType) -> str:
    if typ:
        assert not typ.variants
        ret = ''
        sep = ''
        for memb in typ.members:
            ret += sep
            sep = ', '
            if memb.optional:
                ret += 'arg->has_' + c_name(memb.name) + sep
            ret += 'arg->' + c_name(memb.name)
        ret += sep + 'ctx'
        return ret
    else:
        return 'ctx'


def gen_event_dispatch(name: str,
                       arg_type: QAPISchemaObjectType,
                       boxed: bool,
                       event_enum_name: str,
                       event_dispatch: str) -> str:
    # FIXME: Our declaration of local variables (and of 'errp' in the
    # parameter list) can collide with exploded members of the event's
    # data type passed in as parameters.  If this collision ever hits in
    # practice, we can rename our local variables with a leading _ prefix,
    # or split the code into a wrapper function that creates a boxed
    # 'param' object then calls another to do the real work.
    have_args = boxed or (arg_type and not arg_type.is_empty())
    ret = mcgen('''

void qapi_event_dispatch_%(name)s(%(handler_type)s handler, CFDictionaryRef data, void *ctx)
{
''',
                name=name, handler_type=build_handler_name(name))

    if have_args:
        ret += mcgen('''
    %(c_name)s *arg;
    Visitor *v;
''',
                    c_name=arg_type.c_name())

    if have_args:
        ret += mcgen('''
    v = cf_input_visitor_new(data);
''')
        ret += mcgen('''
    visit_start_struct(v, "event", NULL, 0, &error_abort);
    visit_type_%(c_name)s(v, "data", &arg, &error_abort);
    visit_end_struct(v, NULL);
''',
                         name=name, c_name=arg_type.c_name())

    ret += mcgen('''
    handler(%(param)s);

''',
                 param='arg' if boxed else gen_call_handler(arg_type))

    if have_args:
        ret += mcgen('''
    visit_free(v);
    v = qapi_dealloc_visitor_new();
    visit_type_%(c_name)s(v, "unused", &arg, NULL);
    visit_free(v);
''',
                c_name=arg_type.c_name())
    ret += mcgen('''
}
''')
    return ret


def gen_dispatcher_proto(name: str) -> str:
    return mcgen('''

void %(name)s(const char *event, CFDictionaryRef data, void *ctx);
''',
                name=name)


def gen_dispatcher(name: str,
                   event_enum_name: str,
                   events) -> str:
    ret = mcgen('''

void %(name)s(const char *event, CFDictionaryRef data, void *ctx)
{
    %(event_enum)s num;

    num = (%(event_enum)s)qapi_enum_parse(&%(event_enum)s_lookup, event, 0, &error_abort);
    switch (num) {
        default:
            assert(0);
            break;
''',
                event_enum=event_enum_name, name=name)

    for event in events:
        ret += gen_if(event[0])
        ret += mcgen('''
        case %(enum_name)s:
            if (qapi_enum_handler_registry_data.%(handler_name)s) {
                %(event_name)s(qapi_enum_handler_registry_data.%(handler_name)s, data, ctx);
            }
            break;
''',
                enum_name=event[1], event_name=event[2], handler_name=event[3])
        ret += gen_endif(event[0])

    ret += mcgen('''
    }
}
''')
    return ret


def gen_registry(events) -> str:
    ret = mcgen('''

typedef struct {
''')

    for event in events:
        ret += gen_if(event[0])
        ret += mcgen('''
    %(handler_name)s %(handler_name)s;
''',
                handler_name=event[3])
        ret += gen_endif(event[0])

    ret += mcgen('''
} qapi_enum_handler_registry;

extern qapi_enum_handler_registry qapi_enum_handler_registry_data;
''')
    return ret


class QAPISchemaGenEventVisitor(QAPISchemaModularCVisitor):

    def __init__(self, prefix: str):
        super().__init__(
            prefix, 'qapi-events',
            ' * Schema-defined QAPI/QMP events', None, __doc__)
        self._event_enum_name = c_name(prefix + 'QAPIEvent', protect=False)
        self._event_registry = []
        self._event_enum_members: List[QAPISchemaEnumMember] = []
        self._event_dispatch_name = c_name(prefix + 'qapi_event_dispatch')

    def _begin_user_module(self, name: str) -> None:
        events = self._module_basename('qapi-events', name)
        types = self._module_basename('qapi-types', name)
        visit = self._module_basename('qapi-visit', name)
        self._genc.add(mcgen('''
#include "qemu-compat.h"
#include "%(prefix)sqapi-emit-events.h"
#include "%(events)s.h"
#include "%(visit)s.h"
#include "error.h"
#include "cf-input-visitor.h"
#include "dealloc-visitor.h"

''',
                             events=events, visit=visit,
                             prefix=self._prefix))
        self._genh.add(mcgen('''
#include "util.h"
#include "%(types)s.h"
''',
                             types=types))

    def visit_end(self) -> None:
        self._add_module('./emit', ' * QAPI Events emission')
        self._genc.preamble_add(mcgen('''
#include "qemu-compat.h"
#include "%(prefix)sqapi-emit-events.h"
#include "error.h"
''',
                                      prefix=self._prefix))
        self._genh.preamble_add(mcgen('''
#include "qapi-events.h"
#include "util.h"
'''))
        self._genh.add(gen_enum(self._event_enum_name,
                                self._event_enum_members))
        self._genc.add(gen_enum_lookup(self._event_enum_name,
                                       self._event_enum_members))
        self._genh.add(gen_registry(self._event_registry))
        self._genh.add(gen_dispatcher_proto(self._event_dispatch_name))
        self._genc.add(gen_dispatcher(self._event_dispatch_name,
                                      self._event_enum_name,
                                      self._event_registry))

    def visit_event(self,
                    name: str,
                    info: QAPISourceInfo,
                    ifcond: List[str],
                    features: List[QAPISchemaFeature],
                    arg_type: QAPISchemaObjectType,
                    boxed: bool) -> None:
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_event_dispatch_decl(name, arg_type, boxed))
            self._genc.add(gen_event_dispatch(name, arg_type, boxed,
                                          self._event_enum_name,
                                          self._event_dispatch_name))
            self._event_registry.append((ifcond, c_enum_const(self._event_enum_name, name), 'qapi_event_dispatch_%s' % name, build_handler_name(name)))
        # Note: we generate the enum member regardless of @ifcond, to
        # keep the enumeration usable in target-independent code.
        self._event_enum_members.append(QAPISchemaEnumMember(name, None))


def gen_events(schema: QAPISchema,
               output_dir: str,
               prefix: str) -> None:
    vis = QAPISchemaGenEventVisitor(prefix)
    schema.visit(vis)
    vis.write(output_dir)
