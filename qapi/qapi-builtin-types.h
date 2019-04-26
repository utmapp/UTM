/* AUTOMATICALLY GENERATED, DO NOT MODIFY */

/*
 * Built-in QAPI types
 *
 * Copyright IBM, Corp. 2011
 * Copyright (c) 2013-2018 Red Hat Inc.
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.1 or later.
 * See the COPYING.LIB file in the top-level directory.
 */

#ifndef QAPI_BUILTIN_TYPES_H
#define QAPI_BUILTIN_TYPES_H

#include <CoreFoundation/CoreFoundation.h>
#include "util.h"

typedef struct strList strList;

typedef struct numberList numberList;

typedef struct intList intList;

typedef struct int8List int8List;

typedef struct int16List int16List;

typedef struct int32List int32List;

typedef struct int64List int64List;

typedef struct uint8List uint8List;

typedef struct uint16List uint16List;

typedef struct uint32List uint32List;

typedef struct uint64List uint64List;

typedef struct sizeList sizeList;

typedef struct boolList boolList;

typedef struct anyList anyList;

typedef struct nullList nullList;

typedef enum QType {
    QTYPE_NONE,
    QTYPE_QNULL,
    QTYPE_QNUM,
    QTYPE_QSTRING,
    QTYPE_QDICT,
    QTYPE_QLIST,
    QTYPE_QBOOL,
    QTYPE__MAX,
} QType;

#define QType_str(val) \
    qapi_enum_lookup(&QType_lookup, (val))

extern const QEnumLookup QType_lookup;

struct strList {
    strList *next;
    char *value;
};

void qapi_free_strList(strList *obj);

struct numberList {
    numberList *next;
    double value;
};

void qapi_free_numberList(numberList *obj);

struct intList {
    intList *next;
    int64_t value;
};

void qapi_free_intList(intList *obj);

struct int8List {
    int8List *next;
    int8_t value;
};

void qapi_free_int8List(int8List *obj);

struct int16List {
    int16List *next;
    int16_t value;
};

void qapi_free_int16List(int16List *obj);

struct int32List {
    int32List *next;
    int32_t value;
};

void qapi_free_int32List(int32List *obj);

struct int64List {
    int64List *next;
    int64_t value;
};

void qapi_free_int64List(int64List *obj);

struct uint8List {
    uint8List *next;
    uint8_t value;
};

void qapi_free_uint8List(uint8List *obj);

struct uint16List {
    uint16List *next;
    uint16_t value;
};

void qapi_free_uint16List(uint16List *obj);

struct uint32List {
    uint32List *next;
    uint32_t value;
};

void qapi_free_uint32List(uint32List *obj);

struct uint64List {
    uint64List *next;
    uint64_t value;
};

void qapi_free_uint64List(uint64List *obj);

struct sizeList {
    sizeList *next;
    uint64_t value;
};

void qapi_free_sizeList(sizeList *obj);

struct boolList {
    boolList *next;
    bool value;
};

void qapi_free_boolList(boolList *obj);

struct anyList {
    anyList *next;
    CFTypeRef value;
};

void qapi_free_anyList(anyList *obj);

struct nullList {
    nullList *next;
    CFNullRef value;
};

void qapi_free_nullList(nullList *obj);

#endif /* QAPI_BUILTIN_TYPES_H */
