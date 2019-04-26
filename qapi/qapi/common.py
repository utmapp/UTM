#
# QAPI helper library
#
# Copyright IBM, Corp. 2011
# Copyright (c) 2013-2018 Red Hat Inc.
#
# Authors:
#  Anthony Liguori <aliguori@us.ibm.com>
#  Markus Armbruster <armbru@redhat.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.

from __future__ import print_function
from contextlib import contextmanager
import errno
import os
import re
import string
import sys
from collections import OrderedDict

builtin_types = {
    'null':     'QTYPE_QNULL',
    'str':      'QTYPE_QSTRING',
    'int':      'QTYPE_QNUM',
    'number':   'QTYPE_QNUM',
    'bool':     'QTYPE_QBOOL',
    'int8':     'QTYPE_QNUM',
    'int16':    'QTYPE_QNUM',
    'int32':    'QTYPE_QNUM',
    'int64':    'QTYPE_QNUM',
    'uint8':    'QTYPE_QNUM',
    'uint16':   'QTYPE_QNUM',
    'uint32':   'QTYPE_QNUM',
    'uint64':   'QTYPE_QNUM',
    'size':     'QTYPE_QNUM',
    'any':      None,           # any QType possible, actually
    'QType':    'QTYPE_QSTRING',
}

# Are documentation comments required?
doc_required = False

# Whitelist of commands allowed to return a non-dictionary
returns_whitelist = []

# Whitelist of entities allowed to violate case conventions
name_case_whitelist = []

enum_types = {}
struct_types = {}
union_types = {}
all_names = {}

#
# Parsing the schema into expressions
#


def error_path(parent):
    res = ''
    while parent:
        res = ('In file included from %s:%d:\n' % (parent['file'],
                                                   parent['line'])) + res
        parent = parent['parent']
    return res


class QAPIError(Exception):
    def __init__(self, fname, line, col, incl_info, msg):
        Exception.__init__(self)
        self.fname = fname
        self.line = line
        self.col = col
        self.info = incl_info
        self.msg = msg

    def __str__(self):
        loc = '%s:%d' % (self.fname, self.line)
        if self.col is not None:
            loc += ':%s' % self.col
        return error_path(self.info) + '%s: %s' % (loc, self.msg)


class QAPIParseError(QAPIError):
    def __init__(self, parser, msg):
        col = 1
        for ch in parser.src[parser.line_pos:parser.pos]:
            if ch == '\t':
                col = (col + 7) % 8 + 1
            else:
                col += 1
        QAPIError.__init__(self, parser.fname, parser.line, col,
                           parser.incl_info, msg)


class QAPISemError(QAPIError):
    def __init__(self, info, msg):
        QAPIError.__init__(self, info['file'], info['line'], None,
                           info['parent'], msg)


class QAPIDoc(object):
    class Section(object):
        def __init__(self, name=None):
            # optional section name (argument/member or section name)
            self.name = name
            # the list of lines for this section
            self.text = ''

        def append(self, line):
            self.text += line.rstrip() + '\n'

    class ArgSection(Section):
        def __init__(self, name):
            QAPIDoc.Section.__init__(self, name)
            self.member = None

        def connect(self, member):
            self.member = member

    def __init__(self, parser, info):
        # self._parser is used to report errors with QAPIParseError.  The
        # resulting error position depends on the state of the parser.
        # It happens to be the beginning of the comment.  More or less
        # servicable, but action at a distance.
        self._parser = parser
        self.info = info
        self.symbol = None
        self.body = QAPIDoc.Section()
        # dict mapping parameter name to ArgSection
        self.args = OrderedDict()
        # a list of Section
        self.sections = []
        # the current section
        self._section = self.body

    def has_section(self, name):
        """Return True if we have a section with this name."""
        for i in self.sections:
            if i.name == name:
                return True
        return False

    def append(self, line):
        """Parse a comment line and add it to the documentation."""
        line = line[1:]
        if not line:
            self._append_freeform(line)
            return

        if line[0] != ' ':
            raise QAPIParseError(self._parser, "Missing space after #")
        line = line[1:]

        # FIXME not nice: things like '#  @foo:' and '# @foo: ' aren't
        # recognized, and get silently treated as ordinary text
        if self.symbol:
            self._append_symbol_line(line)
        elif not self.body.text and line.startswith('@'):
            if not line.endswith(':'):
                raise QAPIParseError(self._parser, "Line should end with :")
            self.symbol = line[1:-1]
            # FIXME invalid names other than the empty string aren't flagged
            if not self.symbol:
                raise QAPIParseError(self._parser, "Invalid name")
        else:
            self._append_freeform(line)

    def end_comment(self):
        self._end_section()

    def _append_symbol_line(self, line):
        name = line.split(' ', 1)[0]

        if name.startswith('@') and name.endswith(':'):
            line = line[len(name)+1:]
            self._start_args_section(name[1:-1])
        elif name in ('Returns:', 'Since:',
                      # those are often singular or plural
                      'Note:', 'Notes:',
                      'Example:', 'Examples:',
                      'TODO:'):
            line = line[len(name)+1:]
            self._start_section(name[:-1])

        self._append_freeform(line)

    def _start_args_section(self, name):
        # FIXME invalid names other than the empty string aren't flagged
        if not name:
            raise QAPIParseError(self._parser, "Invalid parameter name")
        if name in self.args:
            raise QAPIParseError(self._parser,
                                 "'%s' parameter name duplicated" % name)
        if self.sections:
            raise QAPIParseError(self._parser,
                                 "'@%s:' can't follow '%s' section"
                                 % (name, self.sections[0].name))
        self._end_section()
        self._section = QAPIDoc.ArgSection(name)
        self.args[name] = self._section

    def _start_section(self, name=None):
        if name in ('Returns', 'Since') and self.has_section(name):
            raise QAPIParseError(self._parser,
                                 "Duplicated '%s' section" % name)
        self._end_section()
        self._section = QAPIDoc.Section(name)
        self.sections.append(self._section)

    def _end_section(self):
        if self._section:
            text = self._section.text = self._section.text.strip()
            if self._section.name and (not text or text.isspace()):
                raise QAPIParseError(self._parser, "Empty doc section '%s'"
                                     % self._section.name)
            self._section = None

    def _append_freeform(self, line):
        in_arg = isinstance(self._section, QAPIDoc.ArgSection)
        if (in_arg and self._section.text.endswith('\n\n')
                and line and not line[0].isspace()):
            self._start_section()
        if (in_arg or not self._section.name
                or not self._section.name.startswith('Example')):
            line = line.strip()
        match = re.match(r'(@\S+:)', line)
        if match:
            raise QAPIParseError(self._parser,
                                 "'%s' not allowed in free-form documentation"
                                 % match.group(1))
        self._section.append(line)

    def connect_member(self, member):
        if member.name not in self.args:
            # Undocumented TODO outlaw
            self.args[member.name] = QAPIDoc.ArgSection(member.name)
        self.args[member.name].connect(member)

    def check_expr(self, expr):
        if self.has_section('Returns') and 'command' not in expr:
            raise QAPISemError(self.info,
                               "'Returns:' is only valid for commands")

    def check(self):
        bogus = [name for name, section in self.args.items()
                 if not section.member]
        if bogus:
            raise QAPISemError(
                self.info,
                "The following documented members are not in "
                "the declaration: %s" % ", ".join(bogus))


