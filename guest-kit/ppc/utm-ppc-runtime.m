// Objective-C 2.0 property accessors GCC calls for @synthesize, which Mac OS X 10.4's
// libobjc does not export (10.5 has them; these local copies are used on both).
#import <Foundation/Foundation.h>
#include <pthread.h>
#include <string.h>

static pthread_mutex_t utm_property_lock = PTHREAD_MUTEX_INITIALIZER;

void objc_copyStruct(void *dest, const void *src, ptrdiff_t size, BOOL atomic, BOOL hasStrong)
{
    (void)hasStrong;
    if (atomic) pthread_mutex_lock(&utm_property_lock);
    memmove(dest, src, size);
    if (atomic) pthread_mutex_unlock(&utm_property_lock);
}

id objc_getProperty(id self, SEL _cmd, ptrdiff_t offset, BOOL atomic)
{
    (void)_cmd;
    id *slot = (id *)((char *)self + offset);
    if (!atomic) return *slot;
    pthread_mutex_lock(&utm_property_lock);
    id value = [*slot retain];
    pthread_mutex_unlock(&utm_property_lock);
    return [value autorelease];
}

void objc_setProperty(id self, SEL _cmd, ptrdiff_t offset, id newValue, BOOL atomic, signed char shouldCopy)
{
    (void)_cmd;
    id *slot = (id *)((char *)self + offset);
    id value = shouldCopy ? [newValue copyWithZone:NULL] : [newValue retain];
    if (atomic) pthread_mutex_lock(&utm_property_lock);
    id old = *slot;
    *slot = value;
    if (atomic) pthread_mutex_unlock(&utm_property_lock);
    [old release];
}
