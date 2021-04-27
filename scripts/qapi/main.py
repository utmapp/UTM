# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.

"""
QAPI Generator

This is the main entry point for generating C code from the QAPI schema.
"""

import argparse
import re
import sys
from typing import Optional

from .commands import gen_commands
from .error import QAPIError
from .events import gen_events
#from .introspect import gen_introspect
from .schema import QAPISchema
from .types import gen_types
from .visit import gen_visit


def invalid_prefix_char(prefix: str) -> Optional[str]:
    match = re.match(r'([A-Za-z_.-][A-Za-z0-9_.-]*)?', prefix)
    # match cannot be None, but mypy cannot infer that.
    assert match is not None
    if match.end() != len(prefix):
        return prefix[match.end()]
    return None


def generate(schema_file: str,
             output_dir: str,
             prefix: str,
             unmask: bool = False,
             builtins: bool = False) -> None:
    """
    Generate C code for the given schema into the target directory.

    :param schema_file: The primary QAPI schema file.
    :param output_dir: The output directory to store generated code.
    :param prefix: Optional C-code prefix for symbol names.
    :param unmask: Expose non-ABI names through introspection?
    :param builtins: Generate code for built-in types?

    :raise QAPIError: On failures.
    """
    assert invalid_prefix_char(prefix) is None

    schema = QAPISchema(schema_file)
    gen_types(schema, output_dir, prefix, builtins)
    gen_visit(schema, output_dir, prefix, builtins)
    gen_commands(schema, output_dir, prefix)
    gen_events(schema, output_dir, prefix)
    #gen_introspect(schema, output_dir, prefix, unmask)


def main() -> int:
    """
    gapi-gen executable entry point.
    Expects arguments via sys.argv, see --help for details.

    :return: int, 0 on success, 1 on failure.
    """
    parser = argparse.ArgumentParser(
        description='Generate code from a QAPI schema')
    parser.add_argument('-b', '--builtins', action='store_true',
                        help="generate code for built-in types")
    parser.add_argument('-o', '--output-dir', action='store',
                        default='',
                        help="write output to directory OUTPUT_DIR")
    parser.add_argument('-p', '--prefix', action='store',
                        default='',
                        help="prefix for symbols")
    parser.add_argument('-u', '--unmask-non-abi-names', action='store_true',
                        dest='unmask',
                        help="expose non-ABI names in introspection")
    parser.add_argument('schema', action='store')
    args = parser.parse_args()

    funny_char = invalid_prefix_char(args.prefix)
    if funny_char:
        msg = f"funny character '{funny_char}' in argument of --prefix"
        print(f"{sys.argv[0]}: {msg}", file=sys.stderr)
        return 1

    try:
        generate(args.schema,
                 output_dir=args.output_dir,
                 prefix=args.prefix,
                 unmask=args.unmask,
                 builtins=args.builtins)
    except QAPIError as err:
        print(f"{sys.argv[0]}: {str(err)}", file=sys.stderr)
        return 1
    return 0
