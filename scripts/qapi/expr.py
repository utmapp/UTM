# -*- coding: utf-8 -*-
#
# Check (context-free) QAPI schema expression structure
#
# Copyright IBM, Corp. 2011
# Copyright (c) 2013-2019 Red Hat Inc.
#
# Authors:
#  Anthony Liguori <aliguori@us.ibm.com>
#  Markus Armbruster <armbru@redhat.com>
#  Eric Blake <eblake@redhat.com>
#  Marc-André Lureau <marcandre.lureau@redhat.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.

from collections import OrderedDict
import re

from .common import c_name
from .error import QAPISemError


# Names consist of letters, digits, -, and _, starting with a letter.
# An experimental name is prefixed with x-.  A name of a downstream
# extension is prefixed with __RFQDN_.  The latter prefix goes first.
valid_name = re.compile(r'(__[a-z0-9.-]+_)?'
                        r'(x-)?'
                        r'([a-z][a-z0-9_-]*)$', re.IGNORECASE)


def check_name_is_str(name, info, source):
    if not isinstance(name, str):
        raise QAPISemError(info, "%s requires a string name" % source)


def check_name_str(name, info, source):
    # Reserve the entire 'q_' namespace for c_name(), and for 'q_empty'
    # and 'q_obj_*' implicit type names.
    match = valid_name.match(name)
    if not match or c_name(name, False).startswith('q_'):
        raise QAPISemError(info, "%s has an invalid name" % source)
    return match.group(3)


def check_name_upper(name, info, source):
    stem = check_name_str(name, info, source)
    if re.search(r'[a-z-]', stem):
        raise QAPISemError(
            info, "name of %s must not use lowercase or '-'" % source)


def check_name_lower(name, info, source,
                     permit_upper=False,
                     permit_underscore=False):
    stem = check_name_str(name, info, source)
    if ((not permit_upper and re.search(r'[A-Z]', stem))
            or (not permit_underscore and '_' in stem)):
        raise QAPISemError(
            info, "name of %s must not use uppercase or '_'" % source)


def check_name_camel(name, info, source):
    stem = check_name_str(name, info, source)
    if not re.match(r'[A-Z][A-Za-z0-9]*[a-z][A-Za-z0-9]*$', stem):
        raise QAPISemError(info, "name of %s must use CamelCase" % source)


def check_defn_name_str(name, info, meta):
    if meta == 'event':
        check_name_upper(name, info, meta)
    elif meta == 'command':
        check_name_lower(
            name, info, meta,
            permit_underscore=name in info.pragma.command_name_exceptions)
    else:
        check_name_camel(name, info, meta)
    if name.endswith('Kind') or name.endswith('List'):
        raise QAPISemError(
            info, "%s name should not end in '%s'" % (meta, name[-4:]))


def check_keys(value, info, source, required, optional):

    def pprint(elems):
        return ', '.join("'" + e + "'" for e in sorted(elems))

    missing = set(required) - set(value)
    if missing:
        raise QAPISemError(
            info,
            "%s misses key%s %s"
            % (source, 's' if len(missing) > 1 else '',
               pprint(missing)))
    allowed = set(required + optional)
    unknown = set(value) - allowed
    if unknown:
        raise QAPISemError(
            info,
            "%s has unknown key%s %s\nValid keys are %s."
            % (source, 's' if len(unknown) > 1 else '',
               pprint(unknown), pprint(allowed)))


def check_flags(expr, info):
    for key in ['gen', 'success-response']:
        if key in expr and expr[key] is not False:
            raise QAPISemError(
                info, "flag '%s' may only use false value" % key)
    for key in ['boxed', 'allow-oob', 'allow-preconfig', 'coroutine']:
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


def check_if(expr, info, source):

    def check_if_str(ifcond, info):
        if not isinstance(ifcond, str):
            raise QAPISemError(
                info,
                "'if' condition of %s must be a string or a list of strings"
                % source)
        if ifcond.strip() == '':
            raise QAPISemError(
                info,
                "'if' condition '%s' of %s makes no sense"
                % (ifcond, source))

    ifcond = expr.get('if')
    if ifcond is None:
        return
    if isinstance(ifcond, list):
        if ifcond == []:
            raise QAPISemError(
                info, "'if' condition [] of %s is useless" % source)
        for elt in ifcond:
            check_if_str(elt, info)
    else:
        check_if_str(ifcond, info)
        expr['if'] = [ifcond]


