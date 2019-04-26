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

void visit_start_struct(Visitor *v, const char *name, void **obj,
                        size_t size, Error **errp)
{
    Error *err = NULL;

    trace_visit_start_struct(v, name, obj, size);
    if (obj) {
        assert(size);
        assert(!(v->type & VISITOR_OUTPUT) || *obj);
    }
    v->start_struct(v, name, obj, size, &err);
    if (obj && (v->type & VISITOR_INPUT)) {
        assert(!err != !*obj);
    }
    error_propagate(errp, err);
}

void visit_check_struct(Visitor *v, Error **errp)
{
    trace_visit_check_struct(v);
    if (v->check_struct) {
        v->check_struct(v, errp);
    }
}

void visit_end_struct(Visitor *v, void **obj)
{
    trace_visit_end_struct(v, obj);
    v->end_struct(v, obj);
}

void visit_start_list(Visitor *v, const char *name, GenericList **list,
                      size_t size, Error **errp)
{
    Error *err = NULL;

    assert(!list || size >= sizeof(GenericList));
    trace_visit_start_list(v, name, list, size);
    v->start_list(v, name, list, size, &err);
    if (list && (v->type & VISITOR_INPUT)) {
        assert(!(err && *list));
    }
    error_propagate(errp, err);
}

GenericList *visit_next_list(Visitor *v, GenericList *tail, size_t size)
{
    assert(tail && size >= sizeof(GenericList));
    trace_visit_next_list(v, tail, size);
    return v->next_list(v, tail, size);
}

void visit_check_list(Visitor *v, Error **errp)
{
    trace_visit_check_list(v);
    if (v->check_list) {
        v->check_list(v, errp);
    }
}

void visit_end_list(Visitor *v, void **obj)
{
    trace_visit_end_list(v, obj);
    v->end_list(v, obj);
}