class QAPISchemaParser(object):

    def __init__(self, fp, previously_included=[], incl_info=None):
        self.fname = fp.name
        previously_included.append(os.path.abspath(fp.name))
        self.incl_info = incl_info
        self.src = fp.read()
        if self.src == '' or self.src[-1] != '\n':
            self.src += '\n'
        self.cursor = 0
        self.line = 1
        self.line_pos = 0
        self.exprs = []
        self.docs = []
        self.accept()
        cur_doc = None

        while self.tok is not None:
            info = {'file': self.fname, 'line': self.line,
                    'parent': self.incl_info}
            if self.tok == '#':
                self.reject_expr_doc(cur_doc)
                cur_doc = self.get_doc(info)
                self.docs.append(cur_doc)
                continue

            expr = self.get_expr(False)
            if 'include' in expr:
                self.reject_expr_doc(cur_doc)
                if len(expr) != 1:
                    raise QAPISemError(info, "Invalid 'include' directive")
                include = expr['include']
                if not isinstance(include, str):
                    raise QAPISemError(info,
                                       "Value of 'include' must be a string")
                incl_fname = os.path.join(os.path.dirname(self.fname),
                                          include)
                self.exprs.append({'expr': {'include': incl_fname},
                                   'info': info})
                exprs_include = self._include(include, info, incl_fname,
                                              previously_included)
                if exprs_include:
                    self.exprs.extend(exprs_include.exprs)
                    self.docs.extend(exprs_include.docs)
            elif "pragma" in expr:
                self.reject_expr_doc(cur_doc)
                if len(expr) != 1:
                    raise QAPISemError(info, "Invalid 'pragma' directive")
                pragma = expr['pragma']
                if not isinstance(pragma, dict):
                    raise QAPISemError(
                        info, "Value of 'pragma' must be a dictionary")
                for name, value in pragma.items():
                    self._pragma(name, value, info)
            else:
                expr_elem = {'expr': expr,
                             'info': info}
                if cur_doc:
                    if not cur_doc.symbol:
                        raise QAPISemError(
                            cur_doc.info, "Expression documentation required")
                    expr_elem['doc'] = cur_doc
                self.exprs.append(expr_elem)
            cur_doc = None
        self.reject_expr_doc(cur_doc)

    @staticmethod
    def reject_expr_doc(doc):
        if doc and doc.symbol:
            raise QAPISemError(
                doc.info,
                "Documentation for '%s' is not followed by the definition"
                % doc.symbol)

    def _include(self, include, info, incl_fname, previously_included):
        incl_abs_fname = os.path.abspath(incl_fname)
        # catch inclusion cycle
        inf = info
        while inf:
            if incl_abs_fname == os.path.abspath(inf['file']):
                raise QAPISemError(info, "Inclusion loop for %s" % include)
            inf = inf['parent']

        # skip multiple include of the same file
        if incl_abs_fname in previously_included:
            return None

        try:
            if sys.version_info[0] >= 3:
                fobj = open(incl_fname, 'r', encoding='utf-8')
            else:
                fobj = open(incl_fname, 'r')
        except IOError as e:
            raise QAPISemError(info, '%s: %s' % (e.strerror, incl_fname))
        return QAPISchemaParser(fobj, previously_included, info)

    def _pragma(self, name, value, info):
        global doc_required, returns_whitelist, name_case_whitelist
        if name == 'doc-required':
            if not isinstance(value, bool):
                raise QAPISemError(info,
                                   "Pragma 'doc-required' must be boolean")
            doc_required = value
        elif name == 'returns-whitelist':
            if (not isinstance(value, list)
                    or any([not isinstance(elt, str) for elt in value])):
                raise QAPISemError(info,
                                   "Pragma returns-whitelist must be"
                                   " a list of strings")
            returns_whitelist = value
        elif name == 'name-case-whitelist':
            if (not isinstance(value, list)
                    or any([not isinstance(elt, str) for elt in value])):
                raise QAPISemError(info,
                                   "Pragma name-case-whitelist must be"
                                   " a list of strings")
            name_case_whitelist = value
        else:
            raise QAPISemError(info, "Unknown pragma '%s'" % name)

    def accept(self, skip_comment=True):
        while True:
            self.tok = self.src[self.cursor]
            self.pos = self.cursor
            self.cursor += 1
            self.val = None

            if self.tok == '#':
                if self.src[self.cursor] == '#':
                    # Start of doc comment
                    skip_comment = False
                self.cursor = self.src.find('\n', self.cursor)
                if not skip_comment:
                    self.val = self.src[self.pos:self.cursor]
                    return
            elif self.tok in '{}:,[]':
                return
            elif self.tok == "'":
                string = ''
                esc = False
                while True:
                    ch = self.src[self.cursor]
                    self.cursor += 1
                    if ch == '\n':
                        raise QAPIParseError(self, 'Missing terminating "\'"')
                    if esc:
                        if ch == 'b':
                            string += '\b'
                        elif ch == 'f':
                            string += '\f'
                        elif ch == 'n':
                            string += '\n'
                        elif ch == 'r':
                            string += '\r'
                        elif ch == 't':
                            string += '\t'
                        elif ch == 'u':
                            value = 0
                            for _ in range(0, 4):
                                ch = self.src[self.cursor]
                                self.cursor += 1
                                if ch not in '0123456789abcdefABCDEF':
                                    raise QAPIParseError(self,
                                                         '\\u escape needs 4 '
                                                         'hex digits')
                                value = (value << 4) + int(ch, 16)
                            # If Python 2 and 3 didn't disagree so much on
                            # how to handle Unicode, then we could allow
                            # Unicode string defaults.  But most of QAPI is
                            # ASCII-only, so we aren't losing much for now.
                            if not value or value > 0x7f:
                                raise QAPIParseError(self,
                                                     'For now, \\u escape '
                                                     'only supports non-zero '
                                                     'values up to \\u007f')
                            string += chr(value)
                        elif ch in '\\/\'"':
                            string += ch
                        else:
                            raise QAPIParseError(self,
                                                 "Unknown escape \\%s" % ch)
                        esc = False
                    elif ch == '\\':
                        esc = True
                    elif ch == "'":
                        self.val = string
                        return
                    else:
                        string += ch
            elif self.src.startswith('true', self.pos):
                self.val = True
                self.cursor += 3
                return
            elif self.src.startswith('false', self.pos):
                self.val = False
                self.cursor += 4
                return
            elif self.src.startswith('null', self.pos):
                self.val = None
                self.cursor += 3
                return
            elif self.tok == '\n':
                if self.cursor == len(self.src):
                    self.tok = None
                    return
                self.line += 1
                self.line_pos = self.cursor
            elif not self.tok.isspace():
                raise QAPIParseError(self, 'Stray "%s"' % self.tok)

    def get_members(self):
        expr = OrderedDict()
        if self.tok == '}':
            self.accept()
            return expr
        if self.tok != "'":
            raise QAPIParseError(self, 'Expected string or "}"')
        while True:
            key = self.val
            self.accept()
            if self.tok != ':':
                raise QAPIParseError(self, 'Expected ":"')
            self.accept()
            if key in expr:
                raise QAPIParseError(self, 'Duplicate key "%s"' % key)
            expr[key] = self.get_expr(True)
            if self.tok == '}':
                self.accept()
                return expr
            if self.tok != ',':
                raise QAPIParseError(self, 'Expected "," or "}"')
            self.accept()
            if self.tok != "'":
                raise QAPIParseError(self, 'Expected string')

    def get_values(self):
        expr = []
        if self.tok == ']':
            self.accept()
            return expr
        if self.tok not in "{['tfn":
            raise QAPIParseError(self, 'Expected "{", "[", "]", string, '
                                 'boolean or "null"')
        while True:
            expr.append(self.get_expr(True))
            if self.tok == ']':
                self.accept()
                return expr
            if self.tok != ',':
                raise QAPIParseError(self, 'Expected "," or "]"')
            self.accept()

    def get_expr(self, nested):
        if self.tok != '{' and not nested:
            raise QAPIParseError(self, 'Expected "{"')
        if self.tok == '{':
            self.accept()
            expr = self.get_members()
        elif self.tok == '[':
            self.accept()
            expr = self.get_values()
        elif self.tok in "'tfn":
            expr = self.val
            self.accept()
        else:
            raise QAPIParseError(self, 'Expected "{", "[", string, '
                                 'boolean or "null"')
        return expr

    def get_doc(self, info):
        if self.val != '##':
            raise QAPIParseError(self, "Junk after '##' at start of "
                                 "documentation comment")

        doc = QAPIDoc(self, info)
        self.accept(False)
        while self.tok == '#':
            if self.val.startswith('##'):
                # End of doc comment
                if self.val != '##':
                    raise QAPIParseError(self, "Junk after '##' at end of "
                                         "documentation comment")
                doc.end_comment()
                self.accept()
                return doc
            else:
                doc.append(self.val)
            self.accept(False)

        raise QAPIParseError(self, "Documentation comment must end with '##'")


#
# Semantic analysis of schema expressions
# TODO fold into QAPISchema
# TODO catching name collisions in generated code would be nice
#


def find_base_members(base):
    if isinstance(base, dict):
        return base
    base_struct_define = struct_types.get(base)
    if not base_struct_define:
        return None
    return base_struct_define['data']


