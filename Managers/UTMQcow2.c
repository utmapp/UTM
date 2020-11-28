//
// Copyright © 2020 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "UTMQcow2.h"

#define QEMU_PACKED __attribute__((packed))

#define BYTES_IN_MIB 1048576
#define DEFAULT_CLUSTER_SIZE 65536
#define L1E_SIZE (sizeof(uint64_t))
#define L2E_SIZE_NORMAL   (sizeof(uint64_t))
#define QCOW_MAGIC (('Q' << 24) | ('F' << 16) | ('I' << 8) | 0xfb)
#define QCOW2_EXT_MAGIC_FEATURE_TABLE 0x6803f857

typedef struct QCowHeader {
    uint32_t magic;
    uint32_t version;
    uint64_t backing_file_offset;
    uint32_t backing_file_size;
    uint32_t cluster_bits;
    uint64_t size; /* in bytes */
    uint32_t crypt_method;
    uint32_t l1_size; /* XXX: save number of clusters instead ? */
    uint64_t l1_table_offset;
    uint64_t refcount_table_offset;
    uint32_t refcount_table_clusters;
    uint32_t nb_snapshots;
    uint64_t snapshots_offset;

    /* The following fields are only valid for version >= 3 */
    uint64_t incompatible_features;
    uint64_t compatible_features;
    uint64_t autoclear_features;

    uint32_t refcount_order;
    uint32_t header_length;

    /* Additional fields */
    uint8_t compression_type;

    /* header must be a multiple of 8 */
    uint8_t padding[7];
} QEMU_PACKED QCowHeader;

typedef struct {
    uint32_t magic;
    uint32_t len;
} QEMU_PACKED QCowExtension;

typedef struct Qcow2Feature {
    uint8_t type;
    uint8_t bit;
    char    name[46];
} QEMU_PACKED Qcow2Feature;

typedef union {
    struct {
        QCowHeader header;
        QCowExtension featuresHeader;
        Qcow2Feature features[7];
    } QEMU_PACKED;
    char buffer[DEFAULT_CLUSTER_SIZE];
} QEMU_PACKED QcowDefaultHeader;

enum {
    QCOW2_FEAT_TYPE_INCOMPATIBLE    = 0,
    QCOW2_FEAT_TYPE_COMPATIBLE      = 1,
    QCOW2_FEAT_TYPE_AUTOCLEAR       = 2,
};

/* Incompatible feature bits */
enum {
    QCOW2_INCOMPAT_DIRTY_BITNR      = 0,
    QCOW2_INCOMPAT_CORRUPT_BITNR    = 1,
    QCOW2_INCOMPAT_DATA_FILE_BITNR  = 2,
    QCOW2_INCOMPAT_COMPRESSION_BITNR = 3,
    QCOW2_INCOMPAT_EXTL2_BITNR      = 4,
    QCOW2_INCOMPAT_DIRTY            = 1 << QCOW2_INCOMPAT_DIRTY_BITNR,
    QCOW2_INCOMPAT_CORRUPT          = 1 << QCOW2_INCOMPAT_CORRUPT_BITNR,
    QCOW2_INCOMPAT_DATA_FILE        = 1 << QCOW2_INCOMPAT_DATA_FILE_BITNR,
    QCOW2_INCOMPAT_COMPRESSION      = 1 << QCOW2_INCOMPAT_COMPRESSION_BITNR,
    QCOW2_INCOMPAT_EXTL2            = 1 << QCOW2_INCOMPAT_EXTL2_BITNR,

    QCOW2_INCOMPAT_MASK             = QCOW2_INCOMPAT_DIRTY
                                    | QCOW2_INCOMPAT_CORRUPT
                                    | QCOW2_INCOMPAT_DATA_FILE
                                    | QCOW2_INCOMPAT_COMPRESSION
                                    | QCOW2_INCOMPAT_EXTL2,
};

/* Compatible feature bits */
enum {
    QCOW2_COMPAT_LAZY_REFCOUNTS_BITNR = 0,
    QCOW2_COMPAT_LAZY_REFCOUNTS       = 1 << QCOW2_COMPAT_LAZY_REFCOUNTS_BITNR,

    QCOW2_COMPAT_FEAT_MASK            = QCOW2_COMPAT_LAZY_REFCOUNTS,
};

/* Autoclear feature bits */
enum {
    QCOW2_AUTOCLEAR_BITMAPS_BITNR       = 0,
    QCOW2_AUTOCLEAR_DATA_FILE_RAW_BITNR = 1,
    QCOW2_AUTOCLEAR_BITMAPS             = 1 << QCOW2_AUTOCLEAR_BITMAPS_BITNR,
    QCOW2_AUTOCLEAR_DATA_FILE_RAW       = 1 << QCOW2_AUTOCLEAR_DATA_FILE_RAW_BITNR,

