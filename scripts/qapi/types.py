"""
QAPI types generator

Copyright IBM, Corp. 2011
Copyright (c) 2013-2018 Red Hat Inc.

Authors:
 Anthony Liguori <aliguori@us.ibm.com>
 Michael Roth <mdroth@linux.vnet.ibm.com>
 Markus Armbruster <armbru@redhat.com>

This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.
"""

from typing import List, Optional, Sequence

from .common import (
    c_enum_const,
    c_name,
    gen_endif,
    gen_if,
    mcgen,
)
from .gen import QAPISchemaModularCVisitor, ifcontext
from .schema import (
    QAPISchema,
    QAPISchemaEnumMember,
    QAPISchemaFeature,
    QAPISchemaObjectType,
    QAPISchemaObjectTypeMember,
    QAPISchemaType,
    QAPISchemaVariants,
)
from .source import QAPISourceInfo


# variants must be emitted before their container; track what has already
# been output
objects_seen = set()


def gen_enum_lookup(name: str,
                    members: List[QAPISchemaEnumMember],
                    prefix: Optional[str] = None) -> str:
    ret = mcgen('''

const QEnumLookup %(c_name)s_lookup = {
    .array = (const char *const[]) {
''',
                c_name=c_name(name))
    for memb in members:
        ret += gen_if(memb.ifcond)
        index = c_enum_const(name, memb.name, prefix)
        ret += mcgen('''
        [%(index)s] = "%(name)s",
''',
                     index=index, name=memb.name)
        ret += gen_endif(memb.ifcond)

    ret += mcgen('''
    },
    .size = %(max_index)s
};
''',
                 max_index=c_enum_const(name, '_MAX', prefix))
    return ret


def gen_enum(name: str,
             members: List[QAPISchemaEnumMember],
             prefix: Optional[str] = None) -> str:
    # append automatically generated _MAX value
    enum_members = members + [QAPISchemaEnumMember('_MAX', None)]

    ret = mcgen('''

typedef enum %(c_name)s {
''',
                c_name=c_name(name))

    for memb in enum_members:
        ret += gen_if(memb.ifcond)
        ret += mcgen('''
    %(c_enum)s,
''',
                     c_enum=c_enum_const(name, memb.name, prefix))
        ret += gen_endif(memb.ifcond)

    ret += mcgen('''
} %(c_name)s;
''',
                 c_name=c_name(name))

    ret += mcgen('''

#define %(c_name)s_str(val) \\
    qapi_enum_lookup(&%(c_name)s_lookup, (val))

extern const QEnumLookup %(c_name)s_lookup;
''',
                 c_name=c_name(name))
    return ret


def gen_fwd_object_or_array(name: str) -> str:
    return mcgen('''

typedef struct %(c_name)s %(c_name)s;
''',
                 c_name=c_name(name))


def gen_array(name: str, element_type: QAPISchemaType) -> str:
    return mcgen('''

struct %(c_name)s {
    %(c_name)s *next;
    %(c_type)s value;
};
''',
                 c_name=c_name(name), c_type=element_type.c_type())


def gen_struct_members(members: List[QAPISchemaObjectTypeMember]) -> str:
    ret = ''
    for memb in members:
        ret += gen_if(memb.ifcond)
        if memb.optional:
            ret += mcgen('''
    bool has_%(c_name)s;
''',
                         c_name=c_name(memb.name))
        ret += mcgen('''
    %(c_type)s %(c_name)s;
''',
                     c_type=memb.type.c_type(), c_name=c_name(memb.name))
        ret += gen_endif(memb.ifcond)
    return ret


def gen_object(name: str, ifcond: Sequence[str],
               base: Optional[QAPISchemaObjectType],
               members: List[QAPISchemaObjectTypeMember],
               variants: Optional[QAPISchemaVariants]) -> str:
    if name in objects_seen:
        return ''
    objects_seen.add(name)

    ret = ''
    for var in variants.variants if variants else ():
        obj = var.type
        if not isinstance(obj, QAPISchemaObjectType):
            continue
        ret += gen_object(obj.name, obj.ifcond, obj.base,
                          obj.local_members, obj.variants)

    ret += mcgen('''

''')
    ret += gen_if(ifcond)
    ret += mcgen('''
struct %(c_name)s {
''',
                 c_name=c_name(name))

    if base:
        if not base.is_implicit():
            ret += mcgen('''
    /* Members inherited from %(c_name)s: */
''',
                         c_name=base.c_name())
        ret += gen_struct_members(base.members)
        if not base.is_implicit():
            ret += mcgen('''
    /* Own members: */
''')
    ret += gen_struct_members(members)

    if variants:
        ret += gen_variants(variants)

    # Make sure that all structs have at least one member; this avoids
    # potential issues with attempting to malloc space for zero-length
    # structs in C, and also incompatibility with C++ (where an empty
    # struct is size 1).
    if (not base or base.is_empty()) and not members and not variants:
        ret += mcgen('''
    char qapi_dummy_for_empty_struct;
''')

    ret += mcgen('''
};
''')
    ret += gen_endif(ifcond)

    return ret