# Return the qtype of an alternate branch, or None on error.
def find_alternate_member_qtype(qapi_type):
    if qapi_type in builtin_types:
        return builtin_types[qapi_type]
    elif qapi_type in struct_types:
        return 'QTYPE_QDICT'
    elif qapi_type in enum_types:
        return 'QTYPE_QSTRING'
    elif qapi_type in union_types:
        return 'QTYPE_QDICT'
    return None


# Return the discriminator enum define if discriminator is specified as an
# enum type, otherwise return None.
def discriminator_find_enum_define(expr):
    base = expr.get('base')
    discriminator = expr.get('discriminator')

    if not (discriminator and base):
        return None

    base_members = find_base_members(base)
    if not base_members:
        return None

    discriminator_value = base_members.get(discriminator)
    if not discriminator_value:
        return None

    return enum_types.get(discriminator_value['type'])


# Names must be letters, numbers, -, and _.  They must start with letter,
# except for downstream extensions which must start with __RFQDN_.
# Dots are only valid in the downstream extension prefix.
valid_name = re.compile(r'^(__[a-zA-Z0-9.-]+_)?'
                        '[a-zA-Z][a-zA-Z0-9_-]*$')


def check_name(info, source, name, allow_optional=False,
               enum_member=False):
    global valid_name
    membername = name

    if not isinstance(name, str):
        raise QAPISemError(info, "%s requires a string name" % source)
    if name.startswith('*'):
        membername = name[1:]
        if not allow_optional:
            raise QAPISemError(info, "%s does not allow optional name '%s'"
                               % (source, name))
    # Enum members can start with a digit, because the generated C
    # code always prefixes it with the enum name
    if enum_member and membername[0].isdigit():
        membername = 'D' + membername
    # Reserve the entire 'q_' namespace for c_name(), and for 'q_empty'
    # and 'q_obj_*' implicit type names.
    if not valid_name.match(membername) or \
       c_name(membername, False).startswith('q_'):
        raise QAPISemError(info, "%s uses invalid name '%s'" % (source, name))


def add_name(name, info, meta, implicit=False):
    global all_names
    check_name(info, "'%s'" % meta, name)
    # FIXME should reject names that differ only in '_' vs. '.'
    # vs. '-', because they're liable to clash in generated C.
    if name in all_names:
        raise QAPISemError(info, "%s '%s' is already defined"
                           % (all_names[name], name))
    if not implicit and (name.endswith('Kind') or name.endswith('List')):
        raise QAPISemError(info, "%s '%s' should not end in '%s'"
                           % (meta, name, name[-4:]))
    all_names[name] = meta


def check_if(expr, info):

    def check_if_str(ifcond, info):
        if not isinstance(ifcond, str):
            raise QAPISemError(
                info, "'if' condition must be a string or a list of strings")
        if ifcond == '':
            raise QAPISemError(info, "'if' condition '' makes no sense")

    ifcond = expr.get('if')
    if ifcond is None:
        return
    if isinstance(ifcond, list):
        if ifcond == []:
            raise QAPISemError(info, "'if' condition [] is useless")
        for elt in ifcond:
            check_if_str(elt, info)
    else:
        check_if_str(ifcond, info)


def check_type(info, source, value, allow_array=False,
               allow_dict=False, allow_optional=False,
               allow_metas=[]):
    global all_names

    if value is None:
        return

    # Check if array type for value is okay
    if isinstance(value, list):
        if not allow_array:
            raise QAPISemError(info, "%s cannot be an array" % source)
        if len(value) != 1 or not isinstance(value[0], str):
            raise QAPISemError(info,
                               "%s: array type must contain single type name" %
                               source)
        value = value[0]

    # Check if type name for value is okay
    if isinstance(value, str):
        if value not in all_names:
            raise QAPISemError(info, "%s uses unknown type '%s'"
                               % (source, value))
        if not all_names[value] in allow_metas:
            raise QAPISemError(info, "%s cannot use %s type '%s'" %
                               (source, all_names[value], value))
        return

    if not allow_dict:
        raise QAPISemError(info, "%s should be a type name" % source)

    if not isinstance(value, OrderedDict):
        raise QAPISemError(info,
                           "%s should be a dictionary or type name" % source)

    # value is a dictionary, check that each member is okay
    for (key, arg) in value.items():
        check_name(info, "Member of %s" % source, key,
                   allow_optional=allow_optional)
        if c_name(key, False) == 'u' or c_name(key, False).startswith('has_'):
            raise QAPISemError(info, "Member of %s uses reserved name '%s'"
                               % (source, key))
        # Todo: allow dictionaries to represent default values of
        # an optional argument.
        check_known_keys(info, "member '%s' of %s" % (key, source),
                         arg, ['type'], ['if'])
        check_type(info, "Member '%s' of %s" % (key, source),
                   arg['type'], allow_array=True,
                   allow_metas=['built-in', 'union', 'alternate', 'struct',
                                'enum'])


def check_command(expr, info):
    name = expr['command']
    boxed = expr.get('boxed', False)

    args_meta = ['struct']
    if boxed:
        args_meta += ['union', 'alternate']
    check_type(info, "'data' for command '%s'" % name,
               expr.get('data'), allow_dict=not boxed, allow_optional=True,
               allow_metas=args_meta)
    returns_meta = ['union', 'struct']
    if name in returns_whitelist:
        returns_meta += ['built-in', 'alternate', 'enum']
    check_type(info, "'returns' for command '%s'" % name,
               expr.get('returns'), allow_array=True,
               allow_optional=True, allow_metas=returns_meta)


def check_event(expr, info):
    name = expr['event']
    boxed = expr.get('boxed', False)

    meta = ['struct']
    if boxed:
        meta += ['union', 'alternate']
    check_type(info, "'data' for event '%s'" % name,
               expr.get('data'), allow_dict=not boxed, allow_optional=True,
               allow_metas=meta)


def enum_get_names(expr):
    return [e['name'] for e in expr['data']]


def check_union(expr, info):
    name = expr['union']
    base = expr.get('base')
    discriminator = expr.get('discriminator')
    members = expr['data']

    # Two types of unions, determined by discriminator.

    # With no discriminator it is a simple union.
    if discriminator is None:
        enum_define = None
        allow_metas = ['built-in', 'union', 'alternate', 'struct', 'enum']
        if base is not None:
            raise QAPISemError(info, "Simple union '%s' must not have a base" %
                               name)

    # Else, it's a flat union.
    else:
        # The object must have a string or dictionary 'base'.
        check_type(info, "'base' for union '%s'" % name,
                   base, allow_dict=True, allow_optional=True,
                   allow_metas=['struct'])
        if not base:
            raise QAPISemError(info, "Flat union '%s' must have a base"
                               % name)
        base_members = find_base_members(base)
        assert base_members is not None

        # The value of member 'discriminator' must name a non-optional
        # member of the base struct.
        check_name(info, "Discriminator of flat union '%s'" % name,
                   discriminator)
        discriminator_value = base_members.get(discriminator)
        if not discriminator_value:
            raise QAPISemError(info,
                               "Discriminator '%s' is not a member of base "
                               "struct '%s'"
                               % (discriminator, base))
        if discriminator_value.get('if'):
            raise QAPISemError(info, 'The discriminator %s.%s for union %s '
                               'must not be conditional' %
                               (base, discriminator, name))
        enum_define = enum_types.get(discriminator_value['type'])
        allow_metas = ['struct']
        # Do not allow string discriminator
        if not enum_define:
            raise QAPISemError(info,
                               "Discriminator '%s' must be of enumeration "
                               "type" % discriminator)

    # Check every branch; don't allow an empty union
    if len(members) == 0:
        raise QAPISemError(info, "Union '%s' cannot have empty 'data'" % name)
    for (key, value) in members.items():
        check_name(info, "Member of union '%s'" % name, key)

        check_known_keys(info, "member '%s' of union '%s'" % (key, name),
                         value, ['type'], ['if'])
        # Each value must name a known type
        check_type(info, "Member '%s' of union '%s'" % (key, name),
                   value['type'],
                   allow_array=not base, allow_metas=allow_metas)

        # If the discriminator names an enum type, then all members
        # of 'data' must also be members of the enum type.
        if enum_define:
            if key not in enum_get_names(enum_define):
                raise QAPISemError(info,
                                   "Discriminator value '%s' is not found in "
                                   "enum '%s'"
                                   % (key, enum_define['enum']))


