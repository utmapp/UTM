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

#ifndef QAPI_VISITOR_H
#define QAPI_VISITOR_H

#include "qemu-compat.h"
#include "qapi-builtin-types.h"

/*
 * The QAPI schema defines both a set of C data types, and a QMP wire
 * format.  QAPI objects can contain references to other QAPI objects,
 * resulting in a directed acyclic graph.  QAPI also generates visitor
 * functions to walk these graphs.  This file represents the interface
 * for doing work at each node of a QAPI graph; it can also be used
 * for a virtual walk, where there is no actual QAPI C struct.
 *
 * There are four kinds of visitor classes: input visitors (QObject,
 * string, and QemuOpts) parse an external representation and build
 * the corresponding QAPI graph, output visitors (QObject and string) take
 * a completed QAPI graph and generate an external representation, the
 * dealloc visitor can take a QAPI graph (possibly partially
 * constructed) and recursively free its resources, and the clone
 * visitor performs a deep clone of one QAPI object to another.  While
 * the dealloc and QObject input/output visitors are general, the string,
 * QemuOpts, and clone visitors have some implementation limitations;
 * see the documentation for each visitor for more details on what it
 * supports.  Also, see visitor-impl.h for the callback contracts
 * implemented by each visitor, and docs/devel/qapi-code-gen.txt for more
 * about the QAPI code generator.
 *
 * All of the visitors are created via:
 *
 * Visitor *subtype_visitor_new(parameters...);
 *
 * A visitor should be used for exactly one top-level visit_type_FOO()
 * or virtual walk; if that is successful, the caller can optionally
 * call visit_complete() (for now, useful only for output visits, but
 * safe to call on all visits).  Then, regardless of success or
 * failure, the user should call visit_free() to clean up resources.
 * It is okay to free the visitor without completing the visit, if
 * some other error is detected in the meantime.
 *
 * All QAPI types have a corresponding function with a signature
 * roughly compatible with this:
 *
 * void visit_type_FOO(Visitor *v, const char *name, T obj, Error **errp);
 *
 * where T is FOO for scalar types, and FOO * otherwise.  The scalar
 * visitors are declared here; the remaining visitors are generated in
 * qapi-visit.h.
 *
 * The @name parameter of visit_type_FOO() describes the relation
 * between this QAPI value and its parent container.  When visiting
 * the root of a tree, @name is ignored; when visiting a member of an
 * object, @name is the key associated with the value; when visiting a
 * member of a list, @name is NULL; and when visiting the member of an
 * alternate, @name should equal the name used for visiting the
 * alternate.
 *
 * The visit_type_FOO() functions expect a non-null @obj argument;
 * they allocate *@obj during input visits, leave it unchanged on
 * output visits, and recursively free any resources during a dealloc
 * visit.  Each function also takes the customary @errp argument (see
 * qapi/error.h for details), for reporting any errors (such as if a
 * member @name is not present, or is present but not the specified
 * type).
 *
 * If an error is detected during visit_type_FOO() with an input
 * visitor, then *@obj will be NULL for pointer types, and left
 * unchanged for scalar types.  Using an output or clone visitor with
 * an incomplete object has undefined behavior (other than a special
 * case for visit_type_str() treating NULL like ""), while the dealloc
 * visitor safely handles incomplete objects.  Since input visitors
 * never produce an incomplete object, such an object is possible only
 * by manual construction.
 *
 * For the QAPI object types (structs, unions, and alternates), there
 * is an additional generated function in qapi-visit.h compatible
 * with:
 *
 * void visit_type_FOO_members(Visitor *v, FOO *obj, Error **errp);
 *
 * for visiting the members of a type without also allocating the QAPI
 * struct.
 *
 * Additionally, in qapi-types.h, all QAPI pointer types (structs,
 * unions, alternates, and lists) have a generated function compatible
 * with:
 *
 * void qapi_free_FOO(FOO *obj);
 *
 * where behaves like free() in that @obj may be NULL.  Such objects
 * may also be used with the following macro, provided alongside the
 * clone visitor:
 *
 * Type *QAPI_CLONE(Type, src);
 *
 * in order to perform a deep clone of @src.  Because of the generated
 * qapi_free functions and the QAPI_CLONE() macro, the clone and
 * dealloc visitor should not be used directly outside of QAPI code.
 *
 * QAPI types can also inherit from a base class; when this happens, a
 * function is generated for easily going from the derived type to the
 * base type:
 *
 * BASE *qapi_CHILD_base(CHILD *obj);
 *
 * For a real QAPI struct, typical input usage involves:
 *
 * <example>
 *  Foo *f;
 *  Error *err = NULL;
 *  Visitor *v;
 *
 *  v = FOO_visitor_new(...);
 *  visit_type_Foo(v, NULL, &f, &err);
 *  if (err) {
 *      ...handle error...
 *  } else {
 *      ...use f...
 *  }
 *  visit_free(v);
 *  qapi_free_Foo(f);
 * </example>
 *
 * For a list, it is:
 * <example>
 *  FooList *l;
 *  Error *err = NULL;
 *  Visitor *v;
 *
 *  v = FOO_visitor_new(...);
 *  visit_type_FooList(v, NULL, &l, &err);
 *  if (err) {
 *      ...handle error...
 *  } else {
 *      for ( ; l; l = l->next) {
 *          ...use l->value...
 *      }
 *  }
 *  visit_free(v);
 *  qapi_free_FooList(l);
 * </example>
 *
 * Similarly, typical output usage is:
 *
 * <example>
 *  Foo *f = ...obtain populated object...
 *  Error *err = NULL;
 *  Visitor *v;
 *  Type *result;
 *
 *  v = FOO_visitor_new(..., &result);
 *  visit_type_Foo(v, NULL, &f, &err);
 *  if (err) {
 *      ...handle error...
 *  } else {
 *      visit_complete(v, &result);
 *      ...use result...
 *  }
 *  visit_free(v);
 * </example>
 *
 * When visiting a real QAPI struct, this file provides several
 * helpers that rely on in-tree information to control the walk:
 * visit_optional() for the 'has_member' field associated with
 * optional 'member' in the C struct; and visit_next_list() for
 * advancing through a FooList linked list.  Similarly, the
 * visit_is_input() helper makes it possible to write code that is
 * visitor-agnostic everywhere except for cleanup.  Only the generated
 * visit_type functions need to use these helpers.
 *
 * It is also possible to use the visitors to do a virtual walk, where
 * no actual QAPI struct is present.  In this situation, decisions
 * about what needs to be walked are made by the calling code, and
 * structured visits are split between pairs of start and end methods
 * (where the end method must be called if the start function
 * succeeded, even if an intermediate visit encounters an error).
 * Thus, a virtual walk corresponding to '{ "list": [1, 2] }' looks
 * like:
 *
 * <example>
 *  Visitor *v;
 *  Error *err = NULL;
 *  int value;
 *
 *  v = FOO_visitor_new(...);
 *  visit_start_struct(v, NULL, NULL, 0, &err);
 *  if (err) {
 *      goto out;
 *  }
 *  visit_start_list(v, "list", NULL, 0, &err);
 *  if (err) {
 *      goto outobj;
 *  }
 *  value = 1;
 *  visit_type_int(v, NULL, &value, &err);
 *  if (err) {
 *      goto outlist;
 *  }
 *  value = 2;
 *  visit_type_int(v, NULL, &value, &err);
 *  if (err) {
 *      goto outlist;
 *  }
 * outlist:
 *  visit_end_list(v, NULL);
 *  if (!err) {
 *      visit_check_struct(v, &err);
 *  }
 * outobj:
 *  visit_end_struct(v, NULL);
 * out:
 *  error_propagate(errp, err);
 *  visit_free(v);
 * </example>
 */

