/*
 * Core Definitions for QAPI Visitor Classes
 *
 * Copyright (C) 2012-2016 Red Hat, Inc.
 * Copyright IBM, Corp. 2011
 *
 * Authors:
 *  Anthony Liguori   <aliguori@us.ibm.com>
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.1 or later.
 * See the COPYING.LIB file in the top-level directory.
 *
 */

#include "qemu-compat.h"
#include "qerror.h"
#include "error.h"
#include "visitor.h"
#include "visitor-impl.h"

void visit_complete(Visitor *v, void *opaque)
{
    assert(v->type != VISITOR_OUTPUT || v->complete);
    trace_visit_complete(v, opaque);
    if (v->complete) {
        v->complete(v, opaque);
    }
}

void visit_free(Visitor *v)
{
    trace_visit_free(v);
    if (v) {
        v->free(v);
    }
}

bool visit_start_struct(Visitor *v, const char *name, void **obj,
                        size_t size, Error **errp)
{
    bool ok;

    trace_visit_start_struct(v, name, obj, size);
    if (obj) {
        assert(size);
        assert(!(v->type & VISITOR_OUTPUT) || *obj);
    }
    ok = v->start_struct(v, name, obj, size, errp);
    if (obj && (v->type & VISITOR_INPUT)) {
        assert(ok != !*obj);
    }
    return ok;
}

bool visit_check_struct(Visitor *v, Error **errp)
{
    trace_visit_check_struct(v);
    return v->check_struct ? v->check_struct(v, errp) : true;
}

void visit_end_struct(Visitor *v, void **obj)
{
    trace_visit_end_struct(v, obj);
    v->end_struct(v, obj);
}

bool visit_start_list(Visitor *v, const char *name, GenericList **list,
                      size_t size, Error **errp)
{
    bool ok;

    assert(!list || size >= sizeof(GenericList));
    trace_visit_start_list(v, name, list, size);
    ok = v->start_list(v, name, list, size, errp);
    if (list && (v->type & VISITOR_INPUT)) {
        assert(ok || !*list);
    }
    return ok;
}

GenericList *visit_next_list(Visitor *v, GenericList *tail, size_t size)
{
    assert(tail && size >= sizeof(GenericList));
    trace_visit_next_list(v, tail, size);
    return v->next_list(v, tail, size);
}

bool visit_check_list(Visitor *v, Error **errp)
{
    trace_visit_check_list(v);
    return v->check_list ? v->check_list(v, errp) : true;
}

void visit_end_list(Visitor *v, void **obj)
{
    trace_visit_end_list(v, obj);
    v->end_list(v, obj);
}

bool visit_start_alternate(Visitor *v, const char *name,
                           GenericAlternate **obj, size_t size,
                           Error **errp)
{
    bool ok;

    assert(obj && size >= sizeof(GenericAlternate));
    assert(!(v->type & VISITOR_OUTPUT) || *obj);
    trace_visit_start_alternate(v, name, obj, size);
    if (!v->start_alternate) {
        assert(!(v->type & VISITOR_INPUT));
        return true;
    }
    ok = v->start_alternate(v, name, obj, size, errp);
    if (v->type & VISITOR_INPUT) {
        assert(ok != !*obj);
    }
    return ok;
}

void visit_end_alternate(Visitor *v, void **obj)
{
    trace_visit_end_alternate(v, obj);
    if (v->end_alternate) {
        v->end_alternate(v, obj);
    }
}

bool visit_optional(Visitor *v, const char *name, bool *present)
{
    trace_visit_optional(v, name, present);
    if (v->optional) {
        v->optional(v, name, present);
    }
    return *present;
}

bool visit_deprecated_accept(Visitor *v, const char *name, Error **errp)
{
    trace_visit_deprecated_accept(v, name);
    if (v->deprecated_accept) {
        return v->deprecated_accept(v, name, errp);
    }
    return true;
}

