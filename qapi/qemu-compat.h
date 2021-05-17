//
// Copyright © 2019 osy. All rights reserved.
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

#ifndef qemu_compat_h
#define qemu_compat_h

#include <CoreFoundation/CoreFoundation.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <glib.h>

typedef struct Error Error;
typedef struct Visitor Visitor;

#ifndef container_of
#define container_of(ptr, type, member) ({                      \
        const typeof(((type *) 0)->member) *__mptr = (ptr);     \
        (type *) ((char *) __mptr - offsetof(type, member));})
#endif

#define error_report(fmt, ...) fprintf(stderr, fmt, ## __VA_ARGS__)
#define warn_report(fmt, ...) fprintf(stderr, fmt, ## __VA_ARGS__)
#define error_printf_unless_qmp(fmt, ...) fprintf(stderr, fmt, ## __VA_ARGS__)

#define trace_visit_complete(...)
#define trace_visit_free(...)
#define trace_visit_start_struct(...)
#define trace_visit_check_struct(...)
#define trace_visit_end_struct(...)
#define trace_visit_start_list(...)
#define trace_visit_next_list(...)
#define trace_visit_check_list(...)
#define trace_visit_end_list(...)
#define trace_visit_start_alternate(...)
#define trace_visit_end_alternate(...)
#define trace_visit_optional(...)
#define trace_visit_type_int(...)
#define trace_visit_type_uint8(...)
#define trace_visit_type_uint16(...)
#define trace_visit_type_uint32(...)
#define trace_visit_type_uint64(...)
#define trace_visit_type_int8(...)
#define trace_visit_type_int16(...)
#define trace_visit_type_int32(...)
#define trace_visit_type_int64(...)
#define trace_visit_type_size(...)
#define trace_visit_type_bool(...)
#define trace_visit_type_str(...)
#define trace_visit_type_number(...)
#define trace_visit_type_any(...)
#define trace_visit_type_null(...)
#define trace_visit_type_enum(...)
#define trace_visit_deprecated_accept(...)
#define trace_visit_deprecated(...)

void qmp_rpc_call(CFDictionaryRef args, CFDictionaryRef *ret, Error **err, void *ctx);

// TODO: make this match with qemu build
#define CONFIG_SPICE 1
#define TARGET_I386 1

#define GCC_FMT_ATTR(n, m)

#endif /* qemu_compat_h */
