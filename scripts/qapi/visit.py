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

from typing import List, Optional, Sequence

from .common import (
    c_enum_const,
    c_name,
    gen_endif,
    gen_if,
    indent,
    mcgen,
)
from .gen import QAPISchemaModularCVisitor, ifcontext
from .schema import (
    QAPISchema,
    QAPISchemaEnumMember,
    QAPISchemaEnumType,
    QAPISchemaFeature,
    QAPISchemaObjectType,
    QAPISchemaObjectTypeMember,
    QAPISchemaType,
    QAPISchemaVariants,
)
from .source import QAPISourceInfo


def gen_visit_decl(name: str, scalar: bool = False) -> str:
    c_type = c_name(name) + ' *'
    if not scalar:
        c_type += '*'
    return mcgen('''

bool visit_type_%(c_name)s(Visitor *v, const char *name,
                 %(c_type)sobj, Error **errp);
''',
                 c_name=c_name(name), c_type=c_type)


def gen_visit_members_decl(name: str) -> str:
    return mcgen('''

bool visit_type_%(c_name)s_members(Visitor *v, %(c_name)s *obj, Error **errp);
''',
                 c_name=c_name(name))


def gen_visit_object_members(name: str,
                             base: Optional[QAPISchemaObjectType],
                             members: List[QAPISchemaObjectTypeMember],
                             variants: Optional[QAPISchemaVariants]) -> str:
    ret = mcgen('''

bool visit_type_%(c_name)s_members(Visitor *v, %(c_name)s *obj, Error **errp)
{
''',
                c_name=c_name(name))

    if base:
        ret += mcgen('''
    if (!visit_type_%(c_type)s_members(v, (%(c_type)s *)obj, errp)) {
        return false;
    }
''',
                     c_type=base.c_name())

    for memb in members:
        deprecated = 'deprecated' in [f.name for f in memb.features]
        ret += gen_if(memb.ifcond)
        if memb.optional:
            ret += mcgen('''
    if (visit_optional(v, "%(name)s", &obj->has_%(c_name)s)) {
''',
                         name=memb.name, c_name=c_name(memb.name))
            indent.increase()
        if deprecated:
            ret += mcgen('''
    if (!visit_deprecated_accept(v, "%(name)s", errp)) {
        return false;
    }
    if (visit_deprecated(v, "%(name)s")) {
''',
                         name=memb.name)
            indent.increase()
        ret += mcgen('''
    if (!visit_type_%(c_type)s(v, "%(name)s", &obj->%(c_name)s, errp)) {
        return false;
    }
''',
                     c_type=memb.type.c_name(), name=memb.name,
                     c_name=c_name(memb.name))
        if deprecated:
            indent.decrease()
            ret += mcgen('''
    }
''')
        if memb.optional:
            indent.decrease()
            ret += mcgen('''
    }
''')
        ret += gen_endif(memb.ifcond)

    if variants:
        tag_member = variants.tag_member
        assert isinstance(tag_member.type, QAPISchemaEnumType)

        ret += mcgen('''
    switch (obj->%(c_name)s) {
''',
                     c_name=c_name(tag_member.name))

        for var in variants.variants:
            case_str = c_enum_const(tag_member.type.name, var.name,
                                    tag_member.type.prefix)
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
        return visit_type_%(c_type)s_members(v, &obj->u.%(c_name)s, errp);
''',
                             case=case_str,
                             c_type=var.type.c_name(), c_name=c_name(var.name))

            ret += gen_endif(var.ifcond)
        ret += mcgen('''
    default:
        abort();
    }
''')

    ret += mcgen('''
    return true;
}
''')
    return ret


def gen_visit_list(name: str, element_type: QAPISchemaType) -> str:
    return mcgen('''

bool visit_type_%(c_name)s(Visitor *v, const char *name,
                 %(c_name)s **obj, Error **errp)
{
    bool ok = false;
    %(c_name)s *tail;
    size_t size = sizeof(**obj);

    if (!visit_start_list(v, name, (GenericList **)obj, size, errp)) {
        return false;
    }

    for (tail = *obj; tail;
         tail = (%(c_name)s *)visit_next_list(v, (GenericList *)tail, size)) {
        if (!visit_type_%(c_elt_type)s(v, NULL, &tail->value, errp)) {
            goto out_obj;
        }
    }

    ok = visit_check_list(v, errp);
out_obj:
    visit_end_list(v, (void **)obj);
    if (!ok && visit_is_input(v)) {
        qapi_free_%(c_name)s(*obj);
        *obj = NULL;
    }
    return ok;
}
''',
                 c_name=c_name(name), c_elt_type=element_type.c_name())


def gen_visit_enum(name: str) -> str:
    return mcgen('''

bool visit_type_%(c_name)s(Visitor *v, const char *name,
                 %(c_name)s *obj, Error **errp)
{
    int value = *obj;
    bool ok = visit_type_enum(v, name, &value, &%(c_name)s_lookup, errp);
    *obj = value;
    return ok;
}
''',
                 c_name=c_name(name))


def gen_visit_alternate(name: str, variants: QAPISchemaVariants) -> str:
    ret = mcgen('''