def check_alternate(expr, info):
    name = expr['alternate']
    members = expr['data']
    types_seen = {}

    # Check every branch; require at least two branches
    if len(members) < 2:
        raise QAPISemError(info,
                           "Alternate '%s' should have at least two branches "
                           "in 'data'" % name)
    for (key, value) in members.items():
        check_name(info, "Member of alternate '%s'" % name, key)
        check_known_keys(info,
                         "member '%s' of alternate '%s'" % (key, name),
                         value, ['type'], ['if'])
        typ = value['type']

        # Ensure alternates have no type conflicts.
        check_type(info, "Member '%s' of alternate '%s'" % (key, name), typ,
                   allow_metas=['built-in', 'union', 'struct', 'enum'])
        qtype = find_alternate_member_qtype(typ)
        if not qtype:
            raise QAPISemError(info, "Alternate '%s' member '%s' cannot use "
                               "type '%s'" % (name, key, typ))
        conflicting = set([qtype])
        if qtype == 'QTYPE_QSTRING':
            enum_expr = enum_types.get(typ)
            if enum_expr:
                for v in enum_get_names(enum_expr):
                    if v in ['on', 'off']:
                        conflicting.add('QTYPE_QBOOL')
                    if re.match(r'[-+0-9.]', v): # lazy, could be tightened
                        conflicting.add('QTYPE_QNUM')
            else:
                conflicting.add('QTYPE_QNUM')
                conflicting.add('QTYPE_QBOOL')
        for qt in conflicting:
            if qt in types_seen:
                raise QAPISemError(info, "Alternate '%s' member '%s' can't "
                                   "be distinguished from member '%s'"
                                   % (name, key, types_seen[qt]))
            types_seen[qt] = key


def check_enum(expr, info):
    name = expr['enum']
    members = expr['data']
    prefix = expr.get('prefix')

    if not isinstance(members, list):
        raise QAPISemError(info,
                           "Enum '%s' requires an array for 'data'" % name)
    if prefix is not None and not isinstance(prefix, str):
        raise QAPISemError(info,
                           "Enum '%s' requires a string for 'prefix'" % name)

    for member in members:
        source = "dictionary member of enum '%s'" % name
        check_known_keys(info, source, member, ['name'], ['if'])
        check_if(member, info)
        check_name(info, "Member of enum '%s'" % name, member['name'],
                   enum_member=True)


def check_struct(expr, info):
    name = expr['struct']
    members = expr['data']

    check_type(info, "'data' for struct '%s'" % name, members,
               allow_dict=True, allow_optional=True)
    check_type(info, "'base' for struct '%s'" % name, expr.get('base'),
               allow_metas=['struct'])


def check_known_keys(info, source, keys, required, optional):

    def pprint(elems):
        return ', '.join("'" + e + "'" for e in sorted(elems))

    missing = set(required) - set(keys)
    if missing:
        raise QAPISemError(info, "Key%s %s %s missing from %s"
                           % ('s' if len(missing) > 1 else '', pprint(missing),
                              'are' if len(missing) > 1 else 'is', source))
    allowed = set(required + optional)
    unknown = set(keys) - allowed
    if unknown:
        raise QAPISemError(info, "Unknown key%s %s in %s\nValid keys are %s."
                           % ('s' if len(unknown) > 1 else '', pprint(unknown),
                              source, pprint(allowed)))


def check_keys(expr_elem, meta, required, optional=[]):
    expr = expr_elem['expr']
    info = expr_elem['info']
    name = expr[meta]
    if not isinstance(name, str):
        raise QAPISemError(info, "'%s' key must have a string value" % meta)
    required = required + [meta]
    source = "%s '%s'" % (meta, name)
    check_known_keys(info, source, expr.keys(), required, optional)
    for (key, value) in expr.items():
        if key in ['gen', 'success-response'] and value is not False:
            raise QAPISemError(info,
                               "'%s' of %s '%s' should only use false value"
                               % (key, meta, name))
        if (key in ['boxed', 'allow-oob', 'allow-preconfig']
                and value is not True):
            raise QAPISemError(info,
                               "'%s' of %s '%s' should only use true value"
                               % (key, meta, name))
        if key == 'if':
            check_if(expr, info)


def normalize_enum(expr):
    if isinstance(expr['data'], list):
        expr['data'] = [m if isinstance(m, dict) else {'name': m}
                        for m in expr['data']]


def normalize_members(members):
    if isinstance(members, OrderedDict):
        for key, arg in members.items():
            if isinstance(arg, dict):
                continue
            members[key] = {'type': arg}


def check_exprs(exprs):
    global all_names

    # Populate name table with names of built-in types
    for builtin in builtin_types.keys():
        all_names[builtin] = 'built-in'

    # Learn the types and check for valid expression keys
    for expr_elem in exprs:
        expr = expr_elem['expr']
        info = expr_elem['info']
        doc = expr_elem.get('doc')

        if 'include' in expr:
            continue

        if not doc and doc_required:
            raise QAPISemError(info,
                               "Expression missing documentation comment")

        if 'enum' in expr:
            meta = 'enum'
            check_keys(expr_elem, 'enum', ['data'], ['if', 'prefix'])
            normalize_enum(expr)
            enum_types[expr[meta]] = expr
        elif 'union' in expr:
            meta = 'union'
            check_keys(expr_elem, 'union', ['data'],
                       ['base', 'discriminator', 'if'])
            normalize_members(expr.get('base'))
            normalize_members(expr['data'])
            union_types[expr[meta]] = expr
        elif 'alternate' in expr:
            meta = 'alternate'
            check_keys(expr_elem, 'alternate', ['data'], ['if'])
            normalize_members(expr['data'])
        elif 'struct' in expr:
            meta = 'struct'
            check_keys(expr_elem, 'struct', ['data'], ['base', 'if'])
            normalize_members(expr['data'])
            struct_types[expr[meta]] = expr
        elif 'command' in expr:
            meta = 'command'
            check_keys(expr_elem, 'command', [],
                       ['data', 'returns', 'gen', 'success-response',
                        'boxed', 'allow-oob', 'allow-preconfig', 'if'])
            normalize_members(expr.get('data'))
        elif 'event' in expr:
            meta = 'event'
            check_keys(expr_elem, 'event', [], ['data', 'boxed', 'if'])
            normalize_members(expr.get('data'))
        else:
            raise QAPISemError(expr_elem['info'],
                               "Expression is missing metatype")
        name = expr[meta]
        add_name(name, info, meta)
        if doc and doc.symbol != name:
            raise QAPISemError(info, "Definition of '%s' follows documentation"
                               " for '%s'" % (name, doc.symbol))

    # Try again for hidden UnionKind enum
    for expr_elem in exprs:
        expr = expr_elem['expr']

        if 'include' in expr:
            continue
        if 'union' in expr and not discriminator_find_enum_define(expr):
            name = '%sKind' % expr['union']
        elif 'alternate' in expr:
            name = '%sKind' % expr['alternate']
        else:
            continue
        enum_types[name] = {'enum': name}
        add_name(name, info, 'enum', implicit=True)

    # Validate that exprs make sense
    for expr_elem in exprs:
        expr = expr_elem['expr']
        info = expr_elem['info']
        doc = expr_elem.get('doc')

        if 'include' in expr:
            continue
        if 'enum' in expr:
            check_enum(expr, info)
        elif 'union' in expr:
            check_union(expr, info)
        elif 'alternate' in expr:
            check_alternate(expr, info)
        elif 'struct' in expr:
            check_struct(expr, info)
        elif 'command' in expr:
            check_command(expr, info)
        elif 'event' in expr:
            check_event(expr, info)
        else:
            assert False, 'unexpected meta type'

        if doc:
            doc.check_expr(expr)

    return exprs


#
# Schema compiler frontend
#

def listify_cond(ifcond):
    if not ifcond:
        return []
    if not isinstance(ifcond, list):
        return [ifcond]
    return ifcond