/*** Useful types ***/

/* This struct is layout-compatible with all other *List structs
 * created by the QAPI generator.  It is used as a typical
 * singly-linked list. */
typedef struct GenericList {
    struct GenericList *next;
    char padding[];
} GenericList;

/* This struct is layout-compatible with all Alternate types
 * created by the QAPI generator. */
typedef struct GenericAlternate {
    CFTypeID type;
    char padding[];
} GenericAlternate;

/*** Visitor cleanup ***/

/*
 * Complete the visit, collecting any output.
 *
 * May only be called only once after a successful top-level
 * visit_type_FOO() or visit_end_ITEM(), and marks the end of the
 * visit.  The @opaque pointer should match the output parameter
 * passed to the subtype_visitor_new() used to create an output
 * visitor, or NULL for any other visitor.  Needed for output
 * visitors, but may also be called with other visitors.
 */
void visit_complete(Visitor *v, void *opaque);

/*
 * Free @v and any resources it has tied up.
 *
 * May be called whether or not the visit has been successfully
 * completed, but should not be called until a top-level
 * visit_type_FOO() or visit_start_ITEM() has been performed on the
 * visitor.  Safe if @v is NULL.
 */
void visit_free(Visitor *v);


/*** Visiting structures ***/

/*
 * Start visiting an object @obj (struct or union).
 *
 * @name expresses the relationship of this object to its parent
 * container; see the general description of @name above.
 *
 * @obj must be non-NULL for a real walk, in which case @size
 * determines how much memory an input or clone visitor will allocate
 * into *@obj.  @obj may also be NULL for a virtual walk, in which
 * case @size is ignored.
 *
 * @errp obeys typical error usage, and reports failures such as a
 * member @name is not present, or present but not an object.  On
 * error, input visitors set *@obj to NULL.
 *
 * After visit_start_struct() succeeds, the caller may visit its
 * members one after the other, passing the member's name and address
 * within the struct.  Finally, visit_end_struct() needs to be called
 * with the same @obj to clean up, even if intermediate visits fail.
 * See the examples above.
 *
 * FIXME Should this be named visit_start_object, since it is also
 * used for QAPI unions, and maps to JSON objects?
 */
