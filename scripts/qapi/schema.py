# -*- coding: utf-8 -*-
#
# QAPI schema internal representation
#
# Copyright (c) 2015-2019 Red Hat Inc.
#
# Authors:
#  Markus Armbruster <armbru@redhat.com>
#  Eric Blake <eblake@redhat.com>
#  Marc-André Lureau <marcandre.lureau@redhat.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.

# TODO catching name collisions in generated code would be nice

from collections import OrderedDict
import os
import re
from typing import Optional

from .common import POINTER_SUFFIX, c_name
from .error import QAPIError, QAPISemError
from .expr import check_exprs
from .parser import QAPISchemaParser


class QAPISchemaEntity:
    meta: Optional[str] = None

    def __init__(self, name: str, info, doc, ifcond=None, features=None):
        assert name is None or isinstance(name, str)
        for f in features or []:
            assert isinstance(f, QAPISchemaFeature)
            f.set_defined_in(name)
        self.name = name
        self._module = None
        # For explicitly defined entities, info points to the (explicit)
        # definition.  For builtins (and their arrays), info is None.
        # For implicitly defined entities, info points to a place that
        # triggered the implicit definition (there may be more than one
        # such place).
        self.info = info
        self.doc = doc
        self._ifcond = ifcond or []
        self.features = features or []
        self._checked = False

    def c_name(self):
        return c_name(self.name)

    def check(self, schema):
        assert not self._checked
        seen = {}
        for f in self.features:
            f.check_clash(self.info, seen)
        self._checked = True

    def connect_doc(self, doc=None):
        doc = doc or self.doc
        if doc:
            for f in self.features:
                doc.connect_feature(f)

    def check_doc(self):
        if self.doc:
            self.doc.check()

    def _set_module(self, schema, info):
        assert self._checked
        fname = info.fname if info else QAPISchemaModule.BUILTIN_MODULE_NAME
        self._module = schema.module_by_fname(fname)
        self._module.add_entity(self)

    def set_module(self, schema):
        self._set_module(schema, self.info)

    @property
    def ifcond(self):
        assert self._checked
        return self._ifcond

    def is_implicit(self):
        return not self.info

    def visit(self, visitor):
        assert self._checked

    def describe(self):
        assert self.meta
        return "%s '%s'" % (self.meta, self.name)


class QAPISchemaVisitor:
    def visit_begin(self, schema):
        pass

    def visit_end(self):
        pass

    def visit_module(self, name):
        pass

    def visit_needed(self, entity):
        # Default to visiting everything
        return True

    def visit_include(self, name, info):
        pass

    def visit_builtin_type(self, name, info, json_type):
        pass

    def visit_enum_type(self, name, info, ifcond, features, members, prefix):
        pass

    def visit_array_type(self, name, info, ifcond, element_type):
        pass

    def visit_object_type(self, name, info, ifcond, features,
                          base, members, variants):
        pass

    def visit_object_type_flat(self, name, info, ifcond, features,
                               members, variants):
        pass

    def visit_alternate_type(self, name, info, ifcond, features, variants):
        pass

    def visit_command(self, name, info, ifcond, features,
                      arg_type, ret_type, gen, success_response, boxed,
                      allow_oob, allow_preconfig, coroutine):
        pass

    def visit_event(self, name, info, ifcond, features, arg_type, boxed):
        pass


class QAPISchemaModule:

    BUILTIN_MODULE_NAME = './builtin'

    def __init__(self, name):
        self.name = name
        self._entity_list = []

    @staticmethod
    def is_system_module(name: str) -> bool:
        """
        System modules are internally defined modules.

        Their names start with the "./" prefix.
        """
        return name.startswith('./')

    @classmethod
    def is_user_module(cls, name: str) -> bool:
        """
        User modules are those defined by the user in qapi JSON files.

        They do not start with the "./" prefix.
        """
        return not cls.is_system_module(name)

    @classmethod
    def is_builtin_module(cls, name: str) -> bool:
        """
        The built-in module is a single System module for the built-in types.

        It is always "./builtin".
        """
        return name == cls.BUILTIN_MODULE_NAME

    def add_entity(self, ent):
        self._entity_list.append(ent)

    def visit(self, visitor):
        visitor.visit_module(self.name)
        for entity in self._entity_list:
            if visitor.visit_needed(entity):
                entity.visit(visitor)


class QAPISchemaInclude(QAPISchemaEntity):
    def __init__(self, sub_module, info):
        super().__init__(None, info, None)
        self._sub_module = sub_module

    def visit(self, visitor):
        super().visit(visitor)
        visitor.visit_include(self._sub_module.name, self.info)