class QAPISchemaEntity(object):
    def __init__(self, name, info, doc, ifcond=None):
        assert name is None or isinstance(name, str)
        self.name = name
        self.module = None
        # For explicitly defined entities, info points to the (explicit)
        # definition.  For builtins (and their arrays), info is None.
        # For implicitly defined entities, info points to a place that
        # triggered the implicit definition (there may be more than one
        # such place).
        self.info = info
        self.doc = doc
        self._ifcond = ifcond  # self.ifcond is set only after .check()

    def c_name(self):
        return c_name(self.name)

    def check(self, schema):
        if isinstance(self._ifcond, QAPISchemaType):
            # inherit the condition from a type
            typ = self._ifcond
            typ.check(schema)
            self.ifcond = typ.ifcond
        else:
            self.ifcond = listify_cond(self._ifcond)
        if self.info:
            self.module = os.path.relpath(self.info['file'],
                                          os.path.dirname(schema.fname))

    def is_implicit(self):
        return not self.info

    def visit(self, visitor):
        pass


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

    def visit_object_type(self, name, info, ifcond, base, members, variants):
        pass

    def visit_object_type_flat(self, name, info, ifcond, members, variants):
        pass

    def visit_alternate_type(self, name, info, ifcond, variants):
        pass

    def visit_command(self, name, info, ifcond, arg_type, ret_type, gen,
                      success_response, boxed, allow_oob, allow_preconfig):
        pass

    def visit_event(self, name, info, ifcond, arg_type, boxed):
        pass


class QAPISchemaInclude(QAPISchemaEntity):

    def __init__(self, fname, info):
        QAPISchemaEntity.__init__(self, None, info, None)
        self.fname = fname

    def visit(self, visitor):
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


class QAPISchemaBuiltinType(QAPISchemaType):
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
        visitor.visit_builtin_type(self.name, self.info, self.json_type())


class QAPISchemaEnumType(QAPISchemaType):
    def __init__(self, name, info, doc, ifcond, members, prefix):
        QAPISchemaType.__init__(self, name, info, doc, ifcond)
        for m in members:
            assert isinstance(m, QAPISchemaMember)
            m.set_owner(name)
        assert prefix is None or isinstance(prefix, str)
        self.members = members
        self.prefix = prefix

    def check(self, schema):
        QAPISchemaType.check(self, schema)
        seen = {}
        for m in self.members:
            m.check_clash(self.info, seen)
            if self.doc:
                self.doc.connect_member(m)

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
        visitor.visit_enum_type(self.name, self.info, self.ifcond,
                                self.members, self.prefix)


class QAPISchemaArrayType(QAPISchemaType):
    def __init__(self, name, info, element_type):
        QAPISchemaType.__init__(self, name, info, None, None)
        assert isinstance(element_type, str)
        self._element_type_name = element_type
        self.element_type = None

    def check(self, schema):
        QAPISchemaType.check(self, schema)
        self.element_type = schema.lookup_type(self._element_type_name)
        assert self.element_type
        self.element_type.check(schema)
        self.module = self.element_type.module
        self.ifcond = self.element_type.ifcond

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
        visitor.visit_array_type(self.name, self.info, self.ifcond,
                                 self.element_type)


class QAPISchemaObjectType(QAPISchemaType):
    def __init__(self, name, info, doc, ifcond,
                 base, local_members, variants):
        # struct has local_members, optional base, and no variants
        # flat union has base, variants, and no local_members
        # simple union has local_members, variants, and no base
        QAPISchemaType.__init__(self, name, info, doc, ifcond)
        assert base is None or isinstance(base, str)
        for m in local_members:
            assert isinstance(m, QAPISchemaObjectTypeMember)
            m.set_owner(name)
        if variants is not None:
            assert isinstance(variants, QAPISchemaObjectTypeVariants)
            variants.set_owner(name)
        self._base_name = base
        self.base = None
        self.local_members = local_members
        self.variants = variants
        self.members = None

    def check(self, schema):
        QAPISchemaType.check(self, schema)
        if self.members is False:               # check for cycles
            raise QAPISemError(self.info,
                               "Object %s contains itself" % self.name)
        if self.members:
            return
        self.members = False                    # mark as being checked
        seen = OrderedDict()
        if self._base_name:
            self.base = schema.lookup_type(self._base_name)
            assert isinstance(self.base, QAPISchemaObjectType)
            self.base.check(schema)
            self.base.check_clash(self.info, seen)
        for m in self.local_members:
            m.check(schema)
            m.check_clash(self.info, seen)
            if self.doc:
                self.doc.connect_member(m)
        self.members = seen.values()
        if self.variants:
            self.variants.check(schema, seen)
            assert self.variants.tag_member in self.members
            self.variants.check_clash(self.info, seen)
        if self.doc:
            self.doc.check()

    # Check that the members of this type do not cause duplicate JSON members,
    # and update seen to track the members seen so far. Report any errors
    # on behalf of info, which is not necessarily self.info
    def check_clash(self, info, seen):
        assert not self.variants       # not implemented
        for m in self.members:
            m.check_clash(info, seen)

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
        visitor.visit_object_type(self.name, self.info, self.ifcond,
                                  self.base, self.local_members, self.variants)
        visitor.visit_object_type_flat(self.name, self.info, self.ifcond,
                                       self.members, self.variants)


class QAPISchemaMember(object):
    role = 'member'

    def __init__(self, name, ifcond=None):
        assert isinstance(name, str)
        self.name = name
        self.ifcond = listify_cond(ifcond)
        self.owner = None

    def set_owner(self, name):
        assert not self.owner
        self.owner = name

    def check_clash(self, info, seen):
        cname = c_name(self.name)
        if cname.lower() != cname and self.owner not in name_case_whitelist:
            raise QAPISemError(info,
                               "%s should not use uppercase" % self.describe())
        if cname in seen:
            raise QAPISemError(info, "%s collides with %s" %
                               (self.describe(), seen[cname].describe()))
        seen[cname] = self

    def _pretty_owner(self):
        owner = self.owner
        if owner.startswith('q_obj_'):
            # See QAPISchema._make_implicit_object_type() - reverse the
            # mapping there to create a nice human-readable description
            owner = owner[6:]
            if owner.endswith('-arg'):
                return '(parameter of %s)' % owner[:-4]
            elif owner.endswith('-base'):
                return '(base of %s)' % owner[:-5]
            else:
                assert owner.endswith('-wrapper')
                # Unreachable and not implemented
                assert False
        if owner.endswith('Kind'):
            # See QAPISchema._make_implicit_enum_type()
            return '(branch of %s)' % owner[:-4]
        return '(%s of %s)' % (self.role, owner)

    def describe(self):
        return "'%s' %s" % (self.name, self._pretty_owner())


class QAPISchemaObjectTypeMember(QAPISchemaMember):
    def __init__(self, name, typ, optional, ifcond=None):
        QAPISchemaMember.__init__(self, name, ifcond)
        assert isinstance(typ, str)
        assert isinstance(optional, bool)
        self._type_name = typ
        self.type = None
        self.optional = optional

    def check(self, schema):
        assert self.owner
        self.type = schema.lookup_type(self._type_name)
        assert self.type


class QAPISchemaObjectTypeVariants(object):
    def __init__(self, tag_name, tag_member, variants):
        # Flat unions pass tag_name but not tag_member.
        # Simple unions and alternates pass tag_member but not tag_name.
        # After check(), tag_member is always set, and tag_name remains
        # a reliable witness of being used by a flat union.
        assert bool(tag_member) != bool(tag_name)
        assert (isinstance(tag_name, str) or
                isinstance(tag_member, QAPISchemaObjectTypeMember))
        assert len(variants) > 0
        for v in variants:
            assert isinstance(v, QAPISchemaObjectTypeVariant)
        self._tag_name = tag_name
        self.tag_member = tag_member
        self.variants = variants

    def set_owner(self, name):
        for v in self.variants:
            v.set_owner(name)

    def check(self, schema, seen):
        if not self.tag_member:    # flat union
            self.tag_member = seen[c_name(self._tag_name)]
            assert self._tag_name == self.tag_member.name
        assert isinstance(self.tag_member.type, QAPISchemaEnumType)
        if self._tag_name:    # flat union
            # branches that are not explicitly covered get an empty type
            cases = set([v.name for v in self.variants])
            for m in self.tag_member.type.members:
                if m.name not in cases:
                    v = QAPISchemaObjectTypeVariant(m.name, 'q_empty',
                                                    m.ifcond)
                    v.set_owner(self.tag_member.owner)
                    self.variants.append(v)
        for v in self.variants:
            v.check(schema)
            # Union names must match enum values; alternate names are
            # checked separately. Use 'seen' to tell the two apart.
            if seen:
                assert v.name in self.tag_member.type.member_names()
                assert isinstance(v.type, QAPISchemaObjectType)
                v.type.check(schema)

    def check_clash(self, info, seen):
        for v in self.variants:
            # Reset seen map for each variant, since qapi names from one
            # branch do not affect another branch
            assert isinstance(v.type, QAPISchemaObjectType)
            v.type.check_clash(info, dict(seen))


