/*
 * Core Definitions for QAPI/QMP Command Registry
 *
 * Copyright (C) 2012-2016 Red Hat, Inc.
 * Copyright IBM, Corp. 2011
 * Copyright (C) 2019 osy
 *
 * Authors:
 *  Anthony Liguori   <aliguori@us.ibm.com>
 *  osy             <dev@getutm.app>
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.1 or later.
 * See the COPYING.LIB file in the top-level directory.
 *
 */

#include "qemu-compat.h"
#include "visitor-impl.h"
#include "queue.h"
#include "cf-output-visitor.h"

typedef struct QStackEntry {
    CFTypeRef value;
    void *qapi; /* sanity check that caller uses same pointer */
    QSLIST_ENTRY(QStackEntry) node;
} QStackEntry;

struct CFObjectOutputVisitor {
    Visitor visitor;
    QSLIST_HEAD(, QStackEntry) stack; /* Stack of unfinished containers */
    CFTypeRef root; /* Root of the output visit */
    CFTypeRef *result; /* User's storage location for result */
};

#define cf_output_add(qov, name, value) \
    cf_output_add_obj(qov, name, (CFTypeRef)(value))
#define cf_output_push(qov, value, qapi) \
    cf_output_push_obj(qov, (CFTypeRef)(value), qapi)

static CFObjectOutputVisitor *to_qov(Visitor *v)
{
    return container_of(v, CFObjectOutputVisitor, visitor);
}

/* Push @value onto the stack of current CFType being built */
static void cf_output_push_obj(CFObjectOutputVisitor *qov, CFTypeRef value,
                                    void *qapi)
{
    QStackEntry *e = g_malloc0(sizeof(*e));

    assert(qov->root);
    assert(value);
    e->value = value;
    e->qapi = qapi;
    QSLIST_INSERT_HEAD(&qov->stack, e, node);
}

/* Pop a value off the stack of CFType being built, and return it. */
static CFTypeRef cf_output_pop(CFObjectOutputVisitor *qov, void *qapi)
{
    QStackEntry *e = QSLIST_FIRST(&qov->stack);
    CFTypeRef value;

    assert(e);
    assert(e->qapi == qapi);
    QSLIST_REMOVE_HEAD(&qov->stack, node);
    value = e->value;
    assert(value);
    g_free(e);
    return value;
}

/* Add @value to the current CFType being built.
 * If the stack is visiting a dictionary or list, @value is now owned
 * by that container. Otherwise, @value is now the root.  */
static void cf_output_add_obj(CFObjectOutputVisitor *qov, const char *name,
                                   CFTypeRef value)
{
    QStackEntry *e = QSLIST_FIRST(&qov->stack);
    CFTypeRef cur = e ? e->value : NULL;
    CFStringRef cfname;

    if (!cur) {
        /* Don't allow reuse of visitor on more than one root */
        assert(!qov->root);
        qov->root = value;
    } else {
        if (CFGetTypeID(cur) == CFDictionaryGetTypeID()) {
            assert(name);
            cfname = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingUTF8);
            CFDictionaryAddValue((CFMutableDictionaryRef)cur, cfname, value);
            CFRelease(cfname);
            CFRelease(value); // now retained by dictionary
        } else {
            assert(CFGetTypeID(cur) == CFArrayGetTypeID());
            assert(!name);
            CFArrayAppendValue((CFMutableArrayRef)cur, value);
            CFRelease(value); // now retained by array
        }
    }
}

static bool cf_output_start_struct(Visitor *v, const char *name,
                                        void **obj, size_t unused, Error **errp)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    cf_output_add(qov, name, dict);
    cf_output_push(qov, dict, obj);
    return true;
}

static void cf_output_end_struct(Visitor *v, void **obj)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    CFTypeRef value = cf_output_pop(qov, obj);
    assert(CFGetTypeID(value) == CFDictionaryGetTypeID());
}

static bool cf_output_start_list(Visitor *v, const char *name,
                                      GenericList **listp, size_t size,
                                      Error **errp)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    CFMutableArrayRef list = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);

    cf_output_add(qov, name, list);
    cf_output_push(qov, list, listp);
    return true;
}