class QAPISchemaType(QAPISchemaEntity):
    # Return the C type for common use.
    # For the types we commonly box, this is a pointer type.
    def c_type(self):
        pass

    # Return the C type to be used in a parameter list.
    def c_param_type(self):
        return self.c_type()

    # Return the C type to be used where we suppress boxing.
    def c_unboxed_type(self):
        return self.c_type()

    def json_type(self):
        pass

    def alternate_qtype(self):
        json2qtype = {
            'null':    'QTYPE_QNULL',
            'string':  'QTYPE_QSTRING',
            'number':  'QTYPE_QNUM',
            'int':     'QTYPE_QNUM',
            'boolean': 'QTYPE_QBOOL',
            'object':  'QTYPE_QDICT'
        }
        return json2qtype.get(self.json_type())

    def doc_type(self):
        if self.is_implicit():
            return None
        return self.name

    def check(self, schema):
        QAPISchemaEntity.check(self, schema)
        if 'deprecated' in [f.name for f in self.features]:
            raise QAPISemError(
                self.info, "feature 'deprecated' is not supported for types")

    def describe(self):
        assert self.meta
        return "%s type '%s'" % (self.meta, self.name)


class QAPISchemaBuiltinType(QAPISchemaType):
    meta = 'built-in'

    def __init__(self, name, json_type, c_type):
        super().__init__(name, None, None)
        assert not c_type or isinstance(c_type, str)
        assert json_type in ('string', 'number', 'int', 'boolean', 'null',
                             'value')
        self._json_type_name = json_type
        self._c_type_name = c_type

    def c_name(self):
        return self.name

    def c_type(self):
        return self._c_type_name

    def c_param_type(self):
        if self.name == 'str':
            return 'const ' + self._c_type_name
        return self._c_type_name

    def json_type(self):
        return self._json_type_name

    def doc_type(self):
        return self.json_type()

    def visit(self, visitor):
        super().visit(visitor)
        visitor.visit_builtin_type(self.name, self.info, self.json_type())


class QAPISchemaEnumType(QAPISchemaType):
    meta = 'enum'

    def __init__(self, name, info, doc, ifcond, features, members, prefix):
        super().__init__(name, info, doc, ifcond, features)
        for m in members:
            assert isinstance(m, QAPISchemaEnumMember)
            m.set_defined_in(name)
        assert prefix is None or isinstance(prefix, str)
        self.members = members
        self.prefix = prefix

    def check(self, schema):
        super().check(schema)
        seen = {}
        for m in self.members:
            m.check_clash(self.info, seen)

    def connect_doc(self, doc=None):
        super().connect_doc(doc)
        doc = doc or self.doc
        for m in self.members:
            m.connect_doc(doc)

    def is_implicit(self):
        # See QAPISchema._make_implicit_enum_type() and ._def_predefineds()
        return self.name.endswith('Kind') or self.name == 'QType'

    def c_type(self):
        return c_name(self.name)

    def member_names(self):
        return [m.name for m in self.members]

    def json_type(self):
        return 'string'

    def visit(self, visitor):
        super().visit(visitor)
        visitor.visit_enum_type(
            self.name, self.info, self.ifcond, self.features,
            self.members, self.prefix)


class QAPISchemaArrayType(QAPISchemaType):
    meta = 'array'

    def __init__(self, name, info, element_type):
        super().__init__(name, info, None)
        assert isinstance(element_type, str)
        self._element_type_name = element_type
        self.element_type = None

    def check(self, schema):
        super().check(schema)
        self.element_type = schema.resolve_type(
            self._element_type_name, self.info,
            self.info and self.info.defn_meta)
        assert not isinstance(self.element_type, QAPISchemaArrayType)

    def set_module(self, schema):
        self._set_module(schema, self.element_type.info)

    @property
    def ifcond(self):
        assert self._checked
        return self.element_type.ifcond

    def is_implicit(self):
        return True

    def c_type(self):
        return c_name(self.name) + POINTER_SUFFIX

    def json_type(self):
        return 'array'

    def doc_type(self):
        elt_doc_type = self.element_type.doc_type()
        if not elt_doc_type:
            return None
        return 'array of ' + elt_doc_type

    def visit(self, visitor):
        super().visit(visitor)
        visitor.visit_array_type(self.name, self.info, self.ifcond,
                                 self.element_type)

    def describe(self):
        assert self.meta
        return "%s type ['%s']" % (self.meta, self._element_type_name)


