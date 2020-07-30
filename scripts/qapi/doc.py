# QAPI texi generator
#
# This work is licensed under the terms of the GNU LGPL, version 2+.
# See the COPYING file in the top-level directory.
"""This script produces the documentation of a qapi schema in texinfo format"""

import re
from qapi.gen import QAPIGenDoc, QAPISchemaVisitor


MSG_FMT = """
@deftypefn {type} {{}} {name}

{body}{members}{features}{sections}
@end deftypefn

""".format

TYPE_FMT = """
@deftp {{{type}}} {name}

{body}{members}{features}{sections}
@end deftp

""".format

EXAMPLE_FMT = """@example
{code}
@end example
""".format


def subst_strong(doc):
    """Replaces *foo* by @strong{foo}"""
    return re.sub(r'\*([^*\n]+)\*', r'@strong{\1}', doc)


def subst_emph(doc):
    """Replaces _foo_ by @emph{foo}"""
    return re.sub(r'\b_([^_\n]+)_\b', r'@emph{\1}', doc)


def subst_vars(doc):
    """Replaces @var by @code{var}"""
    return re.sub(r'@([\w-]+)', r'@code{\1}', doc)


def subst_braces(doc):
    """Replaces {} with @{ @}"""
    return doc.replace('{', '@{').replace('}', '@}')


def texi_example(doc):
    """Format @example"""
    # TODO: Neglects to escape @ characters.
    # We should probably escape them in subst_braces(), and rename the
    # function to subst_special() or subs_texi_special().  If we do that, we
    # need to delay it until after subst_vars() in texi_format().
    doc = subst_braces(doc).strip('\n')
    return EXAMPLE_FMT(code=doc)


def texi_format(doc):
    """
    Format documentation

    Lines starting with:
    - |: generates an @example
    - =: generates @section
    - ==: generates @subsection
    - 1. or 1): generates an @enumerate @item
    - */-: generates an @itemize list
    """
    ret = ''
    doc = subst_braces(doc)
    doc = subst_vars(doc)
    doc = subst_emph(doc)
    doc = subst_strong(doc)
    inlist = ''
    lastempty = False
    for line in doc.split('\n'):
        empty = line == ''

        # FIXME: Doing this in a single if / elif chain is
        # problematic.  For instance, a line without markup terminates
        # a list if it follows a blank line (reaches the final elif),
        # but a line with some *other* markup, such as a = title
        # doesn't.
        #
        # Make sure to update section "Documentation markup" in
        # docs/devel/qapi-code-gen.txt when fixing this.
        if line.startswith('| '):
            line = EXAMPLE_FMT(code=line[2:])
        elif line.startswith('= '):
            line = '@section ' + line[2:]
        elif line.startswith('== '):
            line = '@subsection ' + line[3:]
        elif re.match(r'^([0-9]*\.) ', line):
            if not inlist:
                ret += '@enumerate\n'
                inlist = 'enumerate'
            ret += '@item\n'
            line = line[line.find(' ')+1:]
        elif re.match(r'^[*-] ', line):
            if not inlist:
                ret += '@itemize %s\n' % {'*': '@bullet',
                                          '-': '@minus'}[line[0]]
                inlist = 'itemize'
            ret += '@item\n'
            line = line[2:]
        elif lastempty and inlist:
            ret += '@end %s\n\n' % inlist
            inlist = ''

        lastempty = empty
        ret += line + '\n'

    if inlist:
        ret += '@end %s\n\n' % inlist
    return ret


def texi_body(doc):
    """Format the main documentation body"""
    return texi_format(doc.body.text)


def texi_if(ifcond, prefix='\n', suffix='\n'):
    """Format the #if condition"""
    if not ifcond:
        return ''
    return '%s@b{If:} @code{%s}%s' % (prefix, ', '.join(ifcond), suffix)


def texi_enum_value(value, desc, suffix):
    """Format a table of members item for an enumeration value"""
    return '@item @code{%s}\n%s%s' % (
        value.name, desc, texi_if(value.ifcond, prefix='@*'))


def texi_member(member, desc, suffix):
    """Format a table of members item for an object type member"""
    typ = member.type.doc_type()
    membertype = ': ' + typ if typ else ''
    return '@item @code{%s%s}%s%s\n%s%s' % (
        member.name, membertype,
        ' (optional)' if member.optional else '',
        suffix, desc, texi_if(member.ifcond, prefix='@*'))


