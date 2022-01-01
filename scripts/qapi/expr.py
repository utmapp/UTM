# -*- coding: utf-8 -*-
#
# Copyright IBM, Corp. 2011
# Copyright (c) 2013-2021 Red Hat Inc.
#
# Authors:
#  Anthony Liguori <aliguori@us.ibm.com>
#  Markus Armbruster <armbru@redhat.com>
#  Eric Blake <eblake@redhat.com>
#  Marc-André Lureau <marcandre.lureau@redhat.com>
#  John Snow <jsnow@redhat.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.

"""
Normalize and validate (context-free) QAPI schema expression structures.

`QAPISchemaParser` parses a QAPI schema into abstract syntax trees
consisting of dict, list, str, bool, and int nodes.  This module ensures
that these nested structures have the correct type(s) and key(s) where
appropriate for the QAPI context-free grammar.

The QAPI schema expression language allows for certain syntactic sugar;
this module also handles the normalization process of these nested
structures.

See `check_exprs` for the main entry point.

See `schema.QAPISchema` for processing into native Python data
structures and contextual semantic validation.
"""

import re
from typing import (
    Collection,
    Dict,
    Iterable,
    List,
    Optional,
    Union,
    cast,
)

from .common import c_name
from .error import QAPISemError
from .parser import QAPIDoc
from .source import QAPISourceInfo


# Deserialized JSON objects as returned by the parser.
# The values of this mapping are not necessary to exhaustively type
# here (and also not practical as long as mypy lacks recursive
# types), because the purpose of this module is to interrogate that
# type.
_JSONObject = Dict[str, object]


# See check_name_str(), below.
valid_name = re.compile(r'(__[a-z0-9.-]+_)?'
                        r'(x-)?'
                        r'([a-z][a-z0-9_-]*)$', re.IGNORECASE)


def check_name_is_str(name: object,
                      info: QAPISourceInfo,
                      source: str) -> None:
    """
    Ensure that ``name`` is a ``str``.

    :raise QAPISemError: When ``name`` fails validation.
    """
    if not isinstance(name, str):
        raise QAPISemError(info, "%s requires a string name" % source)


def check_name_str(name: str, info: QAPISourceInfo, source: str) -> str:
    """
    Ensure that ``name`` is a valid QAPI name.

    A valid name consists of ASCII letters, digits, ``-``, and ``_``,
    starting with a letter.  It may be prefixed by a downstream prefix
    of the form __RFQDN_, or the experimental prefix ``x-``.  If both
    prefixes are present, the __RFDQN_ prefix goes first.

    A valid name cannot start with ``q_``, which is reserved.

    :param name: Name to check.
    :param info: QAPI schema source file information.
    :param source: Error string describing what ``name`` belongs to.

    :raise QAPISemError: When ``name`` fails validation.
    :return: The stem of the valid name, with no prefixes.
    """
    # Reserve the entire 'q_' namespace for c_name(), and for 'q_empty'
    # and 'q_obj_*' implicit type names.
    match = valid_name.match(name)
    if not match or c_name(name, False).startswith('q_'):
        raise QAPISemError(info, "%s has an invalid name" % source)
    return match.group(3)


def check_name_upper(name: str, info: QAPISourceInfo, source: str) -> None:
    """
    Ensure that ``name`` is a valid event name.

    This means it must be a valid QAPI name as checked by
    `check_name_str()`, but where the stem prohibits lowercase
    characters and ``-``.

    :param name: Name to check.
    :param info: QAPI schema source file information.
    :param source: Error string describing what ``name`` belongs to.

    :raise QAPISemError: When ``name`` fails validation.
    """
    stem = check_name_str(name, info, source)
    if re.search(r'[a-z-]', stem):
        raise QAPISemError(
            info, "name of %s must not use lowercase or '-'" % source)


def check_name_lower(name: str, info: QAPISourceInfo, source: str,
                     permit_upper: bool = False,
                     permit_underscore: bool = False) -> None:
    """
    Ensure that ``name`` is a valid command or member name.

    This means it must be a valid QAPI name as checked by
    `check_name_str()`, but where the stem prohibits uppercase
    characters and ``_``.

    :param name: Name to check.
    :param info: QAPI schema source file information.
    :param source: Error string describing what ``name`` belongs to.
    :param permit_upper: Additionally permit uppercase.
    :param permit_underscore: Additionally permit ``_``.

    :raise QAPISemError: When ``name`` fails validation.
    """
    stem = check_name_str(name, info, source)
    if ((not permit_upper and re.search(r'[A-Z]', stem))
            or (not permit_underscore and '_' in stem)):
        raise QAPISemError(
            info, "name of %s must not use uppercase or '_'" % source)


