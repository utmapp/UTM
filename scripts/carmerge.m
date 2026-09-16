//
// Copyright © 2026 Turing Software, LLC. All rights reserved.
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

// carmerge: replaces the pre-macOS 26 app icon renditions in an Assets.car with the
// ones from another Assets.car, keeping the Icon Composer renditions intact.
//
// Since Xcode 26.1, actool ignores an .appiconset that shares its name with an .icon
// and renders the older OS icons from the .icon instead. We compile the .appiconset
// separately and use CoreUI (private) to swap its renditions into the final catalog.
//
// usage: carmerge <destination.car> <source.car> <icon name>...

#include <dlfcn.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

typedef struct {
    uint16_t attribute;
    uint16_t value;
} RenditionKeyToken;

typedef struct {
    uint32_t tag;
    uint32_t version;
    uint32_t count;
    uint32_t attributes[];
} RenditionKeyFormat;

@interface CUICommonAssetStorage : NSObject
- (instancetype)initWithPath:(NSString *)path;
- (instancetype)initWithPath:(NSString *)path forWriting:(BOOL)forWriting;
- (const RenditionKeyFormat *)keyFormat;
- (NSArray *)allAssetKeys;
- (NSData *)assetForKey:(NSData *)key;
- (const RenditionKeyToken *)renditionKeyForName:(const char *)name hotSpot:(CGPoint *)hotSpot;
@end

@interface CUIMutableCommonAssetStorage : CUICommonAssetStorage
- (BOOL)setAsset:(NSData *)asset forKey:(NSData *)key;
- (void)removeAssetForKey:(NSData *)key;
- (BOOL)writeToDiskAndCompact:(BOOL)compact;
@end

@interface CUIRenditionKey : NSObject
- (const RenditionKeyToken *)keyList;
@end

@interface CUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (NSArray *)imagesWithName:(NSString *)name;
@end

@interface CUINamedImage : NSObject
@property (readonly) CGImageRef image;
@end

static const uint16_t kAttributeElement = 1;
static const uint16_t kAttributePart = 2;
static const uint16_t kAttributeDimension1 = 8;
static const uint16_t kAttributeIdentifier = 17;

static const uint16_t kPartMultiSizedImage = 218;
static const uint16_t kPartIconImage = 220;
static const uint16_t kElementPackedAsset = 9;

static const uint16_t kLayoutInternalLink = 1003;
static const uint32_t kTLVInternalLink = 1010;
static const uint32_t kInternalLinkMagic = 'INLK';
static const uint32_t kRenditionMagic = 'CTSI';

// Packed atlases copied from the source catalog are moved to dimension1 values above
// this so they cannot collide with the destination's own atlases.
static const uint16_t kPackedAtlasOffset = 100;

// CSI header: magic, version, flags, width, height, scale, pixel format, color space,
// modification time, layout, reserved, name[128], info list length, bitmap info
static const size_t kRenditionLayoutOffset = 36;
static const size_t kRenditionInfoLengthOffset = 168;
static const size_t kRenditionTLVOffset = 184;

typedef NSDictionary<NSNumber *, NSNumber *> Tokens;

static void fail(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2) __attribute__((noreturn));

static void fail(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    fprintf(stderr, "error: carmerge: %s\n", message.UTF8String);
    exit(1);
}

static Tokens *tokensFromList(const RenditionKeyToken *list) {
    NSMutableDictionary *tokens = [NSMutableDictionary dictionary];
    for (; list && list->attribute; list++) {
        tokens[@(list->attribute)] = @(list->value);
    }
    return tokens;
}

static uint16_t tokenValue(Tokens *tokens, uint16_t attribute) {
    return tokens[@(attribute)].unsignedShortValue;
}

static NSData *keyFromTokens(const RenditionKeyFormat *format, Tokens *tokens) {
    NSMutableData *key = [NSMutableData dataWithLength:format->count * sizeof(uint16_t)];
    uint16_t *values = key.mutableBytes;
    NSMutableSet *unused = [NSMutableSet setWithArray:tokens.allKeys];
    for (uint32_t i = 0; i < format->count; i++) {
        NSNumber *attribute = @(format->attributes[i]);
        values[i] = tokens[attribute].unsignedShortValue;
        [unused removeObject:attribute];
    }
    for (NSNumber *attribute in unused) {
        if (tokens[attribute].unsignedShortValue != 0) {
            fail(@"attribute %@ is not in the destination key format", attribute);
        }
    }
    return key;
}

static Tokens *tokensByOffsettingAtlas(Tokens *tokens) {
    NSMutableDictionary *offset = [tokens mutableCopy];
    offset[@(kAttributeDimension1)] = @(tokenValue(tokens, kAttributeDimension1) + kPackedAtlasOffset);
    return offset;
}

static uint32_t readUInt32(NSData *data, size_t offset) {
    uint32_t value;
    if (offset + sizeof(value) > data.length) {
        fail(@"truncated rendition");
    }
    memcpy(&value, (const uint8_t *)data.bytes + offset, sizeof(value));
    return value;
}

