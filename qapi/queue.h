/*      $NetBSD: queue.h,v 1.52 2009/04/20 09:56:08 mschuett Exp $ */

/*
 * QEMU version: Copy from netbsd, removed debug code, removed some of
 * the implementations.  Left in singly-linked lists, lists, simple
 * queues, and tail queues.
 */

/*
 * Copyright (c) 1991, 1993
 *      The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *      @(#)queue.h     8.5 (Berkeley) 8/20/94
 */

#ifndef QEMU_SYS_QUEUE_H
#define QEMU_SYS_QUEUE_H

/*
 * This file defines four types of data structures: singly-linked lists,
 * lists, simple queues, and tail queues.
 *
 * A singly-linked list is headed by a single forward pointer. The
 * elements are singly linked for minimum space and pointer manipulation
 * overhead at the expense of O(n) removal for arbitrary elements. New
 * elements can be added to the list after an existing element or at the
 * head of the list.  Elements being removed from the head of the list
 * should use the explicit macro for this purpose for optimum
 * efficiency. A singly-linked list may only be traversed in the forward
 * direction.  Singly-linked lists are ideal for applications with large
 * datasets and few or no removals or for implementing a LIFO queue.
 *
 * A list is headed by a single forward pointer (or an array of forward
 * pointers for a hash table header). The elements are doubly linked
 * so that an arbitrary element can be removed without a need to
 * traverse the list. New elements can be added to the list before
 * or after an existing element or at the head of the list. A list
 * may only be traversed in the forward direction.
 *
 * A simple queue is headed by a pair of pointers, one the head of the
 * list and the other to the tail of the list. The elements are singly
 * linked to save space, so elements can only be removed from the
 * head of the list. New elements can be added to the list after
 * an existing element, at the head of the list, or at the end of the
 * list. A simple queue may only be traversed in the forward direction.
 *
 * A tail queue is headed by a pair of pointers, one to the head of the
 * list and the other to the tail of the list. The elements are doubly
 * linked so that an arbitrary element can be removed without a need to
 * traverse the list. New elements can be added to the list before or
 * after an existing element, at the head of the list, or at the end of
 * the list. A tail queue may be traversed in either direction.
 *
 * For details on the use of these macros, see the queue(3) manual page.
 */

/*
 * List definitions.
 */
#define QLIST_HEAD(name, type)                                          \
struct name {                                                           \
        struct type *lh_first;  /* first element */                     \
}

#define QLIST_HEAD_INITIALIZER(head)                                    \
        { NULL }

#define QLIST_ENTRY(type)                                               \
struct {                                                                \
        struct type *le_next;   /* next element */                      \
        struct type **le_prev;  /* address of previous next element */  \
}

/*
 * List functions.
 */
#define QLIST_INIT(head) do {                                           \
        (head)->lh_first = NULL;                                        \
} while (/*CONSTCOND*/0)

#define QLIST_SWAP(dstlist, srclist, field) do {                        \
        void *tmplist;                                                  \
        tmplist = (srclist)->lh_first;                                  \
        (srclist)->lh_first = (dstlist)->lh_first;                      \
        if ((srclist)->lh_first != NULL) {                              \
            (srclist)->lh_first->field.le_prev = &(srclist)->lh_first;  \
        }                                                               \
        (dstlist)->lh_first = tmplist;                                  \
        if ((dstlist)->lh_first != NULL) {                              \
            (dstlist)->lh_first->field.le_prev = &(dstlist)->lh_first;  \
        }                                                               \
} while (/*CONSTCOND*/0)

#define QLIST_INSERT_AFTER(listelm, elm, field) do {                    \
        if (((elm)->field.le_next = (listelm)->field.le_next) != NULL)  \
                (listelm)->field.le_next->field.le_prev =               \
                    &(elm)->field.le_next;                              \
        (listelm)->field.le_next = (elm);                               \
        (elm)->field.le_prev = &(listelm)->field.le_next;               \
} while (/*CONSTCOND*/0)

#define QLIST_INSERT_BEFORE(listelm, elm, field) do {                   \
        (elm)->field.le_prev = (listelm)->field.le_prev;                \
        (elm)->field.le_next = (listelm);                               \
        *(listelm)->field.le_prev = (elm);                              \
        (listelm)->field.le_prev = &(elm)->field.le_next;               \
} while (/*CONSTCOND*/0)

