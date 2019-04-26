"""
QAPI visitor generator

Copyright IBM, Corp. 2011
Copyright (C) 2014-2018 Red Hat, Inc.

Authors:
 Anthony Liguori <aliguori@us.ibm.com>
 Michael Roth    <mdroth@linux.vnet.ibm.com>
 Markus Armbruster <armbru@redhat.com>

This work is licensed under the terms of the GNU GPL, version 2.
See the COPYING file in the top-level directory.
"""

from qapi.common import *


def gen_visit_decl(name, scalar=False):
    c_type = c_name(name) + ' *'
    if not scalar:
        c_type += '*'
    return mcgen('''
void visit_type_%(c_name)s(Visitor *v, const char *name, %(c_type)sobj, Error **errp);
''',
                 c_name=c_name(name), c_type=c_type)


def gen_visit_members_decl(name):
    return mcgen('''

void visit_type_%(c_name)s_members(Visitor *v, %(c_name)s *obj, Error **errp);
''',
                 c_name=c_name(name))


def gen_visit_object_members(name, base, members, variants):
    ret = mcgen('''

void visit_type_%(c_name)s_members(Visitor *v, %(c_name)s *obj, Error **errp)
{
    Error *err = NULL;

''',
                c_name=c_name(name))

    if base:
        ret += mcgen('''
    visit_type_%(c_type)s_members(v, (%(c_type)s *)obj, &err);
    if (err) {
        goto out;
    }
''',
                     c_type=base.c_name())

    for memb in members:
        ret += gen_if(memb.ifcond)
        if memb.optional:
            ret += mcgen('''
    if (visit_optional(v, "%(name)s", &obj->has_%(c_name)s)) {
''',
                         name=memb.name, c_name=c_name(memb.name))
            push_indent()
        ret += mcgen('''
    visit_type_%(c_type)s(v, "%(name)s", &obj->%(c_name)s, &err);
    if (err) {
        goto out;
    }
''',
                     c_type=memb.type.c_name(), name=memb.name,
                     c_name=c_name(memb.name))
        if memb.optional:
            pop_indent()
            ret += mcgen('''
    }
''')
        ret += gen_endif(memb.ifcond)

    if variants:
        ret += mcgen('''
    switch (obj->%(c_name)s) {
''',
                     c_name=c_name(variants.tag_member.name))

        for var in variants.variants:
            case_str = c_enum_const(variants.tag_member.type.name,
                                    var.name,
                                    variants.tag_member.type.prefix)
            ret += gen_if(var.ifcond)
            if var.type.name == 'q_empty':
                # valid variant and nothing to do
                ret += mcgen('''
    case %(case)s:
        break;
''',
                             case=case_str)
            else:
                ret += mcgen('''
    case %(case)s:
        visit_type_%(c_type)s_members(v, &obj->u.%(c_name)s, &err);
        break;
''',
                             case=case_str,
                             c_type=var.type.c_name(), c_name=c_name(var.name))

            ret += gen_endif(var.ifcond)
        ret += mcgen('''
    default:
        abort();
    }
''')

    # 'goto out' produced for base, for each member, and if variants were
    # present
    if base or members or variants:
        ret += mcgen('''

out:
''')
    ret += mcgen('''
    error_propagate(errp, err);
}
''')
    return ret


def gen_visit_list(name, element_type):
    return mcgen('''

void visit_type_%(c_name)s(Visitor *v, const char *name, %(c_name)s **obj, Error **errp)
{
    Error *err = NULL;
    %(c_name)s *tail;
    size_t size = sizeof(**obj);

    visit_start_list(v, name, (GenericList **)obj, size, &err);
    if (err) {
        goto out;
    }

    for (tail = *obj; tail;
         tail = (%(c_name)s *)visit_next_list(v, (GenericList *)tail, size)) {
        visit_type_%(c_elt_type)s(v, NULL, &tail->value, &err);
        if (err) {
            break;
        }
    }

    if (!err) {
        visit_check_list(v, &err);
    }
    visit_end_list(v, (void **)obj);
    if (err && visit_is_input(v)) {
        qapi_free_%(c_name)s(*obj);
        *obj = NULL;
    }
out:
    error_propagate(errp, err);
}
''',
                 c_name=c_name(name), c_elt_type=element_type.c_name())


def gen_visit_enum(name):
    return mcgen('''

void visit_type_%(c_name)s(Visitor *v, const char *name, %(c_name)s *obj, Error **errp)
{
    int value = *obj;
    visit_type_enum(v, name, &value, &%(c_name)s_lookup, errp);
    *obj = value;
}
''',
                 c_name=c_name(name))


