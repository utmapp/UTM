/*
 * QEMU Error Objects
 *
 * Copyright IBM, Corp. 2011
 * Copyright (C) 2011-2015 Red Hat, Inc.
 *
 * Authors:
 *  Anthony Liguori   <aliguori@us.ibm.com>
 *  Markus Armbruster <armbru@redhat.com>
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.  See
 * the COPYING.LIB file in the top-level directory.
 */

/*
 * Error reporting system loosely patterned after Glib's GError.
 *
 * = Rules =
 *
 * - Functions that use Error to report errors have an Error **errp
 *   parameter.  It should be the last parameter, except for functions
 *   taking variable arguments.
 *
 * - You may pass NULL to not receive the error, &error_abort to abort
 *   on error, &error_fatal to exit(1) on error, or a pointer to a
 *   variable containing NULL to receive the error.
 *
 * - Separation of concerns: the function is responsible for detecting
 *   errors and failing cleanly; handling the error is its caller's
 *   job.  Since the value of @errp is about handling the error, the
 *   function should not examine it.
 *
 * - The function may pass @errp to functions it calls to pass on
 *   their errors to its caller.  If it dereferences @errp to check
 *   for errors, it must use ERRP_GUARD().
 *
 * - On success, the function should not touch *errp.  On failure, it
 *   should set a new error, e.g. with error_setg(errp, ...), or
 *   propagate an existing one, e.g. with error_propagate(errp, ...).
 *
 * - Whenever practical, also return a value that indicates success /
 *   failure.  This can make the error checking more concise, and can
 *   avoid useless error object creation and destruction.  Note that
 *   we still have many functions returning void.  We recommend
 *   • bool-valued functions return true on success / false on failure,
 *   • pointer-valued functions return non-null / null pointer, and
 *   • integer-valued functions return non-negative / negative.
 *
 * = Creating errors =
 *
 * Create an error:
 *     error_setg(errp, "situation normal, all fouled up");
 * where @errp points to the location to receive the error.
 *
 * Create an error and add additional explanation:
 *     error_setg(errp, "invalid quark");
 *     error_append_hint(errp, "Valid quarks are up, down, strange, "
 *                       "charm, top, bottom.\n");
 * This may require use of ERRP_GUARD(); more on that below.
 *
 * Do *not* contract this to
 *     error_setg(errp, "invalid quark\n" // WRONG!
 *                "Valid quarks are up, down, strange, charm, top, bottom.");
 *
 * = Reporting and destroying errors =
 *
 * Report an error to the current monitor if we have one, else stderr:
 *     error_report_err(err);
 * This frees the error object.
 *
 * Likewise, but with additional text prepended:
 *     error_reportf_err(err, "Could not frobnicate '%s': ", name);
 *
 * Report an error somewhere else:
 *     const char *msg = error_get_pretty(err);
 *     do with msg what needs to be done...
 *     error_free(err);
 * Note that this loses hints added with error_append_hint().
 *
 * Call a function ignoring errors:
 *     foo(arg, NULL);
 * This is more concise than
 *     Error *err = NULL;
 *     foo(arg, &err);
 *     error_free(err); // don't do this
 *
 * Call a function aborting on errors:
 *     foo(arg, &error_abort);
 * This is more concise and fails more nicely than
 *     Error *err = NULL;
 *     foo(arg, &err);
 *     assert(!err); // don't do this
 *
 * Call a function treating errors as fatal:
 *     foo(arg, &error_fatal);
 * This is more concise than
 *     Error *err = NULL;
 *     foo(arg, &err);
 *     if (err) { // don't do this
 *         error_report_err(err);
 *         exit(1);
 *     }
 *
 * Handle an error without reporting it (just for completeness):
 *     error_free(err);
 *
 * Assert that an expected error occurred, but clean it up without
 * reporting it (primarily useful in testsuites):
 *     error_free_or_abort(&err);
 *
 * = Passing errors around =
 *
 * Errors get passed to the caller through the conventional @errp
 * parameter.
 *
 * Create a new error and pass it to the caller:
 *     error_setg(errp, "situation normal, all fouled up");
 *
 * Call a function, receive an error from it, and pass it to the caller
 * - when the function returns a value that indicates failure, say
 *   false:
 *     if (!foo(arg, errp)) {
 *         handle the error...
 *     }
 * - when it does not, say because it is a void function:
 *     ERRP_GUARD();
 *     foo(arg, errp);
 *     if (*errp) {
 *         handle the error...
 *     }
 * More on ERRP_GUARD() below.
 *
 * Code predating ERRP_GUARD() still exists, and looks like this:
 *     Error *err = NULL;
 *     foo(arg, &err);
 *     if (err) {
 *         handle the error...
 *         error_propagate(errp, err); // deprecated
 *     }
 * Avoid in new code.  Do *not* "optimize" it to
 *     foo(arg, errp);
 *     if (*errp) { // WRONG!
 *         handle the error...
 *     }
 * because errp may be NULL without the ERRP_GUARD() guard.
 *
 * But when all you do with the error is pass it on, please use
 *     foo(arg, errp);
 * for readability.
 *
 * Receive an error, and handle it locally
 * - when the function returns a value that indicates failure, say
 *   false:
 *     Error *err = NULL;
 *     if (!foo(arg, &err)) {
 *         handle the error...
 *     }
 * - when it does not, say because it is a void function:
 *     Error *err = NULL;
 *     foo(arg, &err);
 *     if (err) {
 *         handle the error...
 *     }
 *
 * Pass an existing error to the caller:
 *     error_propagate(errp, err);
 * This is rarely needed.  When @err is a local variable, use of
 * ERRP_GUARD() commonly results in more readable code.
 *
 * Pass an existing error to the caller with the message modified:
 *     error_propagate_prepend(errp, err,
 *                             "Could not frobnicate '%s': ", name);
 * This is more concise than
 *     error_propagate(errp, err); // don't do this
 *     error_prepend(errp, "Could not frobnicate '%s': ", name);
 * and works even when @errp is &error_fatal.
 *
 * Receive and accumulate multiple errors (first one wins):
 *     Error *err = NULL, *local_err = NULL;
 *     foo(arg, &err);
 *     bar(arg, &local_err);
 *     error_propagate(&err, local_err);
 *     if (err) {
 *         handle the error...
 *     }
 *
 * Do *not* "optimize" this to
 *     Error *err = NULL;
 *     foo(arg, &err);
 *     bar(arg, &err); // WRONG!
 *     if (err) {
 *         handle the error...
 *     }
 * because this may pass a non-null err to bar().
 *
 * Likewise, do *not*
 *     Error *err = NULL;
 *     if (cond1) {
 *         error_setg(&err, ...);
 *     }
 *     if (cond2) {
 *         error_setg(&err, ...); // WRONG!
 *     }
 * because this may pass a non-null err to error_setg().
 *
 * = Why, when and how to use ERRP_GUARD() =
 *
 * Without ERRP_GUARD(), use of the @errp parameter is restricted:
 * - It must not be dereferenced, because it may be null.
 * - It should not be passed to error_prepend() or
 *   error_append_hint(), because that doesn't work with &error_fatal.
 * ERRP_GUARD() lifts these restrictions.
 *
 * To use ERRP_GUARD(), add it right at the beginning of the function.
 * @errp can then be used without worrying about the argument being
 * NULL or &error_fatal.
 *
 * Using it when it's not needed is safe, but please avoid cluttering
 * the source with useless code.
 *
 * = Converting to ERRP_GUARD() =
 *
 * To convert a function to use ERRP_GUARD():
 *
 * 0. If the Error ** parameter is not named @errp, rename it to
 *    @errp.
 *
 * 1. Add an ERRP_GUARD() invocation, by convention right at the
 *    beginning of the function.  This makes @errp safe to use.
 *
 * 2. Replace &err by errp, and err by *errp.  Delete local variable
 *    @err.
 *
 * 3. Delete error_propagate(errp, *errp), replace
 *    error_propagate_prepend(errp, *errp, ...) by error_prepend(errp, ...)
 *
 * 4. Ensure @errp is valid at return: when you destroy *errp, set
 *    errp = NULL.
 *
 * Example:
 *
 *     bool fn(..., Error **errp)
 *     {
 *         Error *err = NULL;
 *
 *         foo(arg, &err);
 *         if (err) {
 *             handle the error...
 *             error_propagate(errp, err);
 *             return false;
 *         }
 *         ...
 *     }
 *
 * becomes
 *
 *     bool fn(..., Error **errp)
 *     {
 *         ERRP_GUARD();
 *
 *         foo(arg, errp);
 *         if (*errp) {
 *             handle the error...
 *             return false;
 *         }
 *         ...
 *     }
 *
 * For mass-conversion, use scripts/coccinelle/errp-guard.cocci.
 */