bool visit_type_%(c_name)s(Visitor *v, const char *name,
                 %(c_name)s **obj, Error **errp)
{
    bool ok = false;

    if (!visit_start_alternate(v, name, (GenericAlternate **)obj,
                               sizeof(**obj), errp)) {
        return false;
    }
    if (!*obj) {
        /* incomplete */
        assert(visit_is_dealloc(v));
        ok = true;
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
        if (!visit_start_struct(v, name, NULL, 0, errp)) {
            break;
        }
        if (visit_type_%(c_type)s_members(v, &(*obj)->u.%(c_name)s, errp)) {
            ok = visit_check_struct(v, errp);
        }
        visit_end_struct(v, NULL);
''',
                         c_type=var.type.c_name(),
                         c_name=c_name(var.name))
        else:
            ret += mcgen('''
        ok = visit_type_%(c_type)s(v, name, &(*obj)->u.%(c_name)s, errp);
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
        assert(visit_is_input(v));
        error_setg(errp, QERR_INVALID_PARAMETER_TYPE, name ? name : "null",
                   "%(name)s");
        /* Avoid passing invalid *obj to qapi_free_%(c_name)s() */
        g_free(*obj);
        *obj = NULL;
    }
out_obj:
    visit_end_alternate(v, (void **)obj);
    if (!ok && visit_is_input(v)) {
        qapi_free_%(c_name)s(*obj);
        *obj = NULL;
    }
    return ok;
}
''',
                 name=name, c_name=c_name(name))

    return ret


def gen_visit_object(name: str) -> str:
    return mcgen('''

bool visit_type_%(c_name)s(Visitor *v, const char *name,
                 %(c_name)s **obj, Error **errp)
{
    bool ok = false;

    if (!visit_start_struct(v, name, (void **)obj, sizeof(%(c_name)s), errp)) {
        return false;
    }
    if (!*obj) {
        /* incomplete */
        assert(visit_is_dealloc(v));
        ok = true;
        goto out_obj;
    }
    if (!visit_type_%(c_name)s_members(v, *obj, errp)) {
        goto out_obj;
    }
    ok = visit_check_struct(v, errp);
out_obj:
    visit_end_struct(v, (void **)obj);
    if (!ok && visit_is_input(v)) {
        qapi_free_%(c_name)s(*obj);
        *obj = NULL;
    }
    return ok;
}
''',
                 c_name=c_name(name))


class QAPISchemaGenVisitVisitor(QAPISchemaModularCVisitor):

    def __init__(self, prefix: str):
        super().__init__(
            prefix, 'qapi-visit', ' * Schema-defined QAPI visitors',
            ' * Built-in QAPI visitors', __doc__)

    def _begin_builtin_module(self) -> None:
        self._genc.preamble_add(mcgen('''
#include "qemu-compat.h"
#include "error.h"
#include "qapi-builtin-visit.h"
'''))
        self._genh.preamble_add(mcgen('''
#include "visitor.h"
#include "qapi-builtin-types.h"

'''))

    def _begin_user_module(self, name: str) -> None:
        types = self._module_basename('qapi-types', name)
        visit = self._module_basename('qapi-visit', name)
        self._genc.preamble_add(mcgen('''
#include "qemu-compat.h"
#include "error.h"
#include "qerror.h"
#include "%(visit)s.h"
''',
                                      visit=visit))
        self._genh.preamble_add(mcgen('''
#include "qapi-builtin-visit.h"
#include "%(types)s.h"

''',
                                      types=types))

    def visit_enum_type(self,
                        name: str,
                        info: QAPISourceInfo,
                        ifcond: Sequence[str],
                        features: List[QAPISchemaFeature],
                        members: List[QAPISchemaEnumMember],
                        prefix: Optional[str]) -> None:
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_visit_decl(name, scalar=True))
            self._genc.add(gen_visit_enum(name))

    def visit_array_type(self,
                         name: str,
                         info: Optional[QAPISourceInfo],
                         ifcond: Sequence[str],
                         element_type: QAPISchemaType) -> None:
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_visit_decl(name))
            self._genc.add(gen_visit_list(name, element_type))

    def visit_object_type(self,
                          name: str,
                          info: Optional[QAPISourceInfo],
                          ifcond: Sequence[str],
                          features: List[QAPISchemaFeature],
                          base: Optional[QAPISchemaObjectType],
                          members: List[QAPISchemaObjectTypeMember],
                          variants: Optional[QAPISchemaVariants]) -> None:
        # Nothing to do for the special empty builtin
        if name == 'q_empty':
            return
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_visit_members_decl(name))
            self._genc.add(gen_visit_object_members(name, base,
                                                    members, variants))
            # TODO Worth changing the visitor signature, so we could
            # directly use rather than repeat type.is_implicit()?
            #if not name.startswith('q_'):
                # only explicit types need an allocating visit
            self._genh.add(gen_visit_decl(name))
            self._genc.add(gen_visit_object(name))

    def visit_alternate_type(self,
                             name: str,
                             info: QAPISourceInfo,
                             ifcond: Sequence[str],
                             features: List[QAPISchemaFeature],
                             variants: QAPISchemaVariants) -> None:
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.add(gen_visit_decl(name))
            self._genc.add(gen_visit_alternate(name, variants))


def gen_visit(schema: QAPISchema,
              output_dir: str,
              prefix: str,
              opt_builtins: bool) -> None:
    vis = QAPISchemaGenVisitVisitor(prefix)
    schema.visit(vis)
    vis.write(output_dir, opt_builtins)