def normalize_members(members):
    if isinstance(members, OrderedDict):
        for key, arg in members.items():
            if isinstance(arg, dict):
                continue
            members[key] = {'type': arg}


def check_type(value, info, source,
               allow_array=False, allow_dict=False):
    if value is None:
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

    # Type name
    if isinstance(value, str):
        return

    # Anonymous type

    if not allow_dict:
        raise QAPISemError(info, "%s should be a type name" % source)

    if not isinstance(value, OrderedDict):
        raise QAPISemError(info,
                           "%s should be an object or type name" % source)

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


def check_features(features, info):
    if features is None:
        return
    if not isinstance(features, list):
        raise QAPISemError(info, "'features' must be an array")
    features[:] = [f if isinstance(f, dict) else {'name': f}
                   for f in features]
    for f in features:
        source = "'features' member"
        assert isinstance(f, dict)
        check_keys(f, info, source, ['name'], ['if'])
        check_name_is_str(f['name'], info, source)
        source = "%s '%s'" % (source, f['name'])
        check_name_lower(f['name'], info, source)
        check_if(f, info, source)


def check_enum(expr, info):
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
        member_name = member['name']
        check_keys(member, info, source, ['name'], ['if'])
        check_name_is_str(member_name, info, source)
        source = "%s '%s'" % (source, member_name)
        # Enum members may start with a digit
        if member_name[0].isdigit():
            member_name = 'd' + member_name # Hack: hide the digit
        check_name_lower(member_name, info, source,
                         permit_upper=permissive,
                         permit_underscore=permissive)
        check_if(member, info, source)


def check_struct(expr, info):
    name = expr['struct']
    members = expr['data']

    check_type(members, info, "'data'", allow_dict=name)
    check_type(expr.get('base'), info, "'base'")


def check_union(expr, info):
    name = expr['union']
    base = expr.get('base')
    discriminator = expr.get('discriminator')
    members = expr['data']

    if discriminator is None:   # simple union
        if base is not None:
            raise QAPISemError(info, "'base' requires 'discriminator'")
    else:                       # flat union
        check_type(base, info, "'base'", allow_dict=name)
        if not base:
            raise QAPISemError(info, "'discriminator' requires 'base'")
        check_name_is_str(discriminator, info, "'discriminator'")

    for (key, value) in members.items():
        source = "'data' member '%s'" % key
        if discriminator is None:
            check_name_lower(key, info, source)
        # else: name is in discriminator enum, which gets checked
        check_keys(value, info, source, ['type'], ['if'])
        check_if(value, info, source)
        check_type(value['type'], info, source, allow_array=not base)


def check_alternate(expr, info):
    members = expr['data']

    if not members:
        raise QAPISemError(info, "'data' must not be empty")
    for (key, value) in members.items():
        source = "'data' member '%s'" % key
        check_name_lower(key, info, source)
        check_keys(value, info, source, ['type'], ['if'])
        check_if(value, info, source)
        check_type(value['type'], info, source)


def check_command(expr, info):
    args = expr.get('data')
    rets = expr.get('returns')
    boxed = expr.get('boxed', False)

    if boxed and args is None:
        raise QAPISemError(info, "'boxed': true requires 'data'")
    check_type(args, info, "'data'", allow_dict=not boxed)
    check_type(rets, info, "'returns'", allow_array=True)


def check_event(expr, info):
    args = expr.get('data')
    boxed = expr.get('boxed', False)

    if boxed and args is None:
        raise QAPISemError(info, "'boxed': true requires 'data'")
    check_type(args, info, "'data'", allow_dict=not boxed)


def check_exprs(exprs):
    for expr_elem in exprs:
        expr = expr_elem['expr']
        info = expr_elem['info']
        doc = expr_elem.get('doc')

        if 'include' in expr:
            continue

        if 'enum' in expr:
            meta = 'enum'
        elif 'union' in expr:
            meta = 'union'
        elif 'alternate' in expr:
            meta = 'alternate'
        elif 'struct' in expr:
            meta = 'struct'
        elif 'command' in expr:
            meta = 'command'
        elif 'event' in expr:
            meta = 'event'
        else:
            raise QAPISemError(info, "expression is missing metatype")

        name = expr[meta]
        check_name_is_str(name, info, "'%s'" % meta)
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
                       ['union', 'data'],
                       ['base', 'discriminator', 'if', 'features'])
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