class QAPISchemaObjectType(QAPISchemaType):
    def __init__(self, name, info, doc, ifcond, features,
                 base, local_members, variants):
        # struct has local_members, optional base, and no variants
        # flat union has base, variants, and no local_members
        # simple union has local_members, variants, and no base
        super().__init__(name, info, doc, ifcond, features)
        self.meta = 'union' if variants else 'struct'
        assert base is None or isinstance(base, str)
        for m in local_members:
            assert isinstance(m, QAPISchemaObjectTypeMember)
            m.set_defined_in(name)
        if variants is not None:
            assert isinstance(variants, QAPISchemaVariants)
            variants.set_defined_in(name)
        self._base_name = base
        self.base = None
        self.local_members = local_members
        self.variants = variants
        self.members = None

    def check(self, schema):
        # This calls another type T's .check() exactly when the C
        # struct emitted by gen_object() contains that T's C struct
        # (pointers don't count).
        if self.members is not None:
            # A previous .check() completed: nothing to do
            return
        if self._checked:
            # Recursed: C struct contains itself
            raise QAPISemError(self.info,
                               "object %s contains itself" % self.name)

        super().check(schema)
        assert self._checked and self.members is None

        seen = OrderedDict()
        if self._base_name:
            self.base = schema.resolve_type(self._base_name, self.info,
                                            "'base'")
            if (not isinstance(self.base, QAPISchemaObjectType)
                    or self.base.variants):
                raise QAPISemError(
                    self.info,
                    "'base' requires a struct type, %s isn't"
                    % self.base.describe())
            self.base.check(schema)
            self.base.check_clash(self.info, seen)
        for m in self.local_members:
            m.check(schema)
            m.check_clash(self.info, seen)
        members = seen.values()

        if self.variants:
            self.variants.check(schema, seen)
            self.variants.check_clash(self.info, seen)

        self.members = members  # mark completed

    # Check that the members of this type do not cause duplicate JSON members,
    # and update seen to track the members seen so far. Report any errors
    # on behalf of info, which is not necessarily self.info
    def check_clash(self, info, seen):
        assert self._checked
        assert not self.variants       # not implemented
        for m in self.members:
            m.check_clash(info, seen)

    def connect_doc(self, doc=None):
        super().connect_doc(doc)
        doc = doc or self.doc
        if self.base and self.base.is_implicit():
            self.base.connect_doc(doc)
        for m in self.local_members:
            m.connect_doc(doc)

    @property
    def ifcond(self):
        assert self._checked
        if isinstance(self._ifcond, QAPISchemaType):
            # Simple union wrapper type inherits from wrapped type;
            # see _make_implicit_object_type()
            return self._ifcond.ifcond
        return self._ifcond

    def is_implicit(self):
        # See QAPISchema._make_implicit_object_type(), as well as
        # _def_predefineds()
        return self.name.startswith('q_')

    def is_empty(self):
        assert self.members is not None
        return not self.members and not self.variants

    def c_name(self):
        assert self.name != 'q_empty'
        return super().c_name()

    def c_type(self):
        assert not self.is_implicit()
        return c_name(self.name) + POINTER_SUFFIX

    def c_unboxed_type(self):
        return c_name(self.name)

    def json_type(self):
        return 'object'

    def visit(self, visitor):
        super().visit(visitor)
        visitor.visit_object_type(
            self.name, self.info, self.ifcond, self.features,
            self.base, self.local_members, self.variants)
        visitor.visit_object_type_flat(
            self.name, self.info, self.ifcond, self.features,
            self.members, self.variants)


class QAPISchemaAlternateType(QAPISchemaType):
    meta = 'alternate'

    def __init__(self, name, info, doc, ifcond, features, variants):
        super().__init__(name, info, doc, ifcond, features)
        assert isinstance(variants, QAPISchemaVariants)
        assert variants.tag_member
        variants.set_defined_in(name)
        variants.tag_member.set_defined_in(self.name)
        self.variants = variants

    def check(self, schema):
        super().check(schema)
        self.variants.tag_member.check(schema)
        # Not calling self.variants.check_clash(), because there's nothing
        # to clash with
        self.variants.check(schema, {})
        # Alternate branch names have no relation to the tag enum values;
        # so we have to check for potential name collisions ourselves.
        seen = {}
        types_seen = {}
        for v in self.variants.variants:
            v.check_clash(self.info, seen)
            qtype = v.type.alternate_qtype()
            if not qtype:
                raise QAPISemError(
                    self.info,
                    "%s cannot use %s"
                    % (v.describe(self.info), v.type.describe()))
            conflicting = set([qtype])
            if qtype == 'QTYPE_QSTRING':
                if isinstance(v.type, QAPISchemaEnumType):
                    for m in v.type.members:
                        if m.name in ['on', 'off']:
                            conflicting.add('QTYPE_QBOOL')
                        if re.match(r'[-+0-9.]', m.name):
                            # lazy, could be tightened
                            conflicting.add('QTYPE_QNUM')
                else:
                    conflicting.add('QTYPE_QNUM')
                    conflicting.add('QTYPE_QBOOL')
            for qt in conflicting:
                if qt in types_seen:
                    raise QAPISemError(
                        self.info,
                        "%s can't be distinguished from '%s'"
                        % (v.describe(self.info), types_seen[qt]))
                types_seen[qt] = v.name

    def connect_doc(self, doc=None):
        super().connect_doc(doc)
        doc = doc or self.doc
        for v in self.variants.variants:
            v.connect_doc(doc)

    def c_type(self):
        return c_name(self.name) + POINTER_SUFFIX

    def json_type(self):
        return 'value'

    def visit(self, visitor):
        super().visit(visitor)
        visitor.visit_alternate_type(
            self.name, self.info, self.ifcond, self.features, self.variants)


