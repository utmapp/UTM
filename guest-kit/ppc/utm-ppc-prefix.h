// Support for desugar-objc.py: boxed expressions and scoped autorelease pools for GCC's
// Objective-C (NeXT runtime) on Mac OS X 10.4/10.5 PowerPC.
#import <Foundation/Foundation.h>

// No ARC: bridged casts are plain casts.
#define __bridge
#define __bridge_transfer
#define __bridge_retained

static inline void UTMPoolDrain(NSAutoreleasePool **pool) { [*pool drain]; }
#define UTM_POOL_CLEANUP __attribute__((cleanup(UTMPoolDrain)))

static inline NSNumber *UTMBoxBool(signed char v) { return [NSNumber numberWithBool:v]; }
static inline NSNumber *UTMBoxInt(int v) { return [NSNumber numberWithInt:v]; }
static inline NSNumber *UTMBoxUInt(unsigned int v) { return [NSNumber numberWithUnsignedInt:v]; }
static inline NSNumber *UTMBoxLong(long v) { return [NSNumber numberWithLong:v]; }
static inline NSNumber *UTMBoxULong(unsigned long v) { return [NSNumber numberWithUnsignedLong:v]; }
static inline NSNumber *UTMBoxLongLong(long long v) { return [NSNumber numberWithLongLong:v]; }
static inline NSNumber *UTMBoxULongLong(unsigned long long v) { return [NSNumber numberWithUnsignedLongLong:v]; }
static inline NSNumber *UTMBoxDouble(double v) { return [NSNumber numberWithDouble:v]; }
static inline NSString *UTMBoxCString(const char *v) { return [NSString stringWithUTF8String:v]; }

// BOOL is signed char here, as in clang's @(BOOL) boxing.
#define UTMBox(x) _Generic((x), \
    signed char: UTMBoxBool, unsigned char: UTMBoxUInt, short: UTMBoxInt, unsigned short: UTMBoxUInt, \
    int: UTMBoxInt, unsigned int: UTMBoxUInt, long: UTMBoxLong, unsigned long: UTMBoxULong, \
    long long: UTMBoxLongLong, unsigned long long: UTMBoxULongLong, float: UTMBoxDouble, double: UTMBoxDouble, \
    char *: UTMBoxCString, const char *: UTMBoxCString)(x)