class QAPISchemaObjectTypeVariant(QAPISchemaObjectTypeMember):
    role = 'branch'

    def __init__(self, name, typ, ifcond=None):
        QAPISchemaObjectTypeMember.__init__(self, name, typ, False, ifcond)


class QAPISchemaAlternateType(QAPISchemaType):
    def __init__(self, name, info, doc, ifcond, variants):
        QAPISchemaType.__init__(self, name, info, doc, ifcond)
        assert isinstance(variants, QAPISchemaObjectTypeVariants)
        assert variants.tag_member
        variants.set_owner(name)
        variants.tag_member.set_owner(self.name)
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
        for v in self.variants.variants:
            v.check_clash(self.info, seen)
            if self.doc:
                self.doc.connect_member(v)
        if self.doc:
            self.doc.check()

    def c_type(self):
        return c_name(self.name) + pointer_suffix

    def json_type(self):
        return 'value'

    def visit(self, visitor):
        visitor.visit_alternate_type(self.name, self.info, self.ifcond,
                                     self.variants)

    def is_empty(self):
        return False


class QAPISchemaCommand(QAPISchemaEntity):
    def __init__(self, name, info, doc, ifcond, arg_type, ret_type,
                 gen, success_response, boxed, allow_oob, allow_preconfig):
        QAPISchemaEntity.__init__(self, name, info, doc, ifcond)
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
            self.arg_type = schema.lookup_type(self._arg_type_name)
            assert (isinstance(self.arg_type, QAPISchemaObjectType) or
                    isinstance(self.arg_type, QAPISchemaAlternateType))
            self.arg_type.check(schema)
            if self.boxed:
                if self.arg_type.is_empty():
                    raise QAPISemError(self.info,
                                       "Cannot use 'boxed' with empty type")
            else:
                assert not isinstance(self.arg_type, QAPISchemaAlternateType)
                assert not self.arg_type.variants
        elif self.boxed:
            raise QAPISemError(self.info, "Use of 'boxed' requires 'data'")
        if self._ret_type_name:
            self.ret_type = schema.lookup_type(self._ret_type_name)
            assert isinstance(self.ret_type, QAPISchemaType)

    def visit(self, visitor):
        visitor.visit_command(self.name, self.info, self.ifcond,
                              self.arg_type, self.ret_type,
                              self.gen, self.success_response,
                              self.boxed, self.allow_oob,
                              self.allow_preconfig)


class QAPISchemaEvent(QAPISchemaEntity):
    def __init__(self, name, info, doc, ifcond, arg_type, boxed):
        QAPISchemaEntity.__init__(self, name, info, doc, ifcond)
        assert not arg_type or isinstance(arg_type, str)
        self._arg_type_name = arg_type
        self.arg_type = None
        self.boxed = boxed

    def check(self, schema):
        QAPISchemaEntity.check(self, schema)
        if self._arg_type_name:
            self.arg_type = schema.lookup_type(self._arg_type_name)
            assert (isinstance(self.arg_type, QAPISchemaObjectType) or
                    isinstance(self.arg_type, QAPISchemaAlternateType))
            self.arg_type.check(schema)
            if self.boxed:
                if self.arg_type.is_empty():
                    raise QAPISemError(self.info,
                                       "Cannot use 'boxed' with empty type")
            else:
                assert not isinstance(self.arg_type, QAPISchemaAlternateType)
                assert not self.arg_type.variants
        elif self.boxed:
            raise QAPISemError(self.info, "Use of 'boxed' requires 'data'")

    def visit(self, visitor):
        visitor.visit_event(self.name, self.info, self.ifcond,
                            self.arg_type, self.boxed)


class QAPISchema(object):
    def __init__(self, fname):
        self.fname = fname
        if sys.version_info[0] >= 3:
            f = open(fname, 'r', encoding='utf-8')
        else:
            f = open(fname, 'r')
        parser = QAPISchemaParser(f)
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
        assert ent.name is None or ent.name not in self._entity_dict
        self._entity_list.append(ent)
        if ent.name is not None:
            self._entity_dict[ent.name] = ent

    def lookup_entity(self, name, typ=None):
        ent = self._entity_dict.get(name)
        if typ and not isinstance(ent, typ):
            return None
        return ent

    def lookup_type(self, name):
        return self.lookup_entity(name, QAPISchemaType)

    def _def_include(self, expr, info, doc):
        include = expr['include']
        assert doc is None
        main_info = info
        while main_info['parent']:
            main_info = main_info['parent']
        fname = os.path.relpath(include, os.path.dirname(main_info['file']))
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
                  ('any',    'value',   'QObject' + pointer_suffix),
                  ('null',   'null',    'QNull' + pointer_suffix)]:
            self._def_builtin_type(*t)
        self.the_empty_object_type = QAPISchemaObjectType(
            'q_empty', None, None, None, None, [], None)
        self._def_entity(self.the_empty_object_type)

        qtypes = ['none', 'qnull', 'qnum', 'qstring', 'qdict', 'qlist',
                  'qbool']
        qtype_values = self._make_enum_members([{'name': n} for n in qtypes])

        self._def_entity(QAPISchemaEnumType('QType', None, None, None,
                                            qtype_values, 'QTYPE'))

    def _make_enum_members(self, values):
        return [QAPISchemaMember(v['name'], v.get('if')) for v in values]

    def _make_implicit_enum_type(self, name, info, ifcond, values):
        # See also QAPISchemaObjectTypeMember._pretty_owner()
        name = name + 'Kind'   # Use namespace reserved by add_name()
        self._def_entity(QAPISchemaEnumType(
            name, info, None, ifcond, self._make_enum_members(values), None))
        return name

    def _make_array_type(self, element_type, info):
        name = element_type + 'List'   # Use namespace reserved by add_name()
        if not self.lookup_type(name):
            self._def_entity(QAPISchemaArrayType(name, info, element_type))
        return name

    def _make_implicit_object_type(self, name, info, doc, ifcond,
                                   role, members):
        if not members:
            return None
        # See also QAPISchemaObjectTypeMember._pretty_owner()
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
            assert ifcond == typ._ifcond # pylint: disable=protected-access
        else:
            self._def_entity(QAPISchemaObjectType(name, info, doc, ifcond,
                                                  None, members, None))
        return name

    def _def_enum_type(self, expr, info, doc):
        name = expr['enum']
        data = expr['data']
        prefix = expr.get('prefix')
        ifcond = expr.get('if')
        self._def_entity(QAPISchemaEnumType(
            name, info, doc, ifcond,
            self._make_enum_members(data), prefix))

    def _make_member(self, name, typ, ifcond, info):
        optional = False
        if name.startswith('*'):
            name = name[1:]
            optional = True
        if isinstance(typ, list):
            assert len(typ) == 1
            typ = self._make_array_type(typ[0], info)
        return QAPISchemaObjectTypeMember(name, typ, optional, ifcond)

    def _make_members(self, data, info):
        return [self._make_member(key, value['type'], value.get('if'), info)
                for (key, value) in data.items()]

    def _def_struct_type(self, expr, info, doc):
        name = expr['struct']
        base = expr.get('base')
        data = expr['data']
        ifcond = expr.get('if')
        self._def_entity(QAPISchemaObjectType(name, info, doc, ifcond, base,
                                              self._make_members(data, info),
                                              None))

    def _make_variant(self, case, typ, ifcond):
        return QAPISchemaObjectTypeVariant(case, typ, ifcond)

    def _make_simple_variant(self, case, typ, ifcond, info):
        if isinstance(typ, list):
            assert len(typ) == 1
            typ = self._make_array_type(typ[0], info)
        typ = self._make_implicit_object_type(
            typ, info, None, self.lookup_type(typ),
            'wrapper', [self._make_member('data', typ, None, info)])
        return QAPISchemaObjectTypeVariant(case, typ, ifcond)

    def _def_union_type(self, expr, info, doc):
        name = expr['union']
        data = expr['data']
        base = expr.get('base')
        ifcond = expr.get('if')
        tag_name = expr.get('discriminator')
        tag_member = None
        if isinstance(base, dict):
            base = self._make_implicit_object_type(
                name, info, doc, ifcond,
                'base', self._make_members(base, info))
        if tag_name:
            variants = [self._make_variant(key, value['type'], value.get('if'))
                        for (key, value) in data.items()]
            members = []
        else:
            variants = [self._make_simple_variant(key, value['type'],
                                                  value.get('if'), info)
                        for (key, value) in data.items()]
            enum = [{'name': v.name, 'if': v.ifcond} for v in variants]
            typ = self._make_implicit_enum_type(name, info, ifcond, enum)
            tag_member = QAPISchemaObjectTypeMember('type', typ, False)
            members = [tag_member]
        self._def_entity(
            QAPISchemaObjectType(name, info, doc, ifcond, base, members,
                                 QAPISchemaObjectTypeVariants(tag_name,
                                                              tag_member,
                                                              variants)))

    def _def_alternate_type(self, expr, info, doc):
        name = expr['alternate']
        data = expr['data']
        ifcond = expr.get('if')
        variants = [self._make_variant(key, value['type'], value.get('if'))
                    for (key, value) in data.items()]
        tag_member = QAPISchemaObjectTypeMember('type', 'QType', False)
        self._def_entity(
            QAPISchemaAlternateType(name, info, doc, ifcond,
                                    QAPISchemaObjectTypeVariants(None,
                                                                 tag_member,
                                                                 variants)))

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
        if isinstance(data, OrderedDict):
            data = self._make_implicit_object_type(
                name, info, doc, ifcond, 'arg', self._make_members(data, info))
        if isinstance(rets, list):
            assert len(rets) == 1
            rets = self._make_array_type(rets[0], info)
        self._def_entity(QAPISchemaCommand(name, info, doc, ifcond, data, rets,
                                           gen, success_response,
                                           boxed, allow_oob, allow_preconfig))

    def _def_event(self, expr, info, doc):
        name = expr['event']
        data = expr.get('data')
        boxed = expr.get('boxed', False)
        ifcond = expr.get('if')
        if isinstance(data, OrderedDict):
            data = self._make_implicit_object_type(
                name, info, doc, ifcond, 'arg', self._make_members(data, info))
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