class QAPISchemaVariants:
    def __init__(self, tag_name, info, tag_member, variants):
        # Flat unions pass tag_name but not tag_member.
        # Simple unions and alternates pass tag_member but not tag_name.
        # After check(), tag_member is always set, and tag_name remains
        # a reliable witness of being used by a flat union.
        assert bool(tag_member) != bool(tag_name)
        assert (isinstance(tag_name, str) or
                isinstance(tag_member, QAPISchemaObjectTypeMember))
        for v in variants:
            assert isinstance(v, QAPISchemaVariant)
        self._tag_name = tag_name
        self.info = info
        self.tag_member = tag_member
        self.variants = variants

    def set_defined_in(self, name):
        for v in self.variants:
            v.set_defined_in(name)

    def check(self, schema, seen):
        if not self.tag_member:  # flat union
            self.tag_member = seen.get(c_name(self._tag_name))
            base = "'base'"
            # Pointing to the base type when not implicit would be
            # nice, but we don't know it here
            if not self.tag_member or self._tag_name != self.tag_member.name:
                raise QAPISemError(
                    self.info,
                    "discriminator '%s' is not a member of %s"
                    % (self._tag_name, base))
            # Here we do:
            base_type = schema.lookup_type(self.tag_member.defined_in)
            assert base_type
            if not base_type.is_implicit():
                base = "base type '%s'" % self.tag_member.defined_in
            if not isinstance(self.tag_member.type, QAPISchemaEnumType):
                raise QAPISemError(
                    self.info,
                    "discriminator member '%s' of %s must be of enum type"
                    % (self._tag_name, base))
            if self.tag_member.optional:
                raise QAPISemError(
                    self.info,
                    "discriminator member '%s' of %s must not be optional"
                    % (self._tag_name, base))
            if self.tag_member.ifcond:
                raise QAPISemError(
                    self.info,
                    "discriminator member '%s' of %s must not be conditional"
                    % (self._tag_name, base))
        else:                   # simple union
            assert isinstance(self.tag_member.type, QAPISchemaEnumType)
            assert not self.tag_member.optional
            assert self.tag_member.ifcond == []
        if self._tag_name:    # flat union
            # branches that are not explicitly covered get an empty type
            cases = {v.name for v in self.variants}
            for m in self.tag_member.type.members:
                if m.name not in cases:
                    v = QAPISchemaVariant(m.name, self.info,
                                          'q_empty', m.ifcond)
                    v.set_defined_in(self.tag_member.defined_in)
                    self.variants.append(v)
        if not self.variants:
            raise QAPISemError(self.info, "union has no branches")
        for v in self.variants:
            v.check(schema)
            # Union names must match enum values; alternate names are
            # checked separately. Use 'seen' to tell the two apart.
            if seen:
                if v.name not in self.tag_member.type.member_names():
                    raise QAPISemError(
                        self.info,
                        "branch '%s' is not a value of %s"
                        % (v.name, self.tag_member.type.describe()))
                if (not isinstance(v.type, QAPISchemaObjectType)
                        or v.type.variants):
                    raise QAPISemError(
                        self.info,
                        "%s cannot use %s"
                        % (v.describe(self.info), v.type.describe()))
                v.type.check(schema)

    def check_clash(self, info, seen):
        for v in self.variants:
            # Reset seen map for each variant, since qapi names from one
            # branch do not affect another branch
            v.type.check_clash(info, dict(seen))


