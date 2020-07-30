/*
 * Dealloc Visitor
 *
 * Copyright (C) 2012-2016 Red Hat, Inc.
 * Copyright IBM, Corp. 2011
 *
 * Authors:
 *  Michael Roth   <mdroth@linux.vnet.ibm.com>
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.1 or later.
 * See the COPYING.LIB file in the top-level directory.
 *
 */

#include "dealloc-visitor.h"
#include "queue.h"
#include "visitor-impl.h"

struct QapiDeallocVisitor
{
    Visitor visitor;
};

static bool qapi_dealloc_start_struct(Visitor *v, const char *name, void **obj,
                                      size_t unused, Error **errp)
{
    return true;
}

static void qapi_dealloc_end_struct(Visitor *v, void **obj)
{
    if (obj) {
        g_free(*obj);
    }
}

static void qapi_dealloc_end_alternate(Visitor *v, void **obj)
{
    if (obj) {
        g_free(*obj);
    }
}

static bool qapi_dealloc_start_list(Visitor *v, const char *name,
                                    GenericList **list, size_t size,
                                    Error **errp)
{
    return true;
}

static GenericList *qapi_dealloc_next_list(Visitor *v, GenericList *tail,
                                           size_t size)
{
    GenericList *next = tail->next;
    g_free(tail);
    return next;
}

static void qapi_dealloc_end_list(Visitor *v, void **obj)
{
}

static bool qapi_dealloc_type_str(Visitor *v, const char *name, char **obj,
                                  Error **errp)
{
    if (obj) {
        g_free(*obj);
    }
    return true;
}

static bool qapi_dealloc_type_int64(Visitor *v, const char *name, int64_t *obj,
                                    Error **errp)
{
    return true;
}

static bool qapi_dealloc_type_uint64(Visitor *v, const char *name,
                                     uint64_t *obj, Error **errp)
{
    return true;
}

static bool qapi_dealloc_type_bool(Visitor *v, const char *name, bool *obj,
                                   Error **errp)
{
    return true;
}

static bool qapi_dealloc_type_number(Visitor *v, const char *name, double *obj,
                                     Error **errp)
{
    return true;
}

static bool qapi_dealloc_type_anything(Visitor *v, const char *name,
                                       CFTypeRef *obj, Error **errp)
{
    if (obj) {
        CFRelease(*obj);
    }
    return true;
}

static bool qapi_dealloc_type_null(Visitor *v, const char *name,
                                   CFNullRef *obj, Error **errp)
{
    return true;
}

static void qapi_dealloc_free(Visitor *v)
{
    g_free(container_of(v, QapiDeallocVisitor, visitor));
}

Visitor *qapi_dealloc_visitor_new(void)
{
    QapiDeallocVisitor *v;

    v = g_malloc0(sizeof(*v));

    v->visitor.type = VISITOR_DEALLOC;
    v->visitor.start_struct = qapi_dealloc_start_struct;
    v->visitor.end_struct = qapi_dealloc_end_struct;
    v->visitor.end_alternate = qapi_dealloc_end_alternate;
    v->visitor.start_list = qapi_dealloc_start_list;
    v->visitor.next_list = qapi_dealloc_next_list;
    v->visitor.end_list = qapi_dealloc_end_list;
    v->visitor.type_int64 = qapi_dealloc_type_int64;
    v->visitor.type_uint64 = qapi_dealloc_type_uint64;
    v->visitor.type_bool = qapi_dealloc_type_bool;
    v->visitor.type_str = qapi_dealloc_type_str;
    v->visitor.type_number = qapi_dealloc_type_number;
    v->visitor.type_any = qapi_dealloc_type_anything;
    v->visitor.type_null = qapi_dealloc_type_null;
    v->visitor.free = qapi_dealloc_free;

    return &v->visitor;
}
