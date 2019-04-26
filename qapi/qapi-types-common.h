/* AUTOMATICALLY GENERATED, DO NOT MODIFY */

/*
 * Schema-defined QAPI types
 *
 * Copyright IBM, Corp. 2011
 * Copyright (c) 2013-2018 Red Hat Inc.
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.1 or later.
 * See the COPYING.LIB file in the top-level directory.
 */

#ifndef QAPI_TYPES_COMMON_H
#define QAPI_TYPES_COMMON_H

#include "qapi-builtin-types.h"

typedef enum QapiErrorClass {
    QAPI_ERROR_CLASS_GENERICERROR,
    QAPI_ERROR_CLASS_COMMANDNOTFOUND,
    QAPI_ERROR_CLASS_DEVICENOTACTIVE,
    QAPI_ERROR_CLASS_DEVICENOTFOUND,
    QAPI_ERROR_CLASS_KVMMISSINGCAP,
    QAPI_ERROR_CLASS__MAX,
} QapiErrorClass;

#define QapiErrorClass_str(val) \
    qapi_enum_lookup(&QapiErrorClass_lookup, (val))

extern const QEnumLookup QapiErrorClass_lookup;

typedef enum IoOperationType {
    IO_OPERATION_TYPE_READ,
    IO_OPERATION_TYPE_WRITE,
    IO_OPERATION_TYPE__MAX,
} IoOperationType;

#define IoOperationType_str(val) \
    qapi_enum_lookup(&IoOperationType_lookup, (val))

extern const QEnumLookup IoOperationType_lookup;

typedef enum OnOffAuto {
    ON_OFF_AUTO_AUTO,
    ON_OFF_AUTO_ON,
    ON_OFF_AUTO_OFF,
    ON_OFF_AUTO__MAX,
} OnOffAuto;

#define OnOffAuto_str(val) \
    qapi_enum_lookup(&OnOffAuto_lookup, (val))

extern const QEnumLookup OnOffAuto_lookup;

typedef enum OnOffSplit {
    ON_OFF_SPLIT_ON,
    ON_OFF_SPLIT_OFF,
    ON_OFF_SPLIT_SPLIT,
    ON_OFF_SPLIT__MAX,
} OnOffSplit;

#define OnOffSplit_str(val) \
    qapi_enum_lookup(&OnOffSplit_lookup, (val))

extern const QEnumLookup OnOffSplit_lookup;

typedef struct String String;

typedef struct StrOrNull StrOrNull;

typedef enum OffAutoPCIBAR {
    OFF_AUTOPCIBAR_OFF,
    OFF_AUTOPCIBAR_AUTO,
    OFF_AUTOPCIBAR_BAR0,
    OFF_AUTOPCIBAR_BAR1,
    OFF_AUTOPCIBAR_BAR2,
    OFF_AUTOPCIBAR_BAR3,
    OFF_AUTOPCIBAR_BAR4,
    OFF_AUTOPCIBAR_BAR5,
    OFF_AUTOPCIBAR__MAX,
} OffAutoPCIBAR;

#define OffAutoPCIBAR_str(val) \
    qapi_enum_lookup(&OffAutoPCIBAR_lookup, (val))

extern const QEnumLookup OffAutoPCIBAR_lookup;

typedef enum PCIELinkSpeed {
    PCIE_LINK_SPEED_2_5,
    PCIE_LINK_SPEED_5,
    PCIE_LINK_SPEED_8,
    PCIE_LINK_SPEED_16,
    PCIE_LINK_SPEED__MAX,
} PCIELinkSpeed;

#define PCIELinkSpeed_str(val) \
    qapi_enum_lookup(&PCIELinkSpeed_lookup, (val))

extern const QEnumLookup PCIELinkSpeed_lookup;

typedef enum PCIELinkWidth {
    PCIE_LINK_WIDTH_1,
    PCIE_LINK_WIDTH_2,
    PCIE_LINK_WIDTH_4,
    PCIE_LINK_WIDTH_8,
    PCIE_LINK_WIDTH_12,
    PCIE_LINK_WIDTH_16,
    PCIE_LINK_WIDTH_32,
    PCIE_LINK_WIDTH__MAX,
} PCIELinkWidth;

#define PCIELinkWidth_str(val) \
    qapi_enum_lookup(&PCIELinkWidth_lookup, (val))

extern const QEnumLookup PCIELinkWidth_lookup;

typedef enum SysEmuTarget {
    SYS_EMU_TARGET_AARCH64,
    SYS_EMU_TARGET_ALPHA,
    SYS_EMU_TARGET_ARM,
    SYS_EMU_TARGET_CRIS,
    SYS_EMU_TARGET_HPPA,
    SYS_EMU_TARGET_I386,
    SYS_EMU_TARGET_LM32,
    SYS_EMU_TARGET_M68K,
    SYS_EMU_TARGET_MICROBLAZE,
    SYS_EMU_TARGET_MICROBLAZEEL,
    SYS_EMU_TARGET_MIPS,
    SYS_EMU_TARGET_MIPS64,
    SYS_EMU_TARGET_MIPS64EL,
    SYS_EMU_TARGET_MIPSEL,
    SYS_EMU_TARGET_MOXIE,
    SYS_EMU_TARGET_NIOS2,
    SYS_EMU_TARGET_OR1K,
    SYS_EMU_TARGET_PPC,
    SYS_EMU_TARGET_PPC64,
    SYS_EMU_TARGET_RISCV32,
    SYS_EMU_TARGET_RISCV64,
    SYS_EMU_TARGET_S390X,
    SYS_EMU_TARGET_SH4,
    SYS_EMU_TARGET_SH4EB,
    SYS_EMU_TARGET_SPARC,
    SYS_EMU_TARGET_SPARC64,
    SYS_EMU_TARGET_TRICORE,
    SYS_EMU_TARGET_UNICORE32,
    SYS_EMU_TARGET_X86_64,
    SYS_EMU_TARGET_XTENSA,
    SYS_EMU_TARGET_XTENSAEB,
    SYS_EMU_TARGET__MAX,
} SysEmuTarget;

#define SysEmuTarget_str(val) \
    qapi_enum_lookup(&SysEmuTarget_lookup, (val))

extern const QEnumLookup SysEmuTarget_lookup;

typedef struct StringList StringList;

struct String {
    char *str;
};

void qapi_free_String(String *obj);

struct StrOrNull {
    QType type;
    union { /* union tag is @type */
        char *s;
        CFNullRef n;
    } u;
};

void qapi_free_StrOrNull(StrOrNull *obj);

struct StringList {
    StringList *next;
    String *value;
};

void qapi_free_StringList(StringList *obj);

#endif /* QAPI_TYPES_COMMON_H */