#define QLIST_INSERT_HEAD(head, elm, field) do {                        \
        if (((elm)->field.le_next = (head)->lh_first) != NULL)          \
                (head)->lh_first->field.le_prev = &(elm)->field.le_next;\
        (head)->lh_first = (elm);                                       \
        (elm)->field.le_prev = &(head)->lh_first;                       \
} while (/*CONSTCOND*/0)

#define QLIST_REMOVE(elm, field) do {                                   \
        if ((elm)->field.le_next != NULL)                               \
                (elm)->field.le_next->field.le_prev =                   \
                    (elm)->field.le_prev;                               \
        *(elm)->field.le_prev = (elm)->field.le_next;                   \
        (elm)->field.le_next = NULL;                                    \
        (elm)->field.le_prev = NULL;                                    \
} while (/*CONSTCOND*/0)

/*
 * Like QLIST_REMOVE() but safe to call when elm is not in a list
 */
#define QLIST_SAFE_REMOVE(elm, field) do {                              \
        if ((elm)->field.le_prev != NULL) {                             \
                if ((elm)->field.le_next != NULL)                       \
                        (elm)->field.le_next->field.le_prev =           \
                            (elm)->field.le_prev;                       \
                *(elm)->field.le_prev = (elm)->field.le_next;           \
                (elm)->field.le_next = NULL;                            \
                (elm)->field.le_prev = NULL;                            \
        }                                                               \
} while (/*CONSTCOND*/0)

/* Is elm in a list? */
#define QLIST_IS_INSERTED(elm, field) ((elm)->field.le_prev != NULL)

#define QLIST_FOREACH(var, head, field)                                 \
        for ((var) = ((head)->lh_first);                                \
                (var);                                                  \
                (var) = ((var)->field.le_next))

#define QLIST_FOREACH_SAFE(var, head, field, next_var)                  \
        for ((var) = ((head)->lh_first);                                \
                (var) && ((next_var) = ((var)->field.le_next), 1);      \
                (var) = (next_var))

/*
 * List access methods.
 */
#define QLIST_EMPTY(head)                ((head)->lh_first == NULL)
#define QLIST_FIRST(head)                ((head)->lh_first)
#define QLIST_NEXT(elm, field)           ((elm)->field.le_next)


/*
 * Singly-linked List definitions.
 */
#define QSLIST_HEAD(name, type)                                          \
struct name {                                                           \
        struct type *slh_first; /* first element */                     \
}

#define QSLIST_HEAD_INITIALIZER(head)                                    \
        { NULL }

#define QSLIST_ENTRY(type)                                               \
struct {                                                                \
        struct type *sle_next;  /* next element */                      \
}

/*
 * Singly-linked List functions.
 */
#define QSLIST_INIT(head) do {                                           \
        (head)->slh_first = NULL;                                       \
} while (/*CONSTCOND*/0)

#define QSLIST_INSERT_AFTER(slistelm, elm, field) do {                   \
        (elm)->field.sle_next = (slistelm)->field.sle_next;             \
        (slistelm)->field.sle_next = (elm);                             \
} while (/*CONSTCOND*/0)

#define QSLIST_INSERT_HEAD(head, elm, field) do {                        \
        (elm)->field.sle_next = (head)->slh_first;                       \
        (head)->slh_first = (elm);                                       \
} while (/*CONSTCOND*/0)

#define QSLIST_INSERT_HEAD_ATOMIC(head, elm, field) do {                     \
        typeof(elm) save_sle_next;                                           \
        do {                                                                 \
            save_sle_next = (elm)->field.sle_next = (head)->slh_first;       \
        } while (atomic_cmpxchg(&(head)->slh_first, save_sle_next, (elm)) != \
                 save_sle_next);                                             \
} while (/*CONSTCOND*/0)

#define QSLIST_MOVE_ATOMIC(dest, src) do {                               \
        (dest)->slh_first = atomic_xchg(&(src)->slh_first, NULL);        \
} while (/*CONSTCOND*/0)

#define QSLIST_REMOVE_HEAD(head, field) do {                             \
        typeof((head)->slh_first) elm = (head)->slh_first;               \
        (head)->slh_first = elm->field.sle_next;                         \
        elm->field.sle_next = NULL;                                      \
} while (/*CONSTCOND*/0)