void visit_start_alternate(Visitor *v, const char *name,
                           GenericAlternate **obj, size_t size,
                           Error **errp)
{
    Error *err = NULL;

    assert(obj && size >= sizeof(GenericAlternate));
    assert(!(v->type & VISITOR_OUTPUT) || *obj);
    trace_visit_start_alternate(v, name, obj, size);
    if (v->start_alternate) {
        v->start_alternate(v, name, obj, size, &err);
    }
    if (v->type & VISITOR_INPUT) {
        assert(v->start_alternate && !err != !*obj);
    }
    error_propagate(errp, err);
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

bool visit_is_input(Visitor *v)
{
    return v->type == VISITOR_INPUT;
}

void visit_type_int(Visitor *v, const char *name, int64_t *obj, Error **errp)
{
    assert(obj);
    trace_visit_type_int(v, name, obj);
    v->type_int64(v, name, obj, errp);
}

static void visit_type_uintN(Visitor *v, uint64_t *obj, const char *name,
                             uint64_t max, const char *type, Error **errp)
{
    Error *err = NULL;
    uint64_t value = *obj;

    v->type_uint64(v, name, &value, &err);
    if (err) {
        error_propagate(errp, err);
    } else if (value > max) {
        error_setg(errp, QERR_INVALID_PARAMETER_VALUE,
                   name ? name : "null", type);
    } else {
        *obj = value;
    }
}

void visit_type_uint8(Visitor *v, const char *name, uint8_t *obj,
                      Error **errp)
{
    uint64_t value;

    trace_visit_type_uint8(v, name, obj);
    value = *obj;
    visit_type_uintN(v, &value, name, UINT8_MAX, "uint8_t", errp);
    *obj = (uint8_t)value;
}

void visit_type_uint16(Visitor *v, const char *name, uint16_t *obj,
                       Error **errp)
{
    uint64_t value;

    trace_visit_type_uint16(v, name, obj);
    value = *obj;
    visit_type_uintN(v, &value, name, UINT16_MAX, "uint16_t", errp);
    *obj = (uint16_t)value;
}

void visit_type_uint32(Visitor *v, const char *name, uint32_t *obj,
                       Error **errp)
{
    uint64_t value;

    trace_visit_type_uint32(v, name, obj);
    value = *obj;
    visit_type_uintN(v, &value, name, UINT32_MAX, "uint32_t", errp);
    *obj = (uint32_t)value;
}

void visit_type_uint64(Visitor *v, const char *name, uint64_t *obj,
                       Error **errp)
{
    assert(obj);
    trace_visit_type_uint64(v, name, obj);
    v->type_uint64(v, name, obj, errp);
}

static void visit_type_intN(Visitor *v, int64_t *obj, const char *name,
                            int64_t min, int64_t max, const char *type,
                            Error **errp)
{
    Error *err = NULL;
    int64_t value = *obj;

    v->type_int64(v, name, &value, &err);
    if (err) {
        error_propagate(errp, err);
    } else if (value < min || value > max) {
        error_setg(errp, QERR_INVALID_PARAMETER_VALUE,
                   name ? name : "null", type);
    } else {
        *obj = value;
    }
}

void visit_type_int8(Visitor *v, const char *name, int8_t *obj, Error **errp)
{
    int64_t value;

    trace_visit_type_int8(v, name, obj);
    value = *obj;
    visit_type_intN(v, &value, name, INT8_MIN, INT8_MAX, "int8_t", errp);
    *obj = (int8_t)value;
}

void visit_type_int16(Visitor *v, const char *name, int16_t *obj,
                      Error **errp)
{
    int64_t value;

    trace_visit_type_int16(v, name, obj);
    value = *obj;
    visit_type_intN(v, &value, name, INT16_MIN, INT16_MAX, "int16_t", errp);
    *obj = (int16_t)value;
}

void visit_type_int32(Visitor *v, const char *name, int32_t *obj,
                      Error **errp)
{
    int64_t value;

    trace_visit_type_int32(v, name, obj);
    value = *obj;
    visit_type_intN(v, &value, name, INT32_MIN, INT32_MAX, "int32_t", errp);
    *obj = (int32_t)value;
}

void visit_type_int64(Visitor *v, const char *name, int64_t *obj,
                      Error **errp)
{
    assert(obj);
    trace_visit_type_int64(v, name, obj);
    v->type_int64(v, name, obj, errp);
}

void visit_type_size(Visitor *v, const char *name, uint64_t *obj,
                     Error **errp)
{
    assert(obj);
    trace_visit_type_size(v, name, obj);
    if (v->type_size) {
        v->type_size(v, name, obj, errp);
    } else {
        v->type_uint64(v, name, obj, errp);
    }
}

void visit_type_bool(Visitor *v, const char *name, bool *obj, Error **errp)
{
    assert(obj);
    trace_visit_type_bool(v, name, obj);
    v->type_bool(v, name, obj, errp);
}

void visit_type_str(Visitor *v, const char *name, char **obj, Error **errp)
{
    Error *err = NULL;

    assert(obj);
    /* TODO: Fix callers to not pass NULL when they mean "", so that we
     * can enable:
    assert(!(v->type & VISITOR_OUTPUT) || *obj);
     */
    trace_visit_type_str(v, name, obj);
    v->type_str(v, name, obj, &err);
    if (v->type & VISITOR_INPUT) {
        assert(!err != !*obj);
    }
    error_propagate(errp, err);
}

void visit_type_number(Visitor *v, const char *name, double *obj,
                       Error **errp)
{
    assert(obj);
    trace_visit_type_number(v, name, obj);
    v->type_number(v, name, obj, errp);
}

void visit_type_any(Visitor *v, const char *name, CFTypeRef *obj, Error **errp)
{
    Error *err = NULL;

    assert(obj);
    assert(v->type != VISITOR_OUTPUT || *obj);
    trace_visit_type_any(v, name, obj);
    v->type_any(v, name, obj, &err);
    if (v->type == VISITOR_INPUT) {
        assert(!err != !*obj);
    }
    error_propagate(errp, err);
}

void visit_type_null(Visitor *v, const char *name, CFNullRef *obj,
                     Error **errp)
{
    trace_visit_type_null(v, name, obj);
    v->type_null(v, name, obj, errp);
}

static void output_type_enum(Visitor *v, const char *name, int *obj,
                             const QEnumLookup *lookup, Error **errp)
{
    int value = *obj;
    char *enum_str;

    /*
     * TODO why is this an error, not an assertion?  If assertion:
     * delete, and rely on qapi_enum_lookup()
     */
    if (value < 0 || value >= lookup->size) {
        error_setg(errp, QERR_INVALID_PARAMETER, name ? name : "null");
        return;
    }

    enum_str = (char *)qapi_enum_lookup(lookup, value);
    visit_type_str(v, name, &enum_str, errp);
}

static void input_type_enum(Visitor *v, const char *name, int *obj,
                            const QEnumLookup *lookup, Error **errp)
{
    Error *local_err = NULL;
    int64_t value;
    char *enum_str;

    visit_type_str(v, name, &enum_str, &local_err);
    if (local_err) {
        error_propagate(errp, local_err);
        return;
    }

    value = qapi_enum_parse(lookup, enum_str, -1, NULL);
    if (value < 0) {
        error_setg(errp, QERR_INVALID_PARAMETER, enum_str);
        g_free(enum_str);
        return;
    }

    g_free(enum_str);
    *obj = (int)value;
}

void visit_type_enum(Visitor *v, const char *name, int *obj,
                     const QEnumLookup *lookup, Error **errp)
{
    assert(obj && lookup);
    trace_visit_type_enum(v, name, obj);
    switch (v->type) {
    case VISITOR_INPUT:
        input_type_enum(v, name, obj, lookup, errp);
        break;
    case VISITOR_OUTPUT:
        output_type_enum(v, name, obj, lookup, errp);
        break;
    case VISITOR_CLONE:
        /* nothing further to do, scalar value was already copied by
         * g_memdup() during visit_start_*() */
        break;
    case VISITOR_DEALLOC:
        /* nothing to deallocate for a scalar */
        break;
    }
}
