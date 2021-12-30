# -*- coding: utf-8 -*-
#
# QAPI schema parser
#
# Copyright IBM, Corp. 2011
# Copyright (c) 2013-2019 Red Hat Inc.
#
# Authors:
#  Anthony Liguori <aliguori@us.ibm.com>
#  Markus Armbruster <armbru@redhat.com>
#  Marc-André Lureau <marcandre.lureau@redhat.com>
#  Kevin Wolf <kwolf@redhat.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.
# See the COPYING file in the top-level directory.

from collections import OrderedDict
import os
import re
from typing import (
    TYPE_CHECKING,
    Dict,
    List,
    Optional,
    Set,
    Union,
)

from .common import must_match
from .error import QAPISemError, QAPISourceError
from .source import QAPISourceInfo


if TYPE_CHECKING:
    # pylint: disable=cyclic-import
    # TODO: Remove cycle. [schema -> expr -> parser -> schema]
    from .schema import QAPISchemaFeature, QAPISchemaMember


#: Represents a single Top Level QAPI schema expression.
TopLevelExpr = Dict[str, object]

# Return value alias for get_expr().
_ExprValue = Union[List[object], Dict[str, object], str, bool]

# FIXME: Consolidate and centralize definitions for TopLevelExpr,
# _ExprValue, _JSONValue, and _JSONObject; currently scattered across
# several modules.


class QAPIParseError(QAPISourceError):
    """Error class for all QAPI schema parsing errors."""
    def __init__(self, parser: 'QAPISchemaParser', msg: str):
        col = 1
        for ch in parser.src[parser.line_pos:parser.pos]:
            if ch == '\t':
                col = (col + 7) % 8 + 1
            else:
                col += 1
        super().__init__(parser.info, msg, col)