    QCOW2_AUTOCLEAR_MASK                = QCOW2_AUTOCLEAR_BITMAPS
                                        | QCOW2_AUTOCLEAR_DATA_FILE_RAW,
};

static inline uint64_t cpu_to_be64(uint64_t x)
{
    return __builtin_bswap64(x);
}

static inline uint32_t cpu_to_be32(uint32_t x)
{
    return __builtin_bswap32(x);
}

static inline int ctz32(uint32_t val)
{
    return val ? __builtin_ctz(val) : 32;
}

static inline int64_t size_to_l1(int64_t size)
{
    int cluster_bits = ctz32(DEFAULT_CLUSTER_SIZE);
    int shift = 2 * cluster_bits - ctz32(L2E_SIZE_NORMAL);
    return (size + (1ULL << shift) - 1) >> shift;
}

static bool qcow2_create(CFWriteStreamRef writeStream, size_t size) {
    uint32_t l1_size = (uint32_t)size_to_l1(size);
    QcowDefaultHeader header = {
        .header = {
            .magic                      = cpu_to_be32(QCOW_MAGIC),
            .version                    = cpu_to_be32(3),
            .cluster_bits               = cpu_to_be32(ctz32(DEFAULT_CLUSTER_SIZE)),
            .size                       = cpu_to_be64(size),
            .l1_size                    = cpu_to_be32(l1_size),
            .l1_table_offset            = cpu_to_be64(3 * DEFAULT_CLUSTER_SIZE),
            .refcount_table_offset      = cpu_to_be64(DEFAULT_CLUSTER_SIZE),
            .refcount_table_clusters    = cpu_to_be32(1),
            .refcount_order             = cpu_to_be32(4),
            .header_length              = cpu_to_be32(sizeof(header.header)),
        },
        .featuresHeader = {
            .magic                      = cpu_to_be32(QCOW2_EXT_MAGIC_FEATURE_TABLE),
            .len                        = cpu_to_be32(sizeof(header.features)),
        },
        .features = {
            {
                .type = QCOW2_FEAT_TYPE_INCOMPATIBLE,
                .bit  = QCOW2_INCOMPAT_DIRTY_BITNR,
                .name = "dirty bit",
            },
            {
                .type = QCOW2_FEAT_TYPE_INCOMPATIBLE,
                .bit  = QCOW2_INCOMPAT_CORRUPT_BITNR,
                .name = "corrupt bit",
            },
            {
                .type = QCOW2_FEAT_TYPE_INCOMPATIBLE,
                .bit  = QCOW2_INCOMPAT_DATA_FILE_BITNR,
                .name = "external data file",
            },
            {
                .type = QCOW2_FEAT_TYPE_INCOMPATIBLE,
                .bit  = QCOW2_INCOMPAT_COMPRESSION_BITNR,
                .name = "compression type",
            },
            {
                .type = QCOW2_FEAT_TYPE_COMPATIBLE,
                .bit  = QCOW2_COMPAT_LAZY_REFCOUNTS_BITNR,
                .name = "lazy refcounts",
            },
            {
                .type = QCOW2_FEAT_TYPE_AUTOCLEAR,
                .bit  = QCOW2_AUTOCLEAR_BITMAPS_BITNR,
                .name = "bitmaps",
            },
            {
                .type = QCOW2_FEAT_TYPE_AUTOCLEAR,
                .bit  = QCOW2_AUTOCLEAR_DATA_FILE_RAW_BITNR,
                .name = "raw external data",
            },
        },
    };
    
    if (CFWriteStreamWrite(writeStream, (void *)&header.buffer, sizeof(header.buffer)) < 0) {
        return false;
    }
    
    size_t total = 3 * DEFAULT_CLUSTER_SIZE + L1E_SIZE * l1_size;
    for (size_t i = DEFAULT_CLUSTER_SIZE; i < total; i += sizeof(uint64_t)) {
        uint64_t data = 0;
        if (i == DEFAULT_CLUSTER_SIZE) {
            data = cpu_to_be64(0x20000); // initial reftable
        } else if (i == 2 * DEFAULT_CLUSTER_SIZE) {
            data = cpu_to_be64(0x1000100010001); // initial refblock
        }
        if (CFWriteStreamWrite(writeStream, (void *)&data, sizeof(uint64_t)) < 0) {
            return false;
        }
    }
    
    return true;
}

bool GenerateDefaultQcow2File(CFURLRef path, size_t sizeInMib) {
    bool success = false;
    CFWriteStreamRef writeStream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, path);
    
    if (!CFWriteStreamOpen(writeStream)) {
        goto end;
    }
    
    success = qcow2_create(writeStream, sizeInMib * BYTES_IN_MIB);

end:
    CFWriteStreamClose(writeStream);
    CFRelease(writeStream);
    return success;
}