def texi_members(doc, what, base=None, variants=None,
                 member_func=texi_member):
    """Format the table of members"""
    items = ''
    for section in doc.args.values():
        # TODO Drop fallbacks when undocumented members are outlawed
        if section.text:
            desc = texi_format(section.text)
        elif (variants and variants.tag_member == section.member
              and not section.member.type.doc_type()):
            values = section.member.type.member_names()
            members_text = ', '.join(['@t{"%s"}' % v for v in values])
            desc = 'One of ' + members_text + '\n'
        else:
            desc = 'Not documented\n'
        items += member_func(section.member, desc, suffix='')
    if base:
        items += '@item The members of @code{%s}\n' % base.doc_type()
    if variants:
        for v in variants.variants:
            when = ' when @code{%s} is @t{"%s"}%s' % (
                variants.tag_member.name, v.name, texi_if(v.ifcond, " (", ")"))
            if v.type.is_implicit():
                assert not v.type.base and not v.type.variants
                for m in v.type.local_members:
                    items += member_func(m, desc='', suffix=when)
            else:
                items += '@item The members of @code{%s}%s\n' % (
                    v.type.doc_type(), when)
    if not items:
        return ''
    return '\n@b{%s:}\n@table @asis\n%s@end table\n' % (what, items)


def texi_arguments(doc, boxed_arg_type):
    if boxed_arg_type:
        assert not doc.args
        return ('\n@b{Arguments:} the members of @code{%s}\n'
                % boxed_arg_type.name)
    return texi_members(doc, 'Arguments')


def texi_features(doc):
    """Format the table of features"""
    items = ''
    for section in doc.features.values():
        desc = texi_format(section.text)
        items += '@item @code{%s}\n%s' % (section.name, desc)
    if not items:
        return ''
    return '\n@b{Features:}\n@table @asis\n%s@end table\n' % (items)


def texi_sections(doc, ifcond):
    """Format additional sections following arguments"""
    body = ''
    for section in doc.sections:
        if section.name:
            # prefer @b over @strong, so txt doesn't translate it to *Foo:*
            body += '\n@b{%s:}\n' % section.name
        if section.name and section.name.startswith('Example'):
            body += texi_example(section.text)
        else:
            body += texi_format(section.text)
    body += texi_if(ifcond, suffix='')
    return body


def texi_type(typ, doc, ifcond, members):
    return TYPE_FMT(type=typ,
                    name=doc.symbol,
                    body=texi_body(doc),
                    members=members,
                    features=texi_features(doc),
                    sections=texi_sections(doc, ifcond))


def texi_msg(typ, doc, ifcond, members):
    return MSG_FMT(type=typ,
                   name=doc.symbol,
                   body=texi_body(doc),
                   members=members,
                   features=texi_features(doc),
                   sections=texi_sections(doc, ifcond))


class QAPISchemaGenDocVisitor(QAPISchemaVisitor):
    def __init__(self, prefix):
        self._prefix = prefix
        self._gen = QAPIGenDoc(self._prefix + 'qapi-doc.texi')
        self.cur_doc = None

    def write(self, output_dir):
        self._gen.write(output_dir)

    def visit_enum_type(self, name, info, ifcond, features, members, prefix):
        doc = self.cur_doc
        self._gen.add(texi_type('Enum', doc, ifcond,
                                texi_members(doc, 'Values',
                                             member_func=texi_enum_value)))

    def visit_object_type(self, name, info, ifcond, features,
                          base, members, variants):
        doc = self.cur_doc
        if base and base.is_implicit():
            base = None
        self._gen.add(texi_type('Object', doc, ifcond,
                                texi_members(doc, 'Members', base, variants)))

    def visit_alternate_type(self, name, info, ifcond, features, variants):
        doc = self.cur_doc
        self._gen.add(texi_type('Alternate', doc, ifcond,
                                texi_members(doc, 'Members')))

    def visit_command(self, name, info, ifcond, features,
                      arg_type, ret_type, gen, success_response, boxed,
                      allow_oob, allow_preconfig):
        doc = self.cur_doc
        self._gen.add(texi_msg('Command', doc, ifcond,
                               texi_arguments(doc,
                                              arg_type if boxed else None)))

    def visit_event(self, name, info, ifcond, features, arg_type, boxed):
        doc = self.cur_doc
        self._gen.add(texi_msg('Event', doc, ifcond,
                               texi_arguments(doc,
                                              arg_type if boxed else None)))

    def symbol(self, doc, entity):
        if self._gen._body:
            self._gen.add('\n')
        self.cur_doc = doc
        entity.visit(self)
        self.cur_doc = None

    def freeform(self, doc):
        assert not doc.args
        if self._gen._body:
            self._gen.add('\n')
        self._gen.add(texi_body(doc) + texi_sections(doc, None))


def gen_doc(schema, output_dir, prefix):
    vis = QAPISchemaGenDocVisitor(prefix)
    vis.visit_begin(schema)
    for doc in schema.docs:
        if doc.symbol:
            vis.symbol(doc, schema.lookup_entity(doc.symbol))
        else:
            vis.freeform(doc)
    vis.write(output_dir)