def gen_visit_alternate(name, variants):
    ret = mcgen('''

void visit_type_%(c_name)s(Visitor *v, const char *name, %(c_name)s **obj, Error **errp)
{
    Error *err = NULL;

    visit_start_alternate(v, name, (GenericAlternate **)obj, sizeof(**obj),
                          &err);
    if (err) {
        goto out;
    }
    if (!*obj) {
        goto out_obj;
    }
    switch ((*obj)->type) {
''',
                c_name=c_name(name))

    for var in variants.variants:
        ret += gen_if(var.ifcond)
        ret += mcgen('''
    case %(case)s:
''',
                     case=var.type.alternate_qtype())
        if isinstance(var.type, QAPISchemaObjectType):
            ret += mcgen('''
        visit_start_struct(v, name, NULL, 0, &err);
        if (err) {
            break;
        }
        visit_type_%(c_type)s_members(v, &(*obj)->u.%(c_name)s, &err);
        if (!err) {
            visit_check_struct(v, &err);
        }
        visit_end_struct(v, NULL);
''',
                         c_type=var.type.c_name(),
                         c_name=c_name(var.name))
        else:
            ret += mcgen('''
        visit_type_%(c_type)s(v, name, &(*obj)->u.%(c_name)s, &err);
''',
                         c_type=var.type.c_name(),
                         c_name=c_name(var.name))
        ret += mcgen('''
        break;
''')
        ret += gen_endif(var.ifcond)

    ret += mcgen('''
    case QTYPE_NONE:
        abort();
    default:
        error_setg(&err, QERR_INVALID_PARAMETER_TYPE, name ? name : "null",
                   "%(name)s");
    }
out_obj:
    visit_end_alternate(v, (void **)obj);
    if (err && visit_is_input(v)) {
        qapi_free_%(c_name)s(*obj);
        *obj = NULL;
    }
out:
    error_propagate(errp, err);
}
''',
                 name=name, c_name=c_name(name))

    return ret


def gen_visit_object(name, base, members, variants):
    return mcgen('''

void visit_type_%(c_name)s(Visitor *v, const char *name, %(c_name)s **obj, Error **errp)
{
    Error *err = NULL;

    visit_start_struct(v, name, (void **)obj, sizeof(%(c_name)s), &err);
    if (err) {
        goto out;
    }
    if (!*obj) {
        goto out_obj;
    }
    visit_type_%(c_name)s_members(v, *obj, &err);
    if (err) {
        goto out_obj;
    }
    visit_check_struct(v, &err);
out_obj:
    visit_end_struct(v, (void **)obj);
    if (err && visit_is_input(v)) {
        qapi_free_%(c_name)s(*obj);
        *obj = NULL;
    }
out:
    error_propagate(errp, err);
}
''',
                 c_name=c_name(name))


class QAPISchemaGenVisitVisitor(QAPISchemaModularCVisitor):

    def __init__(self, prefix):
        QAPISchemaModularCVisitor.__init__(
            self, prefix, 'qapi-visit', ' * Schema-defined QAPI visitors',
            __doc__)
        self._add_system_module(None, ' * Built-in QAPI visitors')
        self._genc.preamble_add(mcgen('''
#include "qemu/osdep.h"
#include "qemu-common.h"
#include "qapi/error.h"
#include "qapi/qapi-builtin-visit.h"
'''))
        self._genh.preamble_add(mcgen('''
#include "qapi/visitor.h"
#include "qapi/qapi-builtin-types.h"

''',
                                      prefix=prefix))

    def _begin_user_module(self, name):
        types = self._module_basename('qapi-types', name)
        visit = self._module_basename('qapi-visit', name)
        self._genc.preamble_add(mcgen('''
#include "qemu/osdep.h"
#include "qemu-common.h"
#include "qapi/error.h"
#include "qapi/qmp/qerror.h"
#include "%(visit)s.h"
''',
                                      visit=visit))
        self._genh.preamble_add(mcgen('''
#include "qapi/qapi-builtin-visit.h"
#include "%(types)s.h"

''',
                                      types=types))

    def visit_enum_type(self, name, info, ifcond, members, prefix):
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_visit_decl(name, scalar=True))
            self._genc.add(gen_visit_enum(name))

    def visit_array_type(self, name, info, ifcond, element_type):
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_visit_decl(name))
            self._genc.add(gen_visit_list(name, element_type))

    def visit_object_type(self, name, info, ifcond, base, members, variants):
        # Nothing to do for the special empty builtin
        if name == 'q_empty':
            return
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_visit_members_decl(name))
            self._genc.add(gen_visit_object_members(name, base,
                                                    members, variants))
            # TODO Worth changing the visitor signature, so we could
            # directly use rather than repeat type.is_implicit()?
            if not name.startswith('q_'):
                # only explicit types need an allocating visit
                self._genh.add(gen_visit_decl(name))
                self._genc.add(gen_visit_object(name, base, members, variants))

    def visit_alternate_type(self, name, info, ifcond, variants):
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_visit_decl(name))
            self._genc.add(gen_visit_alternate(name, variants))


def gen_visit(schema, output_dir, prefix, opt_builtins):
    vis = QAPISchemaGenVisitVisitor(prefix)
    schema.visit(vis)
    vis.write(output_dir, opt_builtins)
