/*
 * Input Visitor
 *
 * Copyright (C) 2012-2017 Red Hat, Inc.
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
#include "error.h"
#include "visitor-impl.h"
#include "queue.h"
#include "qerror.h"
#include "cf-input-visitor.h"
#include <math.h>

typedef struct StackObject {
    const char *name;            /* Name of @obj in its parent, if any */
    CFTypeRef obj;               /* CFDictionary or CFArray being visited */
    void *qapi; /* sanity check that caller uses same pointer */

    GHashTable *h;              /* If @obj is CFDictionary: unvisited keys */
    CFIndex index;              /* If @obj is CFArray: current index */
    CFIndex count;              /* If @obj is CFArray: total count */

    QSLIST_ENTRY(StackObject) node; /* parent */
} StackObject;

struct CFObjectInputVisitor {
    Visitor visitor;

    /* Root of visit at visitor creation. */
    CFDictionaryRef root;
    bool keyval;                /* Assume @root made with keyval_parse() */

    /* Stack of objects being visited (all entries will be either
     * QDict or QList). */
    QSLIST_HEAD(, StackObject) stack;

    GString *errname;           /* Accumulator for full_name() */
};

static CFObjectInputVisitor *to_qiv(Visitor *v)
{
    return container_of(v, CFObjectInputVisitor, visitor);
}

/*
 * Find the full name of something @qiv is currently visiting.
 * @qiv is visiting something named @name in the stack of containers
 * @qiv->stack.
 * If @n is zero, return its full name.
 * If @n is positive, return the full name of the @n-th container
 * counting from the top.  The stack of containers must have at least
 * @n elements.
 * The returned string is valid until the next full_name_nth(@v) or
 * destruction of @v.
 */
static const char *full_name_nth(CFObjectInputVisitor *qiv, const char *name,
                                 int n)
{
    StackObject *so;
    char buf[32];

    if (qiv->errname) {
        g_string_truncate(qiv->errname, 0);
    } else {
        qiv->errname = g_string_new("");
    }

    QSLIST_FOREACH(so , &qiv->stack, node) {
        if (n) {
            n--;
        } else if (CFGetTypeID(so->obj) == CFDictionaryGetTypeID()) {
            g_string_prepend(qiv->errname, name ?: "<anonymous>");
            g_string_prepend_c(qiv->errname, '.');
        } else {
            snprintf(buf, sizeof(buf),
                     qiv->keyval ? ".%u" : "[%u]",
                     (unsigned)so->index);
            g_string_prepend(qiv->errname, buf);
        }
        name = so->name;
    }
    assert(!n);

    if (name) {
        g_string_prepend(qiv->errname, name);
    } else if (qiv->errname->str[0] == '.') {
        g_string_erase(qiv->errname, 0, 1);
    } else if (!qiv->errname->str[0]) {
        return "<anonymous>";
    }

    return qiv->errname->str;
}

static const char *full_name(CFObjectInputVisitor *qiv, const char *name)
{
    return full_name_nth(qiv, name, 0);
}

static CFTypeRef cf_input_try_get_object(CFObjectInputVisitor *qiv,
                                             const char *name,
                                             bool consume)
{
    StackObject *tos;
    CFTypeRef cfobj;
    CFTypeRef ret;

    if (QSLIST_EMPTY(&qiv->stack)) {
        /* Starting at root, name is ignored. */
        assert(qiv->root);
        return qiv->root;
    }

    /* We are in a container; find the next element. */
    tos = QSLIST_FIRST(&qiv->stack);
    cfobj = tos->obj;
    assert(cfobj);

    if (CFGetTypeID(cfobj) == CFDictionaryGetTypeID()) {
        assert(name);
        CFStringRef cfname = CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, name, kCFStringEncodingUTF8, kCFAllocatorNull);
        ret = (CFTypeRef)CFDictionaryGetValue((CFDictionaryRef)cfobj, cfname);
        if (tos->h && consume && ret) {
            bool removed = g_hash_table_remove(tos->h, cfname);
            assert(removed);
        }
        CFRelease(cfname);
    } else {
        assert(CFGetTypeID(cfobj) == CFArrayGetTypeID());
        assert(!name);
        if (tos->index < tos->count) {
            ret = (CFTypeRef)CFArrayGetValueAtIndex((CFArrayRef)cfobj, tos->index);
            if (consume) {
                tos->index++;
            }
        } else {
            ret = NULL;
        }
    }

    return ret;
}