#define QSLIST_REMOVE_AFTER(slistelm, field) do {                       \
        typeof(slistelm) next = (slistelm)->field.sle_next;             \
        (slistelm)->field.sle_next = next->field.sle_next;              \
        next->field.sle_next = NULL;                                    \
} while (/*CONSTCOND*/0)

#define QSLIST_REMOVE(head, elm, type, field) do {                      \
    if ((head)->slh_first == (elm)) {                                   \
        QSLIST_REMOVE_HEAD((head), field);                              \
    } else {                                                            \
        struct type *curelm = (head)->slh_first;                        \
        while (curelm->field.sle_next != (elm))                         \
            curelm = curelm->field.sle_next;                            \
        curelm->field.sle_next = curelm->field.sle_next->field.sle_next; \
        (elm)->field.sle_next = NULL;                                   \
    }                                                                   \
} while (/*CONSTCOND*/0)

#define QSLIST_FOREACH(var, head, field)                                 \
        for((var) = (head)->slh_first; (var); (var) = (var)->field.sle_next)

#define QSLIST_FOREACH_SAFE(var, head, field, tvar)                      \
        for ((var) = QSLIST_FIRST((head));                               \
            (var) && ((tvar) = QSLIST_NEXT((var), field), 1);            \
            (var) = (tvar))

/*
 * Singly-linked List access methods.
 */
#define QSLIST_EMPTY(head)       ((head)->slh_first == NULL)
#define QSLIST_FIRST(head)       ((head)->slh_first)
#define QSLIST_NEXT(elm, field)  ((elm)->field.sle_next)


/*
 * Simple queue definitions.
 */
#define QSIMPLEQ_HEAD(name, type)                                       \
struct name {                                                           \
    struct type *sqh_first;    /* first element */                      \
    struct type **sqh_last;    /* addr of last next element */          \
}

#define QSIMPLEQ_HEAD_INITIALIZER(head)                                 \
    { NULL, &(head).sqh_first }

#define QSIMPLEQ_ENTRY(type)                                            \
struct {                                                                \
    struct type *sqe_next;    /* next element */                        \
}

/*
 * Simple queue functions.
 */
#define QSIMPLEQ_INIT(head) do {                                        \
    (head)->sqh_first = NULL;                                           \
    (head)->sqh_last = &(head)->sqh_first;                              \
} while (/*CONSTCOND*/0)

#define QSIMPLEQ_INSERT_HEAD(head, elm, field) do {                     \
    if (((elm)->field.sqe_next = (head)->sqh_first) == NULL)            \
        (head)->sqh_last = &(elm)->field.sqe_next;                      \
    (head)->sqh_first = (elm);                                          \
} while (/*CONSTCOND*/0)

#define QSIMPLEQ_INSERT_TAIL(head, elm, field) do {                     \
    (elm)->field.sqe_next = NULL;                                       \
    *(head)->sqh_last = (elm);                                          \
    (head)->sqh_last = &(elm)->field.sqe_next;                          \
} while (/*CONSTCOND*/0)

#define QSIMPLEQ_INSERT_AFTER(head, listelm, elm, field) do {           \
    if (((elm)->field.sqe_next = (listelm)->field.sqe_next) == NULL)    \
        (head)->sqh_last = &(elm)->field.sqe_next;                      \
    (listelm)->field.sqe_next = (elm);                                  \
} while (/*CONSTCOND*/0)

#define QSIMPLEQ_REMOVE_HEAD(head, field) do {                          \
    typeof((head)->sqh_first) elm = (head)->sqh_first;                  \
    if (((head)->sqh_first = elm->field.sqe_next) == NULL)              \
        (head)->sqh_last = &(head)->sqh_first;                          \
    elm->field.sqe_next = NULL;                                         \
} while (/*CONSTCOND*/0)

#define QSIMPLEQ_SPLIT_AFTER(head, elm, field, removed) do {            \
    QSIMPLEQ_INIT(removed);                                             \
    if (((removed)->sqh_first = (head)->sqh_first) != NULL) {           \
        if (((head)->sqh_first = (elm)->field.sqe_next) == NULL) {      \
            (head)->sqh_last = &(head)->sqh_first;                      \
        }                                                               \
        (removed)->sqh_last = &(elm)->field.sqe_next;                   \
        (elm)->field.sqe_next = NULL;                                   \
    }                                                                   \
} while (/*CONSTCOND*/0)