def check_name_camel(name: str, info: QAPISourceInfo, source: str) -> None:
    """
    Ensure that ``name`` is a valid user-defined type name.

    This means it must be a valid QAPI name as checked by
    `check_name_str()`, but where the stem must be in CamelCase.

    :param name: Name to check.
    :param info: QAPI schema source file information.
    :param source: Error string describing what ``name`` belongs to.

    :raise QAPISemError: When ``name`` fails validation.
    """
    stem = check_name_str(name, info, source)
    if not re.match(r'[A-Z][A-Za-z0-9]*[a-z][A-Za-z0-9]*$', stem):
        raise QAPISemError(info, "name of %s must use CamelCase" % source)


def check_defn_name_str(name: str, info: QAPISourceInfo, meta: str) -> None:
    """
    Ensure that ``name`` is a valid definition name.

    Based on the value of ``meta``, this means that:
      - 'event' names adhere to `check_name_upper()`.
      - 'command' names adhere to `check_name_lower()`.
      - Else, meta is a type, and must pass `check_name_camel()`.
        These names must not end with ``List``.

    :param name: Name to check.
    :param info: QAPI schema source file information.
    :param meta: Meta-type name of the QAPI expression.

    :raise QAPISemError: When ``name`` fails validation.
    """
    if meta == 'event':
        check_name_upper(name, info, meta)
    elif meta == 'command':
        check_name_lower(
            name, info, meta,
            permit_underscore=name in info.pragma.command_name_exceptions)
    else:
        check_name_camel(name, info, meta)
        if name.endswith('List'):
            raise QAPISemError(
                info, "%s name should not end in 'List'" % meta)


def check_keys(value: _JSONObject,
               info: QAPISourceInfo,
               source: str,
               required: Collection[str],
               optional: Collection[str]) -> None:
    """
    Ensure that a dict has a specific set of keys.

    :param value: The dict to check.
    :param info: QAPI schema source file information.
    :param source: Error string describing this ``value``.
    :param required: Keys that *must* be present.
    :param optional: Keys that *may* be present.

    :raise QAPISemError: When unknown keys are present.
    """

    def pprint(elems: Iterable[str]) -> str:
        return ', '.join("'" + e + "'" for e in sorted(elems))

    missing = set(required) - set(value)
    if missing:
        raise QAPISemError(
            info,
            "%s misses key%s %s"
            % (source, 's' if len(missing) > 1 else '',
               pprint(missing)))
    allowed = set(required) | set(optional)
    unknown = set(value) - allowed
    if unknown:
        raise QAPISemError(
            info,
            "%s has unknown key%s %s\nValid keys are %s."
            % (source, 's' if len(unknown) > 1 else '',
               pprint(unknown), pprint(allowed)))


def check_flags(expr: _JSONObject, info: QAPISourceInfo) -> None:
    """
    Ensure flag members (if present) have valid values.

    :param expr: The expression to validate.
    :param info: QAPI schema source file information.

    :raise QAPISemError:
        When certain flags have an invalid value, or when
        incompatible flags are present.
    """
    for key in ('gen', 'success-response'):
        if key in expr and expr[key] is not False:
            raise QAPISemError(
                info, "flag '%s' may only use false value" % key)
    for key in ('boxed', 'allow-oob', 'allow-preconfig', 'coroutine'):
        if key in expr and expr[key] is not True:
            raise QAPISemError(
                info, "flag '%s' may only use true value" % key)
    if 'allow-oob' in expr and 'coroutine' in expr:
        # This is not necessarily a fundamental incompatibility, but
        # we don't have a use case and the desired semantics isn't
        # obvious.  The simplest solution is to forbid it until we get
        # a use case for it.
        raise QAPISemError(info, "flags 'allow-oob' and 'coroutine' "
                                 "are incompatible")