static CFTypeRef cf_input_get_object(CFObjectInputVisitor *qiv,
                                         const char *name,
                                         bool consume, Error **errp)
{
    CFTypeRef obj = cf_input_try_get_object(qiv, name, consume);

    if (!obj) {
        error_setg(errp, QERR_MISSING_PARAMETER, full_name(qiv, name));
    }
    return obj;
}

static void cfdictionary_add_key(const void *key, const void *val, void *context)
{
    GHashTable *h = context;
    g_hash_table_insert(h, (gpointer) CFRetain((CFTypeRef)key), NULL);
}

static guint cfstring_hash(gconstpointer key)
{
    return (guint)CFHash((CFTypeRef)key);
}

static gboolean cfstring_equal(gconstpointer a, gconstpointer b)
{
    return CFStringCompare((CFStringRef)a, (CFStringRef)b, 0) == kCFCompareEqualTo;
}

static void cfstring_destroy(gpointer data)
{
    CFRelease((CFTypeRef)data);
}

static void cf_input_push(CFObjectInputVisitor *qiv,
                                            const char *name,
                                            CFTypeRef obj, void *qapi)
{
    GHashTable *h;
    StackObject *tos = g_new0(StackObject, 1);

    assert(obj);
    tos->name = name;
    tos->obj = obj;
    tos->qapi = qapi;

    if (CFGetTypeID(obj) == CFDictionaryGetTypeID()) {
        h = g_hash_table_new_full(cfstring_hash, cfstring_equal, cfstring_destroy, NULL);
        CFDictionaryApplyFunction((CFDictionaryRef)obj, cfdictionary_add_key, h);
        tos->h = h;
    } else {
        assert(CFGetTypeID(obj) == CFArrayGetTypeID());
        tos->count = CFArrayGetCount((CFArrayRef)obj);
        tos->index = 0;
    }

    QSLIST_INSERT_HEAD(&qiv->stack, tos, node);
}


static bool cf_input_check_struct(Visitor *v, Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    StackObject *tos = QSLIST_FIRST(&qiv->stack);
    GHashTableIter iter;
    const char *key;

    assert(tos);

    g_hash_table_iter_init(&iter, tos->h);
    if (g_hash_table_iter_next(&iter, (void **)&key, NULL)) {
        error_setg(errp, "Parameter '%s' is unexpected",
                   full_name(qiv, key));
        return false;
    }
    
    return true;
}

static void cf_input_stack_object_free(StackObject *tos)
{
    if (tos->h) {
        g_hash_table_unref(tos->h);
    }

    g_free(tos);
}

static void cf_input_pop(Visitor *v, void **obj)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    StackObject *tos = QSLIST_FIRST(&qiv->stack);

    assert(tos && tos->qapi == obj);
    QSLIST_REMOVE_HEAD(&qiv->stack, node);
    cf_input_stack_object_free(tos);
}

static bool cf_input_start_struct(Visitor *v, const char *name, void **obj,
                                       size_t size, Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_get_object(qiv, name, true, errp);

    if (obj) {
        *obj = NULL;
    }
    if (!cfobj) {
        return false;
    }
    if (CFGetTypeID(cfobj) != CFDictionaryGetTypeID()) {
        error_setg(errp, QERR_INVALID_PARAMETER_TYPE,
                   full_name(qiv, name), "object");
        return false;
    }

    cf_input_push(qiv, name, cfobj, obj);

    if (obj) {
        *obj = g_malloc0(size);
    }
    
    return true;
}

static void cf_input_end_struct(Visitor *v, void **obj)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    StackObject *tos = QSLIST_FIRST(&qiv->stack);

    assert(CFGetTypeID(tos->obj) == CFDictionaryGetTypeID() && tos->h);
    cf_input_pop(v, obj);
}


static bool cf_input_start_list(Visitor *v, const char *name,
                                     GenericList **list, size_t size,
                                     Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_get_object(qiv, name, true, errp);

    if (list) {
        *list = NULL;
    }
    if (!cfobj) {
        return false;
    }
    if (CFGetTypeID(cfobj) != CFArrayGetTypeID()) {
        error_setg(errp, QERR_INVALID_PARAMETER_TYPE,
                   full_name(qiv, name), "array");
        return false;
    }

    cf_input_push(qiv, name, cfobj, list);
    if (list) {
        *list = g_malloc0(size);
    }
    
    return true;
}

