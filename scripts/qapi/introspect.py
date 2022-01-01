"""
QAPI introspection generator

Copyright (C) 2015-2021 Red Hat, Inc.

Authors:
 Markus Armbruster <armbru@redhat.com>
 John Snow <jsnow@redhat.com>

This work is licensed under the terms of the GNU GPL, version 2.
See the COPYING file in the top-level directory.
"""

from typing import (
    Any,
    Dict,
    Generic,
    List,
    Optional,
    Sequence,
    TypeVar,
    Union,
)

from .common import c_name, mcgen
from .gen import QAPISchemaMonolithicCVisitor
from .schema import (
    QAPISchema,
    QAPISchemaArrayType,
    QAPISchemaBuiltinType,
    QAPISchemaEntity,
    QAPISchemaEnumMember,
    QAPISchemaFeature,
    QAPISchemaIfCond,
    QAPISchemaObjectType,
    QAPISchemaObjectTypeMember,
    QAPISchemaType,
    QAPISchemaVariant,
    QAPISchemaVariants,
)
from .source import QAPISourceInfo


# This module constructs a tree data structure that is used to
# generate the introspection information for QEMU. It is shaped
# like a JSON value.
#
# A complexity over JSON is that our values may or may not be annotated.
#
# Un-annotated values may be:
#     Scalar: str, bool, None.
#     Non-scalar: List, Dict
# _value = Union[str, bool, None, Dict[str, JSONValue], List[JSONValue]]
#
# With optional annotations, the type of all values is:
# JSONValue = Union[_Value, Annotated[_Value]]
#
# Sadly, mypy does not support recursive types; so the _Stub alias is used to
# mark the imprecision in the type model where we'd otherwise use JSONValue.
_Stub = Any
_Scalar = Union[str, bool, None]
_NonScalar = Union[Dict[str, _Stub], List[_Stub]]
_Value = Union[_Scalar, _NonScalar]
JSONValue = Union[_Value, 'Annotated[_Value]']

# These types are based on structures defined in QEMU's schema, so we
# lack precise types for them here. Python 3.6 does not offer
# TypedDict constructs, so they are broadly typed here as simple
# Python Dicts.
SchemaInfo = Dict[str, object]
SchemaInfoEnumMember = Dict[str, object]
SchemaInfoObject = Dict[str, object]
SchemaInfoObjectVariant = Dict[str, object]
SchemaInfoObjectMember = Dict[str, object]
SchemaInfoCommand = Dict[str, object]


_ValueT = TypeVar('_ValueT', bound=_Value)


class Annotated(Generic[_ValueT]):
    """
    Annotated generally contains a SchemaInfo-like type (as a dict),
    But it also used to wrap comments/ifconds around scalar leaf values,
    for the benefit of features and enums.
    """
    # TODO: Remove after Python 3.7 adds @dataclass:
    # pylint: disable=too-few-public-methods
    def __init__(self, value: _ValueT, ifcond: QAPISchemaIfCond,
                 comment: Optional[str] = None):
        self.value = value
        self.comment: Optional[str] = comment
        self.ifcond = ifcond


def _tree_to_qlit(obj: JSONValue,
                  level: int = 0,
                  dict_value: bool = False) -> str:
    """
    Convert the type tree into a QLIT C string, recursively.

    :param obj: The value to convert.
                This value may not be Annotated when dict_value is True.
    :param level: The indentation level for this particular value.
    :param dict_value: True when the value being processed belongs to a
                       dict key; which suppresses the output indent.
    """

    def indent(level: int) -> str:
        return level * 4 * ' '

    if isinstance(obj, Annotated):
        # NB: _tree_to_qlit is called recursively on the values of a
        # key:value pair; those values can't be decorated with
        # comments or conditionals.
        msg = "dict values cannot have attached comments or if-conditionals."
        assert not dict_value, msg

        ret = ''
        if obj.comment:
            ret += indent(level) + f"/* {obj.comment} */\n"
        if obj.ifcond.is_present():
            ret += obj.ifcond.gen_if()
        ret += _tree_to_qlit(obj.value, level)
        if obj.ifcond.is_present():
            ret += '\n' + obj.ifcond.gen_endif()
        return ret

    ret = ''
    if not dict_value:
        ret += indent(level)

    # Scalars:
    if obj is None:
        ret += 'QLIT_QNULL'
    elif isinstance(obj, str):
        ret += f"QLIT_QSTR({to_c_string(obj)})"
    elif isinstance(obj, bool):
        ret += f"QLIT_QBOOL({str(obj).lower()})"

    # Non-scalars:
    elif isinstance(obj, list):
        ret += 'QLIT_QLIST(((QLitObject[]) {\n'
        for value in obj:
            ret += _tree_to_qlit(value, level + 1).strip('\n') + '\n'
        ret += indent(level + 1) + '{}\n'
        ret += indent(level) + '}))'
    elif isinstance(obj, dict):
        ret += 'QLIT_QDICT(((QLitDictEntry[]) {\n'
        for key, value in sorted(obj.items()):
            ret += indent(level + 1) + "{{ {:s}, {:s} }},\n".format(
                to_c_string(key),
                _tree_to_qlit(value, level + 1, dict_value=True)
            )
        ret += indent(level + 1) + '{}\n'
        ret += indent(level) + '}))'
    else:
        raise NotImplementedError(
            f"type '{type(obj).__name__}' not implemented"
        )

    if level > 0:
        ret += ','
    return ret