#
# Code generation helpers
#

def camel_case(name):
    new_name = ''
    first = True
    for ch in name:
        if ch in ['_', '-']:
            first = True
        elif first:
            new_name += ch.upper()
            first = False
        else:
            new_name += ch.lower()
    return new_name


# ENUMName -> ENUM_NAME, EnumName1 -> ENUM_NAME1
# ENUM_NAME -> ENUM_NAME, ENUM_NAME1 -> ENUM_NAME1, ENUM_Name2 -> ENUM_NAME2
# ENUM24_Name -> ENUM24_NAME
def camel_to_upper(value):
    c_fun_str = c_name(value, False)
    if value.isupper():
        return c_fun_str

    new_name = ''
    length = len(c_fun_str)
    for i in range(length):
        c = c_fun_str[i]
        # When c is upper and no '_' appears before, do more checks
        if c.isupper() and (i > 0) and c_fun_str[i - 1] != '_':
            if i < length - 1 and c_fun_str[i + 1].islower():
                new_name += '_'
            elif c_fun_str[i - 1].isdigit():
                new_name += '_'
        new_name += c
    return new_name.lstrip('_').upper()


def c_enum_const(type_name, const_name, prefix=None):
    if prefix is not None:
        type_name = prefix
    return camel_to_upper(type_name) + '_' + c_name(const_name, False).upper()


if hasattr(str, 'maketrans'):
    c_name_trans = str.maketrans('.-', '__')
else:
    c_name_trans = string.maketrans('.-', '__')


# Map @name to a valid C identifier.
# If @protect, avoid returning certain ticklish identifiers (like
# C keywords) by prepending 'q_'.
#
# Used for converting 'name' from a 'name':'type' qapi definition
# into a generated struct member, as well as converting type names
# into substrings of a generated C function name.
# '__a.b_c' -> '__a_b_c', 'x-foo' -> 'x_foo'
# protect=True: 'int' -> 'q_int'; protect=False: 'int' -> 'int'
def c_name(name, protect=True):
    # ANSI X3J11/88-090, 3.1.1
    c89_words = set(['auto', 'break', 'case', 'char', 'const', 'continue',
                     'default', 'do', 'double', 'else', 'enum', 'extern',
                     'float', 'for', 'goto', 'if', 'int', 'long', 'register',
                     'return', 'short', 'signed', 'sizeof', 'static',
                     'struct', 'switch', 'typedef', 'union', 'unsigned',
                     'void', 'volatile', 'while'])
    # ISO/IEC 9899:1999, 6.4.1
    c99_words = set(['inline', 'restrict', '_Bool', '_Complex', '_Imaginary'])
    # ISO/IEC 9899:2011, 6.4.1
    c11_words = set(['_Alignas', '_Alignof', '_Atomic', '_Generic',
                     '_Noreturn', '_Static_assert', '_Thread_local'])
    # GCC http://gcc.gnu.org/onlinedocs/gcc-4.7.1/gcc/C-Extensions.html
    # excluding _.*
    gcc_words = set(['asm', 'typeof'])
    # C++ ISO/IEC 14882:2003 2.11
    cpp_words = set(['bool', 'catch', 'class', 'const_cast', 'delete',
                     'dynamic_cast', 'explicit', 'false', 'friend', 'mutable',
                     'namespace', 'new', 'operator', 'private', 'protected',
                     'public', 'reinterpret_cast', 'static_cast', 'template',
                     'this', 'throw', 'true', 'try', 'typeid', 'typename',
                     'using', 'virtual', 'wchar_t',
                     # alternative representations
                     'and', 'and_eq', 'bitand', 'bitor', 'compl', 'not',
                     'not_eq', 'or', 'or_eq', 'xor', 'xor_eq'])
    # namespace pollution:
    polluted_words = set(['unix', 'errno', 'mips', 'sparc', 'i386'])
    name = name.translate(c_name_trans)
    if protect and (name in c89_words | c99_words | c11_words | gcc_words
                    | cpp_words | polluted_words):
        return 'q_' + name
    return name


eatspace = '\033EATSPACE.'
pointer_suffix = ' *' + eatspace


def genindent(count):
    ret = ''
    for _ in range(count):
        ret += ' '
    return ret


indent_level = 0


def push_indent(indent_amount=4):
    global indent_level
    indent_level += indent_amount


def pop_indent(indent_amount=4):
    global indent_level
    indent_level -= indent_amount


# Generate @code with @kwds interpolated.
# Obey indent_level, and strip eatspace.
def cgen(code, **kwds):
    raw = code % kwds
    if indent_level:
        indent = genindent(indent_level)
        # re.subn() lacks flags support before Python 2.7, use re.compile()
        raw = re.subn(re.compile(r'^(?!(#|$))', re.MULTILINE),
                      indent, raw)
        raw = raw[0]
    return re.sub(re.escape(eatspace) + r' *', '', raw)


def mcgen(code, **kwds):
    if code[0] == '\n':
        code = code[1:]
    return cgen(code, **kwds)


def c_fname(filename):
    return re.sub(r'[^A-Za-z0-9_]', '_', filename)


def guardstart(name):
    return mcgen('''
#ifndef %(name)s
#define %(name)s

''',
                 name=c_fname(name).upper())


def guardend(name):
    return mcgen('''

#endif /* %(name)s */
''',
                 name=c_fname(name).upper())


def gen_if(ifcond):
    ret = ''
    for ifc in ifcond:
        ret += mcgen('''
#if %(cond)s
''', cond=ifc)
    return ret


def gen_endif(ifcond):
    ret = ''
    for ifc in reversed(ifcond):
        ret += mcgen('''
#endif /* %(cond)s */
''', cond=ifc)
    return ret


def _wrap_ifcond(ifcond, before, after):
    if before == after:
        return after   # suppress empty #if ... #endif

    assert after.startswith(before)
    out = before
    added = after[len(before):]
    if added[0] == '\n':
        out += '\n'
        added = added[1:]
    out += gen_if(ifcond)
    out += added
    out += gen_endif(ifcond)
    return out