class QAPISchemaParser:
    """
    Parse QAPI schema source.

    Parse a JSON-esque schema file and process directives.  See
    qapi-code-gen.txt section "Schema Syntax" for the exact syntax.
    Grammatical validation is handled later by `expr.check_exprs()`.

    :param fname: Source file name.
    :param previously_included:
        The absolute names of previously included source files,
        if being invoked from another parser.
    :param incl_info:
       `QAPISourceInfo` belonging to the parent module.
       ``None`` implies this is the root module.

    :ivar exprs: Resulting parsed expressions.
    :ivar docs: Resulting parsed documentation blocks.

    :raise OSError: For problems reading the root schema document.
    :raise QAPIError: For errors in the schema source.
    """
    def __init__(self,
                 fname: str,
                 previously_included: Optional[Set[str]] = None,
                 incl_info: Optional[QAPISourceInfo] = None):
        self._fname = fname
        self._included = previously_included or set()
        self._included.add(os.path.abspath(self._fname))
        self.src = ''

        # Lexer state (see `accept` for details):
        self.info = QAPISourceInfo(self._fname, incl_info)
        self.tok: Union[None, str] = None
        self.pos = 0
        self.cursor = 0
        self.val: Optional[Union[bool, str]] = None
        self.line_pos = 0

        # Parser output:
        self.exprs: List[Dict[str, object]] = []
        self.docs: List[QAPIDoc] = []

        # Showtime!
        self._parse()

    def _parse(self) -> None:
        """
        Parse the QAPI schema document.

        :return: None.  Results are stored in ``.exprs`` and ``.docs``.
        """
        cur_doc = None

        # May raise OSError; allow the caller to handle it.
        with open(self._fname, 'r', encoding='utf-8') as fp:
            self.src = fp.read()
        if self.src == '' or self.src[-1] != '\n':
            self.src += '\n'

        # Prime the lexer:
        self.accept()

        # Parse until done:
        while self.tok is not None:
            info = self.info
            if self.tok == '#':
                self.reject_expr_doc(cur_doc)
                for cur_doc in self.get_doc(info):
                    self.docs.append(cur_doc)
                continue

            expr = self.get_expr()
            if not isinstance(expr, dict):
                raise QAPISemError(
                    info, "top-level expression must be an object")

            if 'include' in expr:
                self.reject_expr_doc(cur_doc)
                if len(expr) != 1:
                    raise QAPISemError(info, "invalid 'include' directive")
                include = expr['include']
                if not isinstance(include, str):
                    raise QAPISemError(info,
                                       "value of 'include' must be a string")
                incl_fname = os.path.join(os.path.dirname(self._fname),
                                          include)
                self.exprs.append({'expr': {'include': incl_fname},
                                   'info': info})
                exprs_include = self._include(include, info, incl_fname,
                                              self._included)
                if exprs_include:
                    self.exprs.extend(exprs_include.exprs)
                    self.docs.extend(exprs_include.docs)
            elif "pragma" in expr:
                self.reject_expr_doc(cur_doc)
                if len(expr) != 1:
                    raise QAPISemError(info, "invalid 'pragma' directive")
                pragma = expr['pragma']
                if not isinstance(pragma, dict):
                    raise QAPISemError(
                        info, "value of 'pragma' must be an object")
                for name, value in pragma.items():
                    self._pragma(name, value, info)
            else:
                expr_elem = {'expr': expr,
                             'info': info}
                if cur_doc:
                    if not cur_doc.symbol:
                        raise QAPISemError(
                            cur_doc.info, "definition documentation required")
                    expr_elem['doc'] = cur_doc
                self.exprs.append(expr_elem)
            cur_doc = None
        self.reject_expr_doc(cur_doc)

    @staticmethod
    def reject_expr_doc(doc: Optional['QAPIDoc']) -> None:
        if doc and doc.symbol:
            raise QAPISemError(
                doc.info,
                "documentation for '%s' is not followed by the definition"
                % doc.symbol)

    @staticmethod
    def _include(include: str,
                 info: QAPISourceInfo,
                 incl_fname: str,
                 previously_included: Set[str]
                 ) -> Optional['QAPISchemaParser']:
        incl_abs_fname = os.path.abspath(incl_fname)
        # catch inclusion cycle
        inf: Optional[QAPISourceInfo] = info
        while inf:
            if incl_abs_fname == os.path.abspath(inf.fname):
                raise QAPISemError(info, "inclusion loop for %s" % include)
            inf = inf.parent

        # skip multiple include of the same file
        if incl_abs_fname in previously_included:
            return None

        try:
            return QAPISchemaParser(incl_fname, previously_included, info)
        except OSError as err:
            raise QAPISemError(
                info,
                f"can't read include file '{incl_fname}': {err.strerror}"
            ) from err

    @staticmethod
    def _pragma(name: str, value: object, info: QAPISourceInfo) -> None:

        def check_list_str(name: str, value: object) -> List[str]:
            if (not isinstance(value, list) or
                    any(not isinstance(elt, str) for elt in value)):
                raise QAPISemError(
                    info,
                    "pragma %s must be a list of strings" % name)
            return value

        pragma = info.pragma

        if name == 'doc-required':
            if not isinstance(value, bool):
                raise QAPISemError(info,
                                   "pragma 'doc-required' must be boolean")
            pragma.doc_required = value
        elif name == 'command-name-exceptions':
            pragma.command_name_exceptions = check_list_str(name, value)
        elif name == 'command-returns-exceptions':
            pragma.command_returns_exceptions = check_list_str(name, value)
        elif name == 'member-name-exceptions':
            pragma.member_name_exceptions = check_list_str(name, value)
        else:
            raise QAPISemError(info, "unknown pragma '%s'" % name)

    def accept(self, skip_comment: bool = True) -> None:
        """
        Read and store the next token.

        :param skip_comment:
            When false, return COMMENT tokens ("#").
            This is used when reading documentation blocks.

        :return:
            None.  Several instance attributes are updated instead:

            - ``.tok`` represents the token type.  See below for values.
            - ``.info`` describes the token's source location.
            - ``.val`` is the token's value, if any.  See below.
            - ``.pos`` is the buffer index of the first character of
              the token.

        * Single-character tokens:

            These are "{", "}", ":", ",", "[", and "]".
            ``.tok`` holds the single character and ``.val`` is None.

        * Multi-character tokens:

          * COMMENT:

            This token is not normally returned by the lexer, but it can
            be when ``skip_comment`` is False.  ``.tok`` is "#", and
            ``.val`` is a string including all chars until end-of-line,
            including the "#" itself.

          * STRING:

            ``.tok`` is "'", the single quote.  ``.val`` contains the
            string, excluding the surrounding quotes.

          * TRUE and FALSE:

            ``.tok`` is either "t" or "f", ``.val`` will be the
            corresponding bool value.

          * EOF:

            ``.tok`` and ``.val`` will both be None at EOF.
        """
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
                # Note: we accept only printable ASCII
                string = ''
                esc = False
                while True:
                    ch = self.src[self.cursor]
                    self.cursor += 1
                    if ch == '\n':
                        raise QAPIParseError(self, "missing terminating \"'\"")
                    if esc:
                        # Note: we recognize only \\ because we have
                        # no use for funny characters in strings
                        if ch != '\\':
                            raise QAPIParseError(self,
                                                 "unknown escape \\%s" % ch)
                        esc = False
                    elif ch == '\\':
                        esc = True
                        continue
                    elif ch == "'":
                        self.val = string
                        return
                    if ord(ch) < 32 or ord(ch) >= 127:
                        raise QAPIParseError(
                            self, "funny character in string")
                    string += ch
            elif self.src.startswith('true', self.pos):
                self.val = True
                self.cursor += 3
                return
            elif self.src.startswith('false', self.pos):
                self.val = False
                self.cursor += 4
                return
            elif self.tok == '\n':
                if self.cursor == len(self.src):
                    self.tok = None
                    return
                self.info = self.info.next_line()
                self.line_pos = self.cursor
            elif not self.tok.isspace():
                # Show up to next structural, whitespace or quote
                # character
                match = must_match('[^[\\]{}:,\\s\'"]+',
                                   self.src[self.cursor-1:])
                raise QAPIParseError(self, "stray '%s'" % match.group(0))

    def get_members(self) -> Dict[str, object]:
        expr: Dict[str, object] = OrderedDict()
        if self.tok == '}':
            self.accept()
            return expr
        if self.tok != "'":
            raise QAPIParseError(self, "expected string or '}'")
        while True:
            key = self.val
            assert isinstance(key, str)  # Guaranteed by tok == "'"

            self.accept()
            if self.tok != ':':
                raise QAPIParseError(self, "expected ':'")
            self.accept()
            if key in expr:
                raise QAPIParseError(self, "duplicate key '%s'" % key)
            expr[key] = self.get_expr()
            if self.tok == '}':
                self.accept()
                return expr
            if self.tok != ',':
                raise QAPIParseError(self, "expected ',' or '}'")
            self.accept()
            if self.tok != "'":
                raise QAPIParseError(self, "expected string")

    def get_values(self) -> List[object]:
        expr: List[object] = []
        if self.tok == ']':
            self.accept()
            return expr
        if self.tok not in tuple("{['tf"):
            raise QAPIParseError(
                self, "expected '{', '[', ']', string, or boolean")
        while True:
            expr.append(self.get_expr())
            if self.tok == ']':
                self.accept()
                return expr
            if self.tok != ',':
                raise QAPIParseError(self, "expected ',' or ']'")
            self.accept()

    def get_expr(self) -> _ExprValue:
        expr: _ExprValue
        if self.tok == '{':
            self.accept()
            expr = self.get_members()
        elif self.tok == '[':
            self.accept()
            expr = self.get_values()
        elif self.tok in tuple("'tf"):
            assert isinstance(self.val, (str, bool))
            expr = self.val
            self.accept()
        else:
            raise QAPIParseError(
                self, "expected '{', '[', string, or boolean")
        return expr

    def get_doc(self, info: QAPISourceInfo) -> List['QAPIDoc']:
        if self.val != '##':
            raise QAPIParseError(
                self, "junk after '##' at start of documentation comment")

        docs = []
        cur_doc = QAPIDoc(self, info)
        self.accept(False)
        while self.tok == '#':
            assert isinstance(self.val, str)
            if self.val.startswith('##'):
                # End of doc comment
                if self.val != '##':
                    raise QAPIParseError(
                        self,
                        "junk after '##' at end of documentation comment")
                cur_doc.end_comment()
                docs.append(cur_doc)
                self.accept()
                return docs
            if self.val.startswith('# ='):
                if cur_doc.symbol:
                    raise QAPIParseError(
                        self,
                        "unexpected '=' markup in definition documentation")
                if cur_doc.body.text:
                    cur_doc.end_comment()
                    docs.append(cur_doc)
                    cur_doc = QAPIDoc(self, info)
            cur_doc.append(self.val)
            self.accept(False)

        raise QAPIParseError(self, "documentation comment must end with '##'")