class QAPISchemaMember:
    """ Represents object members, enum members and features """
    role = 'member'

    def __init__(self, name, info, ifcond=None):
        assert isinstance(name, str)
        self.name = name
        self.info = info
        self.ifcond = ifcond or []
        self.defined_in = None

    def set_defined_in(self, name):
        assert not self.defined_in
        self.defined_in = name

    def check_clash(self, info, seen):
        cname = c_name(self.name)
        if cname in seen:
            raise QAPISemError(
                info,
                "%s collides with %s"
                % (self.describe(info), seen[cname].describe(info)))
        seen[cname] = self

    def connect_doc(self, doc):
        if doc:
            doc.connect_member(self)

    def describe(self, info):
        role = self.role
        defined_in = self.defined_in
        assert defined_in

        if defined_in.startswith('q_obj_'):
            # See QAPISchema._make_implicit_object_type() - reverse the
            # mapping there to create a nice human-readable description
            defined_in = defined_in[6:]
            if defined_in.endswith('-arg'):
                # Implicit type created for a command's dict 'data'
                assert role == 'member'
                role = 'parameter'
            elif defined_in.endswith('-base'):
                # Implicit type created for a flat union's dict 'base'
                role = 'base ' + role
            else:
                # Implicit type created for a simple union's branch
                assert defined_in.endswith('-wrapper')
                # Unreachable and not implemented
                assert False
        elif defined_in.endswith('Kind'):
            # See QAPISchema._make_implicit_enum_type()
            # Implicit enum created for simple union's branches
            assert role == 'value'
            role = 'branch'
        elif defined_in != info.defn_name:
            return "%s '%s' of type '%s'" % (role, self.name, defined_in)
        return "%s '%s'" % (role, self.name)


class QAPISchemaEnumMember(QAPISchemaMember):
    role = 'value'


class QAPISchemaFeature(QAPISchemaMember):
    role = 'feature'


class QAPISchemaObjectTypeMember(QAPISchemaMember):
    def __init__(self, name, info, typ, optional, ifcond=None, features=None):
        super().__init__(name, info, ifcond)
        assert isinstance(typ, str)
        assert isinstance(optional, bool)
        for f in features or []:
            assert isinstance(f, QAPISchemaFeature)
            f.set_defined_in(name)
        self._type_name = typ
        self.type = None
        self.optional = optional
        self.features = features or []

    def check(self, schema):
        assert self.defined_in
        self.type = schema.resolve_type(self._type_name, self.info,
                                        self.describe)
        seen = {}
        for f in self.features:
            f.check_clash(self.info, seen)

    def connect_doc(self, doc):
        super().connect_doc(doc)
        if doc:
            for f in self.features:
                doc.connect_feature(f)


class QAPISchemaVariant(QAPISchemaObjectTypeMember):
    role = 'branch'

    def __init__(self, name, info, typ, ifcond=None):
        super().__init__(name, info, typ, False, ifcond)


class QAPISchemaCommand(QAPISchemaEntity):
    meta = 'command'

    def __init__(self, name, info, doc, ifcond, features,
                 arg_type, ret_type,
                 gen, success_response, boxed, allow_oob, allow_preconfig,
                 coroutine):
        super().__init__(name, info, doc, ifcond, features)
        assert not arg_type or isinstance(arg_type, str)
        assert not ret_type or isinstance(ret_type, str)
        self._arg_type_name = arg_type
        self.arg_type = None
        self._ret_type_name = ret_type
        self.ret_type = None
        self.gen = gen
        self.success_response = success_response
        self.boxed = boxed
        self.allow_oob = allow_oob
        self.allow_preconfig = allow_preconfig
        self.coroutine = coroutine

    def check(self, schema):
        super().check(schema)
        if self._arg_type_name:
            self.arg_type = schema.resolve_type(
                self._arg_type_name, self.info, "command's 'data'")
            if not isinstance(self.arg_type, QAPISchemaObjectType):
                raise QAPISemError(
                    self.info,
                    "command's 'data' cannot take %s"
                    % self.arg_type.describe())
            if self.arg_type.variants and not self.boxed:
                raise QAPISemError(
                    self.info,
                    "command's 'data' can take %s only with 'boxed': true"
                    % self.arg_type.describe())
        if self._ret_type_name:
            self.ret_type = schema.resolve_type(
                self._ret_type_name, self.info, "command's 'returns'")
            if self.name not in self.info.pragma.command_returns_exceptions:
                typ = self.ret_type
                if isinstance(typ, QAPISchemaArrayType):
                    typ = self.ret_type.element_type
                    assert typ
                if not isinstance(typ, QAPISchemaObjectType):
                    raise QAPISemError(
                        self.info,
                        "command's 'returns' cannot take %s"
                        % self.ret_type.describe())

    def connect_doc(self, doc=None):
        super().connect_doc(doc)
        doc = doc or self.doc
        if doc:
            if self.arg_type and self.arg_type.is_implicit():
                self.arg_type.connect_doc(doc)

    def visit(self, visitor):
        super().visit(visitor)
        visitor.visit_command(
            self.name, self.info, self.ifcond, self.features,
            self.arg_type, self.ret_type, self.gen, self.success_response,
            self.boxed, self.allow_oob, self.allow_preconfig,
            self.coroutine)