#ifndef ERROR_H
#define ERROR_H

#include "qapi-types-error.h"

/*
 * Overall category of an error.
 * Based on the qapi type QapiErrorClass, but reproduced here for nicer
 * enum names.
 */
typedef enum ErrorClass {
    ERROR_CLASS_GENERIC_ERROR = QAPI_ERROR_CLASS_GENERICERROR,
    ERROR_CLASS_COMMAND_NOT_FOUND = QAPI_ERROR_CLASS_COMMANDNOTFOUND,
    ERROR_CLASS_DEVICE_NOT_ACTIVE = QAPI_ERROR_CLASS_DEVICENOTACTIVE,
    ERROR_CLASS_DEVICE_NOT_FOUND = QAPI_ERROR_CLASS_DEVICENOTFOUND,
    ERROR_CLASS_KVM_MISSING_CAP = QAPI_ERROR_CLASS_KVMMISSINGCAP,
} ErrorClass;

/*
 * Get @err's human-readable error message.
 */
const char *error_get_pretty(const Error *err);

/*
 * Get @err's error class.
 * Note: use of error classes other than ERROR_CLASS_GENERIC_ERROR is
 * strongly discouraged.
 */
ErrorClass error_get_class(const Error *err);

/*
 * Create a new error object and assign it to *@errp.
 * If @errp is NULL, the error is ignored.  Don't bother creating one
 * then.
 * If @errp is &error_abort, print a suitable message and abort().
 * If @errp is &error_fatal, print a suitable message and exit(1).
 * If @errp is anything else, *@errp must be NULL.
 * The new error's class is ERROR_CLASS_GENERIC_ERROR, and its
 * human-readable error message is made from printf-style @fmt, ...
 * The resulting message should be a single phrase, with no newline or
 * trailing punctuation.
 * Please don't error_setg(&error_fatal, ...), use error_report() and
 * exit(), because that's more obvious.
 * Likewise, don't error_setg(&error_abort, ...), use assert().
 */