class QAPIDoc:
    """
    A documentation comment block, either definition or free-form

    Definition documentation blocks consist of

    * a body section: one line naming the definition, followed by an
      overview (any number of lines)

    * argument sections: a description of each argument (for commands
      and events) or member (for structs, unions and alternates)

    * features sections: a description of each feature flag

    * additional (non-argument) sections, possibly tagged

    Free-form documentation blocks consist only of a body section.
    """

    class Section:
        # pylint: disable=too-few-public-methods
        def __init__(self, parser: QAPISchemaParser,
                     name: Optional[str] = None, indent: int = 0):

            # parser, for error messages about indentation
            self._parser = parser
            # optional section name (argument/member or section name)
            self.name = name
            self.text = ''
            # the expected indent level of the text of this section
            self._indent = indent

        def append(self, line: str) -> None:
            # Strip leading spaces corresponding to the expected indent level
            # Blank lines are always OK.
            if line:
                indent = must_match(r'\s*', line).end()
                if indent < self._indent:
                    raise QAPIParseError(
                        self._parser,
                        "unexpected de-indent (expected at least %d spaces)" %
                        self._indent)
                line = line[self._indent:]

            self.text += line.rstrip() + '\n'

    class ArgSection(Section):
        def __init__(self, parser: QAPISchemaParser,
                     name: str, indent: int = 0):
            super().__init__(parser, name, indent)
            self.member: Optional['QAPISchemaMember'] = None

        def connect(self, member: 'QAPISchemaMember') -> None:
            self.member = member

    class NullSection(Section):
        """
        Immutable dummy section for use at the end of a doc block.
        """
        # pylint: disable=too-few-public-methods
        def append(self, line: str) -> None:
            assert False, "Text appended after end_comment() called."

    def __init__(self, parser: QAPISchemaParser, info: QAPISourceInfo):
        # self._parser is used to report errors with QAPIParseError.  The
        # resulting error position depends on the state of the parser.
        # It happens to be the beginning of the comment.  More or less
        # servicable, but action at a distance.
        self._parser = parser
        self.info = info
        self.symbol: Optional[str] = None
        self.body = QAPIDoc.Section(parser)
        # dicts mapping parameter/feature names to their ArgSection
        self.args: Dict[str, QAPIDoc.ArgSection] = OrderedDict()
        self.features: Dict[str, QAPIDoc.ArgSection] = OrderedDict()
        self.sections: List[QAPIDoc.Section] = []
        # the current section
        self._section = self.body
        self._append_line = self._append_body_line

    def has_section(self, name: str) -> bool:
        """Return True if we have a section with this name."""
        for i in self.sections:
            if i.name == name:
                return True
        return False

    def append(self, line: str) -> None:
        """
        Parse a comment line and add it to the documentation.

        The way that the line is dealt with depends on which part of
        the documentation we're parsing right now:
        * The body section: ._append_line is ._append_body_line
        * An argument section: ._append_line is ._append_args_line
        * A features section: ._append_line is ._append_features_line
        * An additional section: ._append_line is ._append_various_line
        """
        line = line[1:]
        if not line:
            self._append_freeform(line)
            return

        if line[0] != ' ':
            raise QAPIParseError(self._parser, "missing space after #")
        line = line[1:]
        self._append_line(line)

    def end_comment(self) -> None:
        self._switch_section(QAPIDoc.NullSection(self._parser))

    @staticmethod
    def _is_section_tag(name: str) -> bool:
        return name in ('Returns:', 'Since:',
                        # those are often singular or plural
                        'Note:', 'Notes:',
                        'Example:', 'Examples:',
                        'TODO:')

    def _append_body_line(self, line: str) -> None:
        """
        Process a line of documentation text in the body section.

        If this a symbol line and it is the section's first line, this
        is a definition documentation block for that symbol.

        If it's a definition documentation block, another symbol line
        begins the argument section for the argument named by it, and
        a section tag begins an additional section.  Start that
        section and append the line to it.

        Else, append the line to the current section.
        """
        name = line.split(' ', 1)[0]
        # FIXME not nice: things like '#  @foo:' and '# @foo: ' aren't
        # recognized, and get silently treated as ordinary text
        if not self.symbol and not self.body.text and line.startswith('@'):
            if not line.endswith(':'):
                raise QAPIParseError(self._parser, "line should end with ':'")
            self.symbol = line[1:-1]
            # Invalid names are not checked here, but the name provided MUST
            # match the following definition, which *is* validated in expr.py.
            if not self.symbol:
                raise QAPIParseError(
                    self._parser, "name required after '@'")
        elif self.symbol:
            # This is a definition documentation block
            if name.startswith('@') and name.endswith(':'):
                self._append_line = self._append_args_line
                self._append_args_line(line)
            elif line == 'Features:':
                self._append_line = self._append_features_line
            elif self._is_section_tag(name):
                self._append_line = self._append_various_line
                self._append_various_line(line)
            else:
                self._append_freeform(line)
        else:
            # This is a free-form documentation block
            self._append_freeform(line)

    def _append_args_line(self, line: str) -> None:
        """
        Process a line of documentation text in an argument section.

        A symbol line begins the next argument section, a section tag
        section or a non-indented line after a blank line begins an
        additional section.  Start that section and append the line to
        it.

        Else, append the line to the current section.

        """
        name = line.split(' ', 1)[0]

        if name.startswith('@') and name.endswith(':'):
            # If line is "@arg:   first line of description", find
            # the index of 'f', which is the indent we expect for any
            # following lines.  We then remove the leading "@arg:"
            # from line and replace it with spaces so that 'f' has the
            # same index as it did in the original line and can be
            # handled the same way we will handle following lines.
            indent = must_match(r'@\S*:\s*', line).end()
            line = line[indent:]
            if not line:
                # Line was just the "@arg:" header; following lines
                # are not indented
                indent = 0
            else:
                line = ' ' * indent + line
            self._start_args_section(name[1:-1], indent)
        elif self._is_section_tag(name):
            self._append_line = self._append_various_line
            self._append_various_line(line)
            return
        elif (self._section.text.endswith('\n\n')
              and line and not line[0].isspace()):
            if line == 'Features:':
                self._append_line = self._append_features_line
            else:
                self._start_section()
                self._append_line = self._append_various_line
                self._append_various_line(line)
            return

        self._append_freeform(line)

    def _append_features_line(self, line: str) -> None:
        name = line.split(' ', 1)[0]

        if name.startswith('@') and name.endswith(':'):
            # If line is "@arg:   first line of description", find
            # the index of 'f', which is the indent we expect for any
            # following lines.  We then remove the leading "@arg:"
            # from line and replace it with spaces so that 'f' has the
            # same index as it did in the original line and can be
            # handled the same way we will handle following lines.
            indent = must_match(r'@\S*:\s*', line).end()
            line = line[indent:]
            if not line:
                # Line was just the "@arg:" header; following lines
                # are not indented
                indent = 0
            else:
                line = ' ' * indent + line
            self._start_features_section(name[1:-1], indent)
        elif self._is_section_tag(name):
            self._append_line = self._append_various_line
            self._append_various_line(line)
            return
        elif (self._section.text.endswith('\n\n')
              and line and not line[0].isspace()):
            self._start_section()
            self._append_line = self._append_various_line
            self._append_various_line(line)
            return

        self._append_freeform(line)

    def _append_various_line(self, line: str) -> None:
        """
        Process a line of documentation text in an additional section.

        A symbol line is an error.

        A section tag begins an additional section.  Start that
        section and append the line to it.

        Else, append the line to the current section.
        """
        name = line.split(' ', 1)[0]

        if name.startswith('@') and name.endswith(':'):
            raise QAPIParseError(self._parser,
                                 "'%s' can't follow '%s' section"
                                 % (name, self.sections[0].name))
        if self._is_section_tag(name):
            # If line is "Section:   first line of description", find
            # the index of 'f', which is the indent we expect for any
            # following lines.  We then remove the leading "Section:"
            # from line and replace it with spaces so that 'f' has the
            # same index as it did in the original line and can be
            # handled the same way we will handle following lines.
            indent = must_match(r'\S*:\s*', line).end()
            line = line[indent:]
            if not line:
                # Line was just the "Section:" header; following lines
                # are not indented
                indent = 0
            else:
                line = ' ' * indent + line
            self._start_section(name[:-1], indent)

        self._append_freeform(line)

    def _start_symbol_section(
            self,
            symbols_dict: Dict[str, 'QAPIDoc.ArgSection'],
            name: str,
            indent: int) -> None:
        # FIXME invalid names other than the empty string aren't flagged
        if not name:
            raise QAPIParseError(self._parser, "invalid parameter name")
        if name in symbols_dict:
            raise QAPIParseError(self._parser,
                                 "'%s' parameter name duplicated" % name)
        assert not self.sections
        new_section = QAPIDoc.ArgSection(self._parser, name, indent)
        self._switch_section(new_section)
        symbols_dict[name] = new_section

    def _start_args_section(self, name: str, indent: int) -> None:
        self._start_symbol_section(self.args, name, indent)

    def _start_features_section(self, name: str, indent: int) -> None:
        self._start_symbol_section(self.features, name, indent)

    def _start_section(self, name: Optional[str] = None,
                       indent: int = 0) -> None:
        if name in ('Returns', 'Since') and self.has_section(name):
            raise QAPIParseError(self._parser,
                                 "duplicated '%s' section" % name)
        new_section = QAPIDoc.Section(self._parser, name, indent)
        self._switch_section(new_section)
        self.sections.append(new_section)

    def _switch_section(self, new_section: 'QAPIDoc.Section') -> None:
        text = self._section.text = self._section.text.strip()

        # Only the 'body' section is allowed to have an empty body.
        # All other sections, including anonymous ones, must have text.
        if self._section != self.body and not text:
            # We do not create anonymous sections unless there is
            # something to put in them; this is a parser bug.
            assert self._section.name
            raise QAPIParseError(
                self._parser,
                "empty doc section '%s'" % self._section.name)

        self._section = new_section

    def _append_freeform(self, line: str) -> None:
        match = re.match(r'(@\S+:)', line)
        if match:
            raise QAPIParseError(self._parser,
                                 "'%s' not allowed in free-form documentation"
                                 % match.group(1))
        self._section.append(line)

    def connect_member(self, member: 'QAPISchemaMember') -> None:
        if member.name not in self.args:
            # Undocumented TODO outlaw
            self.args[member.name] = QAPIDoc.ArgSection(self._parser,
                                                        member.name)
        self.args[member.name].connect(member)

    def connect_feature(self, feature: 'QAPISchemaFeature') -> None:
        if feature.name not in self.features:
            raise QAPISemError(feature.info,
                               "feature '%s' lacks documentation"
                               % feature.name)
        self.features[feature.name].connect(feature)

    def check_expr(self, expr: TopLevelExpr) -> None:
        if self.has_section('Returns') and 'command' not in expr:
            raise QAPISemError(self.info,
                               "'Returns:' is only valid for commands")

    def check(self) -> None:

        def check_args_section(
                args: Dict[str, QAPIDoc.ArgSection], what: str
        ) -> None:
            bogus = [name for name, section in args.items()
                     if not section.member]
            if bogus:
                raise QAPISemError(
                    self.info,
                    "documented %s%s '%s' %s not exist" % (
                        what,
                        "s" if len(bogus) > 1 else "",
                        "', '".join(bogus),
                        "do" if len(bogus) > 1 else "does"
                    ))

        check_args_section(self.args, 'member')
        check_args_section(self.features, 'feature')