class QAPISchemaEvent(QAPISchemaEntity):
    meta = 'event'

    def __init__(self, name, info, doc, ifcond, features, arg_type, boxed):
        super().__init__(name, info, doc, ifcond, features)
        assert not arg_type or isinstance(arg_type, str)
        self._arg_type_name = arg_type
        self.arg_type = None
        self.boxed = boxed

    def check(self, schema):
        super().check(schema)
        if self._arg_type_name:
            self.arg_type = schema.resolve_type(
                self._arg_type_name, self.info, "event's 'data'")
            if not isinstance(self.arg_type, QAPISchemaObjectType):
                raise QAPISemError(
                    self.info,
                    "event's 'data' cannot take %s"
                    % self.arg_type.describe())
            if self.arg_type.variants and not self.boxed:
                raise QAPISemError(
                    self.info,
                    "event's 'data' can take %s only with 'boxed': true"
                    % self.arg_type.describe())

    def connect_doc(self, doc=None):
        super().connect_doc(doc)
        doc = doc or self.doc
        if doc:
            if self.arg_type and self.arg_type.is_implicit():
                self.arg_type.connect_doc(doc)

    def visit(self, visitor):
        super().visit(visitor)
        visitor.visit_event(
            self.name, self.info, self.ifcond, self.features,
            self.arg_type, self.boxed)


