/*
 * QError Module
 *
 * Copyright (C) 2009 Red Hat Inc.
 *
 * Authors:
 *  Luiz Capitulino <lcapitulino@redhat.com>
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.1 or later.
 * See the COPYING.LIB file in the top-level directory.
 */
#ifndef QERROR_H
#define QERROR_H

/*
 * These macros will go away, please don't use in new code, and do not
 * add new ones!
 */
#define QERR_BASE_NOT_FOUND \
    "Base '%s' not found"

#define QERR_BUS_NO_HOTPLUG \
    "Bus '%s' does not support hotplugging"

#define QERR_DEVICE_HAS_NO_MEDIUM \
    "Device '%s' has no medium"

#define QERR_DEVICE_INIT_FAILED \
    "Device '%s' could not be initialized"

#define QERR_DEVICE_IN_USE \
    "Device '%s' is in use"

#define QERR_DEVICE_NO_HOTPLUG \
    "Device '%s' does not support hotplugging"

#define QERR_FD_NOT_FOUND \
    "File descriptor named '%s' not found"

#define QERR_FD_NOT_SUPPLIED \
    "No file descriptor supplied via SCM_RIGHTS"

#define QERR_FEATURE_DISABLED \
    "The feature '%s' is not enabled"

#define QERR_INVALID_BLOCK_FORMAT \
    "Invalid block format '%s'"

#define QERR_INVALID_PARAMETER \
    "Invalid parameter '%s'"

#define QERR_INVALID_PARAMETER_TYPE \
    "Invalid parameter type for '%s', expected: %s"

#define QERR_INVALID_PARAMETER_VALUE \
    "Parameter '%s' expects %s"

#define QERR_INVALID_PASSWORD \
    "Password incorrect"

#define QERR_IO_ERROR \
    "An IO error has occurred"

#define QERR_MIGRATION_ACTIVE \
    "There's a migration process in progress"

#define QERR_MISSING_PARAMETER \
    "Parameter '%s' is missing"

#define QERR_PERMISSION_DENIED \
    "Insufficient permission to perform this operation"

#define QERR_PROPERTY_VALUE_BAD \
    "Property '%s.%s' doesn't take value '%s'"

#define QERR_PROPERTY_VALUE_OUT_OF_RANGE \
    "Property %s.%s doesn't take value %" PRId64 " (minimum: %" PRId64 ", maximum: %" PRId64 ")"

#define QERR_QGA_COMMAND_FAILED \
    "Guest agent command failed, error was '%s'"

#define QERR_REPLAY_NOT_SUPPORTED \
    "Record/replay feature is not supported for '%s'"

#define QERR_SET_PASSWD_FAILED \
    "Could not set password"

#define QERR_UNDEFINED_ERROR \
    "An undefined error has occurred"

#define QERR_UNSUPPORTED \
    "this feature or command is not currently supported"

#endif /* QERROR_H */