static GenericList *cf_input_next_list(Visitor *v, GenericList *tail,
                                            size_t size)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    StackObject *tos = QSLIST_FIRST(&qiv->stack);

    assert(tos && CFGetTypeID(tos->obj) == CFArrayGetTypeID());

    if (tos->index == tos->count) {
        return NULL;
    }
    tail->next = g_malloc0(size);
    return tail->next;
}

static bool cf_input_check_list(Visitor *v, Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    StackObject *tos = QSLIST_FIRST(&qiv->stack);

    assert(tos && CFGetTypeID(tos->obj) == CFArrayGetTypeID());

    if (tos->index != tos->count) {
        error_setg(errp, "Only %u list elements expected in %s",
                   (unsigned)tos->index + 1, full_name_nth(qiv, NULL, 1));
        return false;
    }
    
    return true;
}

static void cf_input_end_list(Visitor *v, void **obj)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    StackObject *tos = QSLIST_FIRST(&qiv->stack);

    assert(CFGetTypeID(tos->obj) == CFArrayGetTypeID() && !tos->h);
    cf_input_pop(v, obj);
}

static bool cf_input_start_alternate(Visitor *v, const char *name,
                                          GenericAlternate **obj, size_t size,
                                          Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_get_object(qiv, name, false, errp);

    if (!cfobj) {
        *obj = NULL;
        return false;
    }
    *obj = g_malloc0(size);
    (*obj)->type = CFGetTypeID(cfobj);
    
    return true;
}

static bool cf_input_type_int64(Visitor *v, const char *name, int64_t *obj,
                                     Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_get_object(qiv, name, true, errp);
    CFNumberRef cfnum;

    if (!cfobj) {
        return false;
    }
    cfnum = (CFNumberRef)cfobj;
    if (CFGetTypeID(cfobj) != CFNumberGetTypeID() || 
        !CFNumberGetValue(cfnum, kCFNumberSInt64Type, obj)) {
        error_setg(errp, QERR_INVALID_PARAMETER_TYPE,
                   full_name(qiv, name), "integer");
        return false;
    }
    
    return true;
}

static bool cf_input_type_uint64(Visitor *v, const char *name,
                                      uint64_t *obj, Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_get_object(qiv, name, true, errp);
    CFNumberRef cfnum;
    int64_t val;

    if (!cfobj) {
        return false;
    }
    cfnum = (CFNumberRef)cfobj;
    if (CFGetTypeID(cfobj) != CFNumberGetTypeID()) {
        goto err;
    }

    if (CFNumberGetValue(cfnum, kCFNumberSInt64Type, &val)) {
        *obj = val;
        return false;
    }

    // FIXME: CFNumber doesn't work with uint64_t!

    return true;
err:
    error_setg(errp, QERR_INVALID_PARAMETER_VALUE,
               full_name(qiv, name), "uint64");
    return false;
}

static bool cf_input_type_bool(Visitor *v, const char *name, bool *obj,
                                    Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_get_object(qiv, name, true, errp);
    CFBooleanRef cfbool;

    if (!cfobj) {
        return false;
    }
    cfbool = (CFBooleanRef)cfobj;
    if (CFGetTypeID(cfobj) != CFBooleanGetTypeID()) {
        error_setg(errp, QERR_INVALID_PARAMETER_TYPE,
                   full_name(qiv, name), "boolean");
        return false;
    }

    *obj = CFBooleanGetValue(cfbool);
    
    return true;
}

