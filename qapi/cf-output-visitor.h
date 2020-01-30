/*
 * Output Visitor
 *
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

#ifndef CF_OUTPUT_VISITOR_H
#define CF_OUTPUT_VISITOR_H

#include "visitor.h"

typedef struct CFObjectOutputVisitor CFObjectOutputVisitor;

/**
 * Create a CoreFoundation output visitor for @obj
 *
 * A CFType output visitor visit builds a CFType from QAPI Object.
 * This simultaneously walks the QAPI object and the CFType being
 * built.  The latter walk starts at @obj.
 *
 * visit_type_FOO() creates a CFType for QAPI type FOO.  It creates a
 * CFMutableDictionary for struct/union types, a CFMutableArray for 
 * list types, CFString for type 'str' and enumeration types, 
 * CFNumber for integer and float types, CFBoolean for type 'bool'. 
 * For type 'any', it increments the CFType's reference count. 
 * For QAPI alternate types, it creates the CFType for the member 
 * that is in use.
 *
 * visit_start_struct() ... visit_end_struct() visits a QAPI
 * struct/union and creates a CFMutableDictionary.  Visits in between 
 * visit the members.  visit_optional() is true when the struct/union 
 * has this member.  visit_check_struct() does nothing.
 *
 * visit_start_list() ... visit_end_list() visits a QAPI list and
 * creates a CFMutableArray.  Visits in between visit list members, 
 * one after the other.  visit_next_list() returns NULL when all 
 * QAPI list members have been visited.  visit_check_list() does 
 * nothing.
 *
 * visit_start_alternate() ... visit_end_alternate() visits a QAPI
 * alternate.  The visit in between creates the CFType for the
 * alternate member that is in use.
 *
 * Errors are not expected to happen.
 *
 * The caller is responsible for freeing the visitor with
 * visit_free().
 */
Visitor *cf_output_visitor_new(CFTypeRef *result);

#endif
