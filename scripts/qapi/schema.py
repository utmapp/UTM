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

import os
import re
from collections import OrderedDict

from qapi.common import c_name, pointer_suffix
from qapi.error import QAPIError, QAPIParseError, QAPISemError
from qapi.expr import check_exprs
from qapi.parser import QAPISchemaParser


class QAPISchemaEntity(object):
    meta = None

    def __init__(self, name, info, doc, ifcond=None, features=None):
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
        if self.info:
            self._module = os.path.relpath(self.info.fname,
                                           os.path.dirname(schema.fname))
        seen = {}
        for f in self.features:
            f.check_clash(self.info, seen)
            if self.doc:
                self.doc.connect_feature(f)

        self._checked = True

    def connect_doc(self, doc=None):
        pass

    def check_doc(self):
        if self.doc:
            self.doc.check()

    @property
    def ifcond(self):
        assert self._checked
        return self._ifcond

    @property
    def module(self):
        assert self._checked
        return self._module

    def is_implicit(self):
        return not self.info

    def visit(self, visitor):
        assert self._checked

    def describe(self):
        assert self.meta
        return "%s '%s'" % (self.meta, self.name)


class QAPISchemaVisitor(object):
    def visit_begin(self, schema):
        pass

    def visit_end(self):
        pass

    def visit_module(self, fname):
        pass

    def visit_needed(self, entity):
        # Default to visiting everything
        return True

    def visit_include(self, fname, info):
        pass

    def visit_builtin_type(self, name, info, json_type):
        pass

    def visit_enum_type(self, name, info, ifcond, members, prefix):
        pass

    def visit_array_type(self, name, info, ifcond, element_type):
        pass

    def visit_object_type(self, name, info, ifcond, base, members, variants,
                          features):
        pass

    def visit_object_type_flat(self, name, info, ifcond, members, variants,
                               features):
        pass

    def visit_alternate_type(self, name, info, ifcond, variants):
        pass

    def visit_command(self, name, info, ifcond, arg_type, ret_type, gen,
                      success_response, boxed, allow_oob, allow_preconfig,
                      features):
        pass

    def visit_event(self, name, info, ifcond, arg_type, boxed):
        pass


class QAPISchemaInclude(QAPISchemaEntity):

    def __init__(self, fname, info):
        QAPISchemaEntity.__init__(self, None, info, None)
        self.fname = fname

    def visit(self, visitor):
        QAPISchemaEntity.visit(self, visitor)
        visitor.visit_include(self.fname, self.info)


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

    def describe(self):
        assert self.meta
        return "%s type '%s'" % (self.meta, self.name)


class QAPISchemaBuiltinType(QAPISchemaType):
    meta = 'built-in'

    def __init__(self, name, json_type, c_type):
        QAPISchemaType.__init__(self, name, None, None)
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
        QAPISchemaType.visit(self, visitor)
        visitor.visit_builtin_type(self.name, self.info, self.json_type())


class QAPISchemaEnumType(QAPISchemaType):
    meta = 'enum'

    def __init__(self, name, info, doc, ifcond, members, prefix):
        QAPISchemaType.__init__(self, name, info, doc, ifcond)
        for m in members:
            assert isinstance(m, QAPISchemaEnumMember)
            m.set_defined_in(name)
        assert prefix is None or isinstance(prefix, str)
        self.members = members
        self.prefix = prefix

    def check(self, schema):
        QAPISchemaType.check(self, schema)
        seen = {}
        for m in self.members:
            m.check_clash(self.info, seen)

    def connect_doc(self, doc=None):
        doc = doc or self.doc
        if doc:
            for m in self.members:
                doc.connect_member(m)

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
        QAPISchemaType.visit(self, visitor)
        visitor.visit_enum_type(self.name, self.info, self.ifcond,
                                self.members, self.prefix)


