#!/usr/bin/env python
# QAPI generator
#
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.

from __future__ import print_function
import argparse
import re
import sys
from qapi.common import QAPIError, QAPISchema
from qapi.types import gen_types
from qapi.visit import gen_visit
from qapi.commands import gen_commands
from qapi.events import gen_events
from qapi.introspect import gen_introspect
from qapi.doc import gen_doc


def main(argv):
    parser = argparse.ArgumentParser(
        description='Generate code from a QAPI schema')
    parser.add_argument('-b', '--builtins', action='store_true',
                        help="generate code for built-in types")
    parser.add_argument('-o', '--output-dir', action='store', default='',
                        help="write output to directory OUTPUT_DIR")
    parser.add_argument('-p', '--prefix', action='store', default='',
                        help="prefix for symbols")
    parser.add_argument('-u', '--unmask-non-abi-names', action='store_true',
                        dest='unmask',
                        help="expose non-ABI names in introspection")
    parser.add_argument('schema', action='store')
    args = parser.parse_args()

    match = re.match(r'([A-Za-z_.-][A-Za-z0-9_.-]*)?', args.prefix)
    if match.end() != len(args.prefix):
        print("%s: 'funny character '%s' in argument of --prefix"
              % (sys.argv[0], args.prefix[match.end()]),
              file=sys.stderr)
        sys.exit(1)

    try:
        schema = QAPISchema(args.schema)
    except QAPIError as err:
        print(err, file=sys.stderr)
        exit(1)

    gen_types(schema, args.output_dir, args.prefix, args.builtins)
    gen_visit(schema, args.output_dir, args.prefix, args.builtins)
    gen_commands(schema, args.output_dir, args.prefix)
    gen_events(schema, args.output_dir, args.prefix)
    gen_introspect(schema, args.output_dir, args.prefix, args.unmask)
    gen_doc(schema, args.output_dir, args.prefix)


if __name__ == '__main__':
    main(sys.argv)
