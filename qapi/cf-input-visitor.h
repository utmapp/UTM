/*
 * Input Visitor
 *
 * Copyright (C) 2017 Red Hat, Inc.
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

#ifndef CF_INPUT_VISITOR_H
#define CF_INPUT_VISITOR_H

#include "visitor.h"

typedef struct CFObjectInputVisitor CFObjectInputVisitor;

/*
 * Create a CoreFoundation input visitor for @obj
 *
 * A CFType input visitor visit builds a QAPI object from a CFType.
 * This simultaneously walks the QAPI object being built and the
 * CFType.  The latter walk starts at @obj.
 *
 * visit_type_FOO() creates an instance of QAPI type FOO.  The visited
 * CFType must match FOO.  CFDictionary matches struct/union types, 
 * CFArray matches list types, CFString matches type 'str' and enumeration
 * types, CFNumber matches integer and float types, CFBoolean matches type
 * 'bool'.  Type 'any' is matched by CFType.  A QAPI alternate type
 * is matched when one of its member types is.
 *
 * visit_start_struct() ... visit_end_struct() visits a CFDictionary and
 * creates a QAPI struct/union.  Visits in between visit the
 * dictionary members.  visit_optional() is true when the CFDictionary has
 * this member.  visit_check_struct() fails if unvisited members
 * remain.
 *
 * visit_start_list() ... visit_end_list() visits a CFArray and creates
 * a QAPI list.  Visits in between visit list members, one after the
 * other.  visit_next_list() returns NULL when all CFArray members have
 * been visited.  visit_check_list() fails if unvisited members
 * remain.
 *
 * visit_start_alternate() ... visit_end_alternate() visits a CFType
 * and creates a QAPI alternate.  The visit in between visits the same
 * CFType and initializes the alternate member that is in use.
 *
 * Error messages refer to parts of @obj in JavaScript/Python syntax.
 * For example, 'a.b[2]' refers to the second member of the CFArray
 * member 'b' of the CFDictionary member 'a' of CFDictionary @obj.
 *
 * The caller is responsible for freeing the visitor with
 * visit_free().
 */
Visitor *cf_input_visitor_new(CFTypeRef obj);

#endif