#define QSIMPLEQ_REMOVE(head, elm, type, field) do {                    \
    if ((head)->sqh_first == (elm)) {                                   \
        QSIMPLEQ_REMOVE_HEAD((head), field);                            \
    } else {                                                            \
        struct type *curelm = (head)->sqh_first;                        \
        while (curelm->field.sqe_next != (elm))                         \
            curelm = curelm->field.sqe_next;                            \
        if ((curelm->field.sqe_next =                                   \
            curelm->field.sqe_next->field.sqe_next) == NULL)            \
                (head)->sqh_last = &(curelm)->field.sqe_next;           \
        (elm)->field.sqe_next = NULL;                                   \
    }                                                                   \
} while (/*CONSTCOND*/0)

#define QSIMPLEQ_FOREACH(var, head, field)                              \
    for ((var) = ((head)->sqh_first);                                   \
        (var);                                                          \
        (var) = ((var)->field.sqe_next))

#define QSIMPLEQ_FOREACH_SAFE(var, head, field, next)                   \
    for ((var) = ((head)->sqh_first);                                   \
        (var) && ((next = ((var)->field.sqe_next)), 1);                 \
        (var) = (next))

#define QSIMPLEQ_CONCAT(head1, head2) do {                              \
    if (!QSIMPLEQ_EMPTY((head2))) {                                     \
        *(head1)->sqh_last = (head2)->sqh_first;                        \
        (head1)->sqh_last = (head2)->sqh_last;                          \
        QSIMPLEQ_INIT((head2));                                         \
    }                                                                   \
} while (/*CONSTCOND*/0)

#define QSIMPLEQ_PREPEND(head1, head2) do {                             \
    if (!QSIMPLEQ_EMPTY((head2))) {                                     \
        *(head2)->sqh_last = (head1)->sqh_first;                        \
        (head1)->sqh_first = (head2)->sqh_first;                          \
        QSIMPLEQ_INIT((head2));                                         \
    }                                                                   \
} while (/*CONSTCOND*/0)

#define QSIMPLEQ_LAST(head, type, field)                                \
    (QSIMPLEQ_EMPTY((head)) ?                                           \
        NULL :                                                          \
            ((struct type *)(void *)                                    \
        ((char *)((head)->sqh_last) - offsetof(struct type, field))))

/*
 * Simple queue access methods.
 */
#define QSIMPLEQ_EMPTY_ATOMIC(head) (atomic_read(&((head)->sqh_first)) == NULL)
#define QSIMPLEQ_EMPTY(head)        ((head)->sqh_first == NULL)
#define QSIMPLEQ_FIRST(head)        ((head)->sqh_first)
#define QSIMPLEQ_NEXT(elm, field)   ((elm)->field.sqe_next)

typedef struct QTailQLink {
    void *tql_next;
    struct QTailQLink *tql_prev;
} QTailQLink;

/*
 * Tail queue definitions.  The union acts as a poor man template, as if
 * it were QTailQLink<type>.
 */
#define QTAILQ_HEAD(name, type)                                         \
union name {                                                            \
        struct type *tqh_first;       /* first element */               \
        QTailQLink tqh_circ;          /* link for circular backwards list */ \
}

#define QTAILQ_HEAD_INITIALIZER(head)                                   \
        { .tqh_circ = { NULL, &(head).tqh_circ } }

#define QTAILQ_ENTRY(type)                                              \
union {                                                                 \
        struct type *tqe_next;        /* next element */                \
        QTailQLink tqe_circ;          /* link for circular backwards list */ \
}

/*
 * Tail queue functions.
 */
#define QTAILQ_INIT(head) do {                                          \
        (head)->tqh_first = NULL;                                       \
        (head)->tqh_circ.tql_prev = &(head)->tqh_circ;                  \
} while (/*CONSTCOND*/0)

#define QTAILQ_INSERT_HEAD(head, elm, field) do {                       \
        if (((elm)->field.tqe_next = (head)->tqh_first) != NULL)        \
            (head)->tqh_first->field.tqe_circ.tql_prev =                \
                &(elm)->field.tqe_circ;                                 \
        else                                                            \
            (head)->tqh_circ.tql_prev = &(elm)->field.tqe_circ;         \
        (head)->tqh_first = (elm);                                      \
        (elm)->field.tqe_circ.tql_prev = &(head)->tqh_circ;             \
} while (/*CONSTCOND*/0)