static bool cf_input_type_str(Visitor *v, const char *name, char **obj,
                                   Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_get_object(qiv, name, true, errp);
    CFStringRef cfstr;
    const char *str;

    *obj = NULL;
    if (!cfobj) {
        return false;
    }
    cfstr = (CFStringRef)cfobj;
    if (CFGetTypeID(cfobj) != CFStringGetTypeID()) {
        error_setg(errp, QERR_INVALID_PARAMETER_TYPE,
                   full_name(qiv, name), "string");
        return false;
    }
        
    str = CFStringGetCStringPtr(cfstr, CFStringGetFastestEncoding(cfstr));
    if (str == NULL) {
        CFIndex length = CFStringGetLength(cfstr);
        CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
        char *buffer = (char *)g_malloc(maxSize);
        if (!CFStringGetCString(cfstr, buffer, maxSize, kCFStringEncodingUTF8)) {
            error_setg(errp, QERR_INVALID_PARAMETER_TYPE,
                       full_name(qiv, name), "string");
            g_free(buffer);
            return false;
        } else {
            *obj = buffer;
        }
    } else {
        *obj = g_strdup(str);
    }
    return true;
}

static bool cf_input_type_number(Visitor *v, const char *name, double *obj,
                                      Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_get_object(qiv, name, true, errp);
    CFNumberRef cfnum;

    if (!cfobj) {
        return false;
    }
    cfnum = (CFNumberRef)cfobj;
    if (CFGetTypeID(cfobj) != CFNumberGetTypeID() || !CFNumberIsFloatType(cfnum)) {
        error_setg(errp, QERR_INVALID_PARAMETER_TYPE,
                   full_name(qiv, name), "number");
        return false;
    }

    CFNumberGetValue(cfnum, kCFNumberDoubleType, obj);
    return true;
}

static bool cf_input_type_any(Visitor *v, const char *name, CFTypeRef *obj,
                                   Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_get_object(qiv, name, true, errp);

    *obj = NULL;
    if (!cfobj) {
        return false;
    }

    *obj = CFRetain(cfobj);
    return true;
}

static bool cf_input_type_null(Visitor *v, const char *name,
                                    CFNullRef *obj, Error **errp)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_get_object(qiv, name, true, errp);

    *obj = NULL;
    if (!cfobj) {
        return false;
    }

    if (CFGetTypeID(cfobj) != CFNullGetTypeID()) {
        error_setg(errp, QERR_INVALID_PARAMETER_TYPE,
                   full_name(qiv, name), "null");
        return false;
    }
    *obj = kCFNull;
    return true;
}

static void cf_input_optional(Visitor *v, const char *name, bool *present)
{
    CFObjectInputVisitor *qiv = to_qiv(v);
    CFTypeRef cfobj = cf_input_try_get_object(qiv, name, false);

    if (!cfobj) {
        *present = false;
        return;
    }

    *present = true;
}

static void cf_input_free(Visitor *v)
{
    CFObjectInputVisitor *qiv = to_qiv(v);

    while (!QSLIST_EMPTY(&qiv->stack)) {
        StackObject *tos = QSLIST_FIRST(&qiv->stack);

        QSLIST_REMOVE_HEAD(&qiv->stack, node);
        cf_input_stack_object_free(tos);
    }

    CFRelease(qiv->root);
    if (qiv->errname) {
        g_string_free(qiv->errname, true);
    }
    g_free(qiv);
}

static CFObjectInputVisitor *cf_input_visitor_base_new(CFTypeRef obj)
{
    CFObjectInputVisitor *v = g_malloc0(sizeof(*v));

    assert(obj);

    v->visitor.type = VISITOR_INPUT;
    v->visitor.start_struct = cf_input_start_struct;
    v->visitor.check_struct = cf_input_check_struct;
    v->visitor.end_struct = cf_input_end_struct;
    v->visitor.start_list = cf_input_start_list;
    v->visitor.next_list = cf_input_next_list;
    v->visitor.check_list = cf_input_check_list;
    v->visitor.end_list = cf_input_end_list;
    v->visitor.start_alternate = cf_input_start_alternate;
    v->visitor.optional = cf_input_optional;
    v->visitor.free = cf_input_free;

    v->root = CFRetain(obj);

    return v;
}

Visitor *cf_input_visitor_new(CFTypeRef obj)
{
    CFObjectInputVisitor *v = cf_input_visitor_base_new(obj);

    v->visitor.type_int64 = cf_input_type_int64;
    v->visitor.type_uint64 = cf_input_type_uint64;
    v->visitor.type_bool = cf_input_type_bool;
    v->visitor.type_str = cf_input_type_str;
    v->visitor.type_number = cf_input_type_number;
    v->visitor.type_any = cf_input_type_any;
    v->visitor.type_null = cf_input_type_null;

    return &v->visitor;
}