bool visit_deprecated(Visitor *v, const char *name)
{
    trace_visit_deprecated(v, name);
    if (v->deprecated) {
        return v->deprecated(v, name);
    }
    return true;
}

bool visit_is_input(Visitor *v)
{
    return v->type == VISITOR_INPUT;
}

bool visit_is_dealloc(Visitor *v)
{
    return v->type == VISITOR_DEALLOC;
}

bool visit_type_int(Visitor *v, const char *name, int64_t *obj, Error **errp)
{
    assert(obj);
    trace_visit_type_int(v, name, obj);
    return v->type_int64(v, name, obj, errp);
}

static bool visit_type_uintN(Visitor *v, uint64_t *obj, const char *name,
                             uint64_t max, const char *type, Error **errp)
{
    uint64_t value = *obj;

    assert(v->type == VISITOR_INPUT || value <= max);

    if (!v->type_uint64(v, name, &value, errp)) {
        return false;
    }
    if (value > max) {
        assert(v->type == VISITOR_INPUT);
        error_setg(errp, QERR_INVALID_PARAMETER_VALUE,
                   name ? name : "null", type);
        return false;
    }
    *obj = value;
    return true;
}

bool visit_type_uint8(Visitor *v, const char *name, uint8_t *obj,
                      Error **errp)
{
    uint64_t value;
    bool ok;

    trace_visit_type_uint8(v, name, obj);
    value = *obj;
    ok = visit_type_uintN(v, &value, name, UINT8_MAX, "uint8_t", errp);
    *obj = value;
    return ok;
}

bool visit_type_uint16(Visitor *v, const char *name, uint16_t *obj,
                       Error **errp)
{
    uint64_t value;
    bool ok;

    trace_visit_type_uint16(v, name, obj);
    value = *obj;
    ok = visit_type_uintN(v, &value, name, UINT16_MAX, "uint16_t", errp);
    *obj = value;
    return ok;
}

bool visit_type_uint32(Visitor *v, const char *name, uint32_t *obj,
                       Error **errp)
{
    uint64_t value;
    bool ok;

    trace_visit_type_uint32(v, name, obj);
    value = *obj;
    ok = visit_type_uintN(v, &value, name, UINT32_MAX, "uint32_t", errp);
    *obj = (uint32_t)value;
    return ok;
}

bool visit_type_uint64(Visitor *v, const char *name, uint64_t *obj,
                       Error **errp)
{
    assert(obj);
    trace_visit_type_uint64(v, name, obj);
    return v->type_uint64(v, name, obj, errp);
}

static bool visit_type_intN(Visitor *v, int64_t *obj, const char *name,
                            int64_t min, int64_t max, const char *type,
                            Error **errp)
{
    int64_t value = *obj;

    assert(v->type == VISITOR_INPUT || (value >= min && value <= max));

    if (!v->type_int64(v, name, &value, errp)) {
        return false;
    }
    if (value < min || value > max) {
        assert(v->type == VISITOR_INPUT);
        error_setg(errp, QERR_INVALID_PARAMETER_VALUE,
                   name ? name : "null", type);
        return false;
    }
    *obj = value;
    return true;
}

bool visit_type_int8(Visitor *v, const char *name, int8_t *obj, Error **errp)
{
    int64_t value;
    bool ok;

    trace_visit_type_int8(v, name, obj);
    value = *obj;
    ok = visit_type_intN(v, &value, name, INT8_MIN, INT8_MAX, "int8_t", errp);
    *obj = value;
    return ok;
}

bool visit_type_int16(Visitor *v, const char *name, int16_t *obj,
                      Error **errp)
{
    int64_t value;
    bool ok;

    trace_visit_type_int16(v, name, obj);
    value = *obj;
    ok = visit_type_intN(v, &value, name, INT16_MIN, INT16_MAX, "int16_t",
                         errp);
    *obj = value;
    return ok;
}