#define QTAILQ_INSERT_TAIL(head, elm, field) do {                       \
        (elm)->field.tqe_next = NULL;                                   \
        (elm)->field.tqe_circ.tql_prev = (head)->tqh_circ.tql_prev;     \
        (head)->tqh_circ.tql_prev->tql_next = (elm);                    \
        (head)->tqh_circ.tql_prev = &(elm)->field.tqe_circ;             \
} while (/*CONSTCOND*/0)

#define QTAILQ_INSERT_AFTER(head, listelm, elm, field) do {             \
        if (((elm)->field.tqe_next = (listelm)->field.tqe_next) != NULL)\
            (elm)->field.tqe_next->field.tqe_circ.tql_prev =            \
                &(elm)->field.tqe_circ;                                 \
        else                                                            \
            (head)->tqh_circ.tql_prev = &(elm)->field.tqe_circ;         \
        (listelm)->field.tqe_next = (elm);                              \
        (elm)->field.tqe_circ.tql_prev = &(listelm)->field.tqe_circ;    \
} while (/*CONSTCOND*/0)

#define QTAILQ_INSERT_BEFORE(listelm, elm, field) do {                       \
        (elm)->field.tqe_circ.tql_prev = (listelm)->field.tqe_circ.tql_prev; \
        (elm)->field.tqe_next = (listelm);                                   \
        (listelm)->field.tqe_circ.tql_prev->tql_next = (elm);                \
        (listelm)->field.tqe_circ.tql_prev = &(elm)->field.tqe_circ;         \
} while (/*CONSTCOND*/0)

#define QTAILQ_REMOVE(head, elm, field) do {                            \
        if (((elm)->field.tqe_next) != NULL)                            \
            (elm)->field.tqe_next->field.tqe_circ.tql_prev =            \
                (elm)->field.tqe_circ.tql_prev;                         \
        else                                                            \
            (head)->tqh_circ.tql_prev = (elm)->field.tqe_circ.tql_prev; \
        (elm)->field.tqe_circ.tql_prev->tql_next = (elm)->field.tqe_next; \
        (elm)->field.tqe_circ.tql_prev = NULL;                          \
        (elm)->field.tqe_circ.tql_next = NULL;                          \
        (elm)->field.tqe_next = NULL;                                   \
} while (/*CONSTCOND*/0)

/* remove @left, @right and all elements in between from @head */
#define QTAILQ_REMOVE_SEVERAL(head, left, right, field) do {            \
        if (((right)->field.tqe_next) != NULL)                          \
            (right)->field.tqe_next->field.tqe_circ.tql_prev =          \
                (left)->field.tqe_circ.tql_prev;                        \
        else                                                            \
            (head)->tqh_circ.tql_prev = (left)->field.tqe_circ.tql_prev; \
        (left)->field.tqe_circ.tql_prev->tql_next = (right)->field.tqe_next; \
    } while (/*CONSTCOND*/0)

#define QTAILQ_FOREACH(var, head, field)                                \
        for ((var) = ((head)->tqh_first);                               \
                (var);                                                  \
                (var) = ((var)->field.tqe_next))

#define QTAILQ_FOREACH_SAFE(var, head, field, next_var)                 \
        for ((var) = ((head)->tqh_first);                               \
                (var) && ((next_var) = ((var)->field.tqe_next), 1);     \
                (var) = (next_var))

#define QTAILQ_FOREACH_REVERSE(var, head, field)                        \
        for ((var) = QTAILQ_LAST(head);                                 \
                (var);                                                  \
                (var) = QTAILQ_PREV(var, field))

#define QTAILQ_FOREACH_REVERSE_SAFE(var, head, field, prev_var)         \
        for ((var) = QTAILQ_LAST(head);                                 \
             (var) && ((prev_var) = QTAILQ_PREV(var, field), 1);        \
             (var) = (prev_var))

/*
 * Tail queue access methods.
 */