static GenericList *cf_output_next_list(Visitor *v, GenericList *tail,
                                             size_t size)
{
    return tail->next;
}

static void cf_output_end_list(Visitor *v, void **obj)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    CFTypeRef value = cf_output_pop(qov, obj);
    assert(CFGetTypeID(value) == CFArrayGetTypeID());
}

static bool cf_output_type_int64(Visitor *v, const char *name,
                                      int64_t *obj, Error **errp)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    cf_output_add(qov, name, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, obj));
    return true;
}

static bool cf_output_type_uint64(Visitor *v, const char *name,
                                       uint64_t *obj, Error **errp)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    // FIXME: CFNumber does not support uint64_t
    cf_output_add(qov, name, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, obj));
    return true;
}

static bool cf_output_type_bool(Visitor *v, const char *name, bool *obj,
                                     Error **errp)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    cf_output_add(qov, name, *obj ? kCFBooleanTrue : kCFBooleanFalse);
    return true;
}

static bool cf_output_type_str(Visitor *v, const char *name, char **obj,
                                    Error **errp)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    if (*obj) {
        cf_output_add(qov, name, CFStringCreateWithCString(kCFAllocatorDefault, *obj, kCFStringEncodingUTF8));
    } else {
        cf_output_add(qov, name, CFStringCreateWithCString(kCFAllocatorDefault, "", kCFStringEncodingUTF8));
    }
    return true;
}

static bool cf_output_type_number(Visitor *v, const char *name,
                                       double *obj, Error **errp)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    cf_output_add(qov, name, CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, obj));
    return true;
}

static bool cf_output_type_any(Visitor *v, const char *name,
                                    CFTypeRef *obj, Error **errp)
{
    CFObjectOutputVisitor *qov = to_qov(v);

    cf_output_add_obj(qov, name, CFRetain(*obj));
    return true;
}

static bool cf_output_type_null(Visitor *v, const char *name,
                                     CFNullRef *obj, Error **errp)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    cf_output_add(qov, name, kCFNull);
    return true;
}

/* Finish building, and return the root object.
 * The root object is never null. The caller becomes the object's
 * owner, and should use CFRelease() when done with it.  */
static void cf_output_complete(Visitor *v, void *opaque)
{
    CFObjectOutputVisitor *qov = to_qov(v);

    /* A visit must have occurred, with each start paired with end.  */
    assert(qov->root && QSLIST_EMPTY(&qov->stack));
    assert(opaque == qov->result);

    *qov->result = CFRetain(qov->root);
    qov->result = NULL;
}

static void cf_output_free(Visitor *v)
{
    CFObjectOutputVisitor *qov = to_qov(v);
    QStackEntry *e;

    while (!QSLIST_EMPTY(&qov->stack)) {
        e = QSLIST_FIRST(&qov->stack);
        QSLIST_REMOVE_HEAD(&qov->stack, node);
        g_free(e);
    }

    CFRelease(qov->root);
    g_free(qov);
}

Visitor *cf_output_visitor_new(CFTypeRef *result)
{
    CFObjectOutputVisitor *v;

    v = g_malloc0(sizeof(*v));

    v->visitor.type = VISITOR_OUTPUT;
    v->visitor.start_struct = cf_output_start_struct;
    v->visitor.end_struct = cf_output_end_struct;
    v->visitor.start_list = cf_output_start_list;
    v->visitor.next_list = cf_output_next_list;
    v->visitor.end_list = cf_output_end_list;
    v->visitor.type_int64 = cf_output_type_int64;
    v->visitor.type_uint64 = cf_output_type_uint64;
    v->visitor.type_bool = cf_output_type_bool;
    v->visitor.type_str = cf_output_type_str;
    v->visitor.type_number = cf_output_type_number;
    v->visitor.type_any = cf_output_type_any;
    v->visitor.type_null = cf_output_type_null;
    v->visitor.complete = cf_output_complete;
    v->visitor.free = cf_output_free;

    *result = NULL;
    v->result = result;

    return &v->visitor;
}