bool visit_type_int32(Visitor *v, const char *name, int32_t *obj,
                      Error **errp)
{
    int64_t value;
    bool ok;

    trace_visit_type_int32(v, name, obj);
    value = *obj;
    ok = visit_type_intN(v, &value, name, INT32_MIN, INT32_MAX, "int32_t",
                        errp);
    *obj = (int32_t)value;
    return ok;
}

bool visit_type_int64(Visitor *v, const char *name, int64_t *obj,
                      Error **errp)
{
    assert(obj);
    trace_visit_type_int64(v, name, obj);
    return v->type_int64(v, name, obj, errp);
}

bool visit_type_size(Visitor *v, const char *name, uint64_t *obj,
                     Error **errp)
{
    assert(obj);
    trace_visit_type_size(v, name, obj);
    if (v->type_size) {
        return v->type_size(v, name, obj, errp);
    }
    return v->type_uint64(v, name, obj, errp);
}

bool visit_type_bool(Visitor *v, const char *name, bool *obj, Error **errp)
{
    assert(obj);
    trace_visit_type_bool(v, name, obj);
    return v->type_bool(v, name, obj, errp);
}

bool visit_type_str(Visitor *v, const char *name, char **obj, Error **errp)
{
    bool ok;

    assert(obj);
    /* TODO: Fix callers to not pass NULL when they mean "", so that we
     * can enable:
    assert(!(v->type & VISITOR_OUTPUT) || *obj);
     */
    trace_visit_type_str(v, name, obj);
    ok = v->type_str(v, name, obj, errp);
    if (v->type & VISITOR_INPUT) {
        assert(ok != !*obj);
    }
    return ok;
}

bool visit_type_number(Visitor *v, const char *name, double *obj,
                       Error **errp)
{
    assert(obj);
    trace_visit_type_number(v, name, obj);
    return v->type_number(v, name, obj, errp);
}

bool visit_type_any(Visitor *v, const char *name, CFTypeRef *obj, Error **errp)
{
    bool ok;

    assert(obj);
    assert(v->type != VISITOR_OUTPUT || *obj);
    trace_visit_type_any(v, name, obj);
    ok = v->type_any(v, name, obj, errp);
    if (v->type == VISITOR_INPUT) {
        assert(ok != !*obj);
    }
    return ok;
}

bool visit_type_null(Visitor *v, const char *name, CFNullRef *obj,
                     Error **errp)
{
    trace_visit_type_null(v, name, obj);
    return v->type_null(v, name, obj, errp);
}

static bool output_type_enum(Visitor *v, const char *name, int *obj,
                             const QEnumLookup *lookup, Error **errp)
{
    int value = *obj;
    char *enum_str;

    enum_str = (char *)qapi_enum_lookup(lookup, value);
    return visit_type_str(v, name, &enum_str, errp);
}

static bool input_type_enum(Visitor *v, const char *name, int *obj,
                            const QEnumLookup *lookup, Error **errp)
{
    int64_t value;
    char *enum_str;

    if (!visit_type_str(v, name, &enum_str, errp)) {
        return false;
    }

    value = qapi_enum_parse(lookup, enum_str, -1, NULL);
    if (value < 0) {
        error_setg(errp, QERR_INVALID_PARAMETER, enum_str);
        g_free(enum_str);
        return false;
    }

    g_free(enum_str);
    *obj = (int)value;
    return true;
}

bool visit_type_enum(Visitor *v, const char *name, int *obj,
                     const QEnumLookup *lookup, Error **errp)
{
    assert(obj && lookup);
    trace_visit_type_enum(v, name, obj);
    switch (v->type) {
    case VISITOR_INPUT:
        return input_type_enum(v, name, obj, lookup, errp);
    case VISITOR_OUTPUT:
        return output_type_enum(v, name, obj, lookup, errp);
    case VISITOR_CLONE:
        /* nothing further to do, scalar value was already copied by
         * g_memdup() during visit_start_*() */
        return true;
    case VISITOR_DEALLOC:
        /* nothing to deallocate for a scalar */
        return true;
    default:
        abort();
    }
}