#define QTAILQ_EMPTY(head)               ((head)->tqh_first == NULL)
#define QTAILQ_FIRST(head)               ((head)->tqh_first)
#define QTAILQ_NEXT(elm, field)          ((elm)->field.tqe_next)
#define QTAILQ_IN_USE(elm, field)        ((elm)->field.tqe_circ.tql_prev != NULL)

#define QTAILQ_LINK_PREV(link)                                          \
        ((link).tql_prev->tql_prev->tql_next)
#define QTAILQ_LAST(head)                                               \
        ((typeof((head)->tqh_first)) QTAILQ_LINK_PREV((head)->tqh_circ))
#define QTAILQ_PREV(elm, field)                                         \
        ((typeof((elm)->field.tqe_next)) QTAILQ_LINK_PREV((elm)->field.tqe_circ))

#define field_at_offset(base, offset, type)                                    \
        ((type *) (((char *) (base)) + (offset)))

/*
 * Raw access of elements of a tail queue head.  Offsets are all zero
 * because it's a union.
 */
#define QTAILQ_RAW_FIRST(head)                                                 \
        field_at_offset(head, 0, void *)
#define QTAILQ_RAW_TQH_CIRC(head)                                              \
        field_at_offset(head, 0, QTailQLink)

/*
 * Raw access of elements of a tail entry
 */
#define QTAILQ_RAW_NEXT(elm, entry)                                            \
        field_at_offset(elm, entry, void *)
#define QTAILQ_RAW_TQE_CIRC(elm, entry)                                        \
        field_at_offset(elm, entry, QTailQLink)
/*
 * Tail queue traversal using pointer arithmetic.
 */
#define QTAILQ_RAW_FOREACH(elm, head, entry)                                   \
        for ((elm) = *QTAILQ_RAW_FIRST(head);                                  \
             (elm);                                                            \
             (elm) = *QTAILQ_RAW_NEXT(elm, entry))
/*
 * Tail queue insertion using pointer arithmetic.
 */
#define QTAILQ_RAW_INSERT_TAIL(head, elm, entry) do {                           \
        *QTAILQ_RAW_NEXT(elm, entry) = NULL;                                    \
        QTAILQ_RAW_TQE_CIRC(elm, entry)->tql_prev = QTAILQ_RAW_TQH_CIRC(head)->tql_prev; \
        QTAILQ_RAW_TQH_CIRC(head)->tql_prev->tql_next = (elm);                  \
        QTAILQ_RAW_TQH_CIRC(head)->tql_prev = QTAILQ_RAW_TQE_CIRC(elm, entry);  \
} while (/*CONSTCOND*/0)

#define QLIST_RAW_FIRST(head)                                                  \
        field_at_offset(head, 0, void *)

#define QLIST_RAW_NEXT(elm, entry)                                             \
        field_at_offset(elm, entry, void *)

#define QLIST_RAW_PREVIOUS(elm, entry)                                         \
        field_at_offset(elm, entry + sizeof(void *), void *)

#define QLIST_RAW_FOREACH(elm, head, entry)                                    \
        for ((elm) = *QLIST_RAW_FIRST(head);                                   \
             (elm);                                                            \
             (elm) = *QLIST_RAW_NEXT(elm, entry))

#define QLIST_RAW_INSERT_AFTER(head, prev, elem, entry) do {                   \
        *QLIST_RAW_NEXT(prev, entry) = elem;                                   \
        *QLIST_RAW_PREVIOUS(elem, entry) = QLIST_RAW_NEXT(prev, entry);        \
        *QLIST_RAW_NEXT(elem, entry) = NULL;                                   \
} while (0)

#define QLIST_RAW_INSERT_HEAD(head, elm, entry) do {                           \
        void *first = *QLIST_RAW_FIRST(head);                                  \
        *QLIST_RAW_FIRST(head) = elm;                                          \
        *QLIST_RAW_PREVIOUS(elm, entry) = QLIST_RAW_FIRST(head);               \
        if (first) {                                                           \
            *QLIST_RAW_NEXT(elm, entry) = first;                               \
            *QLIST_RAW_PREVIOUS(first, entry) = QLIST_RAW_NEXT(elm, entry);    \
        } else {                                                               \
            *QLIST_RAW_NEXT(elm, entry) = NULL;                                \
        }                                                                      \
} while (0)

#endif /* QEMU_SYS_QUEUE_H */