def check_if(expr: _JSONObject, info: QAPISourceInfo, source: str) -> None:
    """
    Validate the ``if`` member of an object.

    The ``if`` member may be either a ``str`` or a dict.

    :param expr: The expression containing the ``if`` member to validate.
    :param info: QAPI schema source file information.
    :param source: Error string describing ``expr``.

    :raise QAPISemError:
        When the "if" member fails validation, or when there are no
        non-empty conditions.
    :return: None
    """

    def _check_if(cond: Union[str, object]) -> None:
        if isinstance(cond, str):
            if not re.fullmatch(r'[A-Z][A-Z0-9_]*', cond):
                raise QAPISemError(
                    info,
                    "'if' condition '%s' of %s is not a valid identifier"
                    % (cond, source))
            return

        if not isinstance(cond, dict):
            raise QAPISemError(
                info,
                "'if' condition of %s must be a string or an object" % source)
        check_keys(cond, info, "'if' condition of %s" % source, [],
                   ["all", "any", "not"])
        if len(cond) != 1:
            raise QAPISemError(
                info,
                "'if' condition of %s has conflicting keys" % source)

        if 'not' in cond:
            _check_if(cond['not'])
        elif 'all' in cond:
            _check_infix('all', cond['all'])
        else:
            _check_infix('any', cond['any'])

    def _check_infix(operator: str, operands: object) -> None:
        if not isinstance(operands, list):
            raise QAPISemError(
                info,
                "'%s' condition of %s must be an array"
                % (operator, source))
        if not operands:
            raise QAPISemError(
                info, "'if' condition [] of %s is useless" % source)
        for operand in operands:
            _check_if(operand)

    ifcond = expr.get('if')
    if ifcond is None:
        return

    _check_if(ifcond)


def normalize_members(members: object) -> None:
    """
    Normalize a "members" value.

    If ``members`` is a dict, for every value in that dict, if that
    value is not itself already a dict, normalize it to
    ``{'type': value}``.

    :forms:
      :sugared: ``Dict[str, Union[str, TypeRef]]``
      :canonical: ``Dict[str, TypeRef]``

    :param members: The members value to normalize.

    :return: None, ``members`` is normalized in-place as needed.
    """
    if isinstance(members, dict):
        for key, arg in members.items():
            if isinstance(arg, dict):
                continue
            members[key] = {'type': arg}


def check_type(value: Optional[object],
               info: QAPISourceInfo,
               source: str,
               allow_array: bool = False,
               allow_dict: Union[bool, str] = False) -> None:
    """
    Normalize and validate the QAPI type of ``value``.

    Python types of ``str`` or ``None`` are always allowed.

    :param value: The value to check.
    :param info: QAPI schema source file information.
    :param source: Error string describing this ``value``.
    :param allow_array:
        Allow a ``List[str]`` of length 1, which indicates an array of
        the type named by the list element.
    :param allow_dict:
        Allow a dict.  Its members can be struct type members or union
        branches.  When the value of ``allow_dict`` is in pragma
        ``member-name-exceptions``, the dict's keys may violate the
        member naming rules.  The dict members are normalized in place.

    :raise QAPISemError: When ``value`` fails validation.
    :return: None, ``value`` is normalized in-place as needed.
    """
    if value is None:
        return

    # Type name
    if isinstance(value, str):
        return

    # Array type
    if isinstance(value, list):
        if not allow_array:
            raise QAPISemError(info, "%s cannot be an array" % source)
        if len(value) != 1 or not isinstance(value[0], str):
            raise QAPISemError(info,
                               "%s: array type must contain single type name" %
                               source)
        return

    # Anonymous type

    if not allow_dict:
        raise QAPISemError(info, "%s should be a type name" % source)

    if not isinstance(value, dict):
        raise QAPISemError(info,
                           "%s should be an object or type name" % source)

    permissive = False
    if isinstance(allow_dict, str):
        permissive = allow_dict in info.pragma.member_name_exceptions

    # value is a dictionary, check that each member is okay
    for (key, arg) in value.items():
        key_source = "%s member '%s'" % (source, key)
        if key.startswith('*'):
            key = key[1:]
        check_name_lower(key, info, key_source,
                         permit_upper=permissive,
                         permit_underscore=permissive)
        if c_name(key, False) == 'u' or c_name(key, False).startswith('has_'):
            raise QAPISemError(info, "%s uses reserved name" % key_source)
        check_keys(arg, info, key_source, ['type'], ['if', 'features'])
        check_if(arg, info, key_source)
        check_features(arg.get('features'), info)
        check_type(arg['type'], info, key_source, allow_array=True)


