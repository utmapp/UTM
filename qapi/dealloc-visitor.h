/*
 * Dealloc Visitor
 *
 * Copyright IBM, Corp. 2011
 *
 * Authors:
 *  Michael Roth   <mdroth@linux.vnet.ibm.com>
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.1 or later.
 * See the COPYING.LIB file in the top-level directory.
 *
 */

#ifndef QAPI_DEALLOC_VISITOR_H
#define QAPI_DEALLOC_VISITOR_H

#include "visitor.h"

typedef struct QapiDeallocVisitor QapiDeallocVisitor;

/*
 * The dealloc visitor is primarily used only by generated
 * qapi_free_FOO() functions, and is the only visitor designed to work
 * correctly in the face of a partially-constructed QAPI tree.
 */
Visitor *qapi_dealloc_visitor_new(void);

#endif