#define error_setg(errp, fmt, ...)                              \
    error_setg_internal((errp), __FILE__, __LINE__, __func__,   \
                        (fmt), ## __VA_ARGS__)
void error_setg_internal(Error **errp,
                         const char *src, int line, const char *func,
                         const char *fmt, ...)
    GCC_FMT_ATTR(5, 6);

/*
 * Just like error_setg(), with @os_error info added to the message.
 * If @os_error is non-zero, ": " + strerror(os_error) is appended to
 * the human-readable error message.
 *
 * The value of errno (which usually can get clobbered by almost any
 * function call) will be preserved.
 */
#define error_setg_errno(errp, os_error, fmt, ...)                      \
    error_setg_errno_internal((errp), __FILE__, __LINE__, __func__,     \
                              (os_error), (fmt), ## __VA_ARGS__)
void error_setg_errno_internal(Error **errp,
                               const char *fname, int line, const char *func,
                               int os_error, const char *fmt, ...)
    GCC_FMT_ATTR(6, 7);

#ifdef _WIN32
/*
 * Just like error_setg(), with @win32_error info added to the message.
 * If @win32_error is non-zero, ": " + g_win32_error_message(win32_err)
 * is appended to the human-readable error message.
 */
#define error_setg_win32(errp, win32_err, fmt, ...)                     \
    error_setg_win32_internal((errp), __FILE__, __LINE__, __func__,     \
                              (win32_err), (fmt), ## __VA_ARGS__)
void error_setg_win32_internal(Error **errp,
                               const char *src, int line, const char *func,
                               int win32_err, const char *fmt, ...)
    GCC_FMT_ATTR(6, 7);
#endif

/*
 * Propagate error object (if any) from @local_err to @dst_errp.
 * If @local_err is NULL, do nothing (because there's nothing to
 * propagate).
 * Else, if @dst_errp is NULL, errors are being ignored.  Free the
 * error object.
 * Else, if @dst_errp is &error_abort, print a suitable message and
 * abort().
 * Else, if @dst_errp is &error_fatal, print a suitable message and
 * exit(1).
 * Else, if @dst_errp already contains an error, ignore this one: free
 * the error object.
 * Else, move the error object from @local_err to *@dst_errp.
 * On return, @local_err is invalid.
 * Please use ERRP_GUARD() instead when possible.
 * Please don't error_propagate(&error_fatal, ...), use
 * error_report_err() and exit(), because that's more obvious.
 */
void error_propagate(Error **dst_errp, Error *local_err);


/*
 * Propagate error object (if any) with some text prepended.
 * Behaves like
 *     error_prepend(&local_err, fmt, ...);
 *     error_propagate(dst_errp, local_err);
 * Please use ERRP_GUARD() and error_prepend() instead when possible.
 */
void error_propagate_prepend(Error **dst_errp, Error *local_err,
                             const char *fmt, ...)
    GCC_FMT_ATTR(3, 4);

/*
 * Prepend some text to @errp's human-readable error message.
 * The text is made by formatting @fmt, @ap like vprintf().
 */
void error_vprepend(Error *const *errp, const char *fmt, va_list ap)
    GCC_FMT_ATTR(2, 0);

/*
 * Prepend some text to @errp's human-readable error message.
 * The text is made by formatting @fmt, ... like printf().
 */
void error_prepend(Error *const *errp, const char *fmt, ...)
    GCC_FMT_ATTR(2, 3);

/*
 * Append a printf-style human-readable explanation to an existing error.
 * If the error is later reported to a human user with
 * error_report_err() or warn_report_err(), the hints will be shown,
 * too.  If it's reported via QMP, the hints will be ignored.
 * Intended use is adding helpful hints on the human user interface,
 * e.g. a list of valid values.  It's not for clarifying a confusing
 * error message.
 * @errp may be NULL, but not &error_fatal or &error_abort.
 * Trivially the case if you call it only after error_setg() or
 * error_propagate().
 * May be called multiple times.  The resulting hint should end with a
 * newline.
 */
void error_append_hint(Error *const *errp, const char *fmt, ...)
    GCC_FMT_ATTR(2, 3);

/*
 * Convenience function to report open() failure.
 */
#define error_setg_file_open(errp, os_errno, filename)                  \
    error_setg_file_open_internal((errp), __FILE__, __LINE__, __func__, \
                                  (os_errno), (filename))
void error_setg_file_open_internal(Error **errp,
                                   const char *src, int line, const char *func,
                                   int os_errno, const char *filename);

/*
 * Return an exact copy of @err.
 */
Error *error_copy(const Error *err);

/*
 * Free @err.
 * @err may be NULL.
 */
void error_free(Error *err);

/*
 * Convenience function to assert that *@errp is set, then silently free it.
 */
void error_free_or_abort(Error **errp);

/*
 * Convenience function to warn_report() and free @err.
 * The report includes hints added with error_append_hint().
 */
void warn_report_err(Error *err);

/*
 * Convenience function to error_report() and free @err.
 * The report includes hints added with error_append_hint().
 */
void error_report_err(Error *err);

/*
 * Convenience function to error_prepend(), warn_report() and free @err.
 */
void warn_reportf_err(Error *err, const char *fmt, ...)
    GCC_FMT_ATTR(2, 3);

/*
 * Convenience function to error_prepend(), error_report() and free @err.
 */
void error_reportf_err(Error *err, const char *fmt, ...)
    GCC_FMT_ATTR(2, 3);

/*
 * Just like error_setg(), except you get to specify the error class.
 * Note: use of error classes other than ERROR_CLASS_GENERIC_ERROR is
 * strongly discouraged.
 */
#define error_set(errp, err_class, fmt, ...)                    \
    error_set_internal((errp), __FILE__, __LINE__, __func__,    \
                       (err_class), (fmt), ## __VA_ARGS__)
void error_set_internal(Error **errp,
                        const char *src, int line, const char *func,
                        ErrorClass err_class, const char *fmt, ...)
    GCC_FMT_ATTR(6, 7);

/*
 * Make @errp parameter easier to use regardless of argument value
 *
 * This macro is for use right at the beginning of a function that
 * takes an Error **errp parameter to pass errors to its caller.  The
 * parameter must be named @errp.
 *
 * It must be used when the function dereferences @errp or passes
 * @errp to error_prepend(), error_vprepend(), or error_append_hint().
 * It is safe to use even when it's not needed, but please avoid
 * cluttering the source with useless code.
 *
 * If @errp is NULL or &error_fatal, rewrite it to point to a local
 * Error variable, which will be automatically propagated to the
 * original @errp on function exit.
 *
 * Note: &error_abort is not rewritten, because that would move the
 * abort from the place where the error is created to the place where
 * it's propagated.
 */
#define ERRP_GUARD()                                            \
    g_auto(ErrorPropagator) _auto_errp_prop = {.errp = errp};   \
    do {                                                        \
        if (!errp || errp == &error_fatal) {                    \
            errp = &_auto_errp_prop.local_err;                  \
        }                                                       \
    } while (0)

typedef struct ErrorPropagator {
    Error *local_err;
    Error **errp;
} ErrorPropagator;

static inline void error_propagator_cleanup(ErrorPropagator *prop)
{
    error_propagate(prop->errp, prop->local_err);
}

G_DEFINE_AUTO_CLEANUP_CLEAR_FUNC(ErrorPropagator, error_propagator_cleanup);

/*
 * Special error destination to abort on error.
 * See error_setg() and error_propagate() for details.
 */
extern Error *error_abort;

/*
 * Special error destination to exit(1) on error.
 * See error_setg() and error_propagate() for details.
 */
extern Error *error_fatal;

#endif