def to_c_string(string: str) -> str:
    return '"' + string.replace('\\', r'\\').replace('"', r'\"') + '"'


class QAPISchemaGenIntrospectVisitor(QAPISchemaMonolithicCVisitor):

    def __init__(self, prefix: str, unmask: bool):
        super().__init__(
            prefix, 'qapi-introspect',
            ' * QAPI/QMP schema introspection', __doc__)
        self._unmask = unmask
        self._schema: Optional[QAPISchema] = None
        self._trees: List[Annotated[SchemaInfo]] = []
        self._used_types: List[QAPISchemaType] = []
        self._name_map: Dict[str, str] = {}
        self._genc.add(mcgen('''
#include "qemu/osdep.h"
#include "%(prefix)sqapi-introspect.h"

''',
                             prefix=prefix))

    def visit_begin(self, schema: QAPISchema) -> None:
        self._schema = schema

    def visit_end(self) -> None:
        # visit the types that are actually used
        for typ in self._used_types:
            typ.visit(self)
        # generate C
        name = c_name(self._prefix, protect=False) + 'qmp_schema_qlit'
        self._genh.add(mcgen('''
#include "qapi/qmp/qlit.h"

extern const QLitObject %(c_name)s;
''',
                             c_name=c_name(name)))
        self._genc.add(mcgen('''
const QLitObject %(c_name)s = %(c_string)s;
''',
                             c_name=c_name(name),
                             c_string=_tree_to_qlit(self._trees)))
        self._schema = None
        self._trees = []
        self._used_types = []
        self._name_map = {}

    def visit_needed(self, entity: QAPISchemaEntity) -> bool:
        # Ignore types on first pass; visit_end() will pick up used types
        return not isinstance(entity, QAPISchemaType)

    def _name(self, name: str) -> str:
        if self._unmask:
            return name
        if name not in self._name_map:
            self._name_map[name] = '%d' % len(self._name_map)
        return self._name_map[name]

    def _use_type(self, typ: QAPISchemaType) -> str:
        assert self._schema is not None

        # Map the various integer types to plain int
        if typ.json_type() == 'int':
            typ = self._schema.lookup_type('int')
        elif (isinstance(typ, QAPISchemaArrayType) and
              typ.element_type.json_type() == 'int'):
            typ = self._schema.lookup_type('intList')
        # Add type to work queue if new
        if typ not in self._used_types:
            self._used_types.append(typ)
        # Clients should examine commands and events, not types.  Hide
        # type names as integers to reduce the temptation.  Also, it
        # saves a few characters on the wire.
        if isinstance(typ, QAPISchemaBuiltinType):
            return typ.name
        if isinstance(typ, QAPISchemaArrayType):
            return '[' + self._use_type(typ.element_type) + ']'
        return self._name(typ.name)

    @staticmethod
    def _gen_features(features: Sequence[QAPISchemaFeature]
                      ) -> List[Annotated[str]]:
        return [Annotated(f.name, f.ifcond) for f in features]

    def _gen_tree(self, name: str, mtype: str, obj: Dict[str, object],
                  ifcond: QAPISchemaIfCond = QAPISchemaIfCond(),
                  features: Sequence[QAPISchemaFeature] = ()) -> None:
        """
        Build and append a SchemaInfo object to self._trees.

        :param name: The SchemaInfo's name.
        :param mtype: The SchemaInfo's meta-type.
        :param obj: Additional SchemaInfo members, as appropriate for
                    the meta-type.
        :param ifcond: Conditionals to apply to the SchemaInfo.
        :param features: The SchemaInfo's features.
                         Will be omitted from the output if empty.
        """
        comment: Optional[str] = None
        if mtype not in ('command', 'event', 'builtin', 'array'):
            if not self._unmask:
                # Output a comment to make it easy to map masked names
                # back to the source when reading the generated output.
                comment = f'"{self._name(name)}" = {name}'
            name = self._name(name)
        obj['name'] = name
        obj['meta-type'] = mtype
        if features:
            obj['features'] = self._gen_features(features)
        self._trees.append(Annotated(obj, ifcond, comment))

    def _gen_enum_member(self, member: QAPISchemaEnumMember
                         ) -> Annotated[SchemaInfoEnumMember]:
        obj: SchemaInfoEnumMember = {
            'name': member.name,
        }
        if member.features:
            obj['features'] = self._gen_features(member.features)
        return Annotated(obj, member.ifcond)

    def _gen_object_member(self, member: QAPISchemaObjectTypeMember
                           ) -> Annotated[SchemaInfoObjectMember]:
        obj: SchemaInfoObjectMember = {
            'name': member.name,
            'type': self._use_type(member.type)
        }
        if member.optional:
            obj['default'] = None
        if member.features:
            obj['features'] = self._gen_features(member.features)
        return Annotated(obj, member.ifcond)

    def _gen_variant(self, variant: QAPISchemaVariant
                     ) -> Annotated[SchemaInfoObjectVariant]:
        obj: SchemaInfoObjectVariant = {
            'case': variant.name,
            'type': self._use_type(variant.type)
        }
        return Annotated(obj, variant.ifcond)

    def visit_builtin_type(self, name: str, info: Optional[QAPISourceInfo],
                           json_type: str) -> None:
        self._gen_tree(name, 'builtin', {'json-type': json_type})

    def visit_enum_type(self, name: str, info: Optional[QAPISourceInfo],
                        ifcond: QAPISchemaIfCond,
                        features: List[QAPISchemaFeature],
                        members: List[QAPISchemaEnumMember],
                        prefix: Optional[str]) -> None:
        self._gen_tree(
            name, 'enum',
            {'members': [self._gen_enum_member(m) for m in members],
             'values': [Annotated(m.name, m.ifcond) for m in members]},
            ifcond, features
        )

    def visit_array_type(self, name: str, info: Optional[QAPISourceInfo],
                         ifcond: QAPISchemaIfCond,
                         element_type: QAPISchemaType) -> None:
        element = self._use_type(element_type)
        self._gen_tree('[' + element + ']', 'array', {'element-type': element},
                       ifcond)

    def visit_object_type_flat(self, name: str, info: Optional[QAPISourceInfo],
                               ifcond: QAPISchemaIfCond,
                               features: List[QAPISchemaFeature],
                               members: List[QAPISchemaObjectTypeMember],
                               variants: Optional[QAPISchemaVariants]) -> None:
        obj: SchemaInfoObject = {
            'members': [self._gen_object_member(m) for m in members]
        }
        if variants:
            obj['tag'] = variants.tag_member.name
            obj['variants'] = [self._gen_variant(v) for v in variants.variants]
        self._gen_tree(name, 'object', obj, ifcond, features)

    def visit_alternate_type(self, name: str, info: Optional[QAPISourceInfo],
                             ifcond: QAPISchemaIfCond,
                             features: List[QAPISchemaFeature],
                             variants: QAPISchemaVariants) -> None:
        self._gen_tree(
            name, 'alternate',
            {'members': [Annotated({'type': self._use_type(m.type)},
                                   m.ifcond)
                         for m in variants.variants]},
            ifcond, features
        )

    def visit_command(self, name: str, info: Optional[QAPISourceInfo],
                      ifcond: QAPISchemaIfCond,
                      features: List[QAPISchemaFeature],
                      arg_type: Optional[QAPISchemaObjectType],
                      ret_type: Optional[QAPISchemaType], gen: bool,
                      success_response: bool, boxed: bool, allow_oob: bool,
                      allow_preconfig: bool, coroutine: bool) -> None:
        assert self._schema is not None

        arg_type = arg_type or self._schema.the_empty_object_type
        ret_type = ret_type or self._schema.the_empty_object_type
        obj: SchemaInfoCommand = {
            'arg-type': self._use_type(arg_type),
            'ret-type': self._use_type(ret_type)
        }
        if allow_oob:
            obj['allow-oob'] = allow_oob
        self._gen_tree(name, 'command', obj, ifcond, features)

    def visit_event(self, name: str, info: Optional[QAPISourceInfo],
                    ifcond: QAPISchemaIfCond,
                    features: List[QAPISchemaFeature],
                    arg_type: Optional[QAPISchemaObjectType],
                    boxed: bool) -> None:
        assert self._schema is not None

        arg_type = arg_type or self._schema.the_empty_object_type
        self._gen_tree(name, 'event', {'arg-type': self._use_type(arg_type)},
                       ifcond, features)


def gen_introspect(schema: QAPISchema, output_dir: str, prefix: str,
                   opt_unmask: bool) -> None:
    vis = QAPISchemaGenIntrospectVisitor(prefix, opt_unmask)
    schema.visit(vis)
    vis.write(output_dir)