class QAPISchema:
    def __init__(self, fname):
        self.fname = fname
        parser = QAPISchemaParser(fname)
        exprs = check_exprs(parser.exprs)
        self.docs = parser.docs
        self._entity_list = []
        self._entity_dict = {}
        self._module_dict = OrderedDict()
        self._schema_dir = os.path.dirname(fname)
        self._make_module(QAPISchemaModule.BUILTIN_MODULE_NAME)
        self._make_module(fname)
        self._predefining = True
        self._def_predefineds()
        self._predefining = False
        self._def_exprs(exprs)
        self.check()

    def _def_entity(self, ent):
        # Only the predefined types are allowed to not have info
        assert ent.info or self._predefining
        self._entity_list.append(ent)
        if ent.name is None:
            return
        # TODO reject names that differ only in '_' vs. '.'  vs. '-',
        # because they're liable to clash in generated C.
        other_ent = self._entity_dict.get(ent.name)
        if other_ent:
            if other_ent.info:
                where = QAPIError(other_ent.info, None, "previous definition")
                raise QAPISemError(
                    ent.info,
                    "'%s' is already defined\n%s" % (ent.name, where))
            raise QAPISemError(
                ent.info, "%s is already defined" % other_ent.describe())
        self._entity_dict[ent.name] = ent

    def lookup_entity(self, name, typ=None):
        ent = self._entity_dict.get(name)
        if typ and not isinstance(ent, typ):
            return None
        return ent

    def lookup_type(self, name):
        return self.lookup_entity(name, QAPISchemaType)

    def resolve_type(self, name, info, what):
        typ = self.lookup_type(name)
        if not typ:
            if callable(what):
                what = what(info)
            raise QAPISemError(
                info, "%s uses unknown type '%s'" % (what, name))
        return typ

    def _module_name(self, fname: str) -> str:
        if QAPISchemaModule.is_system_module(fname):
            return fname
        return os.path.relpath(fname, self._schema_dir)

    def _make_module(self, fname):
        name = self._module_name(fname)
        if name not in self._module_dict:
            self._module_dict[name] = QAPISchemaModule(name)
        return self._module_dict[name]

    def module_by_fname(self, fname):
        name = self._module_name(fname)
        return self._module_dict[name]

    def _def_include(self, expr, info, doc):
        include = expr['include']
        assert doc is None
        self._def_entity(QAPISchemaInclude(self._make_module(include), info))

    def _def_builtin_type(self, name, json_type, c_type):
        self._def_entity(QAPISchemaBuiltinType(name, json_type, c_type))
        # Instantiating only the arrays that are actually used would
        # be nice, but we can't as long as their generated code
        # (qapi-builtin-types.[ch]) may be shared by some other
        # schema.
        self._make_array_type(name, None)

    def _def_predefineds(self):
        for t in [('str',    'string',  'char' + POINTER_SUFFIX),
                  ('number', 'number',  'double'),
                  ('int',    'int',     'int64_t'),
                  ('int8',   'int',     'int8_t'),
                  ('int16',  'int',     'int16_t'),
                  ('int32',  'int',     'int32_t'),
                  ('int64',  'int',     'int64_t'),
                  ('uint8',  'int',     'uint8_t'),
                  ('uint16', 'int',     'uint16_t'),
                  ('uint32', 'int',     'uint32_t'),
                  ('uint64', 'int',     'uint64_t'),
                  ('size',   'int',     'uint64_t'),
                  ('bool',   'boolean', 'bool'),
                  ('any',    'value',   'CFTypeRef'),
                  ('null',   'null',    'CFNullRef')]:
            self._def_builtin_type(*t)
        self.the_empty_object_type = QAPISchemaObjectType(
            'q_empty', None, None, None, None, None, [], None)
        self._def_entity(self.the_empty_object_type)

        qtypes = ['none', 'qnull', 'qnum', 'qstring', 'qdict', 'qlist',
                  'qbool']
        qtype_values = self._make_enum_members(
            [{'name': n} for n in qtypes], None)

        self._def_entity(QAPISchemaEnumType('QType', None, None, None, None,
                                            qtype_values, 'QTYPE'))

    def _make_features(self, features, info):
        if features is None:
            return []
        return [QAPISchemaFeature(f['name'], info, f.get('if'))
                for f in features]

    def _make_enum_members(self, values, info):
        return [QAPISchemaEnumMember(v['name'], info, v.get('if'))
                for v in values]

    def _make_implicit_enum_type(self, name, info, ifcond, values):
        # See also QAPISchemaObjectTypeMember.describe()
        name = name + 'Kind'    # reserved by check_defn_name_str()
        self._def_entity(QAPISchemaEnumType(
            name, info, None, ifcond, None,
            self._make_enum_members(values, info),
            None))
        return name

    def _make_array_type(self, element_type, info):
        name = element_type + 'List'    # reserved by check_defn_name_str()
        if not self.lookup_type(name):
            self._def_entity(QAPISchemaArrayType(name, info, element_type))
        return name

    def _make_implicit_object_type(self, name, info, ifcond, role, members):
        if not members:
            return None
        # See also QAPISchemaObjectTypeMember.describe()
        name = 'q_obj_%s-%s' % (name, role)
        typ = self.lookup_entity(name, QAPISchemaObjectType)
        if typ:
            # The implicit object type has multiple users.  This can
            # happen only for simple unions' implicit wrapper types.
            # Its ifcond should be the disjunction of its user's
            # ifconds.  Not implemented.  Instead, we always pass the
            # wrapped type's ifcond, which is trivially the same for all
            # users.  It's also necessary for the wrapper to compile.
            # But it's not tight: the disjunction need not imply it.  We
            # may end up compiling useless wrapper types.
            # TODO kill simple unions or implement the disjunction

            # pylint: disable=protected-access
            assert (ifcond or []) == typ._ifcond
        else:
            self._def_entity(QAPISchemaObjectType(
                name, info, None, ifcond, None, None, members, None))
        return name

    def _def_enum_type(self, expr, info, doc):
        name = expr['enum']
        data = expr['data']
        prefix = expr.get('prefix')
        ifcond = expr.get('if')
        features = self._make_features(expr.get('features'), info)
        self._def_entity(QAPISchemaEnumType(
            name, info, doc, ifcond, features,
            self._make_enum_members(data, info), prefix))

    def _make_member(self, name, typ, ifcond, features, info):
        optional = False
        if name.startswith('*'):
            name = name[1:]
            optional = True
        if isinstance(typ, list):
            assert len(typ) == 1
            typ = self._make_array_type(typ[0], info)
        return QAPISchemaObjectTypeMember(name, info, typ, optional, ifcond,
                                          self._make_features(features, info))

    def _make_members(self, data, info):
        return [self._make_member(key, value['type'], value.get('if'),
                                  value.get('features'), info)
                for (key, value) in data.items()]

    def _def_struct_type(self, expr, info, doc):
        name = expr['struct']
        base = expr.get('base')
        data = expr['data']
        ifcond = expr.get('if')
        features = self._make_features(expr.get('features'), info)
        self._def_entity(QAPISchemaObjectType(
            name, info, doc, ifcond, features, base,
            self._make_members(data, info),
            None))

    def _make_variant(self, case, typ, ifcond, info):
        return QAPISchemaVariant(case, info, typ, ifcond)

    def _make_simple_variant(self, case, typ, ifcond, info):
        if isinstance(typ, list):
            assert len(typ) == 1
            typ = self._make_array_type(typ[0], info)
        typ = self._make_implicit_object_type(
            typ, info, self.lookup_type(typ),
            'wrapper', [self._make_member('data', typ, None, None, info)])
        return QAPISchemaVariant(case, info, typ, ifcond)

    def _def_union_type(self, expr, info, doc):
        name = expr['union']
        data = expr['data']
        base = expr.get('base')
        ifcond = expr.get('if')
        features = self._make_features(expr.get('features'), info)
        tag_name = expr.get('discriminator')
        tag_member = None
        if isinstance(base, dict):
            base = self._make_implicit_object_type(
                name, info, ifcond,
                'base', self._make_members(base, info))
        if tag_name:
            variants = [self._make_variant(key, value['type'],
                                           value.get('if'), info)
                        for (key, value) in data.items()]
            members = []
        else:
            variants = [self._make_simple_variant(key, value['type'],
                                                  value.get('if'), info)
                        for (key, value) in data.items()]
            enum = [{'name': v.name, 'if': v.ifcond} for v in variants]
            typ = self._make_implicit_enum_type(name, info, ifcond, enum)
            tag_member = QAPISchemaObjectTypeMember('type', info, typ, False)
            members = [tag_member]
        self._def_entity(
            QAPISchemaObjectType(name, info, doc, ifcond, features,
                                 base, members,
                                 QAPISchemaVariants(
                                     tag_name, info, tag_member, variants)))

    def _def_alternate_type(self, expr, info, doc):
        name = expr['alternate']
        data = expr['data']
        ifcond = expr.get('if')
        features = self._make_features(expr.get('features'), info)
        variants = [self._make_variant(key, value['type'], value.get('if'),
                                       info)
                    for (key, value) in data.items()]
        tag_member = QAPISchemaObjectTypeMember('type', info, 'QType', False)
        self._def_entity(
            QAPISchemaAlternateType(name, info, doc, ifcond, features,
                                    QAPISchemaVariants(
                                        None, info, tag_member, variants)))

    def _def_command(self, expr, info, doc):
        name = expr['command']
        data = expr.get('data')
        rets = expr.get('returns')
        gen = expr.get('gen', True)
        success_response = expr.get('success-response', True)
        boxed = expr.get('boxed', False)
        allow_oob = expr.get('allow-oob', False)
        allow_preconfig = expr.get('allow-preconfig', False)
        coroutine = expr.get('coroutine', False)
        ifcond = expr.get('if')
        features = self._make_features(expr.get('features'), info)
        if isinstance(data, OrderedDict):
            data = self._make_implicit_object_type(
                name, info, ifcond,
                'arg', self._make_members(data, info))
        if isinstance(rets, list):
            assert len(rets) == 1
            rets = self._make_array_type(rets[0], info)
        self._def_entity(QAPISchemaCommand(name, info, doc, ifcond, features,
                                           data, rets,
                                           gen, success_response,
                                           boxed, allow_oob, allow_preconfig,
                                           coroutine))

    def _def_event(self, expr, info, doc):
        name = expr['event']
        data = expr.get('data')
        boxed = expr.get('boxed', False)
        ifcond = expr.get('if')
        features = self._make_features(expr.get('features'), info)
        if isinstance(data, OrderedDict):
            data = self._make_implicit_object_type(
                name, info, ifcond,
                'arg', self._make_members(data, info))
        self._def_entity(QAPISchemaEvent(name, info, doc, ifcond, features,
                                         data, boxed))

    def _def_exprs(self, exprs):
        for expr_elem in exprs:
            expr = expr_elem['expr']
            info = expr_elem['info']
            doc = expr_elem.get('doc')
            if 'enum' in expr:
                self._def_enum_type(expr, info, doc)
            elif 'struct' in expr:
                self._def_struct_type(expr, info, doc)
            elif 'union' in expr:
                self._def_union_type(expr, info, doc)
            elif 'alternate' in expr:
                self._def_alternate_type(expr, info, doc)
            elif 'command' in expr:
                self._def_command(expr, info, doc)
            elif 'event' in expr:
                self._def_event(expr, info, doc)
            elif 'include' in expr:
                self._def_include(expr, info, doc)
            else:
                assert False

    def check(self):
        for ent in self._entity_list:
            ent.check(self)
            ent.connect_doc()
            ent.check_doc()
        for ent in self._entity_list:
            ent.set_module(self)

    def visit(self, visitor):
        visitor.visit_begin(self)
        for mod in self._module_dict.values():
            mod.visit(visitor)
        visitor.visit_end()