void visit_start_struct(Visitor *v, const char *name, void **obj,
                        size_t size, Error **errp);

/*
 * Prepare for completing an object visit.
 *
 * @errp obeys typical error usage, and reports failures such as
 * unparsed keys remaining in the input stream.
 *
 * Should be called prior to visit_end_struct() if all other
 * intermediate visit steps were successful, to allow the visitor one
 * last chance to report errors.  May be skipped on a cleanup path,
 * where there is no need to check for further errors.
 */
void visit_check_struct(Visitor *v, Error **errp);

/*
 * Complete an object visit started earlier.
 *
 * @obj must match what was passed to the paired visit_start_struct().
 *
 * Must be called after any successful use of visit_start_struct(),
 * even if intermediate processing was skipped due to errors, to allow
 * the backend to release any resources.  Destroying the visitor early
 * with visit_free() behaves as if this was implicitly called.
 */
void visit_end_struct(Visitor *v, void **obj);


/*** Visiting lists ***/

/*
 * Start visiting a list.
 *
 * @name expresses the relationship of this list to its parent
 * container; see the general description of @name above.
 *
 * @list must be non-NULL for a real walk, in which case @size
 * determines how much memory an input or clone visitor will allocate
 * into *@list (at least sizeof(GenericList)).  Some visitors also
 * allow @list to be NULL for a virtual walk, in which case @size is
 * ignored.
 *
 * @errp obeys typical error usage, and reports failures such as a
 * member @name is not present, or present but not a list.  On error,
 * input visitors set *@list to NULL.
 *
 * After visit_start_list() succeeds, the caller may visit its members
 * one after the other.  A real visit (where @obj is non-NULL) uses
 * visit_next_list() for traversing the linked list, while a virtual
 * visit (where @obj is NULL) uses other means.  For each list
 * element, call the appropriate visit_type_FOO() with name set to
 * NULL and obj set to the address of the value member of the list
 * element.  Finally, visit_end_list() needs to be called with the
 * same @list to clean up, even if intermediate visits fail.  See the
 * examples above.
 */
void visit_start_list(Visitor *v, const char *name, GenericList **list,
                      size_t size, Error **errp);

/*
 * Iterate over a GenericList during a non-virtual list visit.
 *
 * @size represents the size of a linked list node (at least
 * sizeof(GenericList)).
 *
 * @tail must not be NULL; on the first call, @tail is the value of
 * *list after visit_start_list(), and on subsequent calls @tail must
 * be the previously returned value.  Should be called in a loop until
 * a NULL return or error occurs; for each non-NULL return, the caller
 * then calls the appropriate visit_type_*() for the element type of
 * the list, with that function's name parameter set to NULL and obj
 * set to the address of @tail->value.
 */