static void writeUInt32(NSMutableData *data, size_t offset, uint32_t value) {
    memcpy((uint8_t *)data.mutableBytes + offset, &value, sizeof(value));
}

static uint16_t renditionLayout(NSData *rendition) {
    if (readUInt32(rendition, 0) != kRenditionMagic) {
        fail(@"unrecognized rendition format");
    }
    return (uint16_t)readUInt32(rendition, kRenditionLayoutOffset);
}

/// Points one internal link at the offset copy of its packed atlas.
/// - Parameters:
///   - block: Internal link record, including its type and length
///   - atlasTokens: Returns the key of the packed atlas in the source catalog
/// - Returns: Rewritten record
static NSData *linkByOffsettingAtlas(NSData *block, Tokens **atlasTokens) {
    // type, length, magic, reserved, frame (4 x uint32), layout (uint16), key length, key tokens
    static const size_t kKeyLengthOffset = 8 + 4 + 4 + 16 + 2;
    static const size_t kKeyOffset = kKeyLengthOffset + 4;
    if (readUInt32(block, 8) != kInternalLinkMagic) {
        fail(@"unrecognized internal link format");
    }
    uint32_t keyLength = readUInt32(block, kKeyLengthOffset);
    if (kKeyOffset + keyLength > block.length || keyLength % sizeof(RenditionKeyToken) != 0) {
        fail(@"truncated internal link");
    }
    NSMutableData *list = [NSMutableData dataWithBytes:(const uint8_t *)block.bytes + kKeyOffset length:keyLength];
    [list increaseLengthBy:sizeof(RenditionKeyToken)]; // ensure termination
    Tokens *tokens = tokensFromList(list.bytes);
    if (tokenValue(tokens, kAttributeElement) != kElementPackedAsset) {
        fail(@"internal link does not point to a packed atlas");
    }
    *atlasTokens = tokens;
    Tokens *offsetTokens = tokensByOffsettingAtlas(tokens);
    NSMutableData *newList = [NSMutableData data];
    for (NSNumber *attribute in [offsetTokens.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        RenditionKeyToken token = { attribute.unsignedShortValue, offsetTokens[attribute].unsignedShortValue };
        [newList appendBytes:&token length:sizeof(token)];
    }
    RenditionKeyToken terminator = { 0, 0 };
    [newList appendBytes:&terminator length:sizeof(terminator)];
    NSMutableData *result = [NSMutableData dataWithBytes:block.bytes length:kKeyOffset];
    [result appendData:newList];
    [result appendBytes:(const uint8_t *)block.bytes + kKeyOffset + keyLength
                 length:block.length - kKeyOffset - keyLength];
    writeUInt32(result, 4, readUInt32(block, 4) + (uint32_t)(newList.length - keyLength));
    writeUInt32(result, kKeyLengthOffset, (uint32_t)newList.length);
    return result;
}

/// Points every internal link in a rendition at the offset copies of their packed atlases.
/// - Parameters:
///   - rendition: Internal link rendition from the source catalog
///   - atlases: Collects the keys of the packed atlases in the source catalog
/// - Returns: Rewritten rendition
static NSData *renditionByOffsettingAtlases(NSData *rendition, NSMutableArray<Tokens *> *atlases) {
    uint32_t infoLength = readUInt32(rendition, kRenditionInfoLengthOffset);
    size_t end = kRenditionTLVOffset + infoLength;
    if (end > rendition.length) {
        fail(@"truncated rendition info list");
    }
    NSMutableData *result = [NSMutableData dataWithBytes:rendition.bytes length:kRenditionTLVOffset];
    size_t offset = kRenditionTLVOffset;
    size_t links = 0;
    while (offset + 8 <= end) {
        size_t length = readUInt32(rendition, offset + 4);
        if (offset + 8 + length > end) {
            fail(@"truncated record in rendition info list");
        }
        NSData *block = [rendition subdataWithRange:NSMakeRange(offset, 8 + length)];
        if (readUInt32(rendition, offset) == kTLVInternalLink) {
            Tokens *atlasTokens = nil;
            block = linkByOffsettingAtlas(block, &atlasTokens);
            [atlases addObject:atlasTokens];
            links++;
        }
        [result appendData:block];
        offset += 8 + length;
    }
    if (links == 0) {
        fail(@"internal link rendition is missing its link");
    }
    [result appendBytes:(const uint8_t *)rendition.bytes + end length:rendition.length - end];
    writeUInt32(result, kRenditionInfoLengthOffset, (uint32_t)(result.length - rendition.length) + infoLength);
    return result;
}

static BOOL isLegacyIconPart(Tokens *tokens, uint16_t identifier) {
    uint16_t part = tokenValue(tokens, kAttributePart);
    return tokenValue(tokens, kAttributeIdentifier) == identifier &&
           (part == kPartIconImage || part == kPartMultiSizedImage);
}

static uint16_t identifierForName(CUICommonAssetStorage *storage, const char *name, NSString *label) {
    CGPoint hotSpot;
    uint16_t identifier = tokenValue(tokensFromList([storage renditionKeyForName:name hotSpot:&hotSpot]), kAttributeIdentifier);
    if (identifier == 0) {
        fail(@"'%s' not found in %@ catalog", name, label);
    }
    return identifier;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 4) {
            fprintf(stderr, "usage: %s <destination.car> <source.car> <icon name>...\n", argv[0]);
            return 2;
        }
        if (!dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_NOW)) {
            fail(@"cannot load CoreUI");
        }
        Class mutableStorageClass = NSClassFromString(@"CUIMutableCommonAssetStorage");
        Class storageClass = NSClassFromString(@"CUICommonAssetStorage");
        if (![mutableStorageClass instancesRespondToSelector:@selector(initWithPath:forWriting:)] ||
            ![mutableStorageClass instancesRespondToSelector:@selector(setAsset:forKey:)] ||
            ![storageClass instancesRespondToSelector:@selector(renditionKeyForName:hotSpot:)] ||
            ![NSClassFromString(@"CUIRenditionKey") instancesRespondToSelector:@selector(keyList)]) {
            fail(@"CoreUI interface has changed");
        }
        // -initWithPath: on the mutable class creates a new empty catalog
        CUIMutableCommonAssetStorage *destination = [[mutableStorageClass alloc] initWithPath:@(argv[1]) forWriting:YES];
        CUICommonAssetStorage *source = [[storageClass alloc] initWithPath:@(argv[2])];
        if (!destination.keyFormat || !source.keyFormat) {
            fail(@"cannot open asset catalogs");
        }
        const RenditionKeyFormat *destinationFormat = destination.keyFormat;
        const RenditionKeyFormat *sourceFormat = source.keyFormat;
        NSMutableDictionary<NSData *, Tokens *> *atlases = [NSMutableDictionary dictionary];
        for (int i = 3; i < argc; i++) {
            const char *name = argv[i];
            uint16_t destinationIdentifier = identifierForName(destination, name, @"destination");
            uint16_t sourceIdentifier = identifierForName(source, name, @"source");
            int removed = 0;
            for (CUIRenditionKey *renditionKey in destination.allAssetKeys) {
                Tokens *tokens = tokensFromList(renditionKey.keyList);
                if (isLegacyIconPart(tokens, destinationIdentifier)) {
                    [destination removeAssetForKey:keyFromTokens(destinationFormat, tokens)];
                    removed++;
                }
            }
            int added = 0;
            for (CUIRenditionKey *renditionKey in source.allAssetKeys) {
                Tokens *tokens = tokensFromList(renditionKey.keyList);
                if (!isLegacyIconPart(tokens, sourceIdentifier)) {
                    continue;
                }
                NSData *rendition = [source assetForKey:keyFromTokens(sourceFormat, tokens)];
                if (renditionLayout(rendition) == kLayoutInternalLink) {
                    NSMutableArray<Tokens *> *linked = [NSMutableArray array];
                    rendition = renditionByOffsettingAtlases(rendition, linked);
                    for (Tokens *atlasTokens in linked) {
                        atlases[keyFromTokens(sourceFormat, atlasTokens)] = atlasTokens;
                    }
                }
                NSMutableDictionary *destinationTokens = [tokens mutableCopy];
                destinationTokens[@(kAttributeIdentifier)] = @(destinationIdentifier);
                if (![destination setAsset:rendition forKey:keyFromTokens(destinationFormat, destinationTokens)]) {
                    fail(@"cannot add rendition for '%s'", name);
                }
                added++;
            }
            if (added == 0) {
                fail(@"'%s' has no icon images in source catalog", name);
            }
            if (removed == 0) {
                // actool no longer emits what we expect, so the icons we add may not be
                // the ones macOS picks
                fail(@"'%s' has no icon images in destination catalog", name);
            }
            printf("%s: replaced %d renditions with %d\n", name, removed, added);
        }
        for (NSData *sourceKey in atlases) {
            NSData *atlas = [source assetForKey:sourceKey];
            if (!atlas) {
                fail(@"packed atlas missing from source catalog");
            }
            Tokens *tokens = tokensByOffsettingAtlas(atlases[sourceKey]);
            if (![destination setAsset:atlas forKey:keyFromTokens(destinationFormat, tokens)]) {
                fail(@"cannot add packed atlas");
            }
        }
        if (![destination writeToDiskAndCompact:YES]) {
            fail(@"cannot write %s", argv[1]);
        }
        // the rendition format is undocumented, so make sure what we wrote still decodes
        CUICatalog *catalog = [[NSClassFromString(@"CUICatalog") alloc] initWithURL:[NSURL fileURLWithPath:@(argv[1])] error:NULL];
        for (int i = 3; i < argc; i++) {
            NSUInteger images = 0;
            for (CUINamedImage *image in [catalog imagesWithName:@(argv[i])]) {
                if (![image respondsToSelector:@selector(image)]) {
                    continue; // multi-size image set, which has no image of its own
                }
                if (!image.image) {
                    fail(@"'%s' has an icon image that cannot be decoded", argv[i]);
                }
                images++;
            }
            if (images == 0) {
                fail(@"'%s' has no icon images after merging", argv[i]);
            }
        }
    }
    return 0;
}