def check_features(features: Optional[object],
                   info: QAPISourceInfo) -> None:
    """
    Normalize and validate the ``features`` member.

    ``features`` may be a ``list`` of either ``str`` or ``dict``.
    Any ``str`` element will be normalized to ``{'name': element}``.

    :forms:
      :sugared: ``List[Union[str, Feature]]``
      :canonical: ``List[Feature]``

    :param features: The features member value to validate.
    :param info: QAPI schema source file information.

    :raise QAPISemError: When ``features`` fails validation.
    :return: None, ``features`` is normalized in-place as needed.
    """
    if features is None:
        return
    if not isinstance(features, list):
        raise QAPISemError(info, "'features' must be an array")
    features[:] = [f if isinstance(f, dict) else {'name': f}
                   for f in features]
    for feat in features:
        source = "'features' member"
        assert isinstance(feat, dict)
        check_keys(feat, info, source, ['name'], ['if'])
        check_name_is_str(feat['name'], info, source)
        source = "%s '%s'" % (source, feat['name'])
        check_name_str(feat['name'], info, source)
        check_if(feat, info, source)


def check_enum(expr: _JSONObject, info: QAPISourceInfo) -> None:
    """
    Normalize and validate this expression as an ``enum`` definition.

    :param expr: The expression to validate.
    :param info: QAPI schema source file information.

    :raise QAPISemError: When ``expr`` is not a valid ``enum``.
    :return: None, ``expr`` is normalized in-place as needed.
    """
    name = expr['enum']
    members = expr['data']
    prefix = expr.get('prefix')

    if not isinstance(members, list):
        raise QAPISemError(info, "'data' must be an array")
    if prefix is not None and not isinstance(prefix, str):
        raise QAPISemError(info, "'prefix' must be a string")

    permissive = name in info.pragma.member_name_exceptions

    members[:] = [m if isinstance(m, dict) else {'name': m}
                  for m in members]
    for member in members:
        source = "'data' member"
        check_keys(member, info, source, ['name'], ['if', 'features'])
        member_name = member['name']
        check_name_is_str(member_name, info, source)
        source = "%s '%s'" % (source, member_name)
        # Enum members may start with a digit
        if member_name[0].isdigit():
            member_name = 'd' + member_name  # Hack: hide the digit
        check_name_lower(member_name, info, source,
                         permit_upper=permissive,
                         permit_underscore=permissive)
        check_if(member, info, source)
        check_features(member.get('features'), info)


def check_struct(expr: _JSONObject, info: QAPISourceInfo) -> None:
    """
    Normalize and validate this expression as a ``struct`` definition.

    :param expr: The expression to validate.
    :param info: QAPI schema source file information.

    :raise QAPISemError: When ``expr`` is not a valid ``struct``.
    :return: None, ``expr`` is normalized in-place as needed.
    """
    name = cast(str, expr['struct'])  # Checked in check_exprs
    members = expr['data']

    check_type(members, info, "'data'", allow_dict=name)
    check_type(expr.get('base'), info, "'base'")


def check_union(expr: _JSONObject, info: QAPISourceInfo) -> None:
    """
    Normalize and validate this expression as a ``union`` definition.

    :param expr: The expression to validate.
    :param info: QAPI schema source file information.

    :raise QAPISemError: when ``expr`` is not a valid ``union``.
    :return: None, ``expr`` is normalized in-place as needed.
    """
    name = cast(str, expr['union'])  # Checked in check_exprs
    base = expr['base']
    discriminator = expr['discriminator']
    members = expr['data']

    check_type(base, info, "'base'", allow_dict=name)
    check_name_is_str(discriminator, info, "'discriminator'")

    if not isinstance(members, dict):
        raise QAPISemError(info, "'data' must be an object")

    for (key, value) in members.items():
        source = "'data' member '%s'" % key
        check_keys(value, info, source, ['type'], ['if'])
        check_if(value, info, source)
        check_type(value['type'], info, source, allow_array=not base)


def check_alternate(expr: _JSONObject, info: QAPISourceInfo) -> None:
    """
    Normalize and validate this expression as an ``alternate`` definition.

    :param expr: The expression to validate.
    :param info: QAPI schema source file information.

    :raise QAPISemError: When ``expr`` is not a valid ``alternate``.
    :return: None, ``expr`` is normalized in-place as needed.
    """
    members = expr['data']

    if not members:
        raise QAPISemError(info, "'data' must not be empty")

    if not isinstance(members, dict):
        raise QAPISemError(info, "'data' must be an object")

    for (key, value) in members.items():
        source = "'data' member '%s'" % key
        check_name_lower(key, info, source)
        check_keys(value, info, source, ['type'], ['if'])
        check_if(value, info, source)
        check_type(value['type'], info, source)