GenericList *visit_next_list(Visitor *v, GenericList *tail, size_t size);

/*
 * Prepare for completing a list visit.
 *
 * @errp obeys typical error usage, and reports failures such as
 * unvisited list tail remaining in the input stream.
 *
 * Should be called prior to visit_end_list() if all other
 * intermediate visit steps were successful, to allow the visitor one
 * last chance to report errors.  May be skipped on a cleanup path,
 * where there is no need to check for further errors.
 */
void visit_check_list(Visitor *v, Error **errp);

/*
 * Complete a list visit started earlier.
 *
 * @list must match what was passed to the paired visit_start_list().
 *
 * Must be called after any successful use of visit_start_list(), even
 * if intermediate processing was skipped due to errors, to allow the
 * backend to release any resources.  Destroying the visitor early
 * with visit_free() behaves as if this was implicitly called.
 */
void visit_end_list(Visitor *v, void **list);


/*** Visiting alternates ***/

/*
 * Start the visit of an alternate @obj.
 *
 * @name expresses the relationship of this alternate to its parent
 * container; see the general description of @name above.
 *
 * @obj must not be NULL. Input and clone visitors use @size to
 * determine how much memory to allocate into *@obj, then determine
 * the qtype of the next thing to be visited, stored in (*@obj)->type.
 * Other visitors will leave @obj unchanged.
 *
 * If successful, this must be paired with visit_end_alternate() with
 * the same @obj to clean up, even if visiting the contents of the
 * alternate fails.
 */
void visit_start_alternate(Visitor *v, const char *name,
                           GenericAlternate **obj, size_t size,
                           Error **errp);

/*
 * Finish visiting an alternate type.
 *
 * @obj must match what was passed to the paired visit_start_alternate().
 *
 * Must be called after any successful use of visit_start_alternate(),
 * even if intermediate processing was skipped due to errors, to allow
 * the backend to release any resources.  Destroying the visitor early
 * with visit_free() behaves as if this was implicitly called.
 *
 */
void visit_end_alternate(Visitor *v, void **obj);


/*** Other helpers ***/

/*
 * Does optional struct member @name need visiting?
 *
 * @name must not be NULL.  This function is only useful between
 * visit_start_struct() and visit_end_struct(), since only objects
 * have optional keys.
 *
 * @present points to the address of the optional member's has_ flag.
 *
 * Input visitors set *@present according to input; other visitors
 * leave it unchanged.  In either case, return *@present for
 * convenience.
 */
bool visit_optional(Visitor *v, const char *name, bool *present);

/*
 * Visit an enum value.
 *
 * @name expresses the relationship of this enum to its parent
 * container; see the general description of @name above.
 *
 * @obj must be non-NULL.  Input visitors parse input and set *@obj to
 * the enumeration value, leaving @obj unchanged on error; other
 * visitors use *@obj but leave it unchanged.
 *
 * Currently, all input visitors parse text input, and all output
 * visitors produce text output.  The mapping between enumeration
 * values and strings is done by the visitor core, using @strings; it
 * should be the ENUM_lookup array from visit-types.h.
 *
 * May call visit_type_str() under the hood, and the enum visit may
 * fail even if the corresponding string visit succeeded; this implies
 * that visit_type_str() must have no unwelcome side effects.
 */
void visit_type_enum(Visitor *v, const char *name, int *obj,
                     const QEnumLookup *lookup, Error **errp);

/*
 * Check if visitor is an input visitor.
 */
bool visit_is_input(Visitor *v);

/*** Visiting built-in types ***/

/*
 * Visit an integer value.
 *
 * @name expresses the relationship of this integer to its parent
 * container; see the general description of @name above.
 *
 * @obj must be non-NULL.  Input visitors set *@obj to the value;
 * other visitors will leave *@obj unchanged.
 */
void visit_type_int(Visitor *v, const char *name, int64_t *obj, Error **errp);

/*
 * Visit a uint8_t value.
 * Like visit_type_int(), except clamps the value to uint8_t range.
 */
void visit_type_uint8(Visitor *v, const char *name, uint8_t *obj,
                      Error **errp);