class QAPISchemaArrayType(QAPISchemaType):
    meta = 'array'

    def __init__(self, name, info, element_type):
        QAPISchemaType.__init__(self, name, info, None, None)
        assert isinstance(element_type, str)
        self._element_type_name = element_type
        self.element_type = None

    def check(self, schema):
        QAPISchemaType.check(self, schema)
        self.element_type = schema.resolve_type(
            self._element_type_name, self.info,
            self.info and self.info.defn_meta)
        assert not isinstance(self.element_type, QAPISchemaArrayType)

    @property
    def ifcond(self):
        assert self._checked
        return self.element_type.ifcond

    @property
    def module(self):
        assert self._checked
        return self.element_type.module

    def is_implicit(self):
        return True

    def c_type(self):
        return c_name(self.name) + pointer_suffix

    def json_type(self):
        return 'array'

    def doc_type(self):
        elt_doc_type = self.element_type.doc_type()
        if not elt_doc_type:
            return None
        return 'array of ' + elt_doc_type

    def visit(self, visitor):
        QAPISchemaType.visit(self, visitor)
        visitor.visit_array_type(self.name, self.info, self.ifcond,
                                 self.element_type)

    def describe(self):
        assert self.meta
        return "%s type ['%s']" % (self.meta, self._element_type_name)


class QAPISchemaObjectType(QAPISchemaType):
    def __init__(self, name, info, doc, ifcond,
                 base, local_members, variants, features):
        # struct has local_members, optional base, and no variants
        # flat union has base, variants, and no local_members
        # simple union has local_members, variants, and no base
        QAPISchemaType.__init__(self, name, info, doc, ifcond, features)
        self.meta = 'union' if variants else 'struct'
        assert base is None or isinstance(base, str)
        for m in local_members:
            assert isinstance(m, QAPISchemaObjectTypeMember)
            m.set_defined_in(name)
        if variants is not None:
            assert isinstance(variants, QAPISchemaObjectTypeVariants)
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

        QAPISchemaType.check(self, schema)
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
        doc = doc or self.doc
        if doc:
            if self.base and self.base.is_implicit():
                self.base.connect_doc(doc)
            for m in self.local_members:
                doc.connect_member(m)

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
        return QAPISchemaType.c_name(self)

    def c_type(self):
        assert not self.is_implicit()
        return c_name(self.name) + pointer_suffix

    def c_unboxed_type(self):
        return c_name(self.name)

    def json_type(self):
        return 'object'

    def visit(self, visitor):
        QAPISchemaType.visit(self, visitor)
        visitor.visit_object_type(self.name, self.info, self.ifcond,
                                  self.base, self.local_members, self.variants,
                                  self.features)
        visitor.visit_object_type_flat(self.name, self.info, self.ifcond,
                                       self.members, self.variants,
                                       self.features)


class QAPISchemaMember(object):
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
    def __init__(self, name, info, typ, optional, ifcond=None):
        QAPISchemaMember.__init__(self, name, info, ifcond)
        assert isinstance(typ, str)
        assert isinstance(optional, bool)
        self._type_name = typ
        self.type = None
        self.optional = optional

    def check(self, schema):
        assert self.defined_in
        self.type = schema.resolve_type(self._type_name, self.info,
                                        self.describe)