def check_command(expr: _JSONObject, info: QAPISourceInfo) -> None:
    """
    Normalize and validate this expression as a ``command`` definition.

    :param expr: The expression to validate.
    :param info: QAPI schema source file information.

    :raise QAPISemError: When ``expr`` is not a valid ``command``.
    :return: None, ``expr`` is normalized in-place as needed.
    """
    args = expr.get('data')
    rets = expr.get('returns')
    boxed = expr.get('boxed', False)

    if boxed and args is None:
        raise QAPISemError(info, "'boxed': true requires 'data'")
    check_type(args, info, "'data'", allow_dict=not boxed)
    check_type(rets, info, "'returns'", allow_array=True)


def check_event(expr: _JSONObject, info: QAPISourceInfo) -> None:
    """
    Normalize and validate this expression as an ``event`` definition.

    :param expr: The expression to validate.
    :param info: QAPI schema source file information.

    :raise QAPISemError: When ``expr`` is not a valid ``event``.
    :return: None, ``expr`` is normalized in-place as needed.
    """
    args = expr.get('data')
    boxed = expr.get('boxed', False)

    if boxed and args is None:
        raise QAPISemError(info, "'boxed': true requires 'data'")
    check_type(args, info, "'data'", allow_dict=not boxed)


def check_exprs(exprs: List[_JSONObject]) -> List[_JSONObject]:
    """
    Validate and normalize a list of parsed QAPI schema expressions.

    This function accepts a list of expressions and metadata as returned
    by the parser.  It destructively normalizes the expressions in-place.

    :param exprs: The list of expressions to normalize and validate.

    :raise QAPISemError: When any expression fails validation.
    :return: The same list of expressions (now modified).
    """
    for expr_elem in exprs:
        # Expression
        assert isinstance(expr_elem['expr'], dict)
        for key in expr_elem['expr'].keys():
            assert isinstance(key, str)
        expr: _JSONObject = expr_elem['expr']

        # QAPISourceInfo
        assert isinstance(expr_elem['info'], QAPISourceInfo)
        info: QAPISourceInfo = expr_elem['info']

        # Optional[QAPIDoc]
        tmp = expr_elem.get('doc')
        assert tmp is None or isinstance(tmp, QAPIDoc)
        doc: Optional[QAPIDoc] = tmp

        if 'include' in expr:
            continue

        metas = expr.keys() & {'enum', 'struct', 'union', 'alternate',
                               'command', 'event'}
        if len(metas) != 1:
            raise QAPISemError(
                info,
                "expression must have exactly one key"
                " 'enum', 'struct', 'union', 'alternate',"
                " 'command', 'event'")
        meta = metas.pop()

        check_name_is_str(expr[meta], info, "'%s'" % meta)
        name = cast(str, expr[meta])
        info.set_defn(meta, name)
        check_defn_name_str(name, info, meta)

        if doc:
            if doc.symbol != name:
                raise QAPISemError(
                    info, "documentation comment is for '%s'" % doc.symbol)
            doc.check_expr(expr)
        elif info.pragma.doc_required:
            raise QAPISemError(info,
                               "documentation comment required")

        if meta == 'enum':
            check_keys(expr, info, meta,
                       ['enum', 'data'], ['if', 'features', 'prefix'])
            check_enum(expr, info)
        elif meta == 'union':
            check_keys(expr, info, meta,
                       ['union', 'base', 'discriminator', 'data'],
                       ['if', 'features'])
            normalize_members(expr.get('base'))
            normalize_members(expr['data'])
            check_union(expr, info)
        elif meta == 'alternate':
            check_keys(expr, info, meta,
                       ['alternate', 'data'], ['if', 'features'])
            normalize_members(expr['data'])
            check_alternate(expr, info)
        elif meta == 'struct':
            check_keys(expr, info, meta,
                       ['struct', 'data'], ['base', 'if', 'features'])
            normalize_members(expr['data'])
            check_struct(expr, info)
        elif meta == 'command':
            check_keys(expr, info, meta,
                       ['command'],
                       ['data', 'returns', 'boxed', 'if', 'features',
                        'gen', 'success-response', 'allow-oob',
                        'allow-preconfig', 'coroutine'])
            normalize_members(expr.get('data'))
            check_command(expr, info)
        elif meta == 'event':
            check_keys(expr, info, meta,
                       ['event'], ['data', 'boxed', 'if', 'features'])
            normalize_members(expr.get('data'))
            check_event(expr, info)
        else:
            assert False, 'unexpected meta type'

        check_if(expr, info, meta)
        check_features(expr.get('features'), info)
        check_flags(expr, info)

    return exprs
