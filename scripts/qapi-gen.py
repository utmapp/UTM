#!/usr/bin/env python3

# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.

"""
QAPI code generation execution shim.

This standalone script exists primarily to facilitate the running of the QAPI
code generator without needing to install the python module to the current
execution environment.
"""

import sys

from qapi import main

if __name__ == '__main__':
    sys.exit(main.main())