/*
 * Visit a uint16_t value.
 * Like visit_type_int(), except clamps the value to uint16_t range.
 */
void visit_type_uint16(Visitor *v, const char *name, uint16_t *obj,
                       Error **errp);

/*
 * Visit a uint32_t value.
 * Like visit_type_int(), except clamps the value to uint32_t range.
 */
void visit_type_uint32(Visitor *v, const char *name, uint32_t *obj,
                       Error **errp);

/*
 * Visit a uint64_t value.
 * Like visit_type_int(), except clamps the value to uint64_t range,
 * that is, ensures it is unsigned.
 */
void visit_type_uint64(Visitor *v, const char *name, uint64_t *obj,
                       Error **errp);

/*
 * Visit an int8_t value.
 * Like visit_type_int(), except clamps the value to int8_t range.
 */
void visit_type_int8(Visitor *v, const char *name, int8_t *obj, Error **errp);

/*
 * Visit an int16_t value.
 * Like visit_type_int(), except clamps the value to int16_t range.
 */
void visit_type_int16(Visitor *v, const char *name, int16_t *obj,
                      Error **errp);

/*
 * Visit an int32_t value.
 * Like visit_type_int(), except clamps the value to int32_t range.
 */
void visit_type_int32(Visitor *v, const char *name, int32_t *obj,
                      Error **errp);

/*
 * Visit an int64_t value.
 * Identical to visit_type_int().
 */
void visit_type_int64(Visitor *v, const char *name, int64_t *obj,
                      Error **errp);

/*
 * Visit a uint64_t value.
 * Like visit_type_uint64(), except that some visitors may choose to
 * recognize additional syntax, such as suffixes for easily scaling
 * values.
 */
void visit_type_size(Visitor *v, const char *name, uint64_t *obj,
                     Error **errp);

/*
 * Visit a boolean value.
 *
 * @name expresses the relationship of this boolean to its parent
 * container; see the general description of @name above.
 *
 * @obj must be non-NULL.  Input visitors set *@obj to the value;
 * other visitors will leave *@obj unchanged.
 */
void visit_type_bool(Visitor *v, const char *name, bool *obj, Error **errp);

/*
 * Visit a string value.
 *
 * @name expresses the relationship of this string to its parent
 * container; see the general description of @name above.
 *
 * @obj must be non-NULL.  Input and clone visitors set *@obj to the
 * value (always using "" rather than NULL for an empty string).
 * Other visitors leave *@obj unchanged, and commonly treat NULL like
 * "".
 *
 * It is safe to cast away const when preparing a (const char *) value
 * into @obj for use by an output visitor.
 *
 * FIXME: Callers that try to output NULL *obj should not be allowed.
 */
void visit_type_str(Visitor *v, const char *name, char **obj, Error **errp);

/*
 * Visit a number (i.e. double) value.
 *
 * @name expresses the relationship of this number to its parent
 * container; see the general description of @name above.
 *
 * @obj must be non-NULL.  Input visitors set *@obj to the value;
 * other visitors will leave *@obj unchanged.  Visitors should
 * document if infinity or NaN are not permitted.
 */
void visit_type_number(Visitor *v, const char *name, double *obj,
                       Error **errp);

/*
 * Visit an arbitrary value.
 *
 * @name expresses the relationship of this value to its parent
 * container; see the general description of @name above.
 *
 * @obj must be non-NULL.  Input visitors set *@obj to the value;
 * other visitors will leave *@obj unchanged.  *@obj must be non-NULL
 * for output visitors.
 *
 * Note that some kinds of input can't express arbitrary QObject.
 * E.g. the visitor returned by qobject_input_visitor_new_keyval()
 * can't create numbers or booleans, only strings.
 */
void visit_type_any(Visitor *v, const char *name, CFTypeRef *obj, Error **errp);

/*
 * Visit a JSON null value.
 *
 * @name expresses the relationship of the null value to its parent
 * container; see the general description of @name above.
 *
 * @obj must be non-NULL.  Input visitors set *@obj to the value;
 * other visitors ignore *@obj.
 */
void visit_type_null(Visitor *v, const char *name, CFNullRef *obj,
                     Error **errp);

#endif