def gen_upcast(name: str, base: QAPISchemaObjectType) -> str:
    # C makes const-correctness ugly.  We have to cast away const to let
    # this function work for both const and non-const obj.
    return mcgen('''

static inline %(base)s *qapi_%(c_name)s_base(const %(c_name)s *obj)
{
    return (%(base)s *)obj;
}
''',
                 c_name=c_name(name), base=base.c_name())


def gen_variants(variants: QAPISchemaVariants) -> str:
    ret = mcgen('''
    union { /* union tag is @%(c_name)s */
''',
                c_name=c_name(variants.tag_member.name))

    for var in variants.variants:
        if var.type.name == 'q_empty':
            continue
        ret += gen_if(var.ifcond)
        ret += mcgen('''
        %(c_type)s %(c_name)s;
''',
                     c_type=var.type.c_unboxed_type(),
                     c_name=c_name(var.name))
        ret += gen_endif(var.ifcond)

    ret += mcgen('''
    } u;
''')

    return ret


def gen_type_cleanup_decl(name: str) -> str:
    ret = mcgen('''

void qapi_free_%(c_name)s(%(c_name)s *obj);
G_DEFINE_AUTOPTR_CLEANUP_FUNC(%(c_name)s, qapi_free_%(c_name)s)
''',
                c_name=c_name(name))
    return ret


def gen_type_cleanup(name: str) -> str:
    ret = mcgen('''

void qapi_free_%(c_name)s(%(c_name)s *obj)
{
    Visitor *v;

    if (!obj) {
        return;
    }

    v = qapi_dealloc_visitor_new();
    visit_type_%(c_name)s(v, NULL, &obj, NULL);
    visit_free(v);
}
''',
                c_name=c_name(name))
    return ret


class QAPISchemaGenTypeVisitor(QAPISchemaModularCVisitor):

    def __init__(self, prefix: str):
        super().__init__(
            prefix, 'qapi-types', ' * Schema-defined QAPI types',
            ' * Built-in QAPI types', __doc__)

    def _begin_builtin_module(self) -> None:
        self._genc.preamble_add(mcgen('''
#include "qemu-compat.h"
#include "dealloc-visitor.h"
#include "qapi-builtin-types.h"
#include "qapi-builtin-visit.h"
'''))
        self._genh.preamble_add(mcgen('''
#include "util.h"
'''))

    def _begin_user_module(self, name: str) -> None:
        types = self._module_basename('qapi-types', name)
        visit = self._module_basename('qapi-visit', name)
        self._genc.preamble_add(mcgen('''
#include "qemu-compat.h"
#include "dealloc-visitor.h"
#include "%(types)s.h"
#include "%(visit)s.h"
''',
                                      types=types, visit=visit))
        self._genh.preamble_add(mcgen('''
#include "qapi-builtin-types.h"
'''))

    def visit_begin(self, schema: QAPISchema) -> None:
        # gen_object() is recursive, ensure it doesn't visit the empty type
        objects_seen.add(schema.the_empty_object_type.name)

    def _gen_type_cleanup(self, name: str) -> None:
        self._genh.add(gen_type_cleanup_decl(name))
        self._genc.add(gen_type_cleanup(name))

    def visit_enum_type(self,
                        name: str,
                        info: Optional[QAPISourceInfo],
                        ifcond: Sequence[str],
                        features: List[QAPISchemaFeature],
                        members: List[QAPISchemaEnumMember],
                        prefix: Optional[str]) -> None:
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.preamble_add(gen_enum(name, members, prefix))
            self._genc.add(gen_enum_lookup(name, members, prefix))

    def visit_array_type(self,
                         name: str,
                         info: Optional[QAPISourceInfo],
                         ifcond: Sequence[str],
                         element_type: QAPISchemaType) -> None:
        with ifcontext(ifcond, self._genh, self._genc):
            self._genh.preamble_add(gen_fwd_object_or_array(name))
            self._genh.add(gen_array(name, element_type))
            self._gen_type_cleanup(name)

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
        with ifcontext(ifcond, self._genh):
            self._genh.preamble_add(gen_fwd_object_or_array(name))
        self._genh.add(gen_object(name, ifcond, base, members, variants))
        with ifcontext(ifcond, self._genh, self._genc):
            if base and not base.is_implicit():
                self._genh.add(gen_upcast(name, base))
            # TODO Worth changing the visitor signature, so we could
            # directly use rather than repeat type.is_implicit()?
            #if not name.startswith('q_'):
                # implicit types won't be directly allocated/freed
            self._gen_type_cleanup(name)

    def visit_alternate_type(self,
                             name: str,
                             info: QAPISourceInfo,
                             ifcond: Sequence[str],
                             features: List[QAPISchemaFeature],
                             variants: QAPISchemaVariants) -> None:
        with ifcontext(ifcond, self._genh):
            self._genh.preamble_add(gen_fwd_object_or_array(name))
        self._genh.add(gen_object(name, ifcond, None,
                                  [variants.tag_member], variants))
        with ifcontext(ifcond, self._genh, self._genc):
            self._gen_type_cleanup(name)


def gen_types(schema: QAPISchema,
              output_dir: str,
              prefix: str,
              opt_builtins: bool) -> None:
    vis = QAPISchemaGenTypeVisitor(prefix)
    schema.visit(vis)
    vis.write(output_dir, opt_builtins)