def gen_enum_lookup(name, members, prefix=None):
    ret = mcgen('''

const QEnumLookup %(c_name)s_lookup = {
    .array = (const char *const[]) {
''',
                c_name=c_name(name))
    for m in members:
        ret += gen_if(m.ifcond)
        index = c_enum_const(name, m.name, prefix)
        ret += mcgen('''
        [%(index)s] = "%(name)s",
''',
                     index=index, name=m.name)
        ret += gen_endif(m.ifcond)

    ret += mcgen('''
    },
    .size = %(max_index)s
};
''',
                 max_index=c_enum_const(name, '_MAX', prefix))
    return ret


def gen_enum(name, members, prefix=None):
    # append automatically generated _MAX value
    enum_members = members + [QAPISchemaMember('_MAX')]

    ret = mcgen('''

typedef enum %(c_name)s {
''',
                c_name=c_name(name))

    for m in enum_members:
        ret += gen_if(m.ifcond)
        ret += mcgen('''
    %(c_enum)s,
''',
                     c_enum=c_enum_const(name, m.name, prefix))
        ret += gen_endif(m.ifcond)

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


def build_params(arg_type, boxed, extra=None):
    ret = ''
    sep = ''
    if boxed:
        assert arg_type
        ret += '%s arg' % arg_type.c_param_type()
        sep = ', '
    elif arg_type:
        assert not arg_type.variants
        for memb in arg_type.members:
            ret += sep
            sep = ', '
            if memb.optional:
                ret += 'bool has_%s, ' % c_name(memb.name)
            ret += '%s %s' % (memb.type.c_param_type(),
                              c_name(memb.name))
    if extra:
        ret += sep + extra
    return ret if ret else 'void'


#
# Accumulate and write output
#

class QAPIGen(object):

    def __init__(self, fname):
        self.fname = fname
        self._preamble = ''
        self._body = ''

    def preamble_add(self, text):
        self._preamble += text

    def add(self, text):
        self._body += text

    def get_content(self):
        return self._top() + self._preamble + self._body + self._bottom()

    def _top(self):
        return ''

    def _bottom(self):
        return ''

    def write(self, output_dir):
        pathname = os.path.join(output_dir, self.fname)
        dir = os.path.dirname(pathname)
        if dir:
            try:
                os.makedirs(dir)
            except os.error as e:
                if e.errno != errno.EEXIST:
                    raise
        fd = os.open(pathname, os.O_RDWR | os.O_CREAT, 0o666)
        if sys.version_info[0] >= 3:
            f = open(fd, 'r+', encoding='utf-8')
        else:
            f = os.fdopen(fd, 'r+')
        text = self.get_content()
        oldtext = f.read(len(text) + 1)
        if text != oldtext:
            f.seek(0)
            f.truncate(0)
            f.write(text)
        f.close()


@contextmanager
def ifcontext(ifcond, *args):
    """A 'with' statement context manager to wrap with start_if()/end_if()

    *args: any number of QAPIGenCCode

    Example::

        with ifcontext(ifcond, self._genh, self._genc):
            modify self._genh and self._genc ...

    Is equivalent to calling::

        self._genh.start_if(ifcond)
        self._genc.start_if(ifcond)
        modify self._genh and self._genc ...
        self._genh.end_if()
        self._genc.end_if()
    """
    for arg in args:
        arg.start_if(ifcond)
    yield
    for arg in args:
        arg.end_if()


class QAPIGenCCode(QAPIGen):

    def __init__(self, fname):
        QAPIGen.__init__(self, fname)
        self._start_if = None

    def start_if(self, ifcond):
        assert self._start_if is None
        self._start_if = (ifcond, self._body, self._preamble)

    def end_if(self):
        assert self._start_if
        self._wrap_ifcond()
        self._start_if = None

    def _wrap_ifcond(self):
        self._body = _wrap_ifcond(self._start_if[0],
                                  self._start_if[1], self._body)
        self._preamble = _wrap_ifcond(self._start_if[0],
                                      self._start_if[2], self._preamble)

    def get_content(self):
        assert self._start_if is None
        return QAPIGen.get_content(self)


class QAPIGenC(QAPIGenCCode):

    def __init__(self, fname, blurb, pydoc):
        QAPIGenCCode.__init__(self, fname)
        self._blurb = blurb
        self._copyright = '\n * '.join(re.findall(r'^Copyright .*', pydoc,
                                                  re.MULTILINE))

    def _top(self):
        return mcgen('''
/* AUTOMATICALLY GENERATED, DO NOT MODIFY */

/*
%(blurb)s
 *
 * %(copyright)s
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.1 or later.
 * See the COPYING.LIB file in the top-level directory.
 */

''',
                     blurb=self._blurb, copyright=self._copyright)

    def _bottom(self):
        return mcgen('''

/* Dummy declaration to prevent empty .o file */
char qapi_dummy_%(name)s;
''',
                     name=c_fname(self.fname))


class QAPIGenH(QAPIGenC):

    def _top(self):
        return QAPIGenC._top(self) + guardstart(self.fname)

    def _bottom(self):
        return guardend(self.fname)


class QAPIGenDoc(QAPIGen):

    def _top(self):
        return (QAPIGen._top(self)
                + '@c AUTOMATICALLY GENERATED, DO NOT MODIFY\n\n')


class QAPISchemaMonolithicCVisitor(QAPISchemaVisitor):

    def __init__(self, prefix, what, blurb, pydoc):
        self._prefix = prefix
        self._what = what
        self._genc = QAPIGenC(self._prefix + self._what + '.c',
                              blurb, pydoc)
        self._genh = QAPIGenH(self._prefix + self._what + '.h',
                              blurb, pydoc)

    def write(self, output_dir):
        self._genc.write(output_dir)
        self._genh.write(output_dir)


class QAPISchemaModularCVisitor(QAPISchemaVisitor):

    def __init__(self, prefix, what, blurb, pydoc):
        self._prefix = prefix
        self._what = what
        self._blurb = blurb
        self._pydoc = pydoc
        self._genc = None
        self._genh = None
        self._module = {}
        self._main_module = None

    @staticmethod
    def _is_user_module(name):
        return name and not name.startswith('./')

    @staticmethod
    def _is_builtin_module(name):
        return not name

    def _module_dirname(self, what, name):
        if self._is_user_module(name):
            return os.path.dirname(name)
        return ''

    def _module_basename(self, what, name):
        ret = '' if self._is_builtin_module(name) else self._prefix
        if self._is_user_module(name):
            basename = os.path.basename(name)
            ret += what
            if name != self._main_module:
                ret += '-' + os.path.splitext(basename)[0]
        else:
            name = name[2:] if name else 'builtin'
            ret += re.sub(r'-', '-' + name + '-', what)
        return ret

    def _module_filename(self, what, name):
        return os.path.join(self._module_dirname(what, name),
                            self._module_basename(what, name))

    def _add_module(self, name, blurb):
        basename = self._module_filename(self._what, name)
        genc = QAPIGenC(basename + '.c', blurb, self._pydoc)
        genh = QAPIGenH(basename + '.h', blurb, self._pydoc)
        self._module[name] = (genc, genh)
        self._set_module(name)

    def _add_user_module(self, name, blurb):
        assert self._is_user_module(name)
        if self._main_module is None:
            self._main_module = name
        self._add_module(name, blurb)

    def _add_system_module(self, name, blurb):
        self._add_module(name and './' + name, blurb)

    def _set_module(self, name):
        self._genc, self._genh = self._module[name]

    def write(self, output_dir, opt_builtins=False):
        for name in self._module:
            if self._is_builtin_module(name) and not opt_builtins:
                continue
            (genc, genh) = self._module[name]
            genc.write(output_dir)
            genh.write(output_dir)

    def _begin_user_module(self, name):
        pass

    def visit_module(self, name):
        if name in self._module:
            self._set_module(name)
        elif self._is_builtin_module(name):
            # The built-in module has not been created.  No code may
            # be generated.
            self._genc = None
            self._genh = None
        else:
            self._add_user_module(name, self._blurb)
            self._begin_user_module(name)

    def visit_include(self, name, info):
        relname = os.path.relpath(self._module_filename(self._what, name),
                                  os.path.dirname(self._genh.fname))
        self._genh.preamble_add(mcgen('''
#include "%(relname)s.h"
''',
                                      relname=relname))