class QAPISchemaObjectTypeVariants(object):
    def __init__(self, tag_name, info, tag_member, variants):
        # Flat unions pass tag_name but not tag_member.
        # Simple unions and alternates pass tag_member but not tag_name.
        # After check(), tag_member is always set, and tag_name remains
        # a reliable witness of being used by a flat union.
        assert bool(tag_member) != bool(tag_name)
        assert (isinstance(tag_name, str) or
                isinstance(tag_member, QAPISchemaObjectTypeMember))
        for v in variants:
            assert isinstance(v, QAPISchemaObjectTypeVariant)
        self._tag_name = tag_name
        self.info = info
        self.tag_member = tag_member
        self.variants = variants

    def set_defined_in(self, name):
        for v in self.variants:
            v.set_defined_in(name)

    def check(self, schema, seen):
        if not self.tag_member: # flat union
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
            cases = set([v.name for v in self.variants])
            for m in self.tag_member.type.members:
                if m.name not in cases:
                    v = QAPISchemaObjectTypeVariant(m.name, self.info,
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


class QAPISchemaObjectTypeVariant(QAPISchemaObjectTypeMember):
    role = 'branch'

    def __init__(self, name, info, typ, ifcond=None):
        QAPISchemaObjectTypeMember.__init__(self, name, info, typ,
                                            False, ifcond)


class QAPISchemaAlternateType(QAPISchemaType):
    meta = 'alternate'

    def __init__(self, name, info, doc, ifcond, variants):
        QAPISchemaType.__init__(self, name, info, doc, ifcond)
        assert isinstance(variants, QAPISchemaObjectTypeVariants)
        assert variants.tag_member
        variants.set_defined_in(name)
        variants.tag_member.set_defined_in(self.name)
        self.variants = variants

    def check(self, schema):
        QAPISchemaType.check(self, schema)
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
        doc = doc or self.doc
        if doc:
            for v in self.variants.variants:
                doc.connect_member(v)

    def c_type(self):
        return c_name(self.name) + pointer_suffix

    def json_type(self):
        return 'value'

    def visit(self, visitor):
        QAPISchemaType.visit(self, visitor)
        visitor.visit_alternate_type(self.name, self.info, self.ifcond,
                                     self.variants)


class QAPISchemaCommand(QAPISchemaEntity):
    meta = 'command'

    def __init__(self, name, info, doc, ifcond, arg_type, ret_type,
                 gen, success_response, boxed, allow_oob, allow_preconfig,
                 features):
        QAPISchemaEntity.__init__(self, name, info, doc, ifcond, features)
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

    def check(self, schema):
        QAPISchemaEntity.check(self, schema)
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
            if self.name not in self.info.pragma.returns_whitelist:
                if not (isinstance(self.ret_type, QAPISchemaObjectType)
                        or (isinstance(self.ret_type, QAPISchemaArrayType)
                            and isinstance(self.ret_type.element_type,
                                           QAPISchemaObjectType))):
                    raise QAPISemError(
                        self.info,
                        "command's 'returns' cannot take %s"
                        % self.ret_type.describe())

    def connect_doc(self, doc=None):
        doc = doc or self.doc
        if doc:
            if self.arg_type and self.arg_type.is_implicit():
                self.arg_type.connect_doc(doc)

    def visit(self, visitor):
        QAPISchemaEntity.visit(self, visitor)
        visitor.visit_command(self.name, self.info, self.ifcond,
                              self.arg_type, self.ret_type,
                              self.gen, self.success_response,
                              self.boxed, self.allow_oob,
                              self.allow_preconfig,
                              self.features)


class QAPISchemaEvent(QAPISchemaEntity):
    meta = 'event'

    def __init__(self, name, info, doc, ifcond, arg_type, boxed):
        QAPISchemaEntity.__init__(self, name, info, doc, ifcond)
        assert not arg_type or isinstance(arg_type, str)
        self._arg_type_name = arg_type
        self.arg_type = None
        self.boxed = boxed

    def check(self, schema):
        QAPISchemaEntity.check(self, schema)
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
        doc = doc or self.doc
        if doc:
            if self.arg_type and self.arg_type.is_implicit():
                self.arg_type.connect_doc(doc)

    def visit(self, visitor):
        QAPISchemaEntity.visit(self, visitor)
        visitor.visit_event(self.name, self.info, self.ifcond,
                            self.arg_type, self.boxed)


class QAPISchema(object):
    def __init__(self, fname):
        self.fname = fname
        parser = QAPISchemaParser(fname)
        exprs = check_exprs(parser.exprs)
        self.docs = parser.docs
        self._entity_list = []
        self._entity_dict = {}
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

    def _def_include(self, expr, info, doc):
        include = expr['include']
        assert doc is None
        main_info = info
        while main_info.parent:
            main_info = main_info.parent
        fname = os.path.relpath(include, os.path.dirname(main_info.fname))
        self._def_entity(QAPISchemaInclude(fname, info))

    def _def_builtin_type(self, name, json_type, c_type):
        self._def_entity(QAPISchemaBuiltinType(name, json_type, c_type))
        # Instantiating only the arrays that are actually used would
        # be nice, but we can't as long as their generated code
        # (qapi-builtin-types.[ch]) may be shared by some other
        # schema.
        self._make_array_type(name, None)

    def _def_predefineds(self):
        for t in [('str',    'string',  'char' + pointer_suffix),
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
            'q_empty', None, None, None, None, [], None, [])
        self._def_entity(self.the_empty_object_type)

        qtypes = ['none', 'qnull', 'qnum', 'qstring', 'qdict', 'qlist',
                  'qbool']
        qtype_values = self._make_enum_members(
            [{'name': n} for n in qtypes], None)

        self._def_entity(QAPISchemaEnumType('QType', None, None, None,
                                            qtype_values, 'QTYPE'))

    def _make_features(self, features, info):
        return [QAPISchemaFeature(f['name'], info, f.get('if'))
                for f in features]

    def _make_enum_members(self, values, info):
        return [QAPISchemaEnumMember(v['name'], info, v.get('if'))
                for v in values]

    def _make_implicit_enum_type(self, name, info, ifcond, values):
        # See also QAPISchemaObjectTypeMember.describe()
        name = name + 'Kind'    # reserved by check_defn_name_str()
        self._def_entity(QAPISchemaEnumType(
            name, info, None, ifcond, self._make_enum_members(values, info),
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
            assert (ifcond or []) == typ._ifcond # pylint: disable=protected-access
        else:
            self._def_entity(QAPISchemaObjectType(name, info, None, ifcond,
                                                  None, members, None, []))
        return name

    def _def_enum_type(self, expr, info, doc):
        name = expr['enum']
        data = expr['data']
        prefix = expr.get('prefix')
        ifcond = expr.get('if')
        self._def_entity(QAPISchemaEnumType(
            name, info, doc, ifcond,
            self._make_enum_members(data, info), prefix))

    def _make_member(self, name, typ, ifcond, info):
        optional = False
        if name.startswith('*'):
            name = name[1:]
            optional = True
        if isinstance(typ, list):
            assert len(typ) == 1
            typ = self._make_array_type(typ[0], info)
        return QAPISchemaObjectTypeMember(name, info, typ, optional, ifcond)

    def _make_members(self, data, info):
        return [self._make_member(key, value['type'], value.get('if'), info)
                for (key, value) in data.items()]

    def _def_struct_type(self, expr, info, doc):
        name = expr['struct']
        base = expr.get('base')
        data = expr['data']
        ifcond = expr.get('if')
        features = expr.get('features', [])
        self._def_entity(QAPISchemaObjectType(
            name, info, doc, ifcond, base,
            self._make_members(data, info),
            None,
            self._make_features(features, info)))

    def _make_variant(self, case, typ, ifcond, info):
        return QAPISchemaObjectTypeVariant(case, info, typ, ifcond)

    def _make_simple_variant(self, case, typ, ifcond, info):
        if isinstance(typ, list):
            assert len(typ) == 1
            typ = self._make_array_type(typ[0], info)
        typ = self._make_implicit_object_type(
            typ, info, self.lookup_type(typ),
            'wrapper', [self._make_member('data', typ, None, info)])
        return QAPISchemaObjectTypeVariant(case, info, typ, ifcond)

    def _def_union_type(self, expr, info, doc):
        name = expr['union']
        data = expr['data']
        base = expr.get('base')
        ifcond = expr.get('if')
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
            QAPISchemaObjectType(name, info, doc, ifcond, base, members,
                                 QAPISchemaObjectTypeVariants(
                                     tag_name, info, tag_member, variants),
                                 []))

    def _def_alternate_type(self, expr, info, doc):
        name = expr['alternate']
        data = expr['data']
        ifcond = expr.get('if')
        variants = [self._make_variant(key, value['type'], value.get('if'),
                                       info)
                    for (key, value) in data.items()]
        tag_member = QAPISchemaObjectTypeMember('type', info, 'QType', False)
        self._def_entity(
            QAPISchemaAlternateType(name, info, doc, ifcond,
                                    QAPISchemaObjectTypeVariants(
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
        ifcond = expr.get('if')
        features = expr.get('features', [])
        if isinstance(data, OrderedDict):
            data = self._make_implicit_object_type(
                name, info, ifcond, 'arg', self._make_members(data, info))
        if isinstance(rets, list):
            assert len(rets) == 1
            rets = self._make_array_type(rets[0], info)
        self._def_entity(QAPISchemaCommand(name, info, doc, ifcond, data, rets,
                                           gen, success_response,
                                           boxed, allow_oob, allow_preconfig,
                                           self._make_features(features, info)))

    def _def_event(self, expr, info, doc):
        name = expr['event']
        data = expr.get('data')
        boxed = expr.get('boxed', False)
        ifcond = expr.get('if')
        if isinstance(data, OrderedDict):
            data = self._make_implicit_object_type(
                name, info, ifcond, 'arg', self._make_members(data, info))
        self._def_entity(QAPISchemaEvent(name, info, doc, ifcond, data, boxed))

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

    def visit(self, visitor):
        visitor.visit_begin(self)
        module = None
        visitor.visit_module(module)
        for entity in self._entity_list:
            if visitor.visit_needed(entity):
                if entity.module != module:
                    module = entity.module
                    visitor.visit_module(module)
                entity.visit(visitor)
        visitor.visit_end()
